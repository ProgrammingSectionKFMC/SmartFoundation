using LLama;
using LLama.Common;
using Microsoft.Extensions.Options;
using System.Collections.Concurrent;
using System.Text;

namespace SmartFoundation.Mvc.Services.AiAssistant;

internal sealed class EmbeddedLlamaChatService : IAiChatService, IDisposable
{
    private readonly IAiKnowledgeBase _kb;
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<EmbeddedLlamaChatService> _log;

    private readonly SemaphoreSlim _gate;
    private readonly LLamaWeights _weights;
    private readonly LLamaContext _context;
    private readonly string _modelPath;

    // ========= General Chat =========
    private const string GeneralChatSourceHint = "General_Chat"; // عدّلها لو اسم الملف/السورس مختلف
    private const int GeneralChatMaxAnswerLen = 600;

    // =========================
    // Entities (screens)
    // =========================
    private static readonly (string Key, string Label, string[] Keywords)[] Entities =
    {
        ("Residents",       "مستفيد", new[] { "مستفيد", "المستفيد", "المستفيدين", "ساكن", "Residents" }),
        ("BuildingDetails", "مبنى",   new[] { "مبنى", "المباني", "Building", "BuildingDetails" }),
    };

    // =========================
    // Pending intent between turns (disambiguation follow-up)
    // =========================
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
        IWebHostEnvironment env,
        ILogger<EmbeddedLlamaChatService> log)
    {
        _kb = kb;
        _opt = opt.Value;
        _log = log;

        _gate = new SemaphoreSlim(Math.Max(1, _opt.MaxParallelRequests));

        _modelPath = _opt.ModelPath ?? "AiModels\\model.gguf";
        if (!Path.IsPathRooted(_modelPath))
            _modelPath = Path.Combine(env.ContentRootPath, _modelPath);

        if (!File.Exists(_modelPath))
            throw new FileNotFoundException($"AI model not found: {_modelPath}");

        var p = new ModelParams(_modelPath)
        {
            ContextSize = (uint)Math.Clamp(_opt.ContextSize, 512, 8192),
            Threads = Math.Max(1, _opt.Threads),
        };

        _weights = LLamaWeights.LoadFromFile(p);
        _context = _weights.CreateContext(p);

        _log.LogInformation(
            "Embedded LLM loaded: {Path} | ctx={Ctx} | threads={Threads}",
            _modelPath, _opt.ContextSize, _opt.Threads);
    }

    public async Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct)
    {
        CleanupPending();

        var originalMsg = (request.Message ?? "").Trim();
        if (string.IsNullOrWhiteSpace(originalMsg))
            return new AiChatResult("🙂", Array.Empty<KnowledgeChunk>());

        var msg = originalMsg;
        var pageKey = ResolvePageKey(request);
        var convoKey = ResolveConversationKey(request);

        _log.LogInformation(
            "AI_CHAT: convoKey='{ConvoKey}', userIdField='{UserId}', ConversationId='{ConversationId}', ClientId='{ClientId}', pageKey='{PageKey}', msg='{Msg}'",
            convoKey ?? "",
            GetPropString(request, "userId") ?? "",
            GetPropString(request, "ConversationId") ?? "",
            GetPropString(request, "ClientId") ?? "",
            pageKey ?? "",
            originalMsg.Replace("\n", " ").Trim()
        );

        // 1) Intent from message
        var intent = NormalizeIntent(originalMsg);

        // 2) Detect entity from current message
        var entityHits = DetectEntities(originalMsg);

        // 3) Follow-up: if user answered only entity after disambiguation question
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
                convoKey ?? "",
                pendingState.Intent ?? "",
                pendingState.OriginalMessage ?? ""
            );

            intent = pendingState.Intent;
            selectedEntityKey = entityHits[0].Key;

            // use the original pending question as msg for retrieval
            if (!string.IsNullOrWhiteSpace(pendingState.OriginalMessage))
                msg = pendingState.OriginalMessage;
        }

        // 4) If entity-only and no pending intent -> ask action
        if (string.IsNullOrWhiteSpace(intent) &&
            selectedEntityKey is null &&
            entityHits.Count == 1 &&
            IsShortEntityAnswer(originalMsg))
        {
            var label = entityHits[0].Label;
            return new AiChatResult(
                $"ماذا تريد أن تعمل في {label}؟ إضافة؟ تعديل؟ حذف؟ بحث؟ طباعة؟",
                Array.Empty<KnowledgeChunk>()
            );
        }

        // =========================
        // GENERAL CHAT (NO INTENT) – answer from General_Chat ONLY
        // =========================
        if (string.IsNullOrWhiteSpace(intent))
        {
            if (TryAnswerFromGeneralChat(originalMsg, out var generalAnswer, out var usedGeneral))
            {
                if (!string.IsNullOrWhiteSpace(convoKey))
                    _pending.TryRemove(convoKey, out _);

                return new AiChatResult(generalAnswer, usedGeneral);
            }
        }

        // =========================
        // PROCEDURAL PATH
        // =========================
        var isProcedural = !string.IsNullOrWhiteSpace(intent);

        // retrieval
        var topK = isProcedural ? Math.Max(8, _opt.RetrievalTopK) : Math.Max(8, _opt.RetrievalTopK);

        var searchQuery = msg;
        if (!string.IsNullOrWhiteSpace(selectedEntityKey))
            searchQuery = $"{msg} {GetEntityLabel(selectedEntityKey)}";

        _log.LogInformation(
            "AI_CHAT: intent='{Intent}', selectedEntity='{Entity}', msg='{Msg}', searchQuery='{Q}', topK={TopK}",
            intent ?? "",
            selectedEntityKey ?? "",
            msg ?? "",
            searchQuery ?? "",
            topK
        );

        var citations = _kb.Search(searchQuery, topK);

        // prevent General_Chat from interfering with procedural answers
        if (citations.Count > 0)
        {
            citations = citations
                .Where(c => c.Source?.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase) != true)
                .ToList();
        }

        if (isProcedural)
        {
            // Resolve entity from ORIGINAL message
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
                    _log.LogInformation(
                        "AI_CHAT: PENDING_SET key='{ConvoKey}' intent='{Intent}' original='{Original}'",
                        convoKey ?? "",
                        intent ?? "",
                        originalMsg ?? ""
                    );

                    _pending[convoKey] = new PendingState
                    {
                        Intent = intent,
                        OriginalMessage = originalMsg,
                        At = DateTimeOffset.UtcNow
                    };
                }

                return new AiChatResult(
                    BuildDisambiguationQuestion(intent, Entities.Select(e => e.Label).ToArray()),
                    citations
                );
            }

            if (detected.Count > 1)
            {
                if (!string.IsNullOrWhiteSpace(convoKey))
                {
                    _pending[convoKey] = new PendingState
                    {
                        Intent = intent,
                        OriginalMessage = originalMsg,
                        At = DateTimeOffset.UtcNow
                    };
                }

                var opts = detected.Select(x => x.Label).Distinct().ToArray();
                return new AiChatResult(
                    BuildDisambiguationQuestion(intent, opts),
                    citations
                );
            }

            var entityKey = detected[0].Key;

            // Prefer citations from same entity/source
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
                return new AiChatResult(
                    "لا يوجد شرح لهذه العملية في الدليل الحالي.",
                    citations
                );
            }

            var header = ResolveHeader(entityKey, intent);
            if (string.IsNullOrWhiteSpace(header))
            {
                return new AiChatResult(
                    "لا يوجد شرح لهذه العملية في الدليل الحالي.",
                    citations
                );
            }

            string? best = null;
            var tryCount = Math.Min(6, citations.Count);

            for (int i = 0; i < tryCount; i++)
            {
                var c = citations[i];
                var text = c.Text ?? "";

                if (!ContainsAny(text, "## إضافة", "## تعديل", "## حذف", "## طباعة", "## تصدير", "## البحث"))
                {
                    var fullDoc = _kb.GetDocumentBySource(c.Source);
                    if (!string.IsNullOrWhiteSpace(fullDoc))
                        text = fullDoc;
                }

                var extracted = ExtractSection(text, header);
                if (!string.IsNullOrWhiteSpace(extracted) &&
                    !extracted.Equals(header, StringComparison.OrdinalIgnoreCase))
                {
                    best = extracted;
                    break;
                }
            }

            var answerText = best ?? "لا يوجد قسم مطابق لهذا السؤال في الدليل الحالي.";
            answerText = RemoveKeywords(answerText);
            answerText = TrimToSingleSection(answerText);
            answerText = Clip(answerText, 900).Trim();

            if (string.IsNullOrWhiteSpace(answerText))
                answerText = "لا يوجد قسم مطابق لهذا السؤال في الدليل الحالي.";

            if (!string.IsNullOrWhiteSpace(convoKey))
                _pending.TryRemove(convoKey, out _);

            return new AiChatResult(answerText, citations);
        }

        // =========================
        // Non-procedural fallback
        // =========================
        if (citations.Count == 0)
        {
            return new AiChatResult(
                "اسف مافهمتك باقي اتدرب , ممكن تسألني كيف ابحث؟ كيف اطبع تقرير ؟ كيف اعدل ؟",
                citations
            );
        }

        var system = BuildSystemPrompt(request, citations);

        await _gate.WaitAsync(ct);
        try
        {
            using var ctx = _weights.CreateContext(new ModelParams(_modelPath)
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
            await foreach (var piece in executor.InferAsync(prompt, inferenceParams, ct))
            {
                sb.Append(piece);
                if (sb.Length > 2000) break;
            }

            var answer = sb.ToString().Trim();
            answer = CleanLlmArtifacts(answer);

            if (string.IsNullOrWhiteSpace(answer))
                answer = "لم أستطع توليد رد.";

            return new AiChatResult(answer, citations);
        }
        finally
        {
            _gate.Release();
        }
    }

    // =========================================================
    // GENERAL CHAT: forced retrieval of General_Chat + parse blocks
    // =========================================================
    private bool TryAnswerFromGeneralChat(
        string userMsg,
        out string answer,
        out IReadOnlyList<KnowledgeChunk> usedCitations)
    {
        answer = "";
        usedCitations = Array.Empty<KnowledgeChunk>();

        userMsg ??= "";
        var q = NormalizeForMatch(userMsg);

        // 1) Force the KB to surface General_Chat sources
        var forced = _kb.Search($"{GeneralChatSourceHint} {userMsg}", Math.Max(10, _opt.RetrievalTopK));

        var hits = forced
            .Where(c => !string.IsNullOrWhiteSpace(c.Source) &&
                        c.Source.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (hits.Count == 0)
        {
            // 2) fallback: search only by General_Chat hint
            var forced2 = _kb.Search(GeneralChatSourceHint, Math.Max(10, _opt.RetrievalTopK));
            hits = forced2
                .Where(c => !string.IsNullOrWhiteSpace(c.Source) &&
                            c.Source.Contains(GeneralChatSourceHint, StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (hits.Count == 0)
                return false;
        }

        // Prefer getting the full document
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

            i++; // after [KEYWORDS]
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

                // ignore headings if user put them in the doc by mistake
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

    // =========================
    // Disambiguation Helpers
    // =========================
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

    // =========================
    // Page + Conversation Key
    // =========================
    private static string ResolvePageKey(AiChatRequest request)
    {
        var v =
            (GetPropString(request, "PageName") ??
             GetPropString(request, "Page") ??
             GetPropString(request, "Route") ??
             GetPropString(request, "Screen") ??
             "").Trim();

        if (v.Equals("Residents", StringComparison.OrdinalIgnoreCase)) return "Residents";
        if (v.Equals("BuildingDetails", StringComparison.OrdinalIgnoreCase)) return "BuildingDetails";

        if (v.Contains("BuildingDetails", StringComparison.OrdinalIgnoreCase)) return "BuildingDetails";
        if (v.Contains("Residents", StringComparison.OrdinalIgnoreCase)) return "Residents";

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

    // =========================
    // Header Resolver (Entity + Intent)
    // =========================
    private static string ResolveHeader(string entityKey, string intent)
    {
        if (entityKey.Equals("Residents", StringComparison.OrdinalIgnoreCase))
        {
            return intent switch
            {
                "ADD" => "## إضافة مستفيد",
                "UPDATE" => "## تعديل مستفيد",
                "DELETE" => "## حذف مستفيد",
                "SEARCH" => "## البحث عن مستفيد",
                "PRINT" => "## طباعة تقرير المستفيدين",
                "EXPORT" => "## تصدير البيانات",
                _ => ""
            };
        }

        if (entityKey.Equals("BuildingDetails", StringComparison.OrdinalIgnoreCase))
        {
            return intent switch
            {
                "ADD" => "## إضافة مبنى",
                "UPDATE" => "## تعديل مبنى",
                "DELETE" => "## حذف مبنى",
                "SEARCH" => "## البحث عن مبنى",
                "PRINT" => "## طباعة تقرير المباني",
                "EXPORT" => "## تصدير المباني",
                _ => ""
            };
        }

        return "";
    }

    // =========================
    // Helpers
    // =========================
    private static string ExtractSection(string text, string header)
    {
        if (string.IsNullOrWhiteSpace(text) || string.IsNullOrWhiteSpace(header))
            return "";

        var h = System.Text.RegularExpressions.Regex.Escape(header.Trim());
        h = h.Replace("\\ ", "\\s+");

        var pattern = $"{h}\\s*\\r?\\n(?<body>[\\s\\S]*?)(?=\\r?\\n##\\s|\\z)";
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

    // =========================
    // Intent (Saudi dialect)
    // =========================
    private static string NormalizeIntent(string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return "";
        query = query.Trim().ToLowerInvariant();

        query = query.Replace("؟", "").Replace("?", "").Trim();

        if (ContainsAny(query,
            "تعديل", "عدّل", "عدل", "تحديث", "حدث", "تغيير", "غير",
            "ابي اعدل", "أبي أعدل", "ابغى اعدل", "أبغى أعدل",
            "ابي اغير", "ابغى اغير", "أبي أغير", "أبغى أغير",
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

    public void Dispose()
    {
        try { _context.Dispose(); } catch { }
        try { _weights.Dispose(); } catch { }
        try { _gate.Dispose(); } catch { }
    }
}
