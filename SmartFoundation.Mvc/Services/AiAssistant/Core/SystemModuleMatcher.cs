using System;
using System.Collections.Generic;
using System.Linq;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public sealed class SystemPageMatchResult
{
    public SystemPageDefinition? Page { get; init; }
    public int Score { get; init; }
    public string NormalizedQuestion { get; init; } = "";
    public IReadOnlyList<string> MatchedKeywords { get; init; } = Array.Empty<string>();

    public bool IsMatched => Page is not null && Score > 0;
}

public sealed class SystemActionMatchResult
{
    public SystemActionDefinition? Action { get; init; }
    public int Score { get; init; }
    public IReadOnlyList<string> MatchedKeywords { get; init; } = Array.Empty<string>();

    public bool IsMatched => Action is not null && Score > 0;
}

public sealed class SystemQuestionMatchResult
{
    public string OriginalQuestion { get; init; } = "";
    public string NormalizedQuestion { get; init; } = "";

    public SystemPageDefinition? Page { get; init; }
    public SystemActionDefinition? Action { get; init; }

    public int PageScore { get; init; }
    public int ActionScore { get; init; }

    public IReadOnlyList<string> MatchedPageKeywords { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> MatchedActionKeywords { get; init; } = Array.Empty<string>();

    public bool HasPage => Page is not null;
    public bool HasAction => Action is not null;
}

public static class SystemModuleMatcher
{
    public static SystemQuestionMatchResult MatchQuestion(string? question, string? currentInternalPageName = null)
    {
        var originalQuestion = question ?? string.Empty;
        var normalizedQuestion = ArabicTextNormalizer.Normalize(originalQuestion);

        var pageMatch = MatchPage(question, currentInternalPageName);
        var actionMatch = MatchAction(question, pageMatch.Page);

        return new SystemQuestionMatchResult
        {
            OriginalQuestion = originalQuestion,
            NormalizedQuestion = normalizedQuestion,
            Page = pageMatch.Page,
            Action = actionMatch.Action,
            PageScore = pageMatch.Score,
            ActionScore = actionMatch.Score,
            MatchedPageKeywords = pageMatch.MatchedKeywords,
            MatchedActionKeywords = actionMatch.MatchedKeywords
        };
    }

    public static SystemPageMatchResult MatchPage(string? question, string? currentInternalPageName = null)
    {
        var normalizedQuestion = ArabicTextNormalizer.Normalize(question);
        if (string.IsNullOrWhiteSpace(normalizedQuestion))
        {
            return new SystemPageMatchResult
            {
                NormalizedQuestion = normalizedQuestion
            };
        }

        var pages = SystemModuleRegistry.GetAllPages().ToList();
        var currentPage = SystemModuleRegistry.FindPageByInternalName(currentInternalPageName);

        SystemPageDefinition? bestPage = null;
        int bestScore = 0;
        List<string> bestKeywords = new();

        foreach (var page in pages)
        {
            int score = 0;
            var matchedKeywords = new List<string>();

            // Smart boosts for known high-value phrases
            if (page.InternalPageName.Equals("AllMeterRead", StringComparison.OrdinalIgnoreCase))
            {
                if (ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                    "جميع قراءات العدادات",
                    "عرض جميع قراءات العدادات",
                    "قراءات العدادات",
                    "إضافة قراءة عداد",
                    "اضافة قراءة عداد",
                    "أضيف قراءة عداد",
                    "اضيف قراءة عداد",
                    "قراءة عداد جديدة",
                    "فترة قراءة العدادات",
                    "فتح فترة عدادات",
                    "فتح فترة قراءة",
                    "اغلاق فترة عدادات",
                    "اغلاق فترة قراءة العدادات",
                    "اعتماد قراءة عداد"))
                {
                    score += 24;
                    matchedKeywords.Add("جميع قراءات العدادات");
                }
            }

            if (page.InternalPageName.Equals("Meters", StringComparison.OrdinalIgnoreCase))
            {
                if (ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                    "قراءات العدادات", "قراءة عداد", "فترة قراءة", "فتح فترة", "اغلاق فترة", "اعتماد قراءة"))
                {
                    score -= 8;
                }
            }

