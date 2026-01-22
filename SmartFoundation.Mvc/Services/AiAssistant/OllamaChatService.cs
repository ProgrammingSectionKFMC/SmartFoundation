using Microsoft.AspNetCore.Mvc;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace SmartFoundation.Mvc.Services.AiAssistant;

internal sealed class OllamaChatService : IAiChatService
{
    private readonly HttpClient _http;
    private readonly IAiKnowledgeBase _kb;
    private readonly AiAssistantOptions _opt;
    private readonly ILogger<OllamaChatService> _log;

    public OllamaChatService(HttpClient http, IAiKnowledgeBase kb, IOptions<AiAssistantOptions> opt, ILogger<OllamaChatService> log)
    {
        _http = http;
        _kb = kb;
        _opt = opt.Value;
        _log = log;
    }

    public async Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct)
    {
        var citations = _kb.Search(request.Message, _opt.RetrievalTopK);

        var system = BuildSystemPrompt(request, citations);

        var payload = new
        {
            model = _opt.Model,
            stream = false,
            options = new
            {
                temperature = _opt.Temperature,
                num_predict = _opt.MaxTokens
            },
            messages = new object[]
            {
                new { role = "system", content = system },
                new { role = "user", content = request.Message }
            }
        };

        try
        {
            using var resp = await _http.PostAsJsonAsync("/api/chat", payload, ct);
            resp.EnsureSuccessStatusCode();

            using var doc = await JsonDocument.ParseAsync(await resp.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
            var content = doc.RootElement.GetProperty("message").GetProperty("content").GetString() ?? "";
            return new AiChatResult(content.Trim(), citations);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "AI chat failed.");
            return new AiChatResult("حصل خطأ أثناء تشغيل المساعد. تأكد أن خدمة النموذج المحلي تعمل (مثلاً Ollama) ثم جرّب مرة أخرى.", citations);
        }
    }

    private static string BuildSystemPrompt(AiChatRequest r, IReadOnlyList<KnowledgeChunk> citations)
    {
        var kb = citations.Count == 0
            ? "لا توجد مقاطع مساعدة مطابقة."
            : string.Join("\n\n---\n\n", citations.Select((c, i) => $"[مقطع {i + 1} - {c.Source}]\n{c.Text}"));

        return $"""
أنت مساعد داخل نظام SmartFoundation (ASP.NET MVC Core 8).
مهمتك: شرح طريقة استخدام النظام للمستخدمين خطوة بخطوة باللغة العربية (وبالإنجليزية فقط إذا طلب المستخدم).
التزم بهذه القواعد:
- اعتمد على مقاطع المساعدة الموجودة أدناه قدر الإمكان.
- إذا كانت الإجابة غير موجودة في المقاطع، قل للمستخدم أنك تحتاج لمعلومة إضافية أو أن الدليل لا يغطي ذلك، واقترح أين يمكن إيجادها داخل النظام.
- لا تخمّن بيانات أو أرقام. لا تطلب اتصال بالإنترنت.
- اجعل الرد عمليًا: خطوات مرقمة + أسماء الأزرار/الحقول كما تظهر عادة.
- إن كان السؤال مرتبطًا بالصفحة الحالية فابدأ بالحديث عنها.

سياق المستخدم:
- Page: {r.PageTitle ?? "غير محدد"} | URL: {r.PageUrl ?? "غير محدد"}
- Culture: {r.Culture ?? "ar"}

مقاطع المساعدة (Knowledge Base):
{kb}
""";
    }
}
