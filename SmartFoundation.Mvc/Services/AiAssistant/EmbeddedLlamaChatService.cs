using LLama;
using LLama.Common;
using Microsoft.Extensions.Options;
using SmartFoundation.Application.Mapping;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;

namespace SmartFoundation.Mvc.Services.AiAssistant;

internal sealed class EmbeddedLlamaChatService : IAiChatService, IDisposable
{
    private readonly IAiKnowledgeBase _kb;
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<EmbeddedLlamaChatService> _log;
    private readonly ISmartComponentService? _dataEngine;
    private readonly LLamaModelHolder _modelHolder;

    private readonly SemaphoreSlim _gate;
    private readonly LLamaContext _context;

    private const string GeneralChatSourceHint = "General_Chat";
    private const int GeneralChatMaxAnswerLen = 1500;

    private static readonly (string Key, string Label, string[] Keywords)[] Entities =
    {
        ("Residents", "مستفيد", new[] { "مستفيد", "المستفيد", "المستفيدين", "ساكن", "Residents" }),
        ("BuildingDetails", "مبنى" , new[] { "مبنى", "المباني", "Building", "BuildingDetails" }),
        ("BuildingClass", "فئة مبنى" , new[] { "فئة مبنى", "فئات المباني", "تصنيف مبنى", "تصنيفات المباني", "نوع مبنى", "أنواع المباني", "BuildingClass" }),
        ("ResidentClass", "فئة مستفيد" , new[] { "فئة مستفيد", "فئات المستفيدين", "تصنيف مستفيد", "تصنيفات المستفيدين", "نوع مستفيد", "أنواع المستفيدين", "ResidentClass" }),
        ("WaitingListByResident", "قوائم الانتظار" , new[] { 
            "قوائم الانتظار", "قائمة الانتظار", "قائمة انتظار", "قوائم انتظار",
            "سجل انتظار", "سجلات الانتظار", "سجلات انتظار",
            "خطاب تسكين", "خطابات التسكين", "خطابات تسكين",
            "نقل سجل", "نقل سجلات", "طلب نقل", "طلبات النقل",
            "WaitingListByResident", "WaitingList"
        }),
    };

    private sealed class PendingState
    {
        public string Intent { get; set; } = "";
        public string OriginalMessage { get; set; } = "";
        public DateTimeOffset At { get; set; } = DateTimeOffset.UtcNow;
    }

    private static readonly ConcurrentDictionary<string, PendingState> _pending = new();
    private static readonly TimeSpan PendingTtl = TimeSpan.FromMinutes(2);

    public EmbeddedLlamaChatService(
        IAiKnowledgeBase kb,
        IOptions<AiAssistantOptions> opt,
        LLamaModelHolder modelHolder,
        ILogger<EmbeddedLlamaChatService> log,
        ISmartComponentService? dataEngine = null)
    {
        _kb = kb;
        _opt = opt.Value;
        _log = log;
        _dataEngine = dataEngine;
        _modelHolder = modelHolder;

        _gate = new SemaphoreSlim(Math.Max(1, _opt.MaxParallelRequests));

        _context = _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
        {
            ContextSize = _modelHolder.ContextSize,
            Threads = _modelHolder.Threads
        });

