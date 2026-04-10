namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public enum ModuleType
{
    Operational,
    Reference,
    Inquiry,
    Regulation,
    Import,
    Billing,
    Audit
}

public enum ActionType
{
    View,
    Search,
    Add,
    Update,
    Delete,
    Print,
    Export,
    Approve,
    Reject,
    Move,
    Assign,
    Exclude,
    OpenPeriod,
    ClosePeriod,
    ReadMeter,
    Review,
    Settlement,
    Payment,
    Refund,
    ImportExcel,
    Custom
}

public sealed class SystemActionDefinition
{
    public ActionType ActionType { get; init; } = ActionType.View;

    /// <summary>
    /// Arabic label shown to the end user only.
    /// Example: "إضافة", "تعديل", "اعتماد"
    /// </summary>
    public string ArabicLabel { get; init; } = "";

    /// <summary>
    /// One or more internal permission names used by the page/controller.
    /// Example: INSERT, UPDATEWAITINGLIST, OPENMETERREADPERIOD
    /// </summary>
    public IReadOnlyList<string> PermissionNames { get; init; } = Array.Empty<string>();

    /// <summary>
    /// Arabic trigger phrases for understanding user questions.
    /// Example: "أضف", "إضافة", "سجل", "أنشئ"
    /// </summary>
    public IReadOnlyList<string> Keywords { get; init; } = Array.Empty<string>();

    /// <summary>
    /// Optional help examples shown to the user.
    /// </summary>
    public IReadOnlyList<string> ExampleQuestionsArabic { get; init; } = Array.Empty<string>();
}

public sealed class SystemPageDefinition
{
    /// <summary>
    /// Stable internal key for AI use only.
    /// Example: Housing.Residents
    /// </summary>
    public string Key { get; init; } = "";

    /// <summary>
    /// System/controller area key.
    /// Example: Housing, IncomeSystem, ElectronicBillSystem
    /// </summary>
    public string ModuleKey { get; init; } = "";

    /// <summary>
    /// ASP.NET action/page internal name.
    /// Example: Residents, Assign, FinancialAuditForUser
    /// </summary>
    public string InternalPageName { get; init; } = "";

    /// <summary>
    /// Arabic page name shown to the user.
    /// Example: "المستفيدين", "التخصيص", "التدقيق المالي للمستخدم"
    /// </summary>
    public string ArabicPageName { get; init; } = "";

    /// <summary>
    /// High-level page classification.
    /// </summary>
    public ModuleType ModuleType { get; init; } = ModuleType.Operational;

    /// <summary>
    /// Arabic keywords that may refer to this page.
    /// </summary>
    public IReadOnlyList<string> KeywordsArabic { get; init; } = Array.Empty<string>();

    /// <summary>
    /// Actions supported by this page.
    /// </summary>
    public IReadOnlyList<SystemActionDefinition> Actions { get; init; } = Array.Empty<SystemActionDefinition>();

    /// <summary>
    /// Whether the page can be explained even when the user has no page permission.
    /// Keep false for operational pages, true only for public/general knowledge pages.
    /// </summary>
    public bool AllowGeneralExplanationWithoutPermission { get; init; }

    /// <summary>
    /// Whether this page is linked to regulations/policies.
    /// </summary>
    public bool RelatedToRegulations { get; init; }

    /// <summary>
    /// Short Arabic description of what this page does.
    /// </summary>
    public string ArabicDescription { get; init; } = "";

    /// <summary>
    /// Suggested Arabic questions for the assistant UI.
    /// </summary>
    public IReadOnlyList<string> SuggestedQuestionsArabic { get; init; } = Array.Empty<string>();
}

public sealed class SystemModuleDefinition
{
    /// <summary>
    /// Stable internal key for AI use only.
    /// Example: Housing, IncomeSystem, ElectronicBillSystem
    /// </summary>
    public string Key { get; init; } = "";

    /// <summary>
    /// Arabic module name shown to the user.
    /// Example: "الإسكان", "الإيرادات", "الفوترة الإلكترونية"
    /// </summary>
    public string ArabicName { get; init; } = "";

    /// <summary>
    /// Arabic keywords that may refer to the whole module.
    /// </summary>
    public IReadOnlyList<string> KeywordsArabic { get; init; } = Array.Empty<string>();

    /// <summary>
    /// All pages that belong to this module.
    /// </summary>
    public IReadOnlyList<SystemPageDefinition> Pages { get; init; } = Array.Empty<SystemPageDefinition>();
}