            if (page.InternalPageName.Equals("WaitingListMoveList", StringComparison.OrdinalIgnoreCase))
            {
                if (ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                    "رفض طلب نقل", "اعتماد طلب نقل", "طلبات النقل الواردة", "طلب نقل"))
                {
                    score += 20;
                    matchedKeywords.Add("طلب نقل");
                }
            }

            if (page.InternalPageName.Equals("WaitingListByResident", StringComparison.OrdinalIgnoreCase))
            {
                if (ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                    "اضافة خطاب تسكين", "إضافة خطاب تسكين", "تعديل خطاب تسكين", "حذف خطاب تسكين"))
                {
                    score += 14;
                    matchedKeywords.Add("خطاب تسكين");
                }
            }

            if (page.InternalPageName.Equals("HousingExit", StringComparison.OrdinalIgnoreCase))
            {
                if (ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                    "شروط الاخلاء", "شروط الإخلاء", "ضوابط الاخلاء", "ما معنى الاخلاء", "ما معنى الإخلاء"))
                {
                    score += 12;
                    matchedKeywords.Add("الإخلاء");
                }
            }

            // Boost if current page matches
            if (currentPage is not null &&
                page.InternalPageName.Equals(currentPage.InternalPageName, StringComparison.OrdinalIgnoreCase))
            {
                score += 8;
            }

            // Match Arabic page name
            if (ArabicTextNormalizer.Contains(normalizedQuestion, page.ArabicPageName))
            {
                score += 10;
                matchedKeywords.Add(page.ArabicPageName);
            }

            // Match internal page name if user used it
            if (ArabicTextNormalizer.Contains(normalizedQuestion, page.InternalPageName))
            {
                score += 8;
                matchedKeywords.Add(page.InternalPageName);
            }

            // Match page keywords
            foreach (var keyword in page.KeywordsArabic)
            {
                if (!ArabicTextNormalizer.Contains(normalizedQuestion, keyword))
                    continue;

                var normalizedKeyword = ArabicTextNormalizer.Normalize(keyword);
                score += normalizedKeyword.Length >= 6 ? 5 : 3;
                matchedKeywords.Add(keyword);
            }

            // Boost from module keywords
            var module = SystemModuleRegistry.FindModuleByKey(page.ModuleKey);
            if (module is not null)
            {
                foreach (var keyword in module.KeywordsArabic)
                {
                    if (!ArabicTextNormalizer.Contains(normalizedQuestion, keyword))
                        continue;

                    score += 2;
                    matchedKeywords.Add(keyword);
                }
            }

            // Small boost if suggested questions semantically overlap
            foreach (var suggestion in page.SuggestedQuestionsArabic)
            {
                var suggestionHits = CountSharedTokens(normalizedQuestion, suggestion);
                if (suggestionHits > 0)
                    score += suggestionHits;
            }

            if (score > bestScore)
            {
                bestScore = score;
                bestPage = page;
                bestKeywords = matchedKeywords
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
            }
        }

        return new SystemPageMatchResult
        {
            Page = bestPage,
            Score = bestScore,
            NormalizedQuestion = normalizedQuestion,
            MatchedKeywords = bestKeywords
        };
    }

    public static SystemActionMatchResult MatchAction(string? question, SystemPageDefinition? page)
    {
        var normalizedQuestion = ArabicTextNormalizer.Normalize(question);
        if (string.IsNullOrWhiteSpace(normalizedQuestion) || page is null || page.Actions.Count == 0)
        {
            return new SystemActionMatchResult();
        }

        SystemActionDefinition? bestAction = null;
        int bestScore = 0;
        List<string> bestKeywords = new();

        foreach (var action in page.Actions)
        {
            int score = 0;
            var matchedKeywords = new List<string>();

            // Smart action boosts
            if (page.InternalPageName.Equals("AllMeterRead", StringComparison.OrdinalIgnoreCase))
            {
                if (action.ActionType == ActionType.View &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion,
                        "اعرض جميع قراءات العدادات", "عرض جميع قراءات العدادات", "اعرض القراءات", "عرض القراءات"))
                {
                    score += 24;
                    matchedKeywords.Add("عرض جميع القراءات");
                }

                if (action.ActionType == ActionType.OpenPeriod &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "فتح فترة عدادات", "فتح فترة قراءة", "افتح فترة"))
                {
                    score += 20;
                    matchedKeywords.Add("فتح فترة");
                }

                if (action.ActionType == ActionType.ClosePeriod &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "اغلاق فترة عدادات", "إغلاق فترة عدادات", "اغلق فترة", "اقفل فترة"))
                {
                    score += 20;
                    matchedKeywords.Add("إغلاق فترة");
                }

                if (action.ActionType == ActionType.Approve &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "اعتمد قراءة عداد", "اعتماد قراءة عداد", "اعتماد القراءة", "اعتمد القراءة"))
                {
                    score += 24;
                    matchedKeywords.Add("اعتماد قراءة عداد");
                }

                if (action.ActionType == ActionType.ReadMeter &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "إضافة قراءة عداد", "اضافة قراءة عداد", "أضيف قراءة عداد", "اضيف قراءة عداد", "قراءة عداد جديدة", "ادخل قراءة"))
                {
                    score += 24;
                    matchedKeywords.Add("قراءة عداد");
                }
            }

            if (page.InternalPageName.Equals("WaitingListMoveList", StringComparison.OrdinalIgnoreCase))
            {
                if (action.ActionType == ActionType.Reject &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "رفض طلب نقل", "ارفض طلب نقل", "رفض"))
                {
                    score += 20;
                    matchedKeywords.Add("رفض");
                }

                if (action.ActionType == ActionType.Approve &&
                    ArabicTextNormalizer.ContainsAny(normalizedQuestion, "اعتماد طلب نقل", "اعتمد طلب نقل", "اعتماد"))
                {
                    score += 20;
                    matchedKeywords.Add("اعتماد");
                }
            }

            if (ArabicTextNormalizer.Contains(normalizedQuestion, action.ArabicLabel))
            {
                score += 8;
                matchedKeywords.Add(action.ArabicLabel);
            }

            foreach (var keyword in action.Keywords)
            {
                if (!ArabicTextNormalizer.Contains(normalizedQuestion, keyword))
                    continue;

                var normalizedKeyword = ArabicTextNormalizer.Normalize(keyword);
                score += normalizedKeyword.Length >= 5 ? 5 : 3;
                matchedKeywords.Add(keyword);
            }

            foreach (var example in action.ExampleQuestionsArabic)
            {
                var suggestionHits = CountSharedTokens(normalizedQuestion, example);
                if (suggestionHits > 0)
                    score += suggestionHits;
            }

            if (score > bestScore)
            {
                bestScore = score;
                bestAction = action;
                bestKeywords = matchedKeywords
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
            }
        }

        return new SystemActionMatchResult
        {
            Action = bestAction,
            Score = bestScore,
            MatchedKeywords = bestKeywords
        };
    }

    public static bool IsStrongPageMatch(SystemPageMatchResult match)
        => match.Page is not null && match.Score >= 8;

    public static bool IsStrongActionMatch(SystemActionMatchResult match)
        => match.Action is not null && match.Score >= 6;

    private static int CountSharedTokens(string normalizedQuestion, string candidateText)
    {
        var qTokens = ArabicTextNormalizer.Tokenize(normalizedQuestion);
        var cTokens = ArabicTextNormalizer.Tokenize(candidateText);

        if (qTokens.Length == 0 || cTokens.Length == 0)
            return 0;

        var candidateSet = new HashSet<string>(cTokens, StringComparer.OrdinalIgnoreCase);
        int count = 0;

        foreach (var token in qTokens)
        {
            if (candidateSet.Contains(token))
                count++;
        }

        return count;
    }

    public static bool LooksLikeRegulationQuestion(string? question)
    {
        if (string.IsNullOrWhiteSpace(question))
            return false;

        var normalized = ArabicTextNormalizer.Normalize(question);

        return ArabicTextNormalizer.ContainsAny(normalized,
            "شروط",
            "ضوابط",
            "لائحه",
            "لائحة",
            "نظام",
            "انظمه",
            "أنظمة",
            "ما معنى",
            "ما المقصود",
            "تعريف",
            "احقيه",
            "أحقية",
            "استحقاق",
            "الاخلاء",
            "الإخلاء",
            "التلف",
            "التلف الجزئي",
            "التلف الكلي",
            "مسؤولية",
            "مسوولية",
            "من يحق له",
            "هل يحق");
    }
}
