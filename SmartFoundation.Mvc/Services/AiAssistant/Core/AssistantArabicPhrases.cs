namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public static class AssistantArabicPhrases
{
    public const string AssistantDisplayName = "فيصل";

    public static string WelcomeMessage =>
        "أنا فيصل 👋\n" +
        "مساعدك الذكي داخل النظام.\n" +
        "أقدر أساعدك في شرح الصفحات والإجراءات واللوائح حسب صلاحياتك.";

    public static string SystemOnlyHelpMessage =>
        "أنا مخصص للإجابة عن النظام واللوائح والإجراءات المرتبطة به.\n\n" +
        "أمثلة:\n" +
        "• كيف أضيف مستفيدًا؟\n" +
        "• كيف أبحث في قوائم الانتظار؟\n" +
        "• ما شروط الإخلاء؟\n" +
        "• كيف أفتح فترة قراءة عدادات؟";

    public static string UnknownQuestionMessage =>
        "لم أفهم سؤالك بشكل كافٍ.\n" +
        "جرّب أن تذكر اسم الصفحة أو الإجراء الذي تريده بشكل أوضح.";

    public static string NeedMoreDetailsMessage =>
        "سؤالك ما زال يحتاج تحديدًا أكثر.\n" +
        "اذكر الصفحة أو الإجراء المطلوب حتى أساعدك بشكل أدق.";

    public static string NoKnowledgeMatchMessage =>
        "لم أجد شرحًا واضحًا لهذا السؤال في المعرفة المتاحة حاليًا.";

    public static string NoPermissionMessage =>
        "هذه الصفحة غير متاحة لك حسب صلاحياتك الحالية، لذلك لا أستطيع شرح إجراءاتها التفصيلية.\n" +
        "يمكنك التواصل مع المسؤول عن الصلاحيات إذا كنت تحتاج الوصول إليها.";

    public static string NoPermissionButGeneralHelpMessage =>
        "هذه الصفحة غير متاحة لك حسب صلاحياتك الحالية، لذلك لا أستطيع شرح إجراءاتها التفصيلية.\n" +
        "لكن أقدر أشرح لك الجانب العام أو النظامي المرتبط بها إذا رغبت.";

    public static string RegulationFallbackMessage =>
        "لم يتم العثور على نص واضح لهذا الموضوع في اللوائح أو الأنظمة المتاحة حاليًا.";

    public static string OperationCancelledMessage =>
        "تم إيقاف العملية.";

    public static string UnexpectedErrorMessage =>
        "حدث خطأ غير متوقع في المساعد.";

    public static string TimeoutMessage =>
        "استغرق الطلب وقتًا أطول من المتوقع.\n" +
        "حاول اختصار السؤال أو ذكر الصفحة المطلوبة بشكل مباشر.";

    public static string BuildPermissionDeniedForPage(string arabicPageName)
    {
        if (string.IsNullOrWhiteSpace(arabicPageName))
            return "أعتذر، لا أستطيع شرح هذه الصفحة لأن صلاحيتك الحالية لا تسمح بذلك.";

        return $"أعتذر، صفحة {arabicPageName} غير متاحة لك حسب صلاحياتك الحالية، لذلك لا أستطيع شرح إجراءاتها.\n" +
               "يمكنك التواصل مع المسؤول عن الصلاحيات إذا كنت تحتاج الوصول إليها.";
    }

    public static string BuildPermissionDeniedWithGeneralHelpForPage(string arabicPageName)
    {
        if (string.IsNullOrWhiteSpace(arabicPageName))
            return NoPermissionButGeneralHelpMessage;

        return $"أعتذر، صفحة {arabicPageName} غير متاحة لك حسب صلاحياتك الحالية، لذلك لا أستطيع شرح إجراءاتها التفصيلية.\n" +
               "لكن أقدر أشرح لك الجانب العام أو النظامي المرتبط بها إذا رغبت.";
    }

    public static string BuildPageNotFoundMessage(string pageName)
    {
        if (string.IsNullOrWhiteSpace(pageName))
            return "لم أتعرف على الصفحة المقصودة.";

        return $"لم أتعرف على الصفحة المقصودة: {pageName}";
    }

    public static string BuildActionClarificationMessage(string arabicPageName, IEnumerable<string> actionLabels)
    {
        var actions = actionLabels?
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct()
            .ToArray() ?? [];

        if (actions.Length == 0)
        {
            return string.IsNullOrWhiteSpace(arabicPageName)
                ? "ما الإجراء الذي تريد تنفيذه؟"
                : $"ما الإجراء الذي تريد تنفيذه في صفحة {arabicPageName}؟";
        }

        var joined = string.Join(" أو ", actions);

        return string.IsNullOrWhiteSpace(arabicPageName)
            ? $"هل تريد {joined}؟"
            : $"هل تريد {joined} في صفحة {arabicPageName}؟";
    }

    public static string BuildSuggestedQuestionsMessage(IEnumerable<string> questions)
    {
        var list = questions?
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct()
            .ToArray() ?? [];

        if (list.Length == 0)
            return string.Empty;

        return "جرّب مثلًا:\n• " + string.Join("\n• ", list);
    }

    public static string BuildPageIntroMessage(string arabicPageName, string description)
    {
        if (string.IsNullOrWhiteSpace(arabicPageName) && string.IsNullOrWhiteSpace(description))
            return string.Empty;

        if (string.IsNullOrWhiteSpace(description))
            return $"هذه الصفحة هي: {arabicPageName}";

        if (string.IsNullOrWhiteSpace(arabicPageName))
            return description;

        return $"صفحة {arabicPageName}: {description}";
    }

    public static string BuildGeneralRegulationAnswer(string topic, string content)
    {
        if (string.IsNullOrWhiteSpace(topic))
            return content ?? string.Empty;

        return $"الموضوع: {topic}\n\n{content}";
    }

    public static string BuildExamplesForPage(string arabicPageName, IEnumerable<string> examples)
    {
        var list = examples?
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct()
            .ToArray() ?? [];

        if (list.Length == 0)
            return string.IsNullOrWhiteSpace(arabicPageName)
                ? string.Empty
                : $"أقدر أساعدك في شرح صفحة {arabicPageName}.";

        return string.IsNullOrWhiteSpace(arabicPageName)
            ? "أمثلة مفيدة:\n• " + string.Join("\n• ", list)
            : $"أمثلة مفيدة في صفحة {arabicPageName}:\n• " + string.Join("\n• ", list);
    }
}
