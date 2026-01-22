namespace SmartFoundation.MVC.Reports;

public enum ReportOrientation { Auto, Portrait, Landscape }

public record ReportColumn(
    string Key,
    string Title,
    string? Format = null,
    string Align = "right",
    int Weight = 2,
    float? FontSize = null,
    float? Width = null 
);


public class ReportResult
{
    public string ReportId { get; set; } = "";
    public string Title { get; set; } = "";

    public ReportKind Kind { get; set; } = ReportKind.Table;

    public ReportOrientation Orientation { get; set; } = ReportOrientation.Auto;

    // ===== Header =====
    public Dictionary<string, string> HeaderFields { get; set; } = new();
    public ReportHeaderType HeaderType { get; set; } = ReportHeaderType.Standard;
    public string? LogoPath { get; set; }
    public ReportHeaderRepeat HeaderRepeat { get; set; } = ReportHeaderRepeat.AllPages;

    // ===== Table =====
    public List<ReportColumn> Columns { get; set; } = new();
    public List<Dictionary<string, object?>> Rows { get; set; } = new();
    public float? TableFontSize { get; set; }

    // ===== Letter =====
    public List<LetterBlock> LetterBlocks { get; set; } = new();
    public string? LetterTitle { get; set; }
    public float LetterTitleFontSize { get; set; } = 14;

    // ===== Footer =====
    public Dictionary<string, string>? FooterFields { get; set; } = new();
    public bool ShowFooter { get; set; } = true;
}


public enum ReportHeaderType
{
    Standard,
    LetterOfficial,
    WithLogoRight
}


public enum ReportKind
{
    Table,
    Letter
}

public enum TextAlign
{
    Right,
    Center,
    Left,
    Justify
}

public class LetterBlock
{
    public string Text { get; set; } = "";

    public float FontSize { get; set; } = 12;

    public bool Bold { get; set; } = false;
    public bool Underline { get; set; } = false;

    public TextAlign Align { get; set; } = TextAlign.Right;

    // مسافات خارجية
    public float PaddingTop { get; set; } = 0;
    public float PaddingBottom { get; set; } = 0;
    public float PaddingRight { get; set; } = 0;
    public float PaddingLeft { get; set; } = 0;

    // تباعد الأسطر داخل الفقرة
    public float LineHeight { get; set; } = 1.4f;
}


public enum ReportHeaderRepeat
{
    AllPages,      // الهيدر في كل الصفحات
    FirstPageOnly  // الهيدر في الصفحة الأولى فقط
}





