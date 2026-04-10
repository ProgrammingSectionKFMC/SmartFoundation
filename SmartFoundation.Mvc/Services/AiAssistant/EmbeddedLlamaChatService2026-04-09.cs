using LLama;
using LLama.Abstractions;
using LLama.Common;
using LLama.Native;
using Microsoft.Extensions.Options;
using SmartFoundation.Application.Mapping;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SmartFoundation.Mvc.Services.AiAssistant;

internal sealed class EmbeddedLlamaChatService2 : IAiChatService, IDisposable
{
    private readonly IAiKnowledgeBase _kb;
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<EmbeddedLlamaChatService2> _log;
    private readonly ISmartComponentService? _dataEngine;
    private readonly LLamaModelHolder _modelHolder;

    // ✅ General executor (أسرع من إنشاء جديد كل مرة)
    private readonly StatelessExecutor _generalExecutor;
    private readonly IContextParams _generalCtxParams;

    // ✅ Context Pool (أهم تحسين)
    private readonly SemaphoreSlim _poolGate;
    private readonly ConcurrentQueue<LLamaContext> _ctxPool = new();

    private const int GeneralMaxAnswerLen = 1500;

    private static readonly (string Key, string Label, string[] Keywords)[] Entities =
 {
    ("Residents", "مستفيد", new[] { "مستفيد", "المستفيد", "المستفيدين", "ساكن", "Residents" }),

    ("BuildingDetails", "مبنى" , new[] { "مبنى", "المباني", "Building", "BuildingDetails" }),

    ("BuildingClass", "فئة مبنى" , new[] {
        "فئة مبنى", "فئات المباني", "تصنيف مبنى", "تصنيفات المباني",
        "نوع مبنى", "أنواع المباني", "BuildingClass"
    }),

    ("ResidentClass", "فئة مستفيد" , new[] {
        "فئة مستفيد", "فئات المستفيدين", "تصنيف مستفيد", "تصنيفات المستفيدين",
        "نوع مستفيد", "أنواع المستفيدين", "ResidentClass"
    }),

    ("WaitingListByResident", "قوائم الانتظار" , new[] {
        "قوائم الانتظار", "قائمة الانتظار", "قائمة انتظار", "قوائم انتظار",
        "سجل انتظار", "سجلات الانتظار", "سجلات انتظار",
        "خطاب تسكين", "خطابات التسكين", "خطابات تسكين",
        "نقل سجل", "نقل سجلات", "طلب نقل", "طلبات النقل",
        "WaitingListByResident", "WaitingList"
    }),

    // ✅ الجديد (أضفه هنا)
    ("Regulations", "اللوائح والأنظمة", new[] {
        "لائحة", "اللوائح",
        "نظام", "الأنظمة",
        "مادة", "المادة", "فقرة",
        "تعميم", "تعليمات",
        "ضوابط", "شروط", "استثناء", "استثناءات",
        "آلية", "كيفية التطبيق",
        "التأمين الاحترازي", "الإخلاء", "أحقية السكن"
    }),
};

    private sealed class PendingState
    {
        public string Intent { get; set; } = "";
        public string OriginalMessage { get; set; } = "";
        public DateTimeOffset At { get; set; } = DateTimeOffset.UtcNow;
    }

    private sealed class GeneralChatTurn
    {
        public string Role { get; set; } = ""; // "user" | "assistant"
        public string Text { get; set; } = "";
        public DateTimeOffset At { get; set; } = DateTimeOffset.UtcNow;
    }

    private sealed class GeneralChatState
    {
        public ConcurrentQueue<GeneralChatTurn> Turns { get; } = new();
        public DateTimeOffset LastAccessUtc { get; set; } = DateTimeOffset.UtcNow;
    }

    private static readonly ConcurrentDictionary<string, GeneralChatState> _general = new();
    private static readonly TimeSpan GeneralTtl = TimeSpan.FromMinutes(20);
    private const int GeneralMaxTurns = 10;