        _log.LogInformation(
            "EmbeddedLlamaChatService instance created (Scoped) using model: {Path}",
            _modelHolder.ModelPath);
    }

    public async Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct)
    {
        var startTime = DateTimeOffset.UtcNow;

        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
        var combinedCt = linkedCts.Token;

        try
        {
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
            string? selectedEntityKey = null;

            if (string.IsNullOrWhiteSpace(intent) &&
                entityHits.Count == 1 &&
                IsShortEntityAnswer(originalMsg) &&
                !string.IsNullOrWhiteSpace(convoKey) &&
                _pending.TryGetValue(convoKey, out var pendingState) &&
                DateTimeOffset.UtcNow - pendingState.At <= PendingTtl &&
                !string.IsNullOrWhiteSpace(pendingState.Intent))
            {
                _log.LogInformation(
                    "AI_CHAT: PENDING_HIT key='{ConvoKey}' intent='{Intent}' original='{Original}'",
                    convoKey ?? "", pendingState.Intent ?? "", pendingState.OriginalMessage ?? ""
                );

                intent = pendingState.Intent;
                selectedEntityKey = entityHits[0].Key;

                if (!string.IsNullOrWhiteSpace(pendingState.OriginalMessage))
                    msg = pendingState.OriginalMessage;
            }

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

            if (string.IsNullOrWhiteSpace(intent))
            {
                if (TryAnswerFromGeneralChat(originalMsg, out var generalAnswer, out var usedGeneral))
                {
                    if (!string.IsNullOrWhiteSpace(convoKey))
                        _pending.TryRemove(convoKey, out _);

                    return await SaveAndReturn(request, startTime, generalAnswer, usedGeneral, null, null);
                }
            }

            var isProcedural = !string.IsNullOrWhiteSpace(intent);
            var topK = Math.Max(8, _opt.RetrievalTopK);

            var searchQuery = msg;
            if (!string.IsNullOrWhiteSpace(selectedEntityKey))
                searchQuery = $"{msg} {GetEntityLabel(selectedEntityKey)}";

            _log.LogInformation(
                "AI_CHAT: intent='{Intent}', selectedEntity='{Entity}', searchQuery='{Q}', topK={TopK}",
                intent ?? "", selectedEntityKey ?? "", searchQuery ?? "", topK
            );

            var citations = _kb.Search(searchQuery, topK);

            if (citations.Count > 0)
            {
                citations = citations
                    .Where(c => c.Source?.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase) != true)
                    .ToList();
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
                    {
                        _log.LogInformation("AI_CHAT: PENDING_SET key='{ConvoKey}' intent='{Intent}'", convoKey ?? "", intent ?? "");
                        _pending[convoKey] = new PendingState { Intent = intent, OriginalMessage = originalMsg, At = DateTimeOffset.UtcNow };
                    }

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

                    if (filtered.Count > 0)
                        citations = filtered;
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

                var header = ResolveHeader(entityKey, intent);
                if (string.IsNullOrWhiteSpace(header))
                {
                    var suggestions = GetSuggestions(entityKey);
                    return await SaveAndReturn(
                        request, startTime,
                        $"لا يوجد شرح لهذه العملية في الدليل الحالي.\n\n{suggestions}",
                        citations, entityKey, intent
                    );
                }

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

                            if (!string.IsNullOrWhiteSpace(cached))
                                text = cached;
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

                string answerText;
                if (string.IsNullOrWhiteSpace(best) || best.Equals(header, StringComparison.OrdinalIgnoreCase))
                {
                    var suggestions = GetSuggestions(entityKey);
                    answerText = $"السؤال غير واضح، ممكن تحدد سؤالك؟\n\n{suggestions}";
                }
                else
                {
                    answerText = best;
                    answerText = RemoveKeywords(answerText);
                    answerText = TrimToSingleSection(answerText);
                    answerText = answerText.Trim();
                }

                if (string.IsNullOrWhiteSpace(answerText))
                    answerText = "لا يوجد قسم مطابق لهذا السؤال في الدليل الحالي.";

                if (!string.IsNullOrWhiteSpace(convoKey))
                    _pending.TryRemove(convoKey, out _);

                return await SaveAndReturn(request, startTime, answerText, citations, entityKey, intent);
            }

            if (citations.Count == 0)
            {
                return await SaveAndReturn(
                    request, startTime,
                    "اسف مافهمتك باقي اتدرب , ممكن تسألني كيف ابحث؟ كيف اطبع تقرير ؟ كيف اعدل ؟",
                    citations, null, null
                );
            }

            var system = BuildSystemPrompt(request, citations);

            await _gate.WaitAsync(combinedCt);
            try
            {
                using var ctx = _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
                {
                    ContextSize = (uint)Math.Clamp(_opt.ContextSize, 512, 4096),
                    Threads = Math.Max(1, _opt.Threads),
                });

                var executor = new InteractiveExecutor(ctx);

                var prompt = $"""
[System]
{system}

[User]
{msg}

[Assistant]
""";

                var inferenceParams = new InferenceParams
                {
                    MaxTokens = Math.Min(_opt.MaxTokens, 512),
                    AntiPrompts = new List<string> { "[User]", "[System]" },
                    SamplingPipeline = new LLama.Sampling.DefaultSamplingPipeline
                    {
                        Temperature = (float)_opt.Temperature,
                        Seed = 1337
                    }
                };

                var sb = new StringBuilder();
                await foreach (var piece in executor.InferAsync(prompt, inferenceParams, combinedCt))
                {
                    sb.Append(piece);
                    if (sb.Length > 2000) break;
                }

                var answer = sb.ToString().Trim();
                answer = CleanLlmArtifacts(answer);

                if (string.IsNullOrWhiteSpace(answer))
                    answer = "عذرا السوال غير واضح او الاتصال ضعيف حاول السؤال يكون اكثر تحديدا .";

                return await SaveAndReturn(request, startTime, answer, citations, null, null);
            }
            finally
            {
                _gate.Release();
            }
        }
        catch (OperationCanceledException) when (timeoutCts.Token.IsCancellationRequested)
        {
            _log.LogWarning("AI_TIMEOUT: Request took longer than 30 seconds");
            return await SaveAndReturn(
                request, startTime,
                "معليش، الاتصال ضعيف أو السؤال معقد. حاول تكون أكثر تفصيلاً في السؤال.\n\nمثلاً بدلاً من \"كيف أضيف؟\" اكتب \"كيف أضيف مستفيد؟\"",
                Array.Empty<KnowledgeChunk>(), null, null
            );
        }
        catch (OperationCanceledException)
        {
            _log.LogInformation("AI_CANCELLED: Request cancelled by user");
            return await SaveAndReturn(
                request, startTime,
                "تم إيقاف العملية.",
                Array.Empty<KnowledgeChunk>(), null, null
            );
        }
    }

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

        _log.LogInformation("AI_DEBUG_SAVE: chatId={ChatId}, citations={Count}",
      chatId, citations?.Count ?? 0);

        // ✅ جديد: احفظ الاقتباسات
        if (chatId > 0 && citations is { Count: > 0 })
            await SaveChatCitationsAsync(chatId, citations);

        return new AiChatResult(answer, citations)
        {
            ChatId = chatId,
            EntityKey = entityKey,
            Intent = intent
        };
    }


    private async Task SaveChatCitationsAsync(long chatId, IReadOnlyList<KnowledgeChunk> citations)
    {
        if (_dataEngine is null) return;

        try
        {
            var take = Math.Min(citations.Count, 10);

            for (int i = 0; i < take; i++)
            {
                var c = citations[i];
                if (string.IsNullOrWhiteSpace(c.Source)) continue;

                // لو عمود TextSnippet محدود، قصّه (عدّل 2000 حسب عمودك)
                var snippet = string.IsNullOrWhiteSpace(c.Text) ? null : c.Text;
                if (snippet is not null && snippet.Length > 2000)
                    snippet = snippet.Substring(0, 2000);

                var parameters = new Dictionary<string, object?>
            {
                { "ChatId", chatId },                 // long
                { "Source", c.Source },               // string
                { "TextSnippet", snippet },           // string? or null
                { "UsedInAnswer", 1 }                 // BIT => 1/0 (أضمن من true/false)
            };

                parameters = CleanParams(parameters);

                _log.LogInformation("AI_CITATION_PARAMS: {p}", JsonSerializer.Serialize(parameters));

                var spRequest = new SmartRequest
                {
                    Operation = "sp",
                    SpName = "dbo.sp_AiChat_SaveCitation",
                    Params = parameters
                };

                var resp = await _dataEngine.ExecuteAsync(spRequest);

                if (resp.Success)
                    _log.LogInformation("AI_CITATION_SAVED: ChatId={ChatId}, Source={Source}", chatId, c.Source);
                else
                    _log.LogWarning("AI_CITATION_SAVE_FAILED: ChatId={ChatId}, Source={Source}, msg={Msg}", chatId, c.Source, resp.Message);
            }

            _log.LogInformation("AI_CITATIONS_DONE: ChatId={ChatId}, Count={Count}", chatId, take);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to save citations for ChatId={ChatId}", chatId);
        }
    }





    private bool TryAnswerFromGeneralChat(
        string userMsg,
        out string answer,
        out IReadOnlyList<KnowledgeChunk> usedCitations)
    {
        answer = "";
        usedCitations = Array.Empty<KnowledgeChunk>();

        userMsg ??= "";
        var q = NormalizeForMatch(userMsg);

        var forced = _kb.Search($"{GeneralChatSourceHint} {userMsg}", Math.Max(10, _opt.RetrievalTopK));

        var hits = forced
            .Where(c => !string.IsNullOrWhiteSpace(c.Source) &&
                        c.Source.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (hits.Count == 0)
        {
            var forced2 = _kb.Search(GeneralChatSourceHint, Math.Max(10, _opt.RetrievalTopK));
            hits = forced2
                .Where(c => !string.IsNullOrWhiteSpace(c.Source) &&
                            c.Source.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (hits.Count == 0)
                return false;
        }

        var bestSource = hits[0].Source!;
        var fullDoc = _kb.GetDocumentBySource(bestSource);

        var doc = !string.IsNullOrWhiteSpace(fullDoc) ? fullDoc! : (hits.OrderByDescending(h => (h.Text ?? "").Length).First().Text ?? "");
        if (doc.Length < 50 || !doc.Contains("[KEYWORDS]", StringComparison.OrdinalIgnoreCase))
            return false;

        var blocks = ParseKeywordBlocks(doc);
        if (blocks.Count == 0)
            return false;

        (int score, string ans) best = (0, "");
        foreach (var b in blocks)
        {
            var score = ScoreMatch(q, b.Keywords);
            if (score > best.score)
                best = (score, b.Answer);
        }

        if (best.score <= 0 || string.IsNullOrWhiteSpace(best.ans))
            return false;

        answer = Clip(best.ans.Trim(), GeneralChatMaxAnswerLen);
        usedCitations = hits;
        return true;
    }

    private sealed class KeywordBlock
    {
        public List<string> Keywords { get; set; } = new();
        public string Answer { get; set; } = "";
    }

    private static List<KeywordBlock> ParseKeywordBlocks(string doc)
    {
        doc ??= "";
        doc = doc.Replace("\r\n", "\n");

        var lines = doc.Split('\n');
        var blocks = new List<KeywordBlock>();

        int i = 0;
        while (i < lines.Length)
        {
            if (!lines[i].Trim().Equals("[KEYWORDS]", StringComparison.OrdinalIgnoreCase))
            {
                i++;
                continue;
            }

            i++;
            var kw = new List<string>();

            while (i < lines.Length)
            {
                var t = lines[i].Trim();
                if (t.Length == 0) { i++; break; }
                if (t == "---") break;
                if (t.Equals("[KEYWORDS]", StringComparison.OrdinalIgnoreCase)) break;

                if (t.Contains(','))
                {
                    foreach (var part in t.Split(',', StringSplitOptions.RemoveEmptyEntries))
                        kw.Add(part.Trim());
                }
                else
                {
                    kw.Add(t);
                }
                i++;
            }

            var sb = new StringBuilder();

            while (i < lines.Length)
            {
                var tt = lines[i].Trim();
                if (tt == "---") break;
                if (tt.Equals("[KEYWORDS]", StringComparison.OrdinalIgnoreCase)) break;

                if (tt.StartsWith("# ")) { i++; continue; }

                sb.AppendLine(lines[i]);
                i++;
            }

            var normalizedKeywords = kw
                .Select(NormalizeForMatch)
                .Where(x => x.Length > 0)
                .Distinct()
                .ToList();

            var ans = sb.ToString().Trim();

            if (normalizedKeywords.Count > 0 && !string.IsNullOrWhiteSpace(ans))
            {
                blocks.Add(new KeywordBlock
                {
                    Keywords = normalizedKeywords,
                    Answer = ans
                });
            }

            while (i < lines.Length && lines[i].Trim() == "---") i++;
        }

        return blocks;
    }

    private static int ScoreMatch(string q, List<string> keywords)
    {
        if (string.IsNullOrWhiteSpace(q) || keywords.Count == 0) return 0;

        int best = 0;

        foreach (var k in keywords)
        {
            if (string.IsNullOrWhiteSpace(k)) continue;

            if (q.Equals(k, StringComparison.OrdinalIgnoreCase))
                best = Math.Max(best, 200 + k.Length);
            else if (q.Contains(k, StringComparison.OrdinalIgnoreCase) || k.Contains(q, StringComparison.OrdinalIgnoreCase))
                best = Math.Max(best, 120 + Math.Min(q.Length, k.Length));
            else
            {
                var qt = q.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                var kt = k.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                var common = qt.Intersect(kt, StringComparer.OrdinalIgnoreCase).Count();
                if (common > 0)
                    best = Math.Max(best, 60 + common * 10);
            }
        }

        return best;
    }

    private static string NormalizeForMatch(string s)
    {
        s = (s ?? "").Trim().ToLowerInvariant();
        s = s.Replace("؟", "").Replace("?", "");
        s = s.Replace("أ", "ا").Replace("إ", "ا").Replace("آ", "ا");
        s = s.Replace("ى", "ي").Replace("ة", "ه");
        while (s.Contains("  ")) s = s.Replace("  ", " ");
        return s.Trim();
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
        if (parts.Length > 2) return false;

        return true;
    }

    private static string CleanLlmArtifacts(string s)
    {
        if (string.IsNullOrWhiteSpace(s)) return "";

        s = s.Replace("[System]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase);

        while (s.Contains("\n\n\n"))
            s = s.Replace("\n\n\n", "\n\n");

        return s.Trim();
    }

    private static List<(string Key, string Label)> DetectEntities(string message)
    {
        message ??= "";
        var hits = new List<(string Key, string Label)>();

        foreach (var e in Entities)
        {
            if (e.Keywords.Any(k => message.Contains(k, StringComparison.OrdinalIgnoreCase)))
                hits.Add((e.Key, e.Label));
        }

        return hits
            .GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();
    }

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

        if (v.Equals("WaitingListByResident", StringComparison.OrdinalIgnoreCase)) return "WaitingListByResident";
        if (v.Equals("Residents", StringComparison.OrdinalIgnoreCase)) return "Residents";
        if (v.Equals("BuildingDetails", StringComparison.OrdinalIgnoreCase)) return "BuildingDetails";
        if (v.Equals("BuildingClass", StringComparison.OrdinalIgnoreCase)) return "BuildingClass";
        if (v.Equals("ResidentClass", StringComparison.OrdinalIgnoreCase)) return "ResidentClass";

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

    private static string ResolveHeader(string entityKey, string intent)
    {
        if (string.IsNullOrWhiteSpace(intent))
            return "";

        return (entityKey, intent) switch
        {
            // Residents
            ("Residents", "ADD") => "## إضافة مستفيد",
            ("Residents", "UPDATE") => "## تعديل مستفيد",
            ("Residents", "DELETE") => "## حذف مستفيد",
            ("Residents", "SEARCH") => "## البحث عن مستفيد",
            ("Residents", "PRINT") => "## طباعة تقرير المستفيدين",

            // BuildingDetails
            ("BuildingDetails", "ADD") => "## إضافة مبنى",
            ("BuildingDetails", "UPDATE") => "## تعديل مبنى",
            ("BuildingDetails", "DELETE") => "## حذف مبنى",
            ("BuildingDetails", "SEARCH") => "## البحث عن مبنى",
            ("BuildingDetails", "PRINT") => "## طباعة تقرير المباني",

            // BuildingClass
            ("BuildingClass", "ADD") => "## إضافة فئة جديدة",
            ("BuildingClass", "UPDATE") => "## تعديل فئة موجودة",
            ("BuildingClass", "DELETE") => "## حذف فئة",
            ("BuildingClass", "SEARCH") => "## البحث والتصفية",
            ("BuildingClass", "PRINT") => "## التصدير",
            ("BuildingClass", "EXPORT") => "## التصدير",

            // ResidentClass
            ("ResidentClass", "ADD") => "## إضافة فئة مستفيد",
            ("ResidentClass", "UPDATE") => "## تعديل فئة مستفيد",
            ("ResidentClass", "DELETE") => "## حذف فئة مستفيد",

            // WaitingListByResident
            ("WaitingListByResident", "SEARCH") => "## البحث عن مستفيد",
            ("WaitingListByResident", "ADD") => "### إضافة سجل انتظار جديد",
            ("WaitingListByResident", "UPDATE") => "### تعديل سجل انتظار",
            ("WaitingListByResident", "DELETE") => "### حذف سجل انتظار",
            ("WaitingListByResident", "PRINT") => "## التصدير",
            ("WaitingListByResident", "EXPORT") => "## التصدير",

            _ => ""
        };
    }

    private static string ExtractSection(string text, string header)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(header))
            return "";

        var h = System.Text.RegularExpressions.Regex.Escape(header.Trim());
        h = h.Replace("\\ ", "\\s+");

        // دعم ## و ### headers
        var pattern = $"{h}\\s*\\r?\\n(?<body>[\\s\\S]*?)(?=\\r?\\n###?\\s|\\z)";
        var m = System.Text.RegularExpressions.Regex.Match(text, pattern,
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        if (!m.Success) return header;

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
أنت مساعد داخل نظام SmartFoundation.
أجب بالعربية وبشكل مختصر ودقيق.

سياق الصفحة:
- {r.PageTitle} | {r.PageUrl}

مقاطع المساعدة:
{kb}
""";
    }

    private static string NormalizeIntent(string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return "";
        query = query.Trim().ToLowerInvariant();
        query = query.Replace("؟", "").Replace("?", "").Trim();

        if (ContainsAny(query,
            "تعديل", "عدّل", "عدل", "تحديث", "حدث", "تغيير", "غير",
            "ابي اعدل", "أبي أعدل", "ابغى اعدل", "أبغى أعدل",
            "امي اغير", "ابغى اغير", "أبي أغير", "أبغى أغير",
            "صحح", "تصحيح"))
            return "UPDATE";

        if (ContainsAny(query,
            "حذف", "احذف", "مسح", "امسح", "ازالة", "إزالة", "شيل", "اشيل",
            "ابي احذف", "أبي أحذف", "ابغى احذف", "أبغى أحذف",
            "الغاء", "إلغاء"))
            return "DELETE";

        if (ContainsAny(query,
            "طباعة", "اطبع", "طبع", "تقرير", "pdf", "excel", "اكسل", "تصدير", "صدّر"))
            return "PRINT";

        if (ContainsAny(query,
            "بحث", "ابحث", "ادور", "دور", "القّى", "القى", "ألقى", "وين", "فين"))
            return "SEARCH";

        if (ContainsAny(query,
            "اضافة", "إضافة", "اضف", "أضف", "اضيف", "أضيف",
            "تسجيل", "سجل", "انشاء", "إنشاء",
            "ابي اضيف", "أبي أضيف", "ابغى اضيف", "أبغى أضيف",
            "ابي اسجل", "ابغى اسجل", "أبي أسجل", "أبغى أسجل",
            "جديد", "واحد جديد"))
            return "ADD";

        return "";
    }

    private static bool ContainsAny(string s, params string[] parts)
    {
        foreach (var p in parts)
            if (s.Contains(p, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

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
        if (_dataEngine is null)
        {
            _log.LogWarning("AI_SAVE_SKIPPED: DataEngine is null");
            return 0;
        }

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
            _log.LogInformation("AI_HISTORY_PARAMS: {p}", JsonSerializer.Serialize(parameters));

            var spRequest = new SmartRequest
            {
                Operation = "sp",
                SpName = spName,
                Params = parameters
            };

            var response = await _dataEngine.ExecuteAsync(spRequest);
            _log.LogInformation("AI_HISTORY_SAVE_RESP: success={s}, msg={m}", response.Success, response.Message);

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
        try { _context?.Dispose(); } catch { }
        try { _gate?.Dispose(); } catch { }
    }

    private static Dictionary<string, object?> CleanParams(Dictionary<string, object?> p)
    {
        var cleaned = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

        foreach (var kv in p)
        {
            var v = kv.Value;

            if (v is DBNull) v = null;

            // اختياري: لو تحب تحذف nulls بالكامل (حسب تصميم SP عندك)
            cleaned[kv.Key] = v;
        }

        return cleaned;
    }


}
