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
    // ===== Table =====
    public List<ReportColumn> Columns { get; set; } = new();
    public List<Dictionary<string, object?>> Rows { get; set; } = new();
    public float? TableFontSize { get; set; }

    // التسلسل اختياري وغير مفعّل افتراضيًا
    public bool ShowSerial { get; set; } = false;
    public string SerialLabel { get; set; } = "م";
    public int SerialStart { get; set; } = 1;
    public string? GroupByKey { get; set; }
    public string? GroupTitle { get; set; }
    public bool StartEachGroupOnNewPage { get; set; }

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

public enum ReportHeaderRepeat
{
    AllPages,
    FirstPageOnly
}

public enum LetterBlockType
{
    Text,
    Table,
    Spacer,
    Divider,
    Footer
}

public class LetterTableCell
{
    public string Text { get; set; } = "";
    public int ColumnSpan { get; set; } = 1;
    public int RowSpan { get; set; } = 1;
    public bool Bold { get; set; } = false;
    public TextAlign Align { get; set; } = TextAlign.Center;
    public string BackgroundColor { get; set; } = "#FFFFFF";
    public float FontSize { get; set; } = 11;
}

public class LetterTableRow
{
    public List<LetterTableCell> Cells { get; set; } = new();
    public bool ExtendVertical { get; set; } = false;
    public float MinRowHeight { get; set; } = 0f;
}

public class LetterTable
{
    public List<float> Columns { get; set; } = new();
    public List<LetterTableRow> HeaderRows { get; set; } = new();
    public List<LetterTableRow> Rows { get; set; } = new();

    public float BorderWidth { get; set; } = 1f;
    public string BorderColor { get; set; } = "#444444";
    public float CellPadding { get; set; } = 6f;
    public bool ExtendVertical { get; set; } = false;
    public float MinRowHeight { get; set; } = 0f;
}

public class LetterBlock
{
    public LetterBlockType Type { get; set; } = LetterBlockType.Text;

    // ===== Text =====
    public string Text { get; set; } = "";
    public float FontSize { get; set; } = 12;
    public bool Bold { get; set; } = false;
    public bool Underline { get; set; } = false;
    public TextAlign Align { get; set; } = TextAlign.Right;

    // ===== Common spacing =====
    public float PaddingTop { get; set; } = 0;
    public float PaddingBottom { get; set; } = 0;
    public float PaddingRight { get; set; } = 0;
    public float PaddingLeft { get; set; } = 0;

    // ===== Text only =====
    public float LineHeight { get; set; } = 1.4f;

    // ===== Spacer =====
    public float Height { get; set; } = 0;

    // ===== Table =====
    public LetterTable? Table { get; set; }
    public bool StretchToFill { get; set; } = false;

    // ===== Footer =====
    public string FooterRight { get; set; } = "";
    public string FooterCenter { get; set; } = "";
    public string FooterLeft { get; set; } = "";
    public float FooterFontSize { get; set; } = 6.3f;
}

public static class LetterBlockFactory
{
    public static LetterBlock TextBlock(
        string text,
        float fontSize = 12,
        bool bold = false,
        TextAlign align = TextAlign.Right,
        float paddingTop = 0,
        float paddingBottom = 0,
        float paddingRight = 0,
        float paddingLeft = 0,
        float lineHeight = 1.4f,
        bool underline = false)
    {
        return new LetterBlock
        {
            Type = LetterBlockType.Text,
            Text = text,
            FontSize = fontSize,
            Bold = bold,
            Underline = underline,
            Align = align,
            PaddingTop = paddingTop,
            PaddingBottom = paddingBottom,
            PaddingRight = paddingRight,
            PaddingLeft = paddingLeft,
            LineHeight = lineHeight
        };
    }

    public static LetterBlock TableBlock(
        LetterTable table,
        float paddingTop = 0,
        float paddingBottom = 0,
        float paddingRight = 0,
        float paddingLeft = 0,
        bool stretchToFill = false)
    {
        return new LetterBlock
        {
            Type = LetterBlockType.Table,
            Table = table,
            PaddingTop = paddingTop,
            PaddingBottom = paddingBottom,
            PaddingRight = paddingRight,
            PaddingLeft = paddingLeft,
            StretchToFill = stretchToFill
        };
    }

    public static LetterBlock Spacer(float height)
    {
        return new LetterBlock
        {
            Type = LetterBlockType.Spacer,
            Height = height
        };
    }

    public static LetterBlock Divider(
        float paddingTop = 6,
        float paddingBottom = 6)
    {
        return new LetterBlock
        {
            Type = LetterBlockType.Divider,
            PaddingTop = paddingTop,
            PaddingBottom = paddingBottom
        };
    }

    public static LetterBlock FooterBlock(
        string right,
        string center,
        string left,
        float fontSize = 6.3f,
        float paddingTop = 4)
    {
        return new LetterBlock
        {
            Type = LetterBlockType.Footer,
            FooterRight = right,
            FooterCenter = center,
            FooterLeft = left,
            FooterFontSize = fontSize,
            PaddingTop = paddingTop
        };
    }
}

public static class ReportTableFactory
{
    public static LetterTable CreateOfficialTable(List<float> columns)
    {
        return new LetterTable
        {
            Columns = columns,
            BorderWidth = 1f,
            BorderColor = "#555555",
            CellPadding = 6f
        };
    }

    public static LetterTableCell HeaderCell(string text, TextAlign align = TextAlign.Center)
    {
        return new LetterTableCell
        {
            Text = text,
            Bold = true,
            Align = align,
            BackgroundColor = "#F3F3F3",
            FontSize = 11
        };
    }

    public static LetterTableCell ValueCell(string text, TextAlign align = TextAlign.Center, float fontSize = 11)
    {
        return new LetterTableCell
        {
            Text = text,
            Bold = false,
            Align = align,
            BackgroundColor = "#FFFFFF",
            FontSize = fontSize
        };
    }
}




