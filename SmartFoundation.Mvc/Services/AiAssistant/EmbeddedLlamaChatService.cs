using LLama;
using LLama.Common;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using SmartFoundation.Application.Mapping;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.Mvc.Helpers;
using SmartFoundation.Mvc.Services.AiAssistant.Core;
using SmartFoundation.Mvc.Services.AiAssistant.Security;
using System.Collections.Concurrent;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SmartFoundation.Mvc.Services.AiAssistant;

internal sealed class EmbeddedLlamaChatService : IAiChatService, IDisposable
{
    private readonly IAiKnowledgeBase _kb;
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<EmbeddedLlamaChatService> _log;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly LLamaModelHolder _modelHolder;

    private readonly SemaphoreSlim _poolGate;
    private readonly ConcurrentQueue<LLamaContext> _ctxPool = new();

    private static readonly ConcurrentDictionary<string, PendingState> _pending = new();
    private static readonly TimeSpan PendingTtl = TimeSpan.FromMinutes(2);
    private static readonly HashSet<string> RegulationFileNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "housing_allocation",
        "housing_definitions",
        "housing_entitlement",
        "housing_eviction",
        "housing_maintenance",
        "housing_rules_general",
        "housing-residents"
    };

    private sealed class PendingState
    {
        public string Intent { get; set; } = "";
        public string OriginalMessage { get; set; } = "";
        public DateTimeOffset At { get; set; } = DateTimeOffset.UtcNow;
    }

    public EmbeddedLlamaChatService(
        IAiKnowledgeBase kb,
        IOptions<AiAssistantOptions> opt,
        LLamaModelHolder modelHolder,
        ILogger<EmbeddedLlamaChatService> log,
        IServiceScopeFactory scopeFactory)
    {
        _kb = kb;
        _opt = opt.Value;
        _log = log;
        _scopeFactory = scopeFactory;
        _modelHolder = modelHolder;

        var poolSize = Math.Max(1, _opt.MaxParallelRequests);
        _poolGate = new SemaphoreSlim(poolSize, poolSize);

        var ctxSize = (uint)Math.Clamp(_opt.ContextSize, 512, 4096);
        var threads = Math.Max(1, _opt.Threads);

        for (int i = 0; i < poolSize; i++)
        {
            var ctx = _modelHolder.Weights.CreateContext(new ModelParams(_modelHolder.ModelPath)
            {
                ContextSize = ctxSize,
                Threads = threads
            });

            _ctxPool.Enqueue(ctx);
        }

        _log.LogInformation(
            "EmbeddedLlamaChatService created using model: {Path} | pool={Pool} | ctx={Ctx} | threads={Threads}",
            _modelHolder.ModelPath, poolSize, ctxSize, threads);
    }


    public async Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct)
    {
        var startTime = DateTimeOffset.UtcNow;

        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(8));
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
        var combinedCt = linkedCts.Token;

        try
        {
            CleanupPending();

            var originalMsg = (request.Message ?? "").Trim();
            if (string.IsNullOrWhiteSpace(originalMsg))
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    "🙂",
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    null);
            }

            // ✅ التحية السريعة بدون أي معالجة ثقيلة
            if (ArabicTextNormalizer.ContainsAny(originalMsg, "سلام", "السلام", "هلا", "مرحبا", "اهلا", "أهلا"))
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    "مرحبًا بكم.\n\nأنا فيصل، المساعد الذكي للنظام.\n\nيمكنكم الاستفسار عن إجراءات النظام، مثل:\n• كيف أضيف مستفيد؟\n• كيف أفتح فترة قراءة العدادات؟\n• كيف أطبع تقريرًا؟",
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    "GREETING");
            }

            var pageKey = ResolvePageKey(request);
            var convoKey = ResolveConversationKey(request);
            var effectiveMsg = originalMsg;

            var expandedFromPending = TryExpandPendingActionQuestion(convoKey, originalMsg, out var expandedQuestion);
            if (expandedFromPending)
            {
                effectiveMsg = expandedQuestion;
            }
            else if (TryCanonicalizeDirectActionQuestion(originalMsg, out var canonicalDirectQuestion))
            {
                effectiveMsg = canonicalDirectQuestion;
            }
            else if (TryGetActivePendingIntent(convoKey, out var activePendingIntent) &&
                     IsLikelyEntityReply(originalMsg))
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    BuildGenericActionClarificationMessage(activePendingIntent),
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    "CLARIFY_PAGE");
            }

            _log.LogInformation(
                "AI_CHAT: convoKey='{ConvoKey}', pageKey='{PageKey}', msg='{Msg}'",
                convoKey ?? "", pageKey ?? "", effectiveMsg.Replace("\n", " ").Trim());

            // ✅ تفسير السؤال + الصلاحيات
            var interpretation = BuildInterpretationResult(request, effectiveMsg, pageKey);
            var userFacingMessage = BuildUserFacingMessage(interpretation);

            _log.LogInformation(
                "AI_INTERPRET: page='{Page}', action='{Action}', regulation={Regulation}, detailed={Detailed}, generalOnly={GeneralOnly}",
                interpretation.Page?.InternalPageName ?? "",
                interpretation.Action?.ActionType.ToString() ?? "",
                interpretation.IsRegulationLike,
                interpretation.CanExplainDetailedPageFlow,
                interpretation.CanExplainGeneralOnly);

            // 0) سؤال عام جدًا بصيغة إجراء بدون تحديد صفحة (مثل: كيف أعدل)
            if (IsGenericActionOnlyQuestion(effectiveMsg, interpretation))
            {
                var genericIntent = ResolveGenericActionIntent(interpretation, effectiveMsg);
                RegisterPendingActionQuestion(convoKey, genericIntent, effectiveMsg);

                return await SaveAndReturn(
                    request,
                    startTime,
                    BuildGenericActionClarificationMessage(genericIntent),
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    "CLARIFY_PAGE");
            }

            // 1) سؤال لائحي: مسار مستقل (يسمح بالنصوص النظامية حتى بدون تحديد صفحة)
            if (interpretation.IsRegulationLike)
            {
                var regulationQueries = BuildRegulationSearchQueries(originalMsg, interpretation);
                var regulationCitations = SearchRegulationKnowledgeBase(
                    regulationQueries,
                    interpretation,
                    effectiveMsg,
                    Math.Clamp(_opt.RetrievalTopK, 4, 6));

                var regulationAnswer = TryAnswerRegulationDirectly(effectiveMsg, regulationCitations);

                if (!string.IsNullOrWhiteSpace(regulationAnswer))
                {
                    return await SaveAndReturn(
                        request,
                        startTime,
                        regulationAnswer,
                        regulationCitations,
                        interpretation.Page?.InternalPageName,
                        "REGULATION");
                }

                return await SaveAndReturn(
                    request,
                    startTime,
                    BuildUnableToAnswerMessage(),
                    regulationCitations,
                    interpretation.Page?.InternalPageName,
                    "REGULATION");
            }

            // 2) محادثات عامة محلية (بدون إنترنت) بنبرة رسمية
            if (!interpretation.HasPage &&
                TryBuildGeneralOfficialResponse(effectiveMsg, out var generalResponse, out var generalIntent))
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    generalResponse,
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    generalIntent);
            }

            // 2) إذا الصفحة غير مفهومة
            if (!interpretation.HasPage)
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    BuildUnableToAnswerMessage(),
                    Array.Empty<KnowledgeChunk>(),
                    null,
                    null);
            }

            // 3) إذا لا توجد صلاحية على الصفحة أو الإجراء: اعتذار صريح بدون شرح تفصيلي
            if (!interpretation.CanExplainDetailedPageFlow)
            {
                var denyMessage = interpretation.Permission.DenyReasonArabic;
                if (string.IsNullOrWhiteSpace(denyMessage))
                {
                    denyMessage = "أعتذر، لا أستطيع شرح هذه الصفحة أو هذا الإجراء لأن صلاحيتك الحالية لا تسمح بذلك.";
                }

                return await SaveAndReturn(
                    request,
                    startTime,
                    denyMessage,
                    Array.Empty<KnowledgeChunk>(),
                    interpretation.Page?.InternalPageName,
                    interpretation.Action?.ActionType.ToString());
            }

            // 4) تجهيز البحث الإجرائي
            var searchQueries = BuildSearchQueries(effectiveMsg, interpretation);
            var citations = SearchKnowledgeBase(searchQueries, interpretation, Math.Clamp(_opt.RetrievalTopK, 3, 5));

            // 5) سؤال إجرائي + عنده صلاحية + عنده Action؟ جرّب استخراج مباشر أولًا
            if (interpretation.CanExplainDetailedPageFlow &&
                interpretation.Page is not null &&
                interpretation.Action is not null)
            {
                var proceduralAnswer = TryAnswerProceduralDirectly(interpretation, effectiveMsg, citations);

                if (!string.IsNullOrWhiteSpace(proceduralAnswer))
                {
                    return await SaveAndReturn(
                        request,
                        startTime,
                        proceduralAnswer,
                        citations,
                        interpretation.Page.InternalPageName,
                        interpretation.Action.ActionType.ToString());
                }

                var fallbackAnswer = BuildProceduralFallbackAnswer(interpretation);
                if (!string.IsNullOrWhiteSpace(fallbackAnswer))
                {
                    return await SaveAndReturn(
                        request,
                        startTime,
                        fallbackAnswer,
                        citations,
                        interpretation.Page.InternalPageName,
                        interpretation.Action.ActionType.ToString());
                }
            }

            // 6) إذا السؤال غير محدد كفاية ولم يحدد الإجراء
            if (interpretation.HasPage && !interpretation.HasAction)
            {
                return await SaveAndReturn(
                    request,
                    startTime,
                    BuildUnableToAnswerMessage(),
                    citations,
                    interpretation.Page?.InternalPageName,
                    null);
            }

            return await SaveAndReturn(
                request,
                startTime,
                userFacingMessage,
                citations,
                interpretation.Page?.InternalPageName,
                interpretation.IsRegulationLike ? "REGULATION" : interpretation.Action?.ActionType.ToString());
        }
        catch (OperationCanceledException) when (timeoutCts.Token.IsCancellationRequested)
        {
            _log.LogWarning("AI_TIMEOUT");
            return await SaveAndReturn(
                request,
                startTime,
                "استغرق الطلب وقتًا أطول من المتوقع.\nحاول أن يكون سؤالك أقصر أو أوضح.",
                Array.Empty<KnowledgeChunk>(),
                null,
                null);
        }
        catch (OperationCanceledException)
        {
            return await SaveAndReturn(
                request,
                startTime,
                "تم إيقاف العملية.",
                Array.Empty<KnowledgeChunk>(),
                null,
                null);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "AI_ERROR");
            return await SaveAndReturn(
                request,
                startTime,
                "حدث خطأ غير متوقع في المساعد.",
                Array.Empty<KnowledgeChunk>(),
                null,
                null);
        }
    }

    private string TryAnswerProceduralDirectly(
    AssistantInterpretationResult interpretation,
    string userQuestion,
    IReadOnlyList<KnowledgeChunk> citations)
    {
        if (interpretation.Page is null || interpretation.Action is null || citations.Count == 0)
            return "";

        var entityKey = interpretation.Page.InternalPageName;
        var intent = MapActionToLegacyIntent(interpretation, userQuestion);

        if (string.IsNullOrWhiteSpace(intent))
            return "";

        var headers = ResolveCandidateHeaders(entityKey, intent, userQuestion);
        if (headers.Count == 0)
            return "";

        // مسار مباشر: إذا عرفنا الصفحة، اسحب ملفها أولاً بدل الاعتماد الكامل على نتائج البحث.
        var pageDoc = _kb.GetDocumentByPageInternalName(entityKey);
        if (!string.IsNullOrWhiteSpace(pageDoc))
        {
            foreach (var header in headers)
            {
                var extractedFromPage = ExtractSection(pageDoc, header);
                if (string.IsNullOrWhiteSpace(extractedFromPage))
                    continue;

                extractedFromPage = TrimToSingleSection(RemoveKeywords(extractedFromPage)).Trim();
                if (!string.IsNullOrWhiteSpace(extractedFromPage) &&
                    !extractedFromPage.Equals(header, StringComparison.OrdinalIgnoreCase))
                {
                    return extractedFromPage;
                }
            }
        }

        var fullDocCache = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var orderedCitations = citations
            .OrderByDescending(c => SourceMatchesPage(c.Source, entityKey))
            .ThenByDescending(c =>
                (c.Source ?? "").Contains("pages/", StringComparison.OrdinalIgnoreCase) ||
                (c.Source ?? "").Contains("pages\\", StringComparison.OrdinalIgnoreCase))
            .ThenByDescending(c =>
                interpretation.Action is not null &&
                ArabicTextNormalizer.Contains(c.Text ?? "", interpretation.Action.ArabicLabel))
            .Take(8)
            .ToList();

        foreach (var c in orderedCitations)
        {
            var text = c.Text ?? "";

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

            foreach (var header in headers)
            {
                var extracted = ExtractSection(text, header);
                if (string.IsNullOrWhiteSpace(extracted))
                    continue;

                extracted = TrimToSingleSection(RemoveKeywords(extracted)).Trim();
                if (!string.IsNullOrWhiteSpace(extracted) &&
                    !extracted.Equals(header, StringComparison.OrdinalIgnoreCase))
                {
                    return extracted;
                }
            }
        }

        return "";
    }

    private static IReadOnlyList<string> ResolveCandidateHeaders(string entityKey, string intent, string userQuestion)
    {
        var headers = new List<string>();
        var primary = ResolveHeader(entityKey, intent, userQuestion);
        if (!string.IsNullOrWhiteSpace(primary))
            headers.Add(primary);

        if (entityKey.Equals("WaitingListByResident", StringComparison.OrdinalIgnoreCase))
        {
            if (intent == "ADD")
            {
                if (ContainsAny(userQuestion, "خطاب تسكين", "خطاب", "خطابات"))
                {
                    headers.Add("## إضافة خطاب تسكين");
                    headers.Add("### إضافة خطاب تسكين جديد");
                }
                else
                {
                    headers.Add("## إضافة سجل انتظار");
                    headers.Add("### إضافة سجل انتظار جديد");
                }
            }

            if (intent == "UPDATE")
            {
                if (ContainsAny(userQuestion, "خطاب تسكين", "خطاب", "خطابات"))
                {
                    headers.Add("## تعديل خطاب تسكين");
                    headers.Add("### تعديل خطاب تسكين");
                }
                else
                {
                    headers.Add("## تعديل سجل انتظار");
                    headers.Add("### تعديل سجل انتظار");
                }
            }

            if (intent == "DELETE")
            {
                if (ContainsAny(userQuestion, "خطاب تسكين", "خطاب", "خطابات"))
                {
                    headers.Add("## حذف خطاب تسكين");
                    headers.Add("### حذف خطاب تسكين");
                }
                else
                {
                    headers.Add("## حذف سجل انتظار");
                    headers.Add("### حذف سجل انتظار");
                }
            }
        }

        if (entityKey.Equals("AllMeterRead", StringComparison.OrdinalIgnoreCase))
        {
            if (intent == "VIEW_ALL_READS")
                headers.Add("## عرض جميع قراءات العدادات");
            if (intent == "ADD_METER_READ")
                headers.Add("## إضافة قراءة عداد");
            if (intent == "APPROVE_METER")
                headers.Add("## اعتماد قراءة عداد");
            if (intent == "OPEN_PERIOD")
                headers.Add("## فتح فترة قراءة العدادات");
            if (intent == "CLOSE_PERIOD")
                headers.Add("## إغلاق فترة قراءة العدادات");
            if (intent == "READ_METER")
            {
                headers.Add("## إضافة قراءة عداد");
                headers.Add("## تعديل قراءة عداد");
            }
        }

        return headers
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static bool SourceMatchesPage(string? source, string pageInternalName)
    {
        if (string.IsNullOrWhiteSpace(source) || string.IsNullOrWhiteSpace(pageInternalName))
            return false;

        var normalized = source.Replace('\\', '/').Trim();
        return normalized.EndsWith($"/{pageInternalName}.md", StringComparison.OrdinalIgnoreCase) ||
               normalized.Equals($"{pageInternalName}.md", StringComparison.OrdinalIgnoreCase);
    }

    private string TryAnswerRegulationDirectly(
    string userQuestion,
    IReadOnlyList<KnowledgeChunk> citations)
    {
        var topic = ResolveRegulationTopic(userQuestion);
        var hasTopic = !string.IsNullOrWhiteSpace(topic);
        var topicDisplay = FormatRegulationTopicForDisplay(topic);
        var workingCitations = citations
            .Where(x => IsRegulationSource(x.Source))
            .ToList();

        if (workingCitations.Count == 0)
        {
            workingCitations = BuildRegulationFallbackCitations(topic, userQuestion);
        }

        if (workingCitations.Count == 0)
            return "";

        foreach (var citation in workingCitations.Take(6))
        {
            var doc = _kb.GetDocumentBySource(citation.Source ?? "") ?? citation.Text ?? "";
            if (string.IsNullOrWhiteSpace(doc))
                continue;

            doc = RemoveRegulationMetadata(doc);
            string extracted = "";

            if (hasTopic)
            {
                extracted = ExtractSection(doc, $"## {topic}");
                if (string.IsNullOrWhiteSpace(extracted))
                    extracted = ExtractSectionByTopicHeader(doc, topic);

                extracted = TrimToSingleSection(RemoveRegulationMetadata(RemoveKeywords(extracted))).Trim();
            }

            if (string.IsNullOrWhiteSpace(extracted))
            {
                extracted = ExtractBestRegulationPassage(doc, userQuestion);
                extracted = RemoveRegulationMetadata(RemoveKeywords(extracted)).Trim();
            }

            if (!string.IsNullOrWhiteSpace(extracted))
            {
                if (IsOperationalProceduralText(extracted))
                    continue;

                if (hasTopic)
                {
                    var topicInText = ArabicTextNormalizer.Contains(extracted, topic);
                    var topicInSource = ScoreRegulationSourceByTopic(citation.Source, topic) > 0;
                    if (!topicInText && !topicInSource)
                        continue;
                }

                return hasTopic
                    ? $"📘 الموضوع: {topicDisplay}\n\n{extracted}"
                    : extracted;
            }
        }

        return "";
    }

    private static bool IsOperationalProceduralText(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return true;

        return ContainsAny(
            text,
            "## تسجيل",
            "## إضافة",
            "## تعديل",
            "## حذف",
            "## اعتماد",
            "## نقل",
            "## رفع",
            "## فتح",
            "## إغلاق",
            "1. الدخول إلى صفحة",
            "2. الضغط على زر",
            "3. إدخال",
            "4. حفظ");
    }


    private static string MapActionToLegacyIntent(
    AssistantInterpretationResult interpretation,
    string userQuestion)
    {
        if (interpretation.Page is null || interpretation.Action is null)
            return "";

        var page = interpretation.Page.InternalPageName;
        var action = interpretation.Action.ActionType;

        if (page.Equals("Residents", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => "ADD",
                ActionType.Update => "UPDATE",
                ActionType.Delete => "DELETE",
                ActionType.Search => "SEARCH",
                ActionType.Print => "PRINT",
                _ => ""
            };
        }

        if (page.Equals("BuildingDetails", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => "ADD",
                ActionType.Update => "UPDATE",
                ActionType.Delete => "DELETE",
                ActionType.Search => "SEARCH",
                ActionType.Print => "PRINT",
                _ => ""
            };
        }

        if (page.Equals("BuildingClass", StringComparison.OrdinalIgnoreCase) ||
            page.Equals("BuildingType", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => "ADD",
                ActionType.Update => "UPDATE",
                ActionType.Delete => "DELETE",
                ActionType.Search => "SEARCH",
                ActionType.Print => "PRINT",
                _ => ""
            };
        }

        if (page.Equals("WaitingListByResident", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => "ADD",
                ActionType.Update => "UPDATE",
                ActionType.Delete => "DELETE",
                ActionType.Search => "SEARCH",
                ActionType.Print => "PRINT",
                ActionType.Export => "EXPORT",
                _ => ""
            };
        }

        if (page.Equals("Assign", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.OpenPeriod => "OPEN_ASSIGN",
                ActionType.ClosePeriod => "CLOSE_ASSIGN",
                ActionType.Assign => "ASSIGN_HOUSE",
                ActionType.Update => "UPDATE_ASSIGN",
                ActionType.Exclude => "EXCLUDE_ASSIGN",
                ActionType.Search => "SEARCH",
                ActionType.Print => "PRINT",
                ActionType.Export => "EXPORT",
                _ => ""
            };
        }

        if (page.Equals("AllMeterRead", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.View => "VIEW_ALL_READS",
                ActionType.OpenPeriod => "OPEN_PERIOD",
                ActionType.ClosePeriod => "CLOSE_PERIOD",
                ActionType.ReadMeter => ContainsAny(userQuestion, "إضافة قراءة عداد", "اضافة قراءة عداد", "أضيف قراءة عداد", "اضيف قراءة عداد", "قراءة عداد جديدة")
                    ? "ADD_METER_READ"
                    : "READ_METER",
                ActionType.Approve => "APPROVE_METER",
                _ => ""
            };
        }

        if (page.Equals("Meters", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => ContainsAny(userQuestion, "نوع عداد", "أنواع العدادات", "اضافة نوع عداد", "إضافة نوع عداد")
                    ? "ADD_METER_TYPE"
                    : "ADD_METER",
                ActionType.Assign => "LINK_METER_BUILDING",
                ActionType.Update => ContainsAny(userQuestion, "نوع عداد", "تعديل نوع عداد")
                    ? "UPDATE_METER_TYPE"
                    : "UPDATE_METER",
                ActionType.Delete => ContainsAny(userQuestion, "نوع عداد", "حذف نوع عداد")
                    ? "DELETE_METER_TYPE"
                    : "DELETE_METER",
                _ => ""
            };
        }

        if (page.Equals("HousingExit", StringComparison.OrdinalIgnoreCase))
        {
            return action switch
            {
                ActionType.Add => "ADD",
                ActionType.Update => "UPDATE",
                ActionType.Delete => "DELETE",
                ActionType.Approve => "APPROVE",
                ActionType.Review => "SEND_FINANCE",
                _ => ""
            };
        }

        return "";
    }


    private static string BuildSystemPromptForLlm(
    AssistantInterpretationResult interpretation,
    IReadOnlyList<KnowledgeChunk> citations,
    string userQuestion)
    {
        var sb = new StringBuilder();

        sb.AppendLine("أنت مساعد ذكي داخل نظام SmartFoundation.");
        sb.AppendLine("أجب بالعربية فقط.");
        sb.AppendLine("اعتمد على المقاطع التالية فقط ولا تخترع معلومات.");
        sb.AppendLine("إذا لم تجد جوابًا واضحًا، قل ذلك بوضوح.");
        sb.AppendLine();

        if (interpretation.Page is not null)
            sb.AppendLine($"اسم الصفحة: {interpretation.Page.ArabicPageName}");

        if (interpretation.Action is not null)
            sb.AppendLine($"الإجراء: {interpretation.Action.ArabicLabel}");

        sb.AppendLine($"نوع السؤال اللائحي: {(interpretation.IsRegulationLike ? "نعم" : "لا")}");
        sb.AppendLine();

        foreach (var c in citations.Take(4))
        {
            var txt = Clip(RemoveKeywords(c.Text ?? ""), 700);
            if (!string.IsNullOrWhiteSpace(txt))
            {
                sb.AppendLine("مقطع:");
                sb.AppendLine(txt);
                sb.AppendLine();
            }
        }

        return sb.ToString().Trim();
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
            ("Residents", "PRINT") => "## طباعة بيانات مستفيد",

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

            ("BuildingType", "ADD") => "## إضافة نوع مبنى",
            ("BuildingType", "UPDATE") => "## تعديل نوع مبنى",
            ("BuildingType", "DELETE") => "## حذف نوع مبنى",
            ("BuildingType", "SEARCH") => "## البحث عن نوع مبنى",

            ("ResidentClass", "ADD") => "## إضافة فئة مستفيد",
            ("ResidentClass", "UPDATE") => "## تعديل فئة مستفيد",
            ("ResidentClass", "DELETE") => "## حذف فئة مستفيد",

            ("WaitingListByResident", "SEARCH") => "## البحث في قائمة الانتظار حسب المستفيد",
            ("WaitingListByResident", "ADD") => ContainsAny(userQuery, "خطاب تسكين", "خطاب", "خطابات")
                ? "## إضافة خطاب تسكين"
                : "## إضافة سجل انتظار",
            ("WaitingListByResident", "UPDATE") => ContainsAny(userQuery, "خطاب تسكين", "خطاب", "خطابات")
                ? "## تعديل خطاب تسكين"
                : "## تعديل سجل انتظار",
            ("WaitingListByResident", "DELETE") => ContainsAny(userQuery, "خطاب تسكين", "خطاب", "خطابات")
                ? "## حذف خطاب تسكين"
                : "## حذف سجل انتظار",
            ("WaitingListByResident", "PRINT") => "## طباعة بيانات مستفيد",
            ("WaitingListByResident", "EXPORT") => "## طباعة بيانات مستفيد",

            ("Assign", "OPEN_ASSIGN") => "## إنشاء محضر تخصيص جديد",
            ("Assign", "CLOSE_ASSIGN") => "## إغلاق محضر التخصيص",
            ("Assign", "ASSIGN_HOUSE") => "## تخصيص منزل لمستفيد",
            ("Assign", "UPDATE_ASSIGN") => "## تعديل تخصيص منزل",
            ("Assign", "EXCLUDE_ASSIGN") => "## استبعاد مستفيد من محضر التخصيص",
            ("Assign", "SEARCH") => "## البحث عن مستفيد",
            ("Assign", "DETAILS") => "## عرض التفاصيل",
            ("Assign", "PRINT") => "## طباعة خطاب",
            ("Assign", "EXPORT") => "## تصدير البيانات",

            ("AllMeterRead", "VIEW_ALL_READS") => "## عرض جميع قراءات العدادات",
            ("AllMeterRead", "OPEN_PERIOD") => "## فتح فترة قراءة العدادات",
            ("AllMeterRead", "CLOSE_PERIOD") => "## إغلاق فترة قراءة العدادات",
            ("AllMeterRead", "ADD_METER_READ") => "## إضافة قراءة عداد",
            ("AllMeterRead", "READ_METER") => "## تعديل قراءة عداد",
            ("AllMeterRead", "APPROVE_METER") => "## اعتماد قراءة عداد",
            ("Meters", "ADD_METER") => "## إضافة عداد",
            ("Meters", "ADD_METER_TYPE") => "## إضافة نوع عداد",
            ("Meters", "LINK_METER_BUILDING") => "## ربط عداد بمبنى",
            ("Meters", "UPDATE_METER") => "## تعديل عداد",
            ("Meters", "UPDATE_METER_TYPE") => "## تعديل نوع عداد",
            ("Meters", "DELETE_METER") => "## حذف عداد",
            ("Meters", "DELETE_METER_TYPE") => "## حذف نوع عداد",
            ("HousingExit", "ADD") => "## تسجيل إخلاء",
            ("HousingExit", "UPDATE") => "## تعديل إخلاء",
            ("HousingExit", "APPROVE") => "## اعتماد الإخلاء",
            ("HousingExit", "SEND_FINANCE") => "## إرسال الإخلاء للتدقيق المالي",

            _ => ""
        };
    }


    // =========================================================
    // Interpretation + Permissions
    // =========================================================

    private AssistantInterpretationResult BuildInterpretationResult(
        AiChatRequest request,
        string userQuestion,
        string? currentInternalPageName)
    {
        var match = SystemModuleMatcher.MatchQuestion(userQuestion, currentInternalPageName);
        var permissionMap = UserPermissionSessionAccessor.GetCurrent()
            ?? ResolvePermissionMapFromRequest(request);
        var permission = ResolvePermission(permissionMap, match);

        var looksLikeRegulation = SystemModuleMatcher.LooksLikeRegulationQuestion(userQuestion);
        var isRegulationLike =
            looksLikeRegulation ||
            (match.Page?.ModuleType == ModuleType.Regulation && match.Action is null);

        return new AssistantInterpretationResult
        {
            OriginalQuestion = match.OriginalQuestion,
            NormalizedQuestion = match.NormalizedQuestion,
            Page = match.Page,
            Action = match.Action,
            PageScore = match.PageScore,
            ActionScore = match.ActionScore,
            MatchedPageKeywords = match.MatchedPageKeywords,
            MatchedActionKeywords = match.MatchedActionKeywords,
            Permission = permission,
            IsRegulationLike = isRegulationLike
        };
    }

    private static UserPermissionMap? ResolvePermissionMapFromRequest(AiChatRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserPermissionsJson))
            return null;

        try
        {
            var map = JsonSerializer.Deserialize<UserPermissionMap>(request.UserPermissionsJson);

            return map;
        }
        catch (Exception ex)
        {
            Console.WriteLine("❌ Failed to parse permissions: " + ex.Message);
            return null;
        }
    }

    private static PermissionDecision ResolvePermission(
        UserPermissionMap? permissionMap,
        SystemQuestionMatchResult match)
    {
        if (match.Page is null)
        {
            return new PermissionDecision
            {
                HasAnyPageAccess = false,
                HasRequestedActionPermission = false,
                CanExplainDetailedPageFlow = false,
                CanExplainGeneralOnly = false,
                DenyReasonArabic = AssistantArabicPhrases.BuildPageNotFoundMessage(string.Empty)
            };
        }

        var page = match.Page;

        if (permissionMap is null)
        {
            return new PermissionDecision
            {
                InternalPageName = page.InternalPageName,
                ArabicPageName = page.ArabicPageName,
                HasAnyPageAccess = false,
                HasRequestedActionPermission = false,
                CanExplainDetailedPageFlow = false,
                CanExplainGeneralOnly = false,
                DenyReasonArabic = AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
            };
        }

        var pagePermissionSet = permissionMap.FindPage(page.InternalPageName);
        var hasAnyPageAccess = pagePermissionSet?.HasAccess() == true;

        if (!hasAnyPageAccess)
        {
            return new PermissionDecision
            {
                InternalPageName = page.InternalPageName,
                ArabicPageName = page.ArabicPageName,
                HasAnyPageAccess = false,
                HasRequestedActionPermission = false,
                CanExplainDetailedPageFlow = false,
                CanExplainGeneralOnly = false,
                PagePermissionSet = pagePermissionSet,
                DenyReasonArabic = AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
            };
        }

        if (match.Action is null)
        {
            return new PermissionDecision
            {
                InternalPageName = page.InternalPageName,
                ArabicPageName = page.ArabicPageName,
                HasAnyPageAccess = true,
                HasRequestedActionPermission = true,
                CanExplainDetailedPageFlow = true,
                CanExplainGeneralOnly = true,
                PagePermissionSet = pagePermissionSet
            };
        }

        var requiredPermissionNames = match.Action.PermissionNames?
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray() ?? Array.Empty<string>();

        if (requiredPermissionNames.Length == 0)
        {
            return new PermissionDecision
            {
                InternalPageName = page.InternalPageName,
                ArabicPageName = page.ArabicPageName,
                HasAnyPageAccess = true,
                HasRequestedActionPermission = true,
                CanExplainDetailedPageFlow = true,
                CanExplainGeneralOnly = true,
                PagePermissionSet = pagePermissionSet
            };
        }

        var hasRequestedActionPermission = pagePermissionSet?.HasAnyPermission(requiredPermissionNames) == true;

        if (!hasRequestedActionPermission)
        {
            return new PermissionDecision
            {
                InternalPageName = page.InternalPageName,
                ArabicPageName = page.ArabicPageName,
                RequestedPermissionName = string.Join(", ", requiredPermissionNames),
                HasAnyPageAccess = true,
                HasRequestedActionPermission = false,
                CanExplainDetailedPageFlow = false,
                CanExplainGeneralOnly = false,
                PagePermissionSet = pagePermissionSet,
                DenyReasonArabic = AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
            };
        }

        return new PermissionDecision
        {
            InternalPageName = page.InternalPageName,
            ArabicPageName = page.ArabicPageName,
            RequestedPermissionName = string.Join(", ", requiredPermissionNames),
            HasAnyPageAccess = true,
            HasRequestedActionPermission = true,
            CanExplainDetailedPageFlow = true,
            CanExplainGeneralOnly = true,
            PagePermissionSet = pagePermissionSet
        };
    }

    private static string BuildUserFacingMessage(AssistantInterpretationResult result)
    {
        if (result is null)
            return AssistantArabicPhrases.UnexpectedErrorMessage;

        if (!result.HasPage)
            return AssistantArabicPhrases.UnknownQuestionMessage;

        if (!result.CanExplainDetailedPageFlow)
        {
            if (result.CanExplainGeneralOnly)
            {
                var intro = AssistantArabicPhrases.BuildPageIntroMessage(
                    result.ArabicPageName ?? "",
                    result.Page?.ArabicDescription ?? "");

                var examples = AssistantArabicPhrases.BuildExamplesForPage(
                    result.ArabicPageName ?? "",
                    result.Page?.SuggestedQuestionsArabic ?? Array.Empty<string>());

                return string.Join("\n\n",
                    new[]
                    {
                        result.Permission.DenyReasonArabic,
                        intro,
                        examples
                    }.Where(x => !string.IsNullOrWhiteSpace(x)));
            }

            return result.Permission.DenyReasonArabic
                   ?? AssistantArabicPhrases.NoPermissionMessage;
        }

        if (result.HasPage && !result.HasAction)
        {
            var intro = AssistantArabicPhrases.BuildPageIntroMessage(
                result.ArabicPageName ?? "",
                result.Page?.ArabicDescription ?? "");

            var examples = AssistantArabicPhrases.BuildExamplesForPage(
                result.ArabicPageName ?? "",
                result.Page?.SuggestedQuestionsArabic ?? Array.Empty<string>());

            if (result.IsRegulationLike)
            {
                return string.Join("\n\n",
                    new[]
                    {
                        intro,
                        "فهمت أن سؤالك يتعلق باللوائح أو الشروط أو الجانب النظامي المرتبط بهذه الصفحة.",
                        "سأعتمد على اللوائح والأنظمة والمعرفة المتاحة لإعطائك الإجابة المناسبة.",
                        examples
                    }.Where(x => !string.IsNullOrWhiteSpace(x)));
            }

            var availableActions = result.Page?.Actions?
                .Select(x => x.ArabicLabel)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct()
                .ToArray() ?? Array.Empty<string>();

            var clarification = AssistantArabicPhrases.BuildActionClarificationMessage(
                result.ArabicPageName ?? "",
                availableActions);

            return string.Join("\n\n",
                new[]
                {
                    intro,
                    clarification,
                    examples
                }.Where(x => !string.IsNullOrWhiteSpace(x)));
        }

        if (result.HasPage && result.HasAction)
        {
            var intro = AssistantArabicPhrases.BuildPageIntroMessage(
                result.ArabicPageName ?? "",
                result.Page?.ArabicDescription ?? "");

            return string.Join("\n\n",
                new[]
                {
                    intro,
                    $"فهمت أنك تريد: {result.ArabicActionName} في صفحة {result.ArabicPageName}.",
                    "سأعتمد الآن على شرح الصفحة والمعرفة المتاحة لإعطائك الإجابة المناسبة."
                }.Where(x => !string.IsNullOrWhiteSpace(x)));
        }

        return AssistantArabicPhrases.UnknownQuestionMessage;
    }

    private static bool TryBuildGeneralOfficialResponse(
        string userQuestion,
        out string response,
        out string intent)
    {
        response = "";
        intent = "GENERAL";

        if (string.IsNullOrWhiteSpace(userQuestion))
            return false;

        var normalized = ArabicTextNormalizer.Normalize(userQuestion);
        var now = DateTimeOffset.Now;

        if (ContainsAny(normalized, "كم الساعه", "كم الساعة", "ما الوقت", "ماهو الوقت", "ما هو الوقت", "الوقت الان", "الوقت الآن", "الساعه الان", "الساعة الآن", "الوقت حاليا", "الوقت حالياً"))
        {
            var culture = new CultureInfo("ar-SA");
            var dayName = culture.DateTimeFormat.GetDayName(now.DayOfWeek);

            response =
                $"الوقت الحالي هو {now:HH:mm}.\n" +
                $"تاريخ اليوم: {dayName} {now:dd/MM/yyyy}.\n" +
                "(وفق وقت الخادم المحلي).";
            intent = "GENERAL_TIME";
            return true;
        }

        if (ContainsAny(normalized, "تاريخ اليوم", "اليوم كم", "ما تاريخ اليوم", "كم التاريخ", "اي يوم", "أي يوم"))
        {
            var culture = new CultureInfo("ar-SA");
            var dayName = culture.DateTimeFormat.GetDayName(now.DayOfWeek);
            response = $"تاريخ اليوم هو {dayName} {now:dd/MM/yyyy} (وفق وقت الخادم المحلي).";
            intent = "GENERAL_DATE";
            return true;
        }

        if (ContainsAny(normalized, "من انت", "من أنت", "تعريفك", "وش دورك", "ما دورك", "ماذا تستطيع"))
        {
            response =
                "أنا مساعد ذكي رسمي داخل النظام.\n" +
                "أقدّم شرح الإجراءات واللوائح المعتمدة وفق الصلاحيات المتاحة للمستخدم.";
            intent = "GENERAL_IDENTITY";
            return true;
        }

        if (ContainsAny(normalized, "شكرا", "شكرًا", "يعطيك العافيه", "يعطيك العافية"))
        {
            response = "شكرًا لكم. في خدمتكم.";
            intent = "GENERAL_THANKS";
            return true;
        }

        if (ContainsAny(normalized, "كيف حالك", "اخبارك", "أخبارك"))
        {
            response = "شكرًا لسؤالكم. أنا جاهز لخدمتكم في استفسارات النظام.";
            intent = "GENERAL_SMALLTALK";
            return true;
        }

        if (ContainsAny(normalized, "طقس", "اخبار", "أخبار", "سعر الدولار", "سعر الذهب", "بيتكوين", "انترنت", "إنترنت"))
        {
            response =
                "هذه الخدمة تعمل محليًا وبدون اتصال بالإنترنت.\n" +
                "لذلك أجيب فقط عن إجراءات النظام واللوائح المعتمدة داخله.";
            intent = "GENERAL_OFFLINE_SCOPE";
            return true;
        }

        return false;
    }

    private static string BuildUnableToAnswerMessage()
    {
        return
            "أعتذر منك، لم أتمكن من الإجابة بدقة 🙏\n" +
            "سأحاول تطوير نفسي بشكل مستمر، حيث أنني لا زلت في مرحلة التدريب حاليًا.\n\n" +
            "يمكنك مساعدتي بطرح سؤالك بشكل أوضح، مثل:\n\n" +
            "* كيف أضيف عداد جديد؟\n" +
            "* كيف أفتح فترة قراءة العدادات؟\n" +
            "* كيف أبحث عن مستفيد؟\n" +
            "* كيف أعدل بيانات الساكن؟\n" +
            "* كيف أطبع التقرير؟\n" +
            "* أين أجد صفحة التخصيص؟\n" +
            "* كيف أسجل قراءة عداد؟\n\n" +
            "كلما كان سؤالك محددًا أكثر، كانت إجابتي أدق 👍";
    }

    private static string ResolveGenericActionIntent(AssistantInterpretationResult interpretation, string userQuestion)
    {
        var actionType = interpretation.Action?.ActionType;

        var resolved = actionType switch
        {
            ActionType.Add => "ADD",
            ActionType.Update => "UPDATE",
            ActionType.Delete => "DELETE",
            ActionType.Search => "SEARCH",
            ActionType.Print => "PRINT",
            _ => string.Empty
        };

        if (!string.IsNullOrWhiteSpace(resolved))
            return resolved;

        return TryDetectGenericActionIntent(userQuestion, out var inferredIntent)
            ? inferredIntent
            : string.Empty;
    }

    private static void RegisterPendingActionQuestion(string convoKey, string intent, string originalMessage)
    {
        if (string.IsNullOrWhiteSpace(convoKey) || string.IsNullOrWhiteSpace(intent))
            return;

        _pending[convoKey] = new PendingState
        {
            Intent = intent,
            OriginalMessage = originalMessage,
            At = DateTimeOffset.UtcNow
        };
    }

    private static bool TryExpandPendingActionQuestion(string convoKey, string currentMessage, out string expandedQuestion)
    {
        expandedQuestion = currentMessage;

        if (string.IsNullOrWhiteSpace(convoKey) || string.IsNullOrWhiteSpace(currentMessage))
            return false;

        if (!_pending.TryGetValue(convoKey, out var pendingState))
            return false;

        if (DateTimeOffset.UtcNow - pendingState.At > PendingTtl)
        {
            _pending.TryRemove(convoKey, out _);
            return false;
        }

        // إذا عاد المستخدم وسأل بصيغة كاملة جديدة، نلغي الحالة المؤقتة.
        if (ContainsAny(currentMessage, "كيف", "أضيف", "اضيف", "أعدل", "اعدل", "أحذف", "احذف", "أبحث", "ابحث", "أطبع", "اطبع"))
        {
            _pending.TryRemove(convoKey, out _);
            return false;
        }

        var directPage = ResolveDirectEntityReplyPage(currentMessage);
        var matchedPage = directPage;

        if (matchedPage is null)
        {
            var pageMatch = SystemModuleMatcher.MatchPage(currentMessage);
            if (pageMatch.Page is null || pageMatch.Score < 3)
                return false;

            matchedPage = pageMatch.Page;
        }

        var canonical = BuildCanonicalActionQuestion(pendingState.Intent, matchedPage, currentMessage);
        if (string.IsNullOrWhiteSpace(canonical))
            return false;

        expandedQuestion = canonical;
        pendingState.At = DateTimeOffset.UtcNow;
        _pending.TryRemove(convoKey, out _);
        return true;
    }

    private static bool TryCanonicalizeDirectActionQuestion(string question, out string canonicalQuestion)
    {
        canonicalQuestion = question;

        if (!TryDetectGenericActionIntent(question, out var intent))
            return false;

        var page = ResolveDirectEntityReplyPage(question);
        if (page is null)
            return false;

        var canonical = BuildCanonicalActionQuestion(intent, page, question);
        if (string.IsNullOrWhiteSpace(canonical))
            return false;

        canonicalQuestion = canonical;
        return true;
    }

    private static string BuildCanonicalActionQuestion(string intent, SystemPageDefinition page, string? sourceText = null)
    {
        if (page is null || string.IsNullOrWhiteSpace(intent))
            return string.Empty;

        var src = sourceText ?? string.Empty;

        string actionPhrase;

        if (page.InternalPageName.Equals("Meters", StringComparison.OrdinalIgnoreCase))
        {
            var isType = ContainsAny(src, "نوع عداد", "أنواع العدادات", "انواع العدادات");
            var isLink = ContainsAny(src, "ربط عداد", "ربط عداد بمبنى", "اربط عداد");

            actionPhrase = intent switch
            {
                "ADD" => isType ? "إضافة نوع عداد" : (isLink ? "ربط عداد بمبنى" : "إضافة عداد"),
                "UPDATE" => isType ? "تعديل نوع عداد" : "تعديل عداد",
                "DELETE" => isType ? "حذف نوع عداد" : "حذف عداد",
                "SEARCH" => "البحث عن عداد",
                "PRINT" => "طباعة تقرير العدادات",
                _ => string.Empty
            };

            return actionPhrase;
        }

        if (page.InternalPageName.Equals("AllMeterRead", StringComparison.OrdinalIgnoreCase))
        {
            actionPhrase = intent switch
            {
                "ADD" => "إضافة قراءة عداد",
                "UPDATE" => "تعديل قراءة عداد",
                "SEARCH" => "البحث في جميع قراءات العدادات",
                _ => string.Empty
            };

            return actionPhrase;
        }

        if (page.InternalPageName.Equals("WaitingListByResident", StringComparison.OrdinalIgnoreCase))
        {
            actionPhrase = intent switch
            {
                "ADD" => "إضافة سجل انتظار",
                "UPDATE" => "تعديل سجل انتظار",
                "DELETE" => "حذف سجل انتظار",
                "SEARCH" => "البحث عن سجل انتظار",
                "PRINT" => "طباعة بيانات مستفيد",
                _ => string.Empty
            };

            return actionPhrase;
        }

        if (page.InternalPageName.Equals("BuildingDetails", StringComparison.OrdinalIgnoreCase))
        {
            actionPhrase = intent switch
            {
                "ADD" => "إضافة مبنى",
                "UPDATE" => "تعديل مبنى",
                "DELETE" => "حذف مبنى",
                "SEARCH" => "البحث عن مبنى",
                "PRINT" => "طباعة تقرير المباني",
                _ => string.Empty
            };

            return actionPhrase;
        }

        if (page.InternalPageName.Equals("Residents", StringComparison.OrdinalIgnoreCase))
        {
            actionPhrase = intent switch
            {
                "ADD" => "إضافة مستفيد",
                "UPDATE" => "تعديل مستفيد",
                "DELETE" => "حذف مستفيد",
                "SEARCH" => "البحث عن مستفيد",
                "PRINT" => "طباعة بيانات مستفيد",
                _ => string.Empty
            };

            return actionPhrase;
        }

        var actionWord = intent switch
        {
            "ADD" => "إضافة",
            "UPDATE" => "تعديل",
            "DELETE" => "حذف",
            "SEARCH" => "بحث",
            "PRINT" => "طباعة",
            _ => string.Empty
        };

        if (string.IsNullOrWhiteSpace(actionWord))
            return string.Empty;

        return $"{actionWord} {page.ArabicPageName}";
    }

    private static SystemPageDefinition? ResolveDirectEntityReplyPage(string entityReply)
    {
        if (string.IsNullOrWhiteSpace(entityReply))
            return null;

        if (ContainsAny(entityReply, "قراءة عداد", "قراءات العدادات", "جميع قراءات العدادات"))
            return SystemModuleRegistry.FindPageByInternalName("AllMeterRead");

        if (ContainsAny(entityReply, "نوع عداد", "أنواع العدادات", "انواع العدادات"))
            return SystemModuleRegistry.FindPageByInternalName("Meters");

        if (ContainsAny(entityReply, "مستفيد", "المستفيد", "المستفيدين"))
            return SystemModuleRegistry.FindPageByInternalName("Residents");

        if (ContainsAny(entityReply, "مبنى", "المبنى", "المباني"))
            return SystemModuleRegistry.FindPageByInternalName("BuildingDetails");

        if (ContainsAny(entityReply, "عداد", "العداد", "العدادات"))
            return SystemModuleRegistry.FindPageByInternalName("Meters");

        if (ContainsAny(entityReply, "سجل انتظار", "سجلات الانتظار", "قائمة انتظار", "قوائم الانتظار"))
            return SystemModuleRegistry.FindPageByInternalName("WaitingListByResident");

        if (ContainsAny(entityReply, "فئة مبنى", "فئات المباني"))
            return SystemModuleRegistry.FindPageByInternalName("BuildingClass");

        if (ContainsAny(entityReply, "نوع مبنى", "أنواع المباني", "انواع المباني"))
            return SystemModuleRegistry.FindPageByInternalName("BuildingType");

        return null;
    }

    private static bool TryGetActivePendingIntent(string convoKey, out string intent)
    {
        intent = string.Empty;

        if (string.IsNullOrWhiteSpace(convoKey))
            return false;

        if (!_pending.TryGetValue(convoKey, out var pendingState))
            return false;

        if (DateTimeOffset.UtcNow - pendingState.At > PendingTtl)
        {
            _pending.TryRemove(convoKey, out _);
            return false;
        }

        intent = pendingState.Intent ?? string.Empty;
        return !string.IsNullOrWhiteSpace(intent);
    }

    private static bool IsLikelyEntityReply(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
            return false;

        if (ContainsAny(message, "كيف", "أضيف", "اضيف", "أعدل", "اعدل", "أحذف", "احذف", "أبحث", "ابحث", "أطبع", "اطبع"))
            return false;

        var tokens = ArabicTextNormalizer.Tokenize(message);
        return tokens.Length is > 0 and <= 3;
    }

    private static bool TryDetectGenericActionIntent(string message, out string intent)
    {
        intent = string.Empty;
        if (string.IsNullOrWhiteSpace(message))
            return false;

        var normalized = ArabicTextNormalizer.Normalize(message);

        if (ContainsAny(normalized, "كيف اضيف", "كيف أضيف", "ابي اضيف", "أبي أضيف", "اضافه", "إضافة"))
        {
            intent = "ADD";
            return true;
        }

        if (ContainsAny(normalized, "كيف اعدل", "كيف أعدل", "ابي اعدل", "أبي أعدل", "تعديل"))
        {
            intent = "UPDATE";
            return true;
        }

        if (ContainsAny(normalized, "كيف احذف", "كيف أحذف", "ابي احذف", "أبي أحذف", "حذف"))
        {
            intent = "DELETE";
            return true;
        }

        if (ContainsAny(normalized, "كيف ابحث", "كيف أبحث", "ابي ابحث", "أبي أبحث", "بحث"))
        {
            intent = "SEARCH";
            return true;
        }

        if (ContainsAny(normalized, "كيف اطبع", "كيف أطبع", "ابي اطبع", "أبي أطبع", "طباعه", "طباعة"))
        {
            intent = "PRINT";
            return true;
        }

        return false;
    }

    private static string BuildGenericActionClarificationMessage(string intent)
    {
        return intent switch
        {
            "ADD" =>
                "ماذا تريد أن تضيف؟\n\n" +
                "يمكنك التحديد مثل:\n" +
                "• مبنى\n" +
                "• مستفيد\n" +
                "• سجل انتظار\n" +
                "• عداد",

            "UPDATE" =>
                "ماذا تريد أن تعدل؟\n\n" +
                "يمكنك التحديد مثل:\n" +
                "• مبنى\n" +
                "• مستفيد\n" +
                "• فئة مبنى\n" +
                "• نوع مبنى",

            "DELETE" =>
                "ماذا تريد أن تحذف؟\n\n" +
                "يمكنك التحديد مثل:\n" +
                "• مبنى\n" +
                "• مستفيد\n" +
                "• سجل انتظار\n" +
                "• عداد",

            "SEARCH" =>
                "في أي صفحة تريد تنفيذ البحث؟\n\n" +
                "مثال: مستفيد، مبنى، قائمة انتظار، قراءات العدادات.",

            "PRINT" =>
                "ما الذي تريد طباعته؟\n\n" +
                "مثال: تقرير المستفيدين، تقرير المباني، تقرير القراءات.",

            _ =>
                "يرجى تحديد الصفحة المطلوبة أولًا حتى أقدم خطوات دقيقة.\n\n" +
                "مثال: كيف أعدل مبنى؟ أو كيف أعدل فئة مبنى؟"
        };
    }

    private static bool IsGenericActionOnlyQuestion(string userQuestion, AssistantInterpretationResult interpretation)
    {
        if (string.IsNullOrWhiteSpace(userQuestion))
            return false;

        if (interpretation.IsRegulationLike)
            return false;

        var tokens = ArabicTextNormalizer.Tokenize(userQuestion);
        if (tokens.Length > 4)
            return false;

        if (!TryDetectGenericActionIntent(userQuestion, out _))
            return false;

        var hasPageSignal = interpretation.MatchedPageKeywords is { Count: > 0 };
        if (hasPageSignal)
            return false;

        return true;
    }

    // =========================================================
    // Search
    // =========================================================

    private IReadOnlyList<string> BuildSearchQueries(
        string originalQuestion,
        AssistantInterpretationResult interpretation)
    {
        var queries = new List<string>();

        if (!string.IsNullOrWhiteSpace(originalQuestion))
            queries.Add(originalQuestion);

        var normalized = ArabicTextNormalizer.Normalize(originalQuestion);
        if (!string.IsNullOrWhiteSpace(normalized))
            queries.Add(normalized);

        if (interpretation.Page is not null)
        {
            queries.Add(interpretation.Page.ArabicPageName);
            queries.Add(interpretation.Page.InternalPageName);
            queries.Add($"{originalQuestion} {interpretation.Page.ArabicPageName}");
            queries.Add($"{normalized} {interpretation.Page.ArabicPageName}");
            queries.Add($"{normalized} {interpretation.Page.InternalPageName}");
        }

        if (interpretation.Action is not null)
        {
            queries.Add($"{originalQuestion} {interpretation.Action.ArabicLabel}");
            queries.Add($"{normalized} {interpretation.Action.ArabicLabel}");
        }

        if (interpretation.IsRegulationLike)
        {
            queries.Add($"{originalQuestion} لائحة نظام شروط ضوابط");
            queries.Add($"{normalized} لائحة نظام شروط ضوابط");
        }

        return queries
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(5)
            .ToArray();
    }

    private IReadOnlyList<string> BuildRegulationSearchQueries(
        string originalQuestion,
        AssistantInterpretationResult interpretation)
    {
        var queries = new List<string>();

        if (!string.IsNullOrWhiteSpace(originalQuestion))
            queries.Add(originalQuestion);

        var normalized = ArabicTextNormalizer.Normalize(originalQuestion);
        if (!string.IsNullOrWhiteSpace(normalized))
            queries.Add(normalized);

        var topic = ResolveRegulationTopic(originalQuestion);
        if (!string.IsNullOrWhiteSpace(topic))
        {
            queries.Add(topic);
            queries.Add($"{topic} تعريف شروط ضوابط");

            if (ContainsAny(topic, "احقي", "أحقي", "استحقاق"))
                queries.Add("أحقية السكن شروط الاستحقاق");

            if (ContainsAny(topic, "اخلاء", "إخلاء"))
                queries.Add("شروط الإخلاء الفترة الانتقالية");

            if (ContainsAny(topic, "تلف", "جزئي", "كلي", "صيانة"))
                queries.Add("التلف الجزئي التلف الكلي الصيانة المسؤولية");
        }

        queries.Add($"{originalQuestion} لائحة نظام شروط ضوابط تعريف");
        queries.Add($"{normalized} لائحة نظام شروط ضوابط تعريف");
        queries.Add("اللوائح والانظمة الاسكان");

        if (interpretation.Page is not null)
        {
            queries.Add(interpretation.Page.ArabicPageName);
            queries.Add($"{interpretation.Page.ArabicPageName} شروط");
            queries.Add($"{interpretation.Page.ArabicPageName} تعريف");
        }

        return queries
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(6)
            .ToArray();
    }

    private IReadOnlyList<KnowledgeChunk> SearchKnowledgeBase(
        IReadOnlyList<string> queries,
        AssistantInterpretationResult interpretation,
        int topK)
    {
        var all = new List<KnowledgeChunk>();

        foreach (var q in queries)
        {
            var hits = _kb.Search(q, topK);
            if (hits is { Count: > 0 })
                all.AddRange(hits);
        }

        var deduped = all
            .Where(x => !string.IsNullOrWhiteSpace(x.Source) && !string.IsNullOrWhiteSpace(x.Text))
            .GroupBy(x => $"{x.Source}::{x.Text}", StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();

        if (interpretation.Page is not null)
        {
            deduped = deduped
                .OrderByDescending(x =>
                {
                    var score = 0;
                    var src = (x.Source ?? "").Replace('\\', '/');

                    if (ContainsAny(src, interpretation.Page.InternalPageName))
                        score += 8;

                    if (ContainsAny(x.Text ?? "", interpretation.Page.ArabicPageName))
                        score += 5;

                    if (src.EndsWith($"/{interpretation.Page.InternalPageName}.md", StringComparison.OrdinalIgnoreCase) ||
                        src.Equals($"{interpretation.Page.InternalPageName}.md", StringComparison.OrdinalIgnoreCase))
                    {
                        score += 20;
                    }

                    if (src.Contains("pages/", StringComparison.OrdinalIgnoreCase))
                        score += 6;

                    if (interpretation.Action is not null &&
                        ContainsAny(x.Text ?? "", interpretation.Action.ArabicLabel))
                        score += 4;

                    if (interpretation.IsRegulationLike &&
                        ContainsAny(x.Text ?? "", "شروط", "ضوابط", "لائحة", "تعريف", "أحقية", "إخلاء"))
                        score += 6;

                    return score;
                })
                .Take(Math.Max(topK, 5))
                .ToList();
        }
        else
        {
            deduped = deduped.Take(Math.Max(topK, 5)).ToList();
        }

        return deduped;
    }

    private IReadOnlyList<KnowledgeChunk> SearchRegulationKnowledgeBase(
        IReadOnlyList<string> queries,
        AssistantInterpretationResult interpretation,
        string userQuestion,
        int topK)
    {
        var all = new List<KnowledgeChunk>();

        foreach (var q in queries)
        {
            var hits = _kb.Search(q, Math.Max(topK, 4));
            if (hits is { Count: > 0 })
                all.AddRange(hits);
        }

        var deduped = all
            .Where(x => !string.IsNullOrWhiteSpace(x.Source) && !string.IsNullOrWhiteSpace(x.Text))
            .GroupBy(x => $"{x.Source}::{x.Text}", StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();

        // ⛔ سؤال لائحي = نبحث فقط في ملفات اللوائح والأنظمة، ونستبعد ملفات صفحات الإجراءات.
        var regulationOnly = deduped
            .Where(x => IsRegulationSource(x.Source))
            .ToList();

        if (regulationOnly.Count == 0)
            return Array.Empty<KnowledgeChunk>();

        var topic = ResolveRegulationTopic(userQuestion);

        var ranked = regulationOnly
            .OrderByDescending(x =>
            {
                var score = 0;
                var src = (x.Source ?? "").Replace('\\', '/').ToLowerInvariant();
                var txt = x.Text ?? "";

                if (!src.Contains("pages/", StringComparison.OrdinalIgnoreCase))
                    score += 10;
                else
                    score -= 14;

                if (src.Contains("rules") || src.Contains("regulation") || src.Contains("entitlement") ||
                    src.Contains("eviction") || src.Contains("allocation") || src.Contains("maintenance"))
                    score += 10;

                if (ContainsAny(txt, "## شروط", "## تعريف", "ضوابط", "لائحة", "النظام", "أحقية", "استحقاق", "الإخلاء", "التخصيص"))
                    score += 8;

                if (!string.IsNullOrWhiteSpace(topic))
                {
                    var sourceTopicScore = ScoreRegulationSourceByTopic(src, topic);
                    score += sourceTopicScore;

                    if (ContainsAny(txt, topic))
                        score += 10;

                    if (sourceTopicScore == 0 && !ContainsAny(txt, topic))
                        score -= 10;
                }

                if (interpretation.Page is not null && ContainsAny(txt, interpretation.Page.ArabicPageName))
                    score += 3;

                return score;
            })
            .Take(Math.Max(topK, 6))
            .ToList();

        return ranked;
    }

    private List<KnowledgeChunk> BuildRegulationFallbackCitations(string topic, string userQuestion)
    {
        var candidates = GetPreferredRegulationSources(topic)
            .Concat(RegulationFileNames.Select(x => $"{x}.md"))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var list = new List<KnowledgeChunk>();

        foreach (var source in candidates)
        {
            var doc = _kb.GetDocumentBySource(source);
            if (string.IsNullOrWhiteSpace(doc))
                continue;

            var text = ExtractBestRegulationPassage(doc, userQuestion);
            if (string.IsNullOrWhiteSpace(text))
                text = doc;

            text = RemoveRegulationMetadata(RemoveKeywords(text)).Trim();
            if (string.IsNullOrWhiteSpace(text))
                continue;

            list.Add(new KnowledgeChunk(source, Clip(text, 900)));
        }

        return list;
    }

    private static IReadOnlyList<string> GetPreferredRegulationSources(string topic)
    {
        if (string.IsNullOrWhiteSpace(topic))
            return new[] { "housing_rules_general.md", "housing_definitions.md" };

        if (ContainsAny(topic, "اخلاء"))
            return new[] { "housing_eviction.md", "housing_rules_general.md" };

        if (ContainsAny(topic, "احقي", "استحقاق"))
            return new[] { "housing_entitlement.md", "housing_definitions.md" };

        if (ContainsAny(topic, "تلف", "جزئي", "كلي", "صيانه", "صيانة", "مسؤوليه", "مسؤولية"))
            return new[] { "housing_maintenance.md", "housing_definitions.md", "housing_rules_general.md" };

        if (ContainsAny(topic, "تخصيص"))
            return new[] { "housing_allocation.md", "housing_entitlement.md" };

        return new[] { "housing_rules_general.md", "housing_definitions.md" };
    }

    private static bool IsRegulationSource(string? source)
    {
        if (string.IsNullOrWhiteSpace(source))
            return false;

        var src = source.Replace('\\', '/').Trim().ToLowerInvariant();

        if (src.Contains("pages/", StringComparison.OrdinalIgnoreCase))
            return false;

        var file = src.Split('/').LastOrDefault() ?? src;
        if (file.EndsWith(".md"))
            file = file[..^3];

        // يعتمد فقط على قائمة ملفات اللوائح/الأنظمة المحددة من الفريق.
        return RegulationFileNames.Contains(file);
    }

    private static int ScoreRegulationSourceByTopic(string? source, string? topic)
    {
        if (string.IsNullOrWhiteSpace(source) || string.IsNullOrWhiteSpace(topic))
            return 0;

        var src = source.Replace('\\', '/').ToLowerInvariant();
        var normalizedTopic = ArabicTextNormalizer.Normalize(topic);
        var score = 0;

        if (ContainsAny(normalizedTopic, "احقي", "استحقاق"))
        {
            if (src.Contains("housing_entitlement"))
                score += 18;
            if (src.Contains("housing_definitions"))
                score += 6;
        }

        if (ContainsAny(normalizedTopic, "اخلاء"))
        {
            if (src.Contains("housing_eviction"))
                score += 18;
            if (src.Contains("housing_rules_general"))
                score += 5;
        }

        if (ContainsAny(normalizedTopic, "تلف", "جزئي", "كلي", "صيانه", "صيانة", "مسؤوليه", "مسؤولية"))
        {
            if (src.Contains("housing_maintenance"))
                score += 18;
            if (src.Contains("housing_definitions"))
                score += 8;
            if (src.Contains("housing_rules_general"))
                score += 6;
        }

        if (ContainsAny(normalizedTopic, "تخصيص"))
        {
            if (src.Contains("housing_allocation"))
                score += 18;
            if (src.Contains("housing_entitlement"))
                score += 6;
        }

        return score;
    }

    // =========================================================
    // LLM
    // =========================================================

    private async Task<LLamaContext> AcquireContextAsync(CancellationToken ct)
    {
        await _poolGate.WaitAsync(ct);
        if (_ctxPool.TryDequeue(out var ctx))
            return ctx;

        _poolGate.Release();
        throw new InvalidOperationException("Context pool empty unexpectedly.");
    }

    private void ReleaseContext(LLamaContext ctx)
    {
        _ctxPool.Enqueue(ctx);
        _poolGate.Release();
    }

    private async Task<string> AskLlmWithPromptAsync(string fullPrompt, CancellationToken ct)
    {
        var ctx = await AcquireContextAsync(ct);

        try
        {
            var executor = new InteractiveExecutor(ctx);

            var inferenceParams = new InferenceParams
            {
                MaxTokens = 200,
                AntiPrompts = new List<string>
                {
                    "[تعليمات النظام]",
                    "[رسالة المستخدم]"
                },
                SamplingPipeline = new LLama.Sampling.DefaultSamplingPipeline
                {
                    Temperature = 0.2f,
                    Seed = 1337
                }
            };

            var sb = new StringBuilder();

            await foreach (var piece in executor.InferAsync(fullPrompt, inferenceParams, ct))
            {
                sb.Append(piece);
                if (sb.Length > 3500)
                    break;
            }

            return CleanLlmArtifacts(sb.ToString());
        }
        finally
        {
            ReleaseContext(ctx);
        }
    }

    // =========================================================
    // Save + Utilities
    // =========================================================

    private async Task<AiChatResult> SaveAndReturn(
        AiChatRequest request,
        DateTimeOffset startTime,
        string answer,
        IReadOnlyList<KnowledgeChunk> citations,
        string? entityKey,
        string? intent)
    {
        var responseTime = (int)(DateTimeOffset.UtcNow - startTime).TotalMilliseconds;

        var saveTask = SaveChatHistoryAsync(
            request,
            answer,
            entityKey,
            intent,
            responseTime,
            citations?.Count ?? 0);
        var chatId = 0L;

        var completed = await Task.WhenAny(saveTask, Task.Delay(TimeSpan.FromMilliseconds(350)));
        if (completed == saveTask)
        {
            chatId = await saveTask;
        }
        else
        {
            _log.LogWarning("AI_SAVE_HISTORY_TIMEOUT");
        }

        return new AiChatResult(answer, citations)
        {
            ChatId = chatId,
            EntityKey = entityKey,
            Intent = intent
        };
    }

    private async Task<long> SaveChatHistoryAsync(
        AiChatRequest request,
        string answer,
        string? entityKey,
        string? intent,
        int responseTimeMs,
        int citationsCount)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var dataEngine = scope.ServiceProvider.GetService<ISmartComponentService>();
            if (dataEngine is null)
                return 0;

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

            var response = await dataEngine.ExecuteAsync(spRequest);

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

    private static string ResolvePageKey(AiChatRequest request)
    {
        var v =
            (GetPropString(request, "PageName") ??
             GetPropString(request, "Page") ??
             GetPropString(request, "Route") ??
             GetPropString(request, "Screen") ??
             "").Trim();

        return v;
    }

    private static string ResolveConversationKey(AiChatRequest request)
    {
        var conversationId = (request.ConversationId ?? GetPropString(request, "ConversationId") ?? "").Trim();
        if (!string.IsNullOrWhiteSpace(conversationId))
            return $"conv:{conversationId}";

        var clientId = (request.ClientId ?? GetPropString(request, "ClientId") ?? "").Trim();
        if (!string.IsNullOrWhiteSpace(clientId))
            return $"client:{clientId}";

        var userId = (request.UserId ??
                      GetPropString(request, "userId") ??
                      GetPropString(request, "UserId") ??
                      GetPropString(request, "usersId") ??
                      GetPropString(request, "UsersId") ??
                      "").Trim();

        var ip = (request.IpAddress ?? GetPropString(request, "IpAddress") ?? "").Trim();

        if (!string.IsNullOrWhiteSpace(userId) && !string.IsNullOrWhiteSpace(ip))
            return $"user:{userId}|ip:{ip}";

        if (!string.IsNullOrWhiteSpace(userId))
            return $"user:{userId}";

        if (!string.IsNullOrWhiteSpace(ip))
            return $"ip:{ip}";

        var pageUrl = (request.PageUrl ?? "").Trim();
        if (!string.IsNullOrWhiteSpace(pageUrl))
            return $"page:{pageUrl}";

        return "local-session";
    }

    private static string? GetPropString(object obj, string propName)
    {
        var p = obj.GetType().GetProperty(propName);
        if (p == null) return null;

        var val = p.GetValue(obj);
        return val?.ToString();
    }

    private static string CleanLlmArtifacts(string s)
    {
        if (string.IsNullOrWhiteSpace(s))
            return "";

        s = s.Replace("[System]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase)
             .Replace("<|im_start|>", "", StringComparison.OrdinalIgnoreCase)
             .Replace("<|im_end|>", "", StringComparison.OrdinalIgnoreCase);

        while (s.Contains("\n\n\n"))
            s = s.Replace("\n\n\n", "\n\n");

        return s.Trim();
    }

    private static string RemoveKeywords(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";

        var idx = text.IndexOf("## كلمات مفتاحية", StringComparison.OrdinalIgnoreCase);
        if (idx >= 0)
            text = text[..idx];

        text = text.Replace("Tags:", "", StringComparison.OrdinalIgnoreCase)
                   .Replace("[User]", "", StringComparison.OrdinalIgnoreCase)
                   .Replace("[Assistant]", "", StringComparison.OrdinalIgnoreCase)
                   .Replace("[System]", "", StringComparison.OrdinalIgnoreCase);

        return RemoveRegulationMetadata(text).Trim();
    }

    private static string RemoveRegulationMetadata(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return "";

        var lines = text.Replace("\r\n", "\n")
            .Split('\n', StringSplitOptions.None);

        var cleaned = lines
            .Where(line =>
            {
                var t = line.Trim();

                if (t.StartsWith("- category:", StringComparison.OrdinalIgnoreCase))
                    return false;

                if (t.StartsWith("category:", StringComparison.OrdinalIgnoreCase))
                    return false;

                if (t.StartsWith("- search_tags:", StringComparison.OrdinalIgnoreCase))
                    return false;

                if (t.StartsWith("search_tags:", StringComparison.OrdinalIgnoreCase))
                    return false;

                return true;
            });

        var result = string.Join("\n", cleaned).Trim();

        while (result.Contains("\n\n\n", StringComparison.Ordinal))
            result = result.Replace("\n\n\n", "\n\n", StringComparison.Ordinal);

        return result;
    }

    private static string Clip(string s, int max)
        => string.IsNullOrWhiteSpace(s) ? "" : (s.Length <= max ? s : s[..max] + " ...");

    private static bool ContainsAny(string s, params string[] parts)
    {
        if (string.IsNullOrWhiteSpace(s) || parts is null || parts.Length == 0)
            return false;

        foreach (var p in parts)
        {
            if (string.IsNullOrWhiteSpace(p))
                continue;

            if (ArabicTextNormalizer.Contains(s, p))
                return true;
        }

        return false;
    }

    private static void CleanupPending()
    {
        var now = DateTimeOffset.UtcNow;

        foreach (var kv in _pending)
        {
            if (now - kv.Value.At > PendingTtl)
                _pending.TryRemove(kv.Key, out _);
        }
    }


    private static string ResolveRegulationTopic(string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return "";

        var normalizedQuery = ArabicTextNormalizer.Normalize(query);

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
        "احقيه السكن",
        "التخصيص",
        "الاخلاء",
        "مسؤوليه المستفيد",
        "مسؤوليه الاداره",
        "المسؤوليات",
        "واجبات المستفيد"
    };

        foreach (var topic in knownTopics.OrderByDescending(x => x.Length))
        {
            if (normalizedQuery.Contains(topic, StringComparison.Ordinal))
                return topic;
        }

        return "";
    }

    private static string FormatRegulationTopicForDisplay(string topic)
    {
        var normalized = ArabicTextNormalizer.Normalize(topic);

        return normalized switch
        {
            "الاحقيه" => "الأحقية",
            "احقيه السكن" => "أحقية السكن",
            "الاخلاء" => "الإخلاء",
            "الصيانه" => "الصيانة",
            "الاصلاح" => "الإصلاح",
            "الانهاء" => "الإنهاء",
            _ => string.IsNullOrWhiteSpace(topic) ? "" : topic
        };
    }

    private static string ExtractSection(string text, string header)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(header))
            return "";

        var h = Regex.Escape(header.Trim());
        h = h.Replace("\\ ", "\\s+");

        var pattern = $"{h}\\s*\\r?\\n(?<body>[\\s\\S]*?)(?=\\r?\\n###?\\s|\\z)";
        var m = Regex.Match(text, pattern, RegexOptions.IgnoreCase);

        if (!m.Success)
            return "";

        return (header + "\n" + m.Groups["body"].Value).Trim();
    }

    private static string ExtractSectionByTopicHeader(string text, string topic)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(topic))
            return "";

        var lines = text.Replace("\r\n", "\n")
            .Split('\n', StringSplitOptions.RemoveEmptyEntries);

        var topicNormalized = ArabicTextNormalizer.Normalize(topic);

        foreach (var line in lines)
        {
            var trimmed = line.Trim();
            if (!trimmed.StartsWith("##", StringComparison.Ordinal))
                continue;

            if (!ArabicTextNormalizer.Contains(trimmed, topicNormalized))
                continue;

            var sec = ExtractSection(text, trimmed);
            if (!string.IsNullOrWhiteSpace(sec))
                return sec;
        }

        if (ContainsAny(topicNormalized, "اخلاء"))
        {
            foreach (var candidate in new[] { "## شروط الإخلاء", "## حالات الإخلاء", "## تعريف الإخلاء", "## إجراءات الإخلاء" })
            {
                var sec = ExtractSection(text, candidate);
                if (!string.IsNullOrWhiteSpace(sec))
                    return sec;
            }
        }

        if (ContainsAny(topicNormalized, "احقي", "استحقاق"))
        {
            foreach (var candidate in new[] { "## تعريف الأحقية", "## شروط الأحقية", "## الفئات المستحقة" })
            {
                var sec = ExtractSection(text, candidate);
                if (!string.IsNullOrWhiteSpace(sec))
                    return sec;
            }
        }

        return "";
    }

    private static string TrimToSingleSection(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return "";

        var sep = text.IndexOf("\n---", StringComparison.Ordinal);
        if (sep > 0)
            text = text[..sep];

        var first = text.IndexOf("\n## ", StringComparison.Ordinal);
        if (first >= 0)
        {
            var second = text.IndexOf("\n## ", first + 4, StringComparison.Ordinal);
            if (second > 0)
                text = text[..second];
        }

        return text.Trim();
    }

    private static string ExtractBestRegulationPassage(string text, string query, int maxLength = 1200)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(query))
            return "";

        var paragraphs = text.Replace("\r\n", "\n")
            .Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (paragraphs.Length == 0)
            return "";

        var scored = paragraphs
            .Select(p => new
            {
                Text = p.Trim(),
                Score = ScoreParagraph(p, query)
            })
            .Where(x => x.Score > 0 && !IsUiOrFormNoise(x.Text))
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

    private static int ScoreParagraph(string paragraph, string query)
    {
        if (string.IsNullOrWhiteSpace(paragraph) || string.IsNullOrWhiteSpace(query))
            return 0;

        int score = 0;

        var normalizedParagraph = ArabicTextNormalizer.Normalize(paragraph);
        var normalizedQuery = ArabicTextNormalizer.Normalize(query);

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

        if (ContainsAny(normalizedQuery, "ما هو", "ما هي", "وش", "يعني", "تعريف", "عرف") &&
            ContainsAny(normalizedParagraph, "تعريف", "يقصد به", "هي"))
        {
            score += 3;
        }

        return score;
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
            (text.Contains("حفظ", StringComparison.OrdinalIgnoreCase) && text.Contains("نافذة", StringComparison.OrdinalIgnoreCase)) ||
            text.Contains("لا يعمل زر تعديل", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("تظهر رسالة حقول إلزامية", StringComparison.OrdinalIgnoreCase);
    }

    private static string BuildProceduralFallbackAnswer(AssistantInterpretationResult interpretation)
{
    if (interpretation.Page is null)
        return "";

    var pageName = interpretation.Page.ArabicPageName;
    var pageDescription = interpretation.Page.ArabicDescription;
    var actionName = interpretation.Action?.ArabicLabel ?? "";

    if (string.IsNullOrWhiteSpace(actionName))
    {
        return $"صفحة {pageName}: {pageDescription}";
    }

    return interpretation.Page.InternalPageName switch
    {
        "AllMeterRead" when interpretation.Action?.ActionType == ActionType.View
            => "لعرض جميع قراءات العدادات:\n1) ادخل إلى صفحة جميع قراءات العدادات.\n2) حدّد الفترة أو معايير البحث.\n3) نفّذ البحث.\n4) راجع النتائج الظاهرة في الجدول.",

        "AllMeterRead" when interpretation.Action?.ActionType == ActionType.OpenPeriod
            => "لفتح فترة قراءة عدادات:\n1) ادخل إلى صفحة جميع قراءات العدادات.\n2) اختر فتح فترة.\n3) أدخل بيانات الفترة المطلوبة.\n4) احفظ العملية ثم أكمل إدخال القراءات داخل الفترة.",

        "AllMeterRead" when interpretation.Action?.ActionType == ActionType.ClosePeriod
            => "لإغلاق فترة قراءة عدادات:\n1) ادخل إلى صفحة جميع قراءات العدادات.\n2) اختر الفترة المفتوحة.\n3) نفّذ أمر إغلاق الفترة بعد التأكد من اكتمال القراءات.",

        "AllMeterRead" when interpretation.Action?.ActionType == ActionType.Approve
            => "لاعتماد قراءة عداد:\n1) افتح صفحة جميع قراءات العدادات.\n2) ابحث عن سجل القراءة المطلوب.\n3) حدّد السجل.\n4) نفّذ اعتماد قراءة العداد.",

        "Meters" when interpretation.Action?.ActionType == ActionType.Add
            => "لإضافة عداد جديد:\n1) افتح صفحة العدادات.\n2) اختر إضافة عداد.\n3) أدخل بيانات العداد المطلوبة.\n4) احفظ البيانات.\n5) عند الحاجة اربط العداد بالمبنى المناسب.",

        "Meters" when interpretation.Action?.ActionType == ActionType.Update
            => "لتعديل بيانات عداد أو نوع عداد:\n1) افتح صفحة العدادات.\n2) ابحث عن السجل المطلوب.\n3) اختر التعديل.\n4) حدّث البيانات المطلوبة ثم احفظ.",

        "Residents" when interpretation.Action?.ActionType == ActionType.Add
            => "لإضافة مستفيد:\n1) افتح صفحة المستفيدين.\n2) اختر إضافة مستفيد.\n3) أدخل البيانات الأساسية المطلوبة.\n4) راجع الحقول الإلزامية.\n5) احفظ السجل.",

        "Residents" when interpretation.Action?.ActionType == ActionType.Update
            => "لتعديل بيانات مستفيد:\n1) افتح صفحة المستفيدين.\n2) ابحث عن المستفيد المطلوب.\n3) افتح سجل المستفيد.\n4) عدّل البيانات اللازمة.\n5) احفظ التعديلات.",

        "BuildingDetails" when interpretation.Action?.ActionType == ActionType.Add
            => "لإضافة مبنى:\n1) افتح صفحة المباني.\n2) اختر إضافة مبنى.\n3) أدخل بيانات المبنى والوحدة حسب الحقول المطلوبة.\n4) احفظ السجل.",

        "BuildingDetails" when interpretation.Action?.ActionType == ActionType.Update
            => "لتعديل بيانات مبنى:\n1) افتح صفحة المباني.\n2) ابحث عن المبنى المطلوب.\n3) اختر التعديل.\n4) حدّث البيانات ثم احفظ.",

        "BuildingClass" when interpretation.Action?.ActionType == ActionType.Add
            => "لإضافة فئة مبنى:\n1) افتح صفحة فئات المباني.\n2) اختر إضافة فئة مبنى.\n3) أدخل البيانات المطلوبة.\n4) احفظ السجل.",

        "BuildingClass" when interpretation.Action?.ActionType == ActionType.Update
            => "لتعديل فئة مبنى:\n1) افتح صفحة فئات المباني.\n2) ابحث عن الفئة المطلوبة.\n3) حدّد السجل.\n4) عدّل البيانات ثم احفظ.",

        "BuildingType" when interpretation.Action?.ActionType == ActionType.Add
            => "لإضافة نوع مبنى:\n1) افتح صفحة أنواع المباني.\n2) اختر إضافة نوع مبنى.\n3) أدخل البيانات المطلوبة.\n4) احفظ السجل.",

        "BuildingType" when interpretation.Action?.ActionType == ActionType.Update
            => "لتعديل نوع مبنى:\n1) افتح صفحة أنواع المباني.\n2) ابحث عن النوع المطلوب.\n3) حدّد السجل.\n4) عدّل البيانات ثم احفظ.",

        "HousingExit" when interpretation.Action?.ActionType == ActionType.Add
            => "لتسجيل إخلاء:\n1) افتح صفحة الإخلاء.\n2) اختر تسجيل إخلاء جديد.\n3) أدخل بيانات المستفيد والوحدة وتفاصيل الإخلاء.\n4) احفظ الطلب.\n5) أكمل الاعتماد أو الإرسال للمالية حسب الصلاحية.",

        _ => $"لفهم إجراء {actionName} في صفحة {pageName}:\n1) افتح الصفحة المطلوبة.\n2) اختر الإجراء المناسب من الخيارات المتاحة.\n3) أدخل البيانات المطلوبة.\n4) راجع الحقول الإلزامية.\n5) احفظ أو اعتمد حسب نوع العملية."
    };
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
}
