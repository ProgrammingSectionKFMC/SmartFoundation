using SmartFoundation.Mvc.Helpers;
using SmartFoundation.Mvc.Services.AiAssistant.Core;

namespace SmartFoundation.Mvc.Services.AiAssistant.Security;

public sealed class PermissionDecision
{
    public bool HasAnyPageAccess { get; init; }
    public bool HasRequestedActionPermission { get; init; }
    public bool CanExplainDetailedPageFlow { get; init; }
    public bool CanExplainGeneralOnly { get; init; }

    public string? InternalPageName { get; init; }
    public string? ArabicPageName { get; init; }
    public string? RequestedPermissionName { get; init; }
    public string? DenyReasonArabic { get; init; }

    public UserPagePermissionSet? PagePermissionSet { get; init; }
}

public sealed class PermissionResolver
{
    public PermissionDecision Resolve(HttpContext httpContext, SystemQuestionMatchResult match)
    {
        if (httpContext == null)
        {
            return new PermissionDecision
            {
                HasAnyPageAccess = false,
                HasRequestedActionPermission = false,
                CanExplainDetailedPageFlow = false,
                CanExplainGeneralOnly = false,
                DenyReasonArabic = AssistantArabicPhrases.UnexpectedErrorMessage
            };
        }

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

        var permissionMap = UserPermissionSessionHelper.Get(httpContext);
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
                CanExplainGeneralOnly = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations,
                DenyReasonArabic = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations
                    ? AssistantArabicPhrases.BuildPermissionDeniedWithGeneralHelpForPage(page.ArabicPageName)
                    : AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
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
                CanExplainGeneralOnly = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations,
                PagePermissionSet = pagePermissionSet,
                DenyReasonArabic = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations
                    ? AssistantArabicPhrases.BuildPermissionDeniedWithGeneralHelpForPage(page.ArabicPageName)
                    : AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
            };
        }

        // إذا ما فيه Action محدد، يكفي وجود أي صلاحية على الصفحة
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

        // إذا الإجراء في الـ registry ما له permission names، نسمح طالما الصفحة مسموحة
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
                CanExplainGeneralOnly = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations,
                PagePermissionSet = pagePermissionSet,
                DenyReasonArabic = page.AllowGeneralExplanationWithoutPermission || page.RelatedToRegulations
                    ? AssistantArabicPhrases.BuildPermissionDeniedWithGeneralHelpForPage(page.ArabicPageName)
                    : AssistantArabicPhrases.BuildPermissionDeniedForPage(page.ArabicPageName)
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
}