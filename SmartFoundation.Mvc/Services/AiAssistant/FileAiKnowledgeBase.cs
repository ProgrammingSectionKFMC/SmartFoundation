using Microsoft.AspNetCore.Mvc;
using System.Text;
using Microsoft.Extensions.Options;

namespace SmartFoundation.Mvc.Services.AiAssistant;


public sealed class FileAiKnowledgeBase : IAiKnowledgeBase
{
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<FileAiKnowledgeBase> _log;

    private readonly List<(string source, string text, Dictionary<string, int> tf)> _chunks = new();

    private readonly Dictionary<string, string> _docs =
    new(StringComparer.OrdinalIgnoreCase);


    private static readonly HashSet<string> Stop = new(StringComparer.OrdinalIgnoreCase)
    {
        "the","a","an","and","or","to","of","in","on","for","with","is","are","was","were",
        "من","في","على","الى","إلى","عن","هو","هي","هم","هن","هذا","هذه","ذلك","تلك","و","او","أو","ثم","لكن","مع","ب","ل"
    };

    public FileAiKnowledgeBase(IOptions<AiAssistantOptions> opt, ILogger<FileAiKnowledgeBase> log, IWebHostEnvironment env)
    {
        _opt = opt.Value;
        _log = log;

        var kbPath = _opt.KnowledgeBasePath ?? "AiDocs/UserHelp";
        if (!Path.IsPathRooted(kbPath))
            kbPath = Path.Combine(env.ContentRootPath, kbPath);

        Load(kbPath);
    }

    public IReadOnlyList<KnowledgeChunk> Search(string query, int topK)
    {
        if (string.IsNullOrWhiteSpace(query) || _chunks.Count == 0)
            return Array.Empty<KnowledgeChunk>();

        topK = Math.Clamp(topK, 1, 10);

        var qTokens = Tokenize(query).ToArray();
        if (qTokens.Length == 0) return Array.Empty<KnowledgeChunk>();

        var scored = _chunks
            .Select(c =>
            {
                double s = 0;
                foreach (var t in qTokens)
                {
                    if (c.tf.TryGetValue(t, out var n)) s += n;
                }
                s = s / Math.Sqrt(20 + c.text.Length);
                return (c.source, c.text, score: s);
            })
            .Where(x => x.score > 0)
            .OrderByDescending(x => x.score)
            .Take(topK)
            .Select(x =>
            {
                var section = ExtractRelevantSection(x.text, query);

                // ✅ لو طلع عنوان فقط أو قصير، اسحب من الملف كاملًا
                if (section.Trim().StartsWith("##", StringComparison.OrdinalIgnoreCase) && section.Length < 80)
                {
                    if (_docs.TryGetValue(x.source, out var fullDoc) && !string.IsNullOrWhiteSpace(fullDoc))
                        section = ExtractRelevantSection(fullDoc, query);
                }

                section = RemoveTagsBlock(section);
                section = Clip(section, 650);
                return new KnowledgeChunk(x.source, section);
            })
            .ToList();

        return scored;
    }

    private static string ExtractRelevantSection(string text, string query)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";

        // اختر عنوان القسم حسب السؤال
        var q = query.Trim();

        string[] headers;
        if (ContainsAny(q, "اضف", "أضف", "إضافة", "اضافة", "أضيف", "اضيف"))
            headers = new[] { 
                "### إضافة سجل انتظار جديد",  // ✅ WaitingListByResident
                "### إضافة خطاب تسكين جديد",   // ✅ WaitingListByResident
                "## إضافة مستفيد", 
                "## إضافة مبنى", 
                "## إضافة فئة جديدة",
                "## إضافة سجل", 
                "## إضافة" 
            };
        else if (ContainsAny(q, "عدل", "تعديل", "تحديث", "عدّل", "تعديل بيانات"))
            headers = new[] { 
                "### تعديل سجل انتظار",         // ✅ WaitingListByResident
                "### تعديل خطاب تسكين",          // ✅ WaitingListByResident
                "## تعديل مستفيد", 
                "## تعديل مبنى", 
                "## تعديل فئة موجودة",
                "## تعديل سجل", 
                "## تعديل" 
            };
        else if (ContainsAny(q, "حذف", "امسح", "مسح", "إزالة", "ازالة", "إلغاء", "الغاء"))
            headers = new[] { 
                "### حذف سجل انتظار",            // ✅ WaitingListByResident
                "### حذف خطاب تسكين",             // ✅ WaitingListByResident
                "### إلغاء طلب نقل",              // ✅ WaitingListByResident
                "## حذف مستفيد", 
                "## حذف مبنى", 
                "## حذف فئة",
                "## حذف سجل", 
                "## حذف" 
            };
        else if (ContainsAny(q, "نقل", "انقل", "طلب نقل", "نقل سجل", "نقل قائمة"))
            headers = new[] { 
                "### نقل سجل انتظار لإدارة أخرى", // ✅ WaitingListByResident
                "## طلبات نقل سجلات الانتظار",   // ✅ WaitingListByResident
                "## نقل"
            };
        else if (ContainsAny(q, "بحث", "ابحث", "البحث", "فلتر", "تصفية", "هوية", "رقم الهوية"))
            headers = new[] { 
                "## البحث عن مستفيد",            // ✅ WaitingListByResident
                "### خطوات البحث",                // ✅ WaitingListByResident
                "## البحث عن مبنى", 
                "## البحث والتصفية",
                "## البحث", 
                "## Search" 
            };
        else if (ContainsAny(q, "طباعة", "اطبع", "طبع", "تقرير", "PDF", "تصدير", "صدّر", "excel"))
            headers = new[] { 
                "### تصدير قوائم الانتظار",       // ✅ WaitingListByResident
                "## التصدير",                     // ✅ WaitingListByResident
                "## طباعة تقرير المستفيدين", 
                "## طباعة تقرير المباني", 
                "## الطباعة", 
                "## طباعة",
                "## تصدير البيانات"
            };
        else if (ContainsAny(q, "خطاب تسكين", "خطابات", "خطاب", "تسكين"))
            headers = new[] { 
                "## إدارة خطابات التسكين",         // ✅ WaitingListByResident
                "### عرض خطابات التسكين",          // ✅ WaitingListByResident
                "### إضافة خطاب تسكين جديد",       // ✅ WaitingListByResident
                "### تعديل خطاب تسكين",            // ✅ WaitingListByResident
                "### حذف خطاب تسكين"               // ✅ WaitingListByResident
            };
        else if (ContainsAny(q, "قائمة انتظار", "قوائم انتظار", "سجل انتظار", "سجلات"))
            headers = new[] { 
                "## إدارة قوائم الانتظار",         // ✅ WaitingListByResident
                "### عرض قوائم الانتظار",          // ✅ WaitingListByResident
                "### إضافة سجل انتظار جديد",       // ✅ WaitingListByResident
                "## إدارة"
            };
        else
            headers = Array.Empty<string>();

