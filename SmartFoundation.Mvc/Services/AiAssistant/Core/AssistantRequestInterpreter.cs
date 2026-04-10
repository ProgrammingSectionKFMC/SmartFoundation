using SmartFoundation.Mvc.Services.AiAssistant.Security;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public sealed class AssistantInterpretationResult
{
    public string OriginalQuestion { get; init; } = "";
    public string NormalizedQuestion { get; init; } = "";

    public SystemPageDefinition? Page { get; init; }
    public SystemActionDefinition? Action { get; init; }

    public int PageScore { get; init; }
    public int ActionScore { get; init; }

    public IReadOnlyList<string> MatchedPageKeywords { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> MatchedActionKeywords { get; init; } = Array.Empty<string>();

    public PermissionDecision Permission { get; init; } = new();

    public bool HasPage => Page is not null;
    public bool HasAction => Action is not null;

    public bool CanExplainDetailedPageFlow => Permission.CanExplainDetailedPageFlow;
    public bool CanExplainGeneralOnly => Permission.CanExplainGeneralOnly;

    public bool IsRegulationLike { get; init; }

    public string? ArabicPageName => Page?.ArabicPageName;
    public string? ArabicActionName => Action?.ArabicLabel;
}

public sealed class AssistantRequestInterpreter
{
    private readonly PermissionResolver _permissionResolver = new();

    public AssistantInterpretationResult Interpret(
        HttpContext httpContext,
        string? userQuestion,
        string? currentInternalPageName = null)
    {
        var match = SystemModuleMatcher.MatchQuestion(userQuestion, currentInternalPageName);
        var permission = _permissionResolver.Resolve(httpContext, match);

        var isRegulationLike =
     SystemModuleMatcher.LooksLikeRegulationQuestion(userQuestion) ||
     match.Page?.ModuleType == ModuleType.Regulation ||
     (match.Page?.RelatedToRegulations ?? false);

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

    public string BuildUserFacingMessage(AssistantInterpretationResult result)
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

        // عند السماح
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
}