using SmartFoundation.Mvc.Services.AiAssistant.Security;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public sealed class AssistantOrchestratorResult
{
    public AssistantInterpretationResult Interpretation { get; init; } = new();
    public string UserFacingMessage { get; init; } = "";
    public string FullPrompt { get; init; } = "";
    public bool ShouldCallLlm { get; init; }
    public bool IsPermissionDenied => !Interpretation.CanExplainDetailedPageFlow && !Interpretation.CanExplainGeneralOnly;
    public bool IsGeneralOnly => !Interpretation.CanExplainDetailedPageFlow && Interpretation.CanExplainGeneralOnly;
}

public sealed class AssistantOrchestrator
{
    private readonly AssistantRequestInterpreter _interpreter = new();

    public AssistantOrchestratorResult Prepare(
        HttpContext httpContext,
        string? userQuestion,
        string? currentInternalPageName,
        IReadOnlyList<string>? knowledgeSnippets = null,
        IReadOnlyList<string>? regulationSnippets = null)
    {
        var interpretation = _interpreter.Interpret(httpContext, userQuestion, currentInternalPageName);
        var userFacingMessage = _interpreter.BuildUserFacingMessage(interpretation);

        // إذا لم تُعرف الصفحة أصلًا، لا داعي لنداء الموديل
        if (!interpretation.HasPage)
        {
            return new AssistantOrchestratorResult
            {
                Interpretation = interpretation,
                UserFacingMessage = userFacingMessage,
                FullPrompt = "",
                ShouldCallLlm = false
            };
        }

        // إذا الشرح ممنوع بالكامل، لا داعي لنداء الموديل
        if (!interpretation.CanExplainDetailedPageFlow && !interpretation.CanExplainGeneralOnly)
        {
            return new AssistantOrchestratorResult
            {
                Interpretation = interpretation,
                UserFacingMessage = userFacingMessage,
                FullPrompt = "",
                ShouldCallLlm = false
            };
        }

        // إذا السؤال غير محدد كفاية ولم يحدد الإجراء، غالبًا نرجع رسالة توضيح بدل LLM
        if (interpretation.HasPage && !interpretation.HasAction && !interpretation.IsRegulationLike)
        {
            return new AssistantOrchestratorResult
            {
                Interpretation = interpretation,
                UserFacingMessage = userFacingMessage,
                FullPrompt = "",
                ShouldCallLlm = false
            };
        }

        var promptContext = new AssistantPromptContext
        {
            UserQuestion = userQuestion ?? "",
            CurrentInternalPageName = currentInternalPageName ?? "",
            Interpretation = interpretation,
            KnowledgeSnippets = knowledgeSnippets ?? Array.Empty<string>(),
            RegulationSnippets = regulationSnippets ?? Array.Empty<string>()
        };

        var fullPrompt = AssistantPromptBuilder.BuildFullPrompt(promptContext);

        return new AssistantOrchestratorResult
        {
            Interpretation = interpretation,
            UserFacingMessage = userFacingMessage,
            FullPrompt = fullPrompt,
            ShouldCallLlm = true
        };
    }
}