        // إذا ما قدرنا نحدد قسم، رجع أول جزء مفيد
        if (headers.Length == 0)
            return text;

        foreach (var h in headers)
        {
            var sec = SliceMarkdownSection(text, h);
            if (!string.IsNullOrWhiteSpace(sec))
                return sec;
        }

        return text;
    }

    // يأخذ القسم من عنوان header إلى العنوان التالي "## " أو "### "
    private static string SliceMarkdownSection(string text, string header)
    {
        var start = text.IndexOf(header, StringComparison.OrdinalIgnoreCase);
        if (start < 0) return "";

        // نهاية القسم: أول "## " أو "### " بعد البداية (غير نفس العنوان)
        var headerLevel = header.StartsWith("###") ? "\n### " : "\n## ";
        var next = text.IndexOf(headerLevel, start + header.Length, StringComparison.OrdinalIgnoreCase);
        if (next < 0) next = text.Length;

        return text.Substring(start, next - start).Trim();
    }

    private static bool ContainsAny(string s, params string[] parts)
    {
        foreach (var p in parts)
            if (s.Contains(p, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    private static string RemoveTagsBlock(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";

        // احذف سطر "## كلمات مفتاحية" وما بعده إذا موجود داخل المقطع
        var idx = text.IndexOf("## كلمات مفتاحية", StringComparison.OrdinalIgnoreCase);
        if (idx >= 0)
            return text.Substring(0, idx).Trim();

        // احذف سطر "Tags:" إذا جاء بالبداية
        text = text.Replace("Tags:", ""); // تنظيف بسيط
        return text.Trim();
    }

    private static string Clip(string s, int max)
    {
        if (string.IsNullOrWhiteSpace(s)) return "";
        s = s.Trim();
        return s.Length <= max ? s : s.Substring(0, max) + " ...";
    }


    private void Load(string kbPath)
    {
        try
        {
            if (!Directory.Exists(kbPath))
            {
                _log.LogWarning("AI knowledge base path not found: {Path}", kbPath);
                return;
            }

            var files = Directory.EnumerateFiles(kbPath, "*.*", SearchOption.AllDirectories)
                .Where(f => f.EndsWith(".md", StringComparison.OrdinalIgnoreCase)
                         || f.EndsWith(".txt", StringComparison.OrdinalIgnoreCase))
                .ToList();

            foreach (var f in files)
            {
                var fileName = Path.GetFileName(f);
                var text = File.ReadAllText(f, Encoding.UTF8);

                // ✅ خزّن النص الكامل للملف
                _docs[fileName] = text;

                foreach (var chunk in Chunk(text))
                {
                    var tf = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
                    foreach (var tok in Tokenize(chunk))
                    {
                        tf[tok] = tf.TryGetValue(tok, out var n) ? n + 1 : 1;
                    }
                    if (tf.Count == 0) continue;
                    _chunks.Add((fileName, chunk, tf));
                }
            }


            _log.LogInformation("AI knowledge base loaded: {Files} files, {Chunks} chunks", files.Count, _chunks.Count);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to load AI knowledge base.");
        }
    }

    private static IEnumerable<string> Chunk(string text)
    {
        var paras = text.Replace("\r\n", "\n")
            .Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        var sb = new StringBuilder();
        foreach (var p in paras)
        {
            if (sb.Length + p.Length + 2 > 1100 && sb.Length > 200)
            {
                yield return sb.ToString();
                sb.Clear();
            }
            sb.AppendLine(p);
            sb.AppendLine();
        }
        if (sb.Length > 50) yield return sb.ToString();
    }

    private static IEnumerable<string> Tokenize(string input)
    {
        var sb = new StringBuilder(input.Length);
        foreach (var ch in input)
        {
            if (char.IsLetterOrDigit(ch) || ch == '_' || ch == '-')
                sb.Append(char.ToLowerInvariant(ch));
            else
                sb.Append(' ');
        }

        foreach (var w in sb.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (w.Length < 2) continue;
            if (Stop.Contains(w)) continue;
            yield return w;
        }
    }

    public string? GetDocumentBySource(string source)
    {
        if (string.IsNullOrWhiteSpace(source))
            return null;

        return _docs.TryGetValue(source, out var full) ? full : null;
    }





}

