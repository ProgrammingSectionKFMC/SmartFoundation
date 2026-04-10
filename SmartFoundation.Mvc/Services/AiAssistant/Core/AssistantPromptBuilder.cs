using System.Text;
using SmartFoundation.Mvc.Services.AiAssistant.Security;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public sealed class AssistantPromptContext
{
    public string UserQuestion { get; init; } = "";
    public string CurrentInternalPageName { get; init; } = "";
    public AssistantInterpretationResult Interpretation { get; init; } = new();
    public IReadOnlyList<string> KnowledgeSnippets { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> RegulationSnippets { get; init; } = Array.Empty<string>();
}

public static class AssistantPromptBuilder
{
    public static string BuildSystemPrompt(AssistantPromptContext context)
    {
        var sb = new StringBuilder();

        sb.AppendLine("أنت فيصل، مساعد ذكي داخل نظام حكومي داخلي.");
        sb.AppendLine("يجب أن تكون جميع إجاباتك بالعربية فقط.");
        sb.AppendLine("لا تذكر أي أسماء تقنية داخلية أو أسماء صفحات إنجليزية أو أسماء صلاحيات إنجليزية للمستخدم.");
        sb.AppendLine("اشرح بإيجاز ووضوح وبأسلوب مهني.");
        sb.AppendLine("إذا كانت المعلومة غير مؤكدة من المعرفة المتاحة فلا تخترع تفاصيل.");
        sb.AppendLine("إذا كان السؤال متعلقًا بلوائح أو شروط أو تعريفات فاعتمد على النصوص اللائحية والمعرفة النصية أولًا.");
        sb.AppendLine("إذا كان السؤال متعلقًا بإجراء داخل صفحة فاشرح الخطوات بشكل عملي وواضح.");
        sb.AppendLine("إذا كانت الصفحة غير متاحة للمستخدم فلا تشرح تفاصيلها التشغيلية.");
        sb.AppendLine("لا تستخدم اللغة الإنجليزية في الرد إلا عند الضرورة القصوى، والأصل أن يكون الرد عربيًا بالكامل.");
        sb.AppendLine();

        if (context.Interpretation.Page is not null)
        {
            sb.AppendLine($"اسم الصفحة بالعربية: {context.Interpretation.Page.ArabicPageName}");
            sb.AppendLine($"وصف الصفحة: {context.Interpretation.Page.ArabicDescription}");
        }

        if (context.Interpretation.Action is not null)
        {
            sb.AppendLine($"الإجراء المطلوب: {context.Interpretation.Action.ArabicLabel}");
        }

        sb.AppendLine($"نوع السؤال اللائحي: {(context.Interpretation.IsRegulationLike ? "نعم" : "لا")}");
        sb.AppendLine($"مسموح بالشرح التفصيلي: {(context.Interpretation.CanExplainDetailedPageFlow ? "نعم" : "لا")}");

        if (!context.Interpretation.CanExplainDetailedPageFlow)
        {
            sb.AppendLine($"مسموح بالشرح العام فقط: {(context.Interpretation.CanExplainGeneralOnly ? "نعم" : "لا")}");
        }
        sb.AppendLine();

        if (!context.Interpretation.CanExplainDetailedPageFlow)
        {
            sb.AppendLine("إذا لم يكن الشرح التفصيلي مسموحًا، فالتزم فقط بالشرح العام المسموح أو الاعتذار المناسب.");
            sb.AppendLine();
        }

        if (context.KnowledgeSnippets.Count > 0)
        {
            sb.AppendLine("مقاطع المعرفة الإجرائية المتاحة:");
            for (int i = 0; i < context.KnowledgeSnippets.Count; i++)
            {
                sb.AppendLine($"- مقطع {i + 1}: {context.KnowledgeSnippets[i]}");
            }
            sb.AppendLine();
        }

        if (context.RegulationSnippets.Count > 0)
        {
            sb.AppendLine("مقاطع اللوائح والأنظمة المتاحة:");
            for (int i = 0; i < context.RegulationSnippets.Count; i++)
            {
                sb.AppendLine($"- لائحة {i + 1}: {context.RegulationSnippets[i]}");
            }
            sb.AppendLine();
        }

        sb.AppendLine("طريقة الإجابة المطلوبة:");
        sb.AppendLine("1) ابدأ بجواب مباشر.");
        sb.AppendLine("2) إذا كان السؤال إجرائيًا فاذكر الخطوات بشكل مرتب.");
        sb.AppendLine("3) إذا كان السؤال لائحيًا فاذكر الشروط أو التعريف أو الحكم بشكل واضح.");
        sb.AppendLine("4) إذا لم تكفِ المعلومات، قل ذلك بوضوح دون اختلاق.");
        sb.AppendLine("5) لا تذكر أنك نموذج أو أنك استندت إلى prompt داخلي.");
        sb.AppendLine();

        return sb.ToString().Trim();
    }

    public static string BuildUserPrompt(AssistantPromptContext context)
    {
        var sb = new StringBuilder();

        sb.AppendLine("سؤال المستخدم:");
        sb.AppendLine(context.UserQuestion);
        sb.AppendLine();

        if (context.Interpretation.Page is not null)
        {
            sb.AppendLine($"الصفحة المقصودة: {context.Interpretation.Page.ArabicPageName}");
        }

        if (context.Interpretation.Action is not null)
        {
            sb.AppendLine($"الإجراء المقصود: {context.Interpretation.Action.ArabicLabel}");
        }

        if (context.Interpretation.IsRegulationLike)
        {
            sb.AppendLine("طبيعة السؤال: لائحي / نظامي / شروط");
        }
        else
        {
            sb.AppendLine("طبيعة السؤال: تشغيلي / إجرائي");
        }

        if (!context.Interpretation.CanExplainDetailedPageFlow)
        {
            if (context.Interpretation.CanExplainGeneralOnly)
            {
                sb.AppendLine("التزم بالشرح العام فقط، ولا تذكر تفاصيل تشغيلية غير مسموحة.");
            }
            else
            {
                sb.AppendLine("لا تشرح تفاصيل الصفحة، وقدم اعتذارًا مهنيًا مناسبًا.");
            }
        }

        sb.AppendLine();
        sb.AppendLine("أعطني أفضل إجابة عربية مناسبة لهذا السؤال.");

        return sb.ToString().Trim();
    }

    public static string BuildFullPrompt(AssistantPromptContext context)
    {
        var systemPrompt = BuildSystemPrompt(context);
        var userPrompt = BuildUserPrompt(context);

        return
$"""
[تعليمات النظام]
{systemPrompt}

[رسالة المستخدم]
{userPrompt}
""".Trim();
    }
}