    private static void CleanupGeneral()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var kv in _general)
            if (now - kv.Value.LastAccessUtc > GeneralTtl)
                _general.TryRemove(kv.Key, out _);
    }

    private static void AddGeneralTurn(string convoKey, string role, string text)
    {
        if (string.IsNullOrWhiteSpace(convoKey)) return;

        var st = _general.GetOrAdd(convoKey, _ => new GeneralChatState());
        st.LastAccessUtc = DateTimeOffset.UtcNow;

        st.Turns.Enqueue(new GeneralChatTurn { Role = role, Text = text, At = DateTimeOffset.UtcNow });

        while (st.Turns.Count > GeneralMaxTurns)
            st.Turns.TryDequeue(out _);
    }

    private static List<GeneralChatTurn> GetGeneralTurns(string convoKey)
    {
        if (string.IsNullOrWhiteSpace(convoKey)) return new();
        if (!_general.TryGetValue(convoKey, out var st)) return new();
        st.LastAccessUtc = DateTimeOffset.UtcNow;
        return st.Turns.ToList();
    }

    private static readonly ConcurrentDictionary<string, PendingState> _pending = new();
    private static readonly TimeSpan PendingTtl = TimeSpan.FromMinutes(2);

    public EmbeddedLlamaChatService2(
        IAiKnowledgeBase kb,
        IOptions<AiAssistantOptions> opt,
        LLamaModelHolder modelHolder,
        ILogger<EmbeddedLlamaChatService2> log,
        ISmartComponentService? dataEngine = null)
    {
        _kb = kb;
        _opt = opt.Value;
        _log = log;
        _dataEngine = dataEngine;
        _modelHolder = modelHolder;

        // ✅ عدد الـContexts (Pool size)
        var poolSize = Math.Max(1, _opt.MaxParallelRequests);

        // ✅ Gate يعكس pool size
        _poolGate = new SemaphoreSlim(poolSize, poolSize);

        // ✅ أنشئ contexts مرة واحدة فقط
        // Qwen2.5-3B أفضل توازن: 1024~2048
        var ctxSize = (uint)Math.Clamp(_opt.ContextSize, 512, 2048);
        var threads = Math.Max(1, _opt.Threads);

        for (int i = 0; i < poolSize; i++)
        {
            var ctx = _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
            {
                ContextSize = 1024,
                Threads = threads
            });
            _ctxPool.Enqueue(ctx);
        }

        _generalCtxParams = new ModelParams(_modelHolder.ModelPath)
        {
            ContextSize = ctxSize,     // نفس ctxSize اللي فوق
            Threads = threads          // نفس threads اللي فوق
        };

        _generalExecutor = new StatelessExecutor(_modelHolder.Weights, _generalCtxParams, _log);

        _log.LogInformation(
            "EmbeddedLlamaChatService created using model: {Path} | pool={Pool} | ctx={Ctx} | threads={Threads}",
            _modelHolder.ModelPath, poolSize, ctxSize, threads);
    }

    public async Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct)
    {
        var startTime = DateTimeOffset.UtcNow;

        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
        var combinedCt = linkedCts.Token;

        try
        {
            CleanupGeneral();
            CleanupPending();

            var originalMsg = (request.Message ?? "").Trim();
            if (string.IsNullOrWhiteSpace(originalMsg))
                return await SaveAndReturn(request, startTime, "🙂", Array.Empty<KnowledgeChunk>(), null, null);

            var msg = originalMsg;
            var pageKey = ResolvePageKey(request);
            var convoKey = ResolveConversationKey(request);

            _log.LogInformation(
                "AI_CHAT: convoKey='{ConvoKey}', pageKey='{PageKey}', msg='{Msg}'",
                convoKey ?? "", pageKey ?? "", originalMsg.Replace("\n", " ").Trim()
            );

            var intent = NormalizeIntent(originalMsg);
            var entityHits = DetectEntities(originalMsg);
            if (entityHits.Count == 0 &&
                !string.IsNullOrWhiteSpace(pageKey) &&
                IsKnownEntity(pageKey))
            {
                entityHits.Add((pageKey, GetEntityLabel(pageKey)));
            }
            string? selectedEntityKey = null;

            // ---- Pending follow-up support (محسّن) ----
            if (!string.IsNullOrWhiteSpace(convoKey) &&
                _pending.TryGetValue(convoKey, out var pendingState) &&
                DateTimeOffset.UtcNow - pendingState.At <= PendingTtl)
            {
                // لو المستخدم كتب فقط الكيان بعد سؤال توضيح
                if (string.IsNullOrWhiteSpace(intent) &&
                    entityHits.Count == 1)
                {
                    intent = pendingState.Intent;
                    selectedEntityKey = entityHits[0].Key;
                    msg = pendingState.OriginalMessage;
                }
            }

            // ---- لو المستخدم كتب فقط اسم كيان ----
            if (string.IsNullOrWhiteSpace(intent) &&
                selectedEntityKey is null &&
                entityHits.Count == 1 &&
                IsShortEntityAnswer(originalMsg))
            {
                var label = entityHits[0].Label;
                return await SaveAndReturn(
                    request, startTime,
                    $"ماذا تريد أن تعمل في {label}؟ إضافة؟ تعديل؟ حذف؟ بحث؟ طباعة؟",
                    Array.Empty<KnowledgeChunk>(),
                    entityHits[0].Key,
                    null
                );
            }

            // =========================
            // ✅ تحديد عام vs نظام
            // =========================
            bool isSystem =
                !string.IsNullOrWhiteSpace(intent) ||
                entityHits.Count > 0 ||
                (!string.IsNullOrWhiteSpace(pageKey) && IsKnownEntity(pageKey));

            bool isGeneral = !isSystem;

            // =========================
            // ✅ مسار المحادثة العامة (بدون KB)
            // =========================


            if (isGeneral)
            {
                if (!string.IsNullOrWhiteSpace(convoKey))
                    _pending.TryRemove(convoKey, out _);

                var systemOnlyMessage =
                    "أنا فيصل 👋\n" +
                    "المساعد الذكي مصمم فقط للإجابة عن النظام الموحد.\n\n" +
                    "اكتب سؤالك عن النظام بهذه الطريقة:\n" +
                    "• كيف أضيف مستفيد؟\n" +
                    "• كيف أضيف مبنى؟\n" +
                    "• كيف أبحث في قوائم الانتظار؟\n" +
                    "• كيف أطبع أو أصدّر؟";

                return await SaveAndReturn(
                    request,
                    startTime,
                    systemOnlyMessage,
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    null
                );
            }


            //if (isGeneral)
            //{
            //    if (!string.IsNullOrWhiteSpace(convoKey))
            //        _pending.TryRemove(convoKey, out _);

            //    // ردود سريعة بدون LLM (اختياري لكنه يسرّع)
            //    if (IsTrivialGreeting(originalMsg))
            //    {
            //        var quick = "هلا 👋 تفضل، وش تحب تسولف فيه؟";
            //        return await SaveAndReturn(request, startTime, quick, Array.Empty<KnowledgeChunk>(), null, null);
            //    }

            //    var generalAnswer = await AskLlmGeneralAsync(convoKey, originalMsg, combinedCt);
            //    generalAnswer = Clip(generalAnswer, GeneralMaxAnswerLen);

            //    // خزّن turnين (user + assistant)
            //    if (!string.IsNullOrWhiteSpace(convoKey))
            //    {
            //        AddGeneralTurn(convoKey, "user", originalMsg);
            //        AddGeneralTurn(convoKey, "assistant", generalAnswer);
            //    }

            //    return await SaveAndReturn(
            //        request,
            //        startTime,
            //        generalAnswer,
            //        Array.Empty<KnowledgeChunk>(),
            //        null,
            //        null
            //    );
            //}

            // =========================
            // ✅ مسار النظام (RAG)
            // =========================
            var isProcedural = !string.IsNullOrWhiteSpace(intent);
            var topK = Math.Max(8, _opt.RetrievalTopK);

            var searchQuery = msg;
            if (!string.IsNullOrWhiteSpace(selectedEntityKey))
                searchQuery = $"{msg} {GetEntityLabel(selectedEntityKey)}";

            //var citations = _kb.Search(searchQuery, topK);
            var normalizedMsg = NormalizeArabic(originalMsg);
            var citations = _kb.Search(normalizedMsg + " لائحه نظام", topK);
            //var citations = _kb.Search(originalMsg + " لائحة نظام", topK);

            // ✅ مسار خاص للأنظمة واللوائح
            if (intent == "REGULATION")
            {
                var detected = DetectEntities(originalMsg);
                var entityKey = detected.FirstOrDefault().Key ?? "Regulations";

                if (citations.Count == 0)
                {
                    return await SaveAndReturn(
                        request, startTime,
                        "لم أجد نصًا نظاميًا مطابقًا لهذا السؤال.",
                        citations, entityKey, intent
                    );
                }

                var topic = ResolveRegulationTopic(originalMsg);

                string result = "";
                string sourceName = "مرجع غير معروف";

                foreach (var citation in citations)
                {
                    var doc = _kb.GetDocumentBySource(citation.Source ?? "") ?? citation.Text ?? "";
                    if (string.IsNullOrWhiteSpace(doc))
                        continue;

                    string extracted = "";

                    // 1) نحاول استخراج قسم بعنوان واضح
                    if (!string.IsNullOrWhiteSpace(topic))
                    {
                        extracted = ExtractSection(doc, $"## {topic}");
                        extracted = TrimToSingleSection(RemoveKeywords(extracted)).Trim();
                    }

                    // 2) إذا فشل، نأخذ أفضل فقرة/مقطع من النص الكامل
                    if (string.IsNullOrWhiteSpace(extracted))
                    {
                        var searchText = !string.IsNullOrWhiteSpace(topic) ? topic : originalMsg;
                        extracted = ExtractBestRegulationPassage(doc, searchText); extracted = RemoveKeywords(extracted).Trim();
                    }

                    if (!string.IsNullOrWhiteSpace(extracted))
                    {
                        // ❌ تجاهل نتائج النماذج أو الشاشات
                        if (extracted.Contains("رقم الهوية") ||
                            extracted.Contains("الرقم العام") ||
                            extracted.Contains("اضغط زر"))
                        {
                            continue;
                        }

                        result = extracted;
                        sourceName = citation.Source ?? "مرجع غير معروف";
                        break;
                    }
                }

                if (string.IsNullOrWhiteSpace(result))
                    result = "لم يتم العثور على نص واضح لهذا الموضوع. تأكد من أن ملف الـ MD يحتوي النص الفعلي وليس العنوان أو الهيكل فقط.";

                if (!string.IsNullOrWhiteSpace(topic))
                {
                    result =
            $@"📘 الموضوع: {topic}

📄 النص:
{result}

📚 المرجع:
دليل اجراءات الاسكان والممتلكات";
                }
                else
                {
                    result =
            $@"📄 النص:
{result}

📚 المرجع:
دليل اجراءات الاسكان والممتلكات";
                }

                return await SaveAndReturn(
                    request, startTime,
                    result,
                    citations,
                    entityKey,
                    intent
                );
            }

            if (isProcedural)
            {
                var detected = DetectEntities(originalMsg);

                if (!string.IsNullOrWhiteSpace(selectedEntityKey))
                {
                    detected = new List<(string Key, string Label)>
                    {
                        (selectedEntityKey, GetEntityLabel(selectedEntityKey))
                    };
                }

                if (detected.Count == 0 && !string.IsNullOrWhiteSpace(pageKey) && IsKnownEntity(pageKey))
                    detected.Add((pageKey, GetEntityLabel(pageKey)));

                if (detected.Count == 0)
                {
                    if (!string.IsNullOrWhiteSpace(convoKey))
                        _pending[convoKey] = new PendingState { Intent = intent, OriginalMessage = originalMsg, At = DateTimeOffset.UtcNow };

                    return await SaveAndReturn(
                        request, startTime,
                        BuildDisambiguationQuestion(intent, Entities.Select(e => e.Label).ToArray()),
                        citations, null, intent
                    );
                }

                if (detected.Count > 1)
                {
                    if (!string.IsNullOrWhiteSpace(convoKey))
                        _pending[convoKey] = new PendingState { Intent = intent, OriginalMessage = originalMsg, At = DateTimeOffset.UtcNow };

                    var opts = detected.Select(x => x.Label).Distinct().ToArray();
                    return await SaveAndReturn(
                        request, startTime,
                        BuildDisambiguationQuestion(intent, opts),
                        citations, null, intent
                    );
                }

                var entityKey = detected[0].Key;

                if (citations.Count > 0)
                {
                    var filtered = citations
                        .Where(c => !string.IsNullOrWhiteSpace(c.Source) &&
                                    c.Source.Contains(entityKey, StringComparison.OrdinalIgnoreCase))
                        .ToList();
                    if (filtered.Count > 0) citations = filtered;
                }

                if (citations.Count == 0)
                {
                    var suggestions = GetSuggestions(entityKey);
                    return await SaveAndReturn(
                        request, startTime,
                        $"لم أجد معلومات محددة لهذا السؤال.\n\n{suggestions}",
                        citations, entityKey, intent
                    );
                }

                var header = ResolveHeader(entityKey, intent, originalMsg);
                if (string.IsNullOrWhiteSpace(header))
                {
                    var suggestions = GetSuggestions(entityKey);
                    return await SaveAndReturn(
                        request, startTime,
                        $"لا يوجد شرح لهذه العملية في الدليل الحالي.\n\n{suggestions}",
                        citations, entityKey, intent
                    );
                }

                // (هنا أنت ما تستخدم LLM للـ procedural، فقط استخراج section)
                string? best = null;
                var tryCount = Math.Min(6, citations.Count);
                var fullDocCache = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                for (int i = 0; i < tryCount; i++)
                {
                    combinedCt.ThrowIfCancellationRequested();

                    var c = citations[i];
                    var text = c.Text ?? "";

                    if (!ContainsAny(text, "## إضافة", "## تعديل", "## حذف", "## طباعة", "## تصدير", "## البحث"))
                    {
                        if (!string.IsNullOrWhiteSpace(c.Source))
                        {
                            if (!fullDocCache.TryGetValue(c.Source, out var cached))
                            {
                                cached = _kb.GetDocumentBySource(c.Source) ?? "";
                                fullDocCache[c.Source] = cached;
                            }
                            if (!string.IsNullOrWhiteSpace(cached)) text = cached;
                        }
                    }

                    var extracted = ExtractSection(text, header);
                    if (!string.IsNullOrWhiteSpace(extracted) &&
                        !extracted.Equals(header, StringComparison.OrdinalIgnoreCase))
                    {
                        best = extracted;
                        break;
                    }
                }

                var answerText = string.IsNullOrWhiteSpace(best) || best.Equals(header, StringComparison.OrdinalIgnoreCase)
                    ? $"السؤال غير واضح، ممكن تحدد سؤالك؟\n\n{GetSuggestions(entityKey)}"
                    : TrimToSingleSection(RemoveKeywords(best)).Trim();

                if (string.IsNullOrWhiteSpace(answerText))
                    answerText = "لا يوجد قسم مطابق لهذا السؤال في الدليل الحالي.";

                if (!string.IsNullOrWhiteSpace(convoKey))
                    _pending.TryRemove(convoKey, out _);

                return await SaveAndReturn(request, startTime, answerText, citations, entityKey, intent);
            }

            // ---- غير إجرائي لكن داخل النظام: إذا لا توجد اقتباسات ----
            if (citations.Count == 0)
            {
                return await SaveAndReturn(
                    request, startTime,
                    "لم أفهم بشكل كافي. جرّب: كيف أضيف؟ كيف أبحث؟ كيف أطبع؟ واذكر (مستفيد/مبنى/قوائم انتظار...).",
                    citations, null, null
                );
            }

            // ---- داخل النظام + citations: نخلي LLM يصيغ الإجابة ----
            var systemPrompt = BuildSystemPrompt(request, citations);
            var answerFromLlm = await AskLlmWithCitationsAsync(msg, systemPrompt, combinedCt);
            if (string.IsNullOrWhiteSpace(answerFromLlm))
                answerFromLlm = "وضح سؤالك أكثر.";

            return await SaveAndReturn(request, startTime, answerFromLlm, citations, null, null);
        }
        catch (OperationCanceledException) when (timeoutCts.Token.IsCancellationRequested)
        {
            _log.LogWarning("AI_TIMEOUT: Request took longer than 30 seconds");
            return await SaveAndReturn(
                request, startTime,
                "معليش، أخذ وقت طويل. حاول تختصر السؤال أو تحدده.\nمثال: بدل (كيف أضيف؟) قل (كيف أضيف مستفيد؟).",
                Array.Empty<KnowledgeChunk>(), null, null
            );
        }
        catch (OperationCanceledException)
        {
            return await SaveAndReturn(
                request, startTime,
                "تم إيقاف العملية.",
                Array.Empty<KnowledgeChunk>(), null, null
            );
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "AI_ERROR");
            return await SaveAndReturn(
                request, startTime,
                "صار خطأ غير متوقع في المساعد.",
                Array.Empty<KnowledgeChunk>(), null, null
            );
        }
    }

    // =========================
    // ✅ LLM Helpers (Pool-based)
    // =========================
    private async Task<LLamaContext> AcquireContextAsync(CancellationToken ct)
    {
        await _poolGate.WaitAsync(ct);
        if (_ctxPool.TryDequeue(out var ctx))
            return ctx;

        // احتياط (المفروض ما يصير)
        _poolGate.Release();
        throw new InvalidOperationException("Context pool empty unexpectedly.");
    }

    private void ReleaseContext(LLamaContext ctx)
    {
        _ctxPool.Enqueue(ctx);
        _poolGate.Release();
    }

    private LLamaContext CreateNewContext()
    {
        var ctxSize = (uint)Math.Clamp(_opt.ContextSize, 512, 2048);
        var threads = Math.Max(1, _opt.Threads);

        return _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
        {
            ContextSize = ctxSize,
            Threads = threads
        });
    }

    private void ReleaseGeneralContext(LLamaContext ctx)
    {
        try { ctx.Dispose(); } catch { }

        // استبدله بواحد جديد نظيف
        var fresh = CreateNewContext();
        _ctxPool.Enqueue(fresh);
        _poolGate.Release();
    }

    private async Task<string> AskLlmGeneralAsync(string? convoKey, string userMsg, CancellationToken ct)
    {
        var ctx = await AcquireContextAsync(ct);

        try
        {
            // ✅ خذ آخر كم turn فقط لتقليل التوكنز وتسريع
            var history = (!string.IsNullOrWhiteSpace(convoKey))
                ? GetGeneralTurns(convoKey!).TakeLast(6).ToList()
                : new List<GeneralChatTurn>();

            // ✅ ChatML لـ Qwen (مع تعليمات خفيفة وطبيعية)
            var sbPrompt = new StringBuilder();
            sbPrompt.AppendLine("<|system|>");
            sbPrompt.AppendLine("أنت مساعد دردشة ودي وخفيف دم. أجب بالعربية وبشكل طبيعي وبشرح كافٍ.");
            sbPrompt.AppendLine("أكمل إجابتك حتى تنتهي الفكرة. لا تنهِ الرد بكلمة ناقصة أو بنقاط.");
            sbPrompt.AppendLine("إذا طلب المستخدم نكتة: اكتب النكتة كاملة (سؤال + جواب) بدون مقدمات طويلة.");
            sbPrompt.AppendLine("إذا كان السؤال يحتاج تفاصيل، أعطِ تفاصيل.");
            sbPrompt.AppendLine("إذا كانت إجابة قصيرة تكفي، اجعلها قصيرة."); sbPrompt.AppendLine("إذا كان السؤال عن نظام SmartFoundation اطلب اسم الشاشة/الصفحة.");
            sbPrompt.AppendLine("ممنوع تكتب أي ترويسات مثل <|system|> أو <|user|> داخل الإجابة.");
            sbPrompt.AppendLine("</s>");

            // ✅ أضف history (قص كل رسالة لتقليل الحمل)
            foreach (var t in history)
            {
                var txt = Clip(t.Text ?? "", 300);

                if (string.Equals(t.Role, "user", StringComparison.OrdinalIgnoreCase))
                {
                    sbPrompt.AppendLine("<|user|>");
                    sbPrompt.AppendLine(txt);
                    sbPrompt.AppendLine("</s>");
                }
                else
                {
                    sbPrompt.AppendLine("<|assistant|>");
                    sbPrompt.AppendLine(txt);
                    sbPrompt.AppendLine("</s>");
                }
            }

            sbPrompt.AppendLine("<|user|>");
            sbPrompt.AppendLine(userMsg);
            sbPrompt.AppendLine("</s>");
            sbPrompt.AppendLine("<|assistant|>");

            var prompt = sbPrompt.ToString();

            // ✅ InteractiveExecutor أسرع عادةً مع Pool
            var executor = new InteractiveExecutor(ctx);

            var inferenceParams = new InferenceParams
            {
                MaxTokens = 350,
                AntiPrompts = new List<string>
    {
        "<|system|>",
        "<|user|>",
        "<|assistant|>"
    },
                SamplingPipeline = new LLama.Sampling.DefaultSamplingPipeline
                {
                    Temperature = 0.6f,
                    Seed = 1337
                }
            };

            var sb = new StringBuilder();
            await foreach (var piece in executor.InferAsync(prompt, inferenceParams, ct))
            {
                sb.Append(piece);

                if (sb.Length > 2000) break;
            }

            var answer = CleanLlmArtifacts(sb.ToString()).Trim();


            // ✅ قص أي تسريب ChatML لو ظهر (احتياط)
            var cut = answer.IndexOf("<|assistant|>", StringComparison.Ordinal);
            if (cut >= 0) answer = answer[..cut];


           

            if (string.IsNullOrWhiteSpace(answer))
                answer = "تمام 🙂 وش ودّك نتكلم عنه؟";

            return answer;
        }
        finally
        {
            // ✅ أهم جزء: بما أننا ما نقدر نمسح KV cache في إصدارك
            // نعمل Replace للـContext بعد كل General request حتى ما تتلوث الحالة وتسبب تكرار
            try { ctx.Dispose(); } catch { }

            try
            {
                // أنشئ Context جديد "نظيف" وأعده للـPool بدل القديم
                var fresh = _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
                {
                    // خلك على نفس ctx اللي عندك في الإعدادات (أنت الآن 2048)
                    ContextSize = (uint)Math.Clamp(_opt.ContextSize, 512, 2048),
                    Threads = Math.Max(1, _opt.Threads)
                });

                _ctxPool.Enqueue(fresh);
            }
            catch
            {
                // لو فشل الإنشاء لأي سبب، لا نخلي الـSemaphore معلّق
                // (هنا ما نقدر نرجع ctx لأنه تم Dispose، لكن على الأقل نفك القفل)
            }
            finally
            {
                _poolGate.Release();
            }
        }
    }

    private async Task<string> AskLlmWithCitationsAsync(string userMsg, string systemPrompt, CancellationToken ct)
    {
        var ctx = await AcquireContextAsync(ct);
        try
        {
            var executor = new InteractiveExecutor(ctx);

            var prompt = $"""
<|im_start|>system
أنت مساعد ذكي داخل نظام SmartFoundation ومتخصص في أنظمة ولوائح الإسكان والممتلكات.

تعليمات مهمة:
- أجب بالعربية الفصحى المبسطة.
- اعتمد فقط على مقاطع المساعدة المعطاة لك.
- لا تخترع معلومات غير موجودة.
- إذا لم تجد جوابًا واضحًا في النص، قل: لم يتم العثور على نص واضح لهذا الموضوع.
- إذا كان السؤال عن تعريف، اذكر التعريف مباشرة.
- إذا كان السؤال عن شروط، اذكر الشروط بنقاط.
- إذا كان السؤال عن خطوات أو إجراء، اذكر الخطوات مرتبة.
- إذا كان السؤال عن مقارنة، اذكر الطرفين بوضوح.
- لا تكرر التعليمات.
- لا تضف مقدمات طويلة.
<|im_end|>
<|im_start|>user
مقاطع المساعدة:
{systemPrompt}

سؤال المستخدم:
{userMsg}
<|im_end|>
<|im_start|>assistant
""";

            var inferenceParams = new InferenceParams
            {
                MaxTokens = Math.Min(_opt.MaxTokens, 320),
                AntiPrompts = new List<string>
            {
                "<|im_start|>",
                "<|im_end|>"
            },
                SamplingPipeline = new LLama.Sampling.DefaultSamplingPipeline
                {
                    Temperature = 0.25f,
                    Seed = 1337
                }
            };

            var sb = new StringBuilder();
            await foreach (var piece in executor.InferAsync(prompt, inferenceParams, ct))
            {
                sb.Append(piece);
                if (sb.Length > 2500) break;
            }

            return CleanLlmArtifacts(sb.ToString());
        }
        finally
        {
            ReleaseContext(ctx);
        }
    }

    //    private async Task<string> AskLlmWithCitationsAsync(string userMsg, string systemPrompt, CancellationToken ct)
    //    {
    //        var ctx = await AcquireContextAsync(ct);
    //        try
    //        {
    //            var executor = new InteractiveExecutor(ctx);

    //            // ✅ قالب “سؤال/إجابة” أفضل مع Qwen من [System]/[User]
    //            var prompt = $"""
    //أنت مساعد داخل نظام SmartFoundation.
    //أجب بالعربية وباختصار ودقة.
    //استخدم مقاطع المساعدة فقط إذا كانت مفيدة ولا تكرر تعليمات النظام.

    //مقاطع المساعدة:
    //{systemPrompt}

    //سؤال المستخدم:
    //{userMsg}

    //إجابتك:
    //""";

    //            var inferenceParams = new InferenceParams
    //            {
    //                MaxTokens = Math.Min(_opt.MaxTokens, 320),
    //                AntiPrompts = new List<string> { "سؤال المستخدم:", "مقاطع المساعدة:", "إجابتك:" },
    //                SamplingPipeline = new LLama.Sampling.DefaultSamplingPipeline
    //                {
    //                    Temperature = 0.25f,
    //                    Seed = 1337
    //                }
    //            };

    //            var sb = new StringBuilder();
    //            await foreach (var piece in executor.InferAsync(prompt, inferenceParams, ct))
    //            {
    //                sb.Append(piece);
    //                if (sb.Length > 2500) break;
    //            }

    //            return CleanLlmArtifacts(sb.ToString());
    //        }
    //        finally
    //        {
    //            ReleaseContext(ctx);
    //        }
    //    }

    private static bool IsTrivialGreeting(string msg)
    {
        msg = (msg ?? "").Trim().ToLowerInvariant();
        msg = msg.Replace("؟", "").Replace("!", "").Replace(".", "").Trim();
        return msg is "سلام" or "هلا" or "هلاا" or "هلا 👋" or "مرحبا" or "اهلا" or "hello" or "hi";
    }

    // =========================
    // ✅ Save + Utilities (كما عندك)
    // =========================
    private async Task<AiChatResult> SaveAndReturn(
      AiChatRequest request,
      DateTimeOffset startTime,
      string answer,
      IReadOnlyList<KnowledgeChunk> citations,
      string? entityKey,
      string? intent)
    {
        var responseTime = (int)(DateTimeOffset.UtcNow - startTime).TotalMilliseconds;

        var chatId = await SaveChatHistoryAsync(
            request, answer, entityKey, intent, responseTime, citations?.Count ?? 0
        );

        return new AiChatResult(answer, citations)
        {
            ChatId = chatId,
            EntityKey = entityKey,
            Intent = intent
        };
    }

    private static string BuildDisambiguationQuestion(string intent, string[] options)
    {
        var verb = intent switch
        {
            "ADD" => "تضيف",
            "UPDATE" => "تعدل",
            "DELETE" => "تحذف",
            "PRINT" => "تطبع",
            "EXPORT" => "تصدّر",
            "SEARCH" => "تبحث",
            _ => "تعمل"
        };

        var opts = string.Join(" ؟ ", options.Select(o => o.Trim()).Where(o => o.Length > 0));
        return $"ماذا تريد أن {verb}؟ {opts}؟";
    }

    private static bool IsShortEntityAnswer(string msg)
    {
        msg = (msg ?? "").Trim().Replace("؟", "").Replace("?", "").Trim();
        if (msg.Length == 0 || msg.Length > 20) return false;

        var parts = msg.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length <= 2;
    }


    private static string CleanLlmArtifacts(string s)
    {
        if (string.IsNullOrWhiteSpace(s)) return "";

        s = s.Replace("[System]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("<|im_start|>", "", StringComparison.OrdinalIgnoreCase)
             .Replace("<|im_end|>", "", StringComparison.OrdinalIgnoreCase);

        while (s.Contains("\n\n\n"))
            s = s.Replace("\n\n\n", "\n\n");

        return s.Trim();
    }
    //private static string CleanLlmArtifacts(string s)
    //{
    //    if (string.IsNullOrWhiteSpace(s)) return "";

    //    s = s.Replace("[System]", "", StringComparison.OrdinalIgnoreCase)
    //         .Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
    //         .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase);

    //    while (s.Contains("\n\n\n"))
    //        s = s.Replace("\n\n\n", "\n\n");

    //    return s.Trim();
    //}


    private static List<(string Key, string Label)> DetectEntities(string message)
    {
        message ??= "";
        var hits = new List<(string Key, string Label)>();
        var normalizedMessage = NormalizeArabic(message);

        foreach (var e in Entities)
        {
            if (e.Keywords.Any(k => normalizedMessage.Contains(NormalizeArabic(k), StringComparison.Ordinal)))
                hits.Add((e.Key, e.Label));
        }

        return hits
            .GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();
    }
    //private static List<(string Key, string Label)> DetectEntities(string message)
    //{
    //    message ??= "";
    //    var hits = new List<(string Key, string Label)>();

    //    foreach (var e in Entities)
    //    {
    //        if (e.Keywords.Any(k => message.Contains(k, StringComparison.OrdinalIgnoreCase)))
    //            hits.Add((e.Key, e.Label));
    //    }

    //    return hits
    //        .GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
    //        .Select(g => g.First())
    //        .ToList();
    //}

    private static bool IsKnownEntity(string key)
        => Entities.Any(e => e.Key.Equals(key, StringComparison.OrdinalIgnoreCase));

    private static string GetEntityLabel(string key)
        => Entities.FirstOrDefault(e => e.Key.Equals(key, StringComparison.OrdinalIgnoreCase)).Label ?? key;

    private static void CleanupPending()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var kv in _pending)
        {
            if (now - kv.Value.At > PendingTtl)
                _pending.TryRemove(kv.Key, out _);
        }
    }

    private static string ResolvePageKey(AiChatRequest request)
    {
        var v =
            (GetPropString(request, "PageName") ??
             GetPropString(request, "Page") ??
             GetPropString(request, "Route") ??
             GetPropString(request, "Screen") ??
             "").Trim();

        if (v.Contains("WaitingList", StringComparison.OrdinalIgnoreCase)) return "WaitingListByResident";
        if (v.Contains("BuildingDetails", StringComparison.OrdinalIgnoreCase)) return "BuildingDetails";
        if (v.Contains("Residents", StringComparison.OrdinalIgnoreCase)) return "Residents";
        if (v.Contains("BuildingClass", StringComparison.OrdinalIgnoreCase)) return "BuildingClass";
        if (v.Contains("ResidentClass", StringComparison.OrdinalIgnoreCase)) return "ResidentClass";

        return v;
    }

    private static string ResolveConversationKey(AiChatRequest request)
    {
        var v =
            (GetPropString(request, "ConversationId") ??
             GetPropString(request, "ClientId") ??
             GetPropString(request, "userId") ??
             GetPropString(request, "UserId") ??
             GetPropString(request, "usersId") ??
             GetPropString(request, "UsersId") ??
             "").Trim();

        return v;
    }

    private static string? GetPropString(object obj, string propName)
    {
        var p = obj.GetType().GetProperty(propName);
        if (p == null) return null;
        var val = p.GetValue(obj);
        return val?.ToString();
    }

    private static string GetSuggestions(string entityKey)
    {
        return entityKey switch
        {
            "Residents" => "💡 جرب:\n• كيف أضيف مستفيد؟\n• كيف أعدل بيانات مستفيد؟\n• كيف أحذف مستفيد؟\n• كيف أبحث عن مستفيد؟",
            "BuildingDetails" => "💡 جرب:\n• كيف أضيف مبنى؟\n• كيف أعدل بيانات مبنى؟\n• كيف أحذف مبنى؟\n• كيف أبحث عن مبنى؟",
            "BuildingClass" => "💡 جرب:\n• كيف أضيف فئة مبنى؟\n• كيف أعدل فئة مبنى؟\n• كيف أحذف فئة مبنى؟\n• كيف أطبع قائمة فئات المباني؟",
            "ResidentClass" => "💡 جرب:\n• كيف أضيف فئة مستفيد؟\n• كيف أعدل فئة مستفيد؟\n• كيف أحذف فئة مستفيد؟",
            "WaitingListByResident" => "💡 جرب:\n• كيف أبحث عن مستفيد برقم الهوية؟\n• كيف أضيف سجل انتظار؟\n• كيف أنقل سجل انتظار لإدارة أخرى؟\n• كيف أضيف خطاب تسكين؟\n• كيف أحذف طلب نقل؟",
            _ => "💡 جرب: كيف أضيف؟ كيف أعدل؟ كيف أحذف؟ كيف أبحث؟"
        };
    }

    private static string ResolveHeader(string entityKey, string intent, string userQuery = "")
    {
        if (string.IsNullOrWhiteSpace(intent)) return "";

        // ✅ دعم اللوائح والأنظمة بشكل عام
        if (entityKey.Equals("Regulations", StringComparison.OrdinalIgnoreCase))
        {
            var topic = ResolveRegulationTopic(userQuery);

            // إذا قدرنا نستخرج موضوع من السؤال نرجع عنوانه مباشرة
            if (!string.IsNullOrWhiteSpace(topic))
                return $"## {topic}";

            // fallback عام: لا يوجد عنوان محدد
            return "##";
        }

        return (entityKey, intent) switch
        {
            ("Residents", "ADD") => "## إضافة مستفيد",
            ("Residents", "UPDATE") => "## تعديل مستفيد",
            ("Residents", "DELETE") => "## حذف مستفيد",
            ("Residents", "SEARCH") => "## البحث عن مستفيد",
            ("Residents", "PRINT") => "## طباعة تقرير المستفيدين",

            ("BuildingDetails", "ADD") => "## إضافة مبنى",
            ("BuildingDetails", "UPDATE") => "## تعديل مبنى",
            ("BuildingDetails", "DELETE") => "## حذف مبنى",
            ("BuildingDetails", "SEARCH") => "## البحث عن مبنى",
            ("BuildingDetails", "PRINT") => "## طباعة تقرير المباني",

            ("BuildingClass", "ADD") => "## إضافة فئة مبنى",
            ("BuildingClass", "UPDATE") => "## تعديل فئة مبنى",
            ("BuildingClass", "DELETE") => "## حذف فئة مبنى",
            ("BuildingClass", "SEARCH") => "## البحث عن فئة مبنى",
            ("BuildingClass", "PRINT") => "## طباعة تقرير فئات المباني",

            ("ResidentClass", "ADD") => "## إضافة فئة مستفيد",
            ("ResidentClass", "UPDATE") => "## تعديل فئة مستفيد",
            ("ResidentClass", "DELETE") => "## حذف فئة مستفيد",

            ("WaitingListByResident", "SEARCH") => "## البحث عن مستفيد",
            ("WaitingListByResident", "ADD") => "### إضافة سجل انتظار جديد",
            ("WaitingListByResident", "UPDATE") => "### تعديل سجل انتظار",
            ("WaitingListByResident", "DELETE") => "### حذف سجل انتظار",
            ("WaitingListByResident", "PRINT") => "## التصدير",
            ("WaitingListByResident", "EXPORT") => "## التصدير",

            ("Assign", "OPEN_ASSIGN") => "## إنشاء محضر تخصيص جديد",
            ("Assign", "CLOSE_ASSIGN") => "## إغلاق محضر التخصيص",
            ("Assign", "ASSIGN_HOUSE") => "## تخصيص منزل لمستفيد",
            ("Assign", "UPDATE_ASSIGN") => "## تعديل تخصيص منزل",
            ("Assign", "EXCLUDE_ASSIGN") => "## استبعاد مستفيد من محضر التخصيص",
            ("Assign", "SEARCH") => "## البحث عن مستفيد",
            ("Assign", "DETAILS") => "## عرض التفاصيل",
            ("Assign", "PRINT") => "## طباعة خطاب",
            ("Assign", "EXPORT") => "## تصدير البيانات",

            _ => ""
        };
    }



    private static string ResolveRegulationTopic(string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return "";

        var normalizedQuery = NormalizeArabic(query);

        var knownTopics = new[]
        {
        "العمر الافتراضي",
        "المنشاه السكنيه",
        "المنشاه العسكريه",
        "البند",
        "الصنف",
        "القوائم",
        "المعاينه",
        "اللائحه التنظيميه",
        "الرسوم",
        "الفتره الانتقاليه",
        "سكن العزاب",
        "سكن العائلات",
        "المعدات الثابته",
        "الغرامات",
        "التلف الجزئي",
        "التلف الكلي",
        "الضياع",
        "الصيانه",
        "الاهمال",
        "الاصلاح",
        "الاستبدال",
        "الانهاء",
        "الاحقيه",
        "التخصيص",
        "الاخلاء"
    };

        foreach (var topic in knownTopics.OrderByDescending(x => x.Length))
        {
            if (normalizedQuery.Contains(topic, StringComparison.Ordinal))
                return topic;
        }

        return "";
    }


    //    private static string ResolveRegulationTopic(string query)
    //    {
    //        if (string.IsNullOrWhiteSpace(query)) return "";

    //        query = query.Trim();

    //        var knownTopics = new[]
    //{
    //    "العمر الافتراضي",
    //    "المنشأة السكنية",
    //    "المنشأة العسكرية",
    //    "البند",
    //    "الصنف",
    //    "القوائم",
    //    "المعاينة",
    //    "اللائحة التنظيمية",
    //    "الرسوم",
    //    "الفترة الانتقالية",
    //    "سكن العزاب",
    //    "سكن العائلات",
    //    "المعدات الثابتة",
    //    "الغرامات",
    //    "التلف الجزئي",
    //    "التلف الكلي",
    //    "الضياع",
    //    "الصيانة",
    //    "الإهمال",
    //    "الإصلاح",
    //    "الاستبدال",
    //    "الإنهاء",
    //    "الأحقية",
    //    "التخصيص",
    //    "الإخلاء"
    //};

    //        foreach (var topic in knownTopics.OrderByDescending(x => x.Length))
    //        {
    //            if (query.Contains(topic, StringComparison.OrdinalIgnoreCase))
    //                return topic;
    //        }

    //        return "";
    //    }

    private static string ExtractSection(string text, string header)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(header)) return "";

        var h = System.Text.RegularExpressions.Regex.Escape(header.Trim());
        h = h.Replace("\\ ", "\\s+");

        var pattern = $"{h}\\s*\\r?\\n(?<body>[\\s\\S]*?)(?=\\r?\\n###?\\s|\\z)";
        var m = System.Text.RegularExpressions.Regex.Match(
            text,
            pattern,
            System.Text.RegularExpressions.RegexOptions.IgnoreCase
        );

        // ✅ لا ترجع العنوان فقط عند الفشل
        if (!m.Success) return "";

        return (header + "\n" + m.Groups["body"].Value).Trim();
    }

    private static string TrimToSingleSection(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";

        var sep = text.IndexOf("\n---", StringComparison.Ordinal);
        if (sep > 0) text = text[..sep];

        var first = text.IndexOf("\n## ", StringComparison.Ordinal);
        if (first >= 0)
        {
            var second = text.IndexOf("\n## ", first + 4, StringComparison.Ordinal);
            if (second > 0) text = text[..second];
        }

        return text.Trim();
    }

    private static string BuildSystemPrompt(AiChatRequest r, IReadOnlyList<KnowledgeChunk> citations)
    {
        var kb = string.Join(
            "\n\n---\n\n",
            citations.Select((c, i) => $"[مقطع {i + 1}]\n{Clip(RemoveKeywords(c.Text ?? ""), 800)}")
        );

        return $"""
سياق الصفحة:
- {r.PageTitle} | {r.PageUrl}

{kb}
""";
    }

    private static string NormalizeIntent(string query)
    {
        //if (string.IsNullOrWhiteSpace(query)) return "";
        //query = query.Trim().ToLowerInvariant();
        //query = query.Replace("؟", "").Replace("?", "").Trim();

        if (string.IsNullOrWhiteSpace(query)) return "";

        query = NormalizeArabic(query);

        if (ContainsAny(query, "تعديل", "عدّل", "عدل", "تحديث", "حدث", "تغيير", "غير", "صحح", "تصحيح"))
            return "UPDATE";

        if (ContainsAny(query, "حذف", "احذف", "مسح", "امسح", "ازالة", "إزالة", "الغاء", "إلغاء"))
            return "DELETE";

        if (ContainsAny(query, "طباعة", "اطبع", "تقرير", "pdf", "excel", "اكسل", "تصدير", "صدّر"))
            return "PRINT";

        if (ContainsAny(query, "بحث", "ابحث", "ادور", "وين", "فين"))
            return "SEARCH";

        if (ContainsAny(query, "اضافة", "إضافة", "اضف", "أضف", "اضيف", "أضيف", "تسجيل", "سجل", "انشاء", "إنشاء", "جديد"))
            return "ADD";

        if (ContainsAny(query,
    "أضيف", "اضافة", "إنشاء",
    "تعديل", "احذف", "حذف",
    "بحث", "طباعة", "تصدير",
    "مستفيد", "مبنى", "قائمة الانتظار"
))
        {
            return "SYSTEM";
        }

        if (ContainsAny(query,
     "مادة", "نص المادة", "النص النظامي",
     "لائحة", "اللوائح", "نظام", "الأنظمة", "تعليمات",
     "شروط", "استثناء", "استثناءات", "ضوابط",
     "آلية", "كيف يطبق", "كيفية التطبيق",
     "التأمين الاحترازي", "الإخلاء", "أحقية السكن",
     "الفترة الانتقالية", "الغرامات", "الصيانة", "الدفاع",
     "التلف الجزئي", "التلف الكلي", "التخصيص", "إيجار السكن",
     "سكن العزاب", "سكن العائلات", "الرسوم", "التجهيزات"))
            return "REGULATION";

        if (ContainsAny(query,
   "ما هو", "ما هي", "وش", "عرف", "تعريف", "يعني", "المقصود"
))
        {
            return "REGULATION";
        }

        if (ContainsAny(query,
    "الأحقية", "التخصيص", "الإخلاء",
    "الصيانة", "التلف", "الضياع",
    "الرسوم", "الغرامات",
    "المنشأة", "العمر الافتراضي",
    "الإهمال", "الإصلاح", "الاستبدال",
    "الإنهاء", "القوائم", "المعاينة",
    "اللائحة", "الفترة الانتقالية"
))
        {
            return "REGULATION";
        }

        if (
    (query.StartsWith("كيف") || query.StartsWith("اذا") || query.StartsWith("وش"))
    &&
    ContainsAny(query,
        "السكن",
        "الأحقية",
        "التخصيص",
        "الإخلاء",
        "الصيانة",
        "التلف",
        "الضياع",
        "الغرامات",
        "الرسوم",
        "المستفيد",
        "الوحدة",
        "الفترة الانتقالية"
    )
)
        {
            return "REGULATION";
        }

        return "";

       

    }


    private static bool ContainsAny(string s, params string[] parts)
    {
        return ArabicContainsAny(s, parts);
    }
    //private static bool ContainsAny(string s, params string[] parts)
    //{
    //    foreach (var p in parts)
    //        if (s.Contains(p, StringComparison.OrdinalIgnoreCase))
    //            return true;
    //    return false;
    //}

    private static string RemoveKeywords(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";

        var idx = text.IndexOf("## كلمات مفتاحية", StringComparison.OrdinalIgnoreCase);
        if (idx >= 0) text = text.Substring(0, idx);

        text = text.Replace("Tags:", "", StringComparison.OrdinalIgnoreCase);

        text = text.Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
                   .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase)
                   .Replace("[System]", "", StringComparison.OrdinalIgnoreCase);

        return text.Trim();
    }

    private static string Clip(string s, int max)
        => string.IsNullOrWhiteSpace(s) ? "" : (s.Length <= max ? s : s[..max] + " ...");

    private async Task<long> SaveChatHistoryAsync(
        AiChatRequest request,
        string answer,
        string? entityKey,
        string? intent,
        int responseTimeMs,
        int citationsCount)
    {
        if (_dataEngine is null) return 0;

        try
        {
            var userId = GetPropString(request, "UserId");
            var idaraId = GetPropString(request, "IdaraId") ?? "1";

            var parameters = new Dictionary<string, object?>
            {
                { "pageName_", "AiChatHistory" },
                { "ActionType", "SAVEAICHATHISTORY" },
                { "idaraID", int.TryParse(idaraId, out var idaraIdInt) ? idaraIdInt : 1 },
                { "entrydata", !string.IsNullOrWhiteSpace(userId) && int.TryParse(userId, out var uid) ? uid : 1 },
                { "hostname", request.IpAddress ?? "unknown" },
                { "parameter_02", request.Message ?? "" },
                { "parameter_03", answer },
                { "parameter_09", responseTimeMs.ToString() },
                { "parameter_10", citationsCount.ToString() }
            };

            if (!string.IsNullOrWhiteSpace(userId) && int.TryParse(userId, out var userIdInt))
                parameters["parameter_01"] = userIdInt.ToString();

            if (!string.IsNullOrWhiteSpace(request.PageName))
                parameters["parameter_04"] = request.PageName;

            if (!string.IsNullOrWhiteSpace(request.PageTitle))
                parameters["parameter_05"] = request.PageTitle;

            if (!string.IsNullOrWhiteSpace(request.PageUrl))
                parameters["parameter_06"] = request.PageUrl;

            if (!string.IsNullOrWhiteSpace(entityKey))
                parameters["parameter_07"] = entityKey;

            if (!string.IsNullOrWhiteSpace(intent))
                parameters["parameter_08"] = intent;

            if (!string.IsNullOrWhiteSpace(request.IpAddress))
                parameters["parameter_11"] = request.IpAddress;

            var spName = ProcedureMapper.GetProcedureName("aichat", "saveHistory");

            parameters = CleanParams(parameters);

            var spRequest = new SmartRequest
            {
                Operation = "sp",
                SpName = spName,
                Params = parameters
            };

            var response = await _dataEngine.ExecuteAsync(spRequest);

            if (response.Success && response.Data?.Count > 0)
            {
                var chatIdKey = response.Data[0].Keys
                    .FirstOrDefault(k => k.Equals("ChatId", StringComparison.OrdinalIgnoreCase));

                if (chatIdKey != null)
                    return Convert.ToInt64(response.Data[0][chatIdKey]);
            }
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to save chat history");
        }

        return 0;
    }

    public void Dispose()
    {
        try
        {
            while (_ctxPool.TryDequeue(out var ctx))
            {
                try { ctx.Dispose(); } catch { }
            }
        }
        catch { }

        try { _poolGate?.Dispose(); } catch { }
    }

    private static Dictionary<string, object?> CleanParams(Dictionary<string, object?> p)
    {
        var cleaned = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        foreach (var kv in p)
        {
            var v = kv.Value;
            if (v is DBNull) v = null;
            cleaned[kv.Key] = v;
        }
        return cleaned;
    }


    private static string ExtractBestRegulationPassage(string text, string query, int maxLength = 1200)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(query))
            return "";

        var normalizedQuery = query.Trim();

        var paragraphs = text.Replace("\r\n", "\n")
            .Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (paragraphs.Length == 0)
            return "";

        var scored = paragraphs
            .Select(p => new
            {
                Text = p.Trim(),
                Score = ScoreParagraph(p, normalizedQuery)
            })
            .Where(x =>
                x.Score > 0 &&
                !IsUiOrFormNoise(x.Text))
            .OrderByDescending(x => x.Score)
            .ToList();

        if (scored.Count == 0)
            return "";

        var sb = new StringBuilder();

        foreach (var item in scored.Take(3))
        {
            if (sb.Length + item.Text.Length + 2 > maxLength)
                break;

            if (sb.Length > 0)
                sb.AppendLine().AppendLine();

            sb.Append(item.Text);
        }

        return sb.ToString().Trim();
    }

    private static bool IsUiOrFormNoise(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return true;

        return
            text.Contains("رقم الهوية", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("الرقم العام", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("اضغط زر", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("إضافة مستفيد", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("إدخال بيانات", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("حفظ", StringComparison.OrdinalIgnoreCase) && text.Contains("نافذة", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("لا يعمل زر تعديل", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("تظهر رسالة حقول إلزامية", StringComparison.OrdinalIgnoreCase);
    }


    private static int ScoreParagraph(string paragraph, string query)
    {
        if (string.IsNullOrWhiteSpace(paragraph) || string.IsNullOrWhiteSpace(query))
            return 0;

        int score = 0;

        var normalizedParagraph = NormalizeArabic(paragraph);
        var normalizedQuery = NormalizeArabic(query);

        var topics = new[]
        {
        "العمر الافتراضي",
        "المنشاه السكنيه",
        "المنشاه العسكريه",
        "البند",
        "الصنف",
        "القوائم",
        "المعاينه",
        "اللائحه التنظيميه",
        "الرسوم",
        "الفتره الانتقاليه",
        "سكن العزاب",
        "سكن العائلات",
        "المعدات الثابته",
        "الغرامات",
        "التلف الجزئي",
        "التلف الكلي",
        "الضياع",
        "الصيانه",
        "الاهمال",
        "الاصلاح",
        "الاستبدال",
        "الانهاء",
        "الاحقيه",
        "احقيه السكن",
        "التخصيص",
        "الاخلاء",
        "مسؤوليه المستفيد",
        "مسؤوليه الاداره",
        "المسؤوليات",
        "واجبات المستفيد"
    };

        foreach (var topic in topics)
        {
            if (normalizedQuery.Contains(topic) && normalizedParagraph.Contains(topic))
                score += 10;
        }

        var words = normalizedQuery.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        foreach (var word in words)
        {
            if (word.Length < 2) continue;
            if (normalizedParagraph.Contains(word))
                score += 1;
        }

        if (normalizedParagraph.StartsWith("##"))
            score += 2;

        if (normalizedParagraph.StartsWith("###"))
            score += 1;

        if (ArabicContainsAny(normalizedQuery, "ما هو", "ما هي", "وش", "يعني", "تعريف", "عرف") &&
            ArabicContainsAny(normalizedParagraph, "تعريف", "يقصد به", "هي"))
        {
            score += 3;
        }

        return score;
    }

    //private static int ScoreParagraph(string paragraph, string query)
    //{
    //    if (string.IsNullOrWhiteSpace(paragraph) || string.IsNullOrWhiteSpace(query))
    //        return 0;

    //    int score = 0;

    //    var topics = new[]
    //    {
    //    "العمر الافتراضي",
    //    "المنشأة السكنية",
    //    "المنشأة العسكرية",
    //    "البند",
    //    "الصنف",
    //    "القوائم",
    //    "المعاينة",
    //    "اللائحة التنظيمية",
    //    "الرسوم",
    //    "الفترة الانتقالية",
    //    "سكن العزاب",
    //    "سكن العائلات",
    //    "المعدات الثابتة",
    //    "الغرامات",
    //    "التلف الجزئي",
    //    "التلف الكلي",
    //    "الضياع",
    //    "الصيانة",
    //    "الإهمال",
    //    "الإصلاح",
    //    "الاستبدال",
    //    "الإنهاء",
    //    "الأحقية",
    //    "أحقية السكن",
    //    "التخصيص",
    //    "الإخلاء",
    //    "مسؤولية المستفيد",
    //    "مسؤولية الإدارة",
    //    "المسؤوليات",
    //    "واجبات المستفيد"
    //};

    //    foreach (var topic in topics)
    //    {
    //        if (query.Contains(topic, StringComparison.OrdinalIgnoreCase) &&
    //            paragraph.Contains(topic, StringComparison.OrdinalIgnoreCase))
    //        {
    //            score += 10;
    //        }
    //    }

    //    var words = query.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    //    foreach (var word in words)
    //    {
    //        if (word.Length < 2) continue;

    //        if (paragraph.Contains(word, StringComparison.OrdinalIgnoreCase))
    //            score += 1;
    //    }

    //    if (paragraph.StartsWith("##"))
    //        score += 2;

    //    if (paragraph.StartsWith("###"))
    //        score += 1;

    //    if ((query.Contains("ما هو", StringComparison.OrdinalIgnoreCase) ||
    //         query.Contains("ما هي", StringComparison.OrdinalIgnoreCase) ||
    //         query.Contains("وش", StringComparison.OrdinalIgnoreCase) ||
    //         query.Contains("يعني", StringComparison.OrdinalIgnoreCase) ||
    //         query.Contains("تعريف", StringComparison.OrdinalIgnoreCase) ||
    //         query.Contains("عرف", StringComparison.OrdinalIgnoreCase))
    //         &&
    //         (paragraph.Contains("تعريف", StringComparison.OrdinalIgnoreCase) ||
    //          paragraph.Contains("يقصد به", StringComparison.OrdinalIgnoreCase) ||
    //          paragraph.Contains("هي", StringComparison.OrdinalIgnoreCase)))
    //    {
    //        score += 3;
    //    }

    //    return score;
    //}


    private static string NormalizeArabic(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return "";

        text = text.Trim();

        // إزالة التشكيل
        text = Regex.Replace(text, "[\u064B-\u065F\u0670\u06D6-\u06ED]", "");

        // توحيد الحروف
        text = text
            .Replace('أ', 'ا')
            .Replace('إ', 'ا')
            .Replace('آ', 'ا')
            .Replace('ٱ', 'ا')
            .Replace('ى', 'ي')
            .Replace('ئ', 'ي')
            .Replace('ؤ', 'و')
            .Replace('ة', 'ه');

        // إزالة التطويل
        text = text.Replace("ـ", "");

        // توحيد الأرقام العربية/الفارسية إلى إنجليزية
        text = text
            .Replace('٠', '0').Replace('١', '1').Replace('٢', '2').Replace('٣', '3').Replace('٤', '4')
            .Replace('٥', '5').Replace('٦', '6').Replace('٧', '7').Replace('٨', '8').Replace('٩', '9')
            .Replace('۰', '0').Replace('۱', '1').Replace('۲', '2').Replace('۳', '3').Replace('۴', '4')
            .Replace('۵', '5').Replace('۶', '6').Replace('۷', '7').Replace('۸', '8').Replace('۹', '9');

        // إزالة الرموز الشائعة
        text = text.Replace("؟", " ")
                   .Replace("?", " ")
                   .Replace("،", " ")
                   .Replace(",", " ")
                   .Replace(".", " ")
                   .Replace(";", " ")
                   .Replace(":", " ")
                   .Replace("/", " ")
                   .Replace("\\", " ")
                   .Replace("-", " ")
                   .Replace("_", " ");

        // توحيد المسافات
        text = Regex.Replace(text, @"\s+", " ").Trim();

        return text.ToLowerInvariant();
    }

    private static bool ArabicContains(string source, string target)
    {
        if (string.IsNullOrWhiteSpace(source) || string.IsNullOrWhiteSpace(target))
            return false;

        return NormalizeArabic(source).Contains(NormalizeArabic(target), StringComparison.Ordinal);
    }

    private static bool ArabicContainsAny(string source, params string[] values)
    {
        if (string.IsNullOrWhiteSpace(source) || values == null || values.Length == 0)
            return false;

        var normalizedSource = NormalizeArabic(source);

        foreach (var value in values)
        {
            if (string.IsNullOrWhiteSpace(value)) continue;
            if (normalizedSource.Contains(NormalizeArabic(value), StringComparison.Ordinal))
                return true;
        }

        return false;
    }

}
