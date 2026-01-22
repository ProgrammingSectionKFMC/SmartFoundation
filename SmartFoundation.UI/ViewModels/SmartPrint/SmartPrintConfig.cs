using System.Text.RegularExpressions;

// هذا الملف يعرّف نموذج البيانات الكامل للتقارير القابلة للطباعة، ويحدد شكل تقرير A4 الطولي ومحتواه (الهيدر، البلوكات، الجداول، الفوتر) بنفس أسلوب ومعمارية SmartCharts
//SmartFoundation\SmartFoundation.UI\ViewModels\SmartPrint
namespace SmartFoundation.UI.ViewModels.SmartPrint
{
    //  A4 + طولي
    public enum PrintDocType
    {
        A4PortraitReport
    }
    public enum PrintTone { Neutral, Info, Success, Warning, Danger }
    public enum PrintDocSize { Sm, Md, Lg }
    public enum PrintDocVariant { Soft, Outline, Solid }

    // أزرار أعلى بلوك الطباعة (مثل ChartAction)
    public class PrintAction
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Text { get; set; } = "";
        public string? Icon { get; set; }          // FontAwesome class

        public string? Href { get; set; }          // رابط
        public string? OnClickJs { get; set; }     // JS snippet

        public string? CssClass { get; set; }      // تخصيص مظهر
        public bool Show { get; set; } = true;

        public string? Title { get; set; }         // tooltip
        public bool OpenNewTab { get; set; } = false;
    }


    // شعار من DB: إما Url أو Base64
    public class PrintLogo
    {
        public string? Url { get; set; }        // "/uploads/logo.png"
        public string? Base64 { get; set; }     // "iVBORw0KGgo..."
        public string Alt { get; set; } = "Logo";
        public int Width { get; set; } = 56;
        public int Height { get; set; } = 56;
    }

    // عناصر Key/Value 
    public class PrintKeyValue
    {
        public string Key { get; set; } = "";
        public string Value { get; set; } = "";
        public string? Icon { get; set; }
    }

    // هيدر يمين/يسار
    public class PrintHeaderBlock
    {
        public string? Title { get; set; }
        public string? Subtitle { get; set; }
        public List<PrintKeyValue> Meta { get; set; } = new();
    }

    // فوتر
    public class PrintFooter
    {
        public string? LeftText { get; set; }
        public string? CenterText { get; set; }
        public string? RightText { get; set; }
        public bool ShowPageNumbers { get; set; } = true;
    }

    //  نبدأ بـ 3 بلوكات  (تغطي 80% من التقارير)
    public enum PrintBlockType
    {
        KeyValueGrid,
        Paragraph,
        Table
    }

    public class PrintTableColumn
    {
        public string Field { get; set; } = "";   // key في row dict
        public string Label { get; set; } = "";   // عنوان
        public string Type { get; set; } = "text";
        public bool Visible { get; set; } = true;
        public string? Width { get; set; }        // "20%" أو "120px"
        public string? Align { get; set; }        // left/center/right
    }

    public class PrintBlock
    {
        public string Key { get; set; } = Guid.NewGuid().ToString("N");
        public PrintBlockType Type { get; set; }
        public string Dir { get; set; } = "rtl";

        public string? Title { get; set; }
        public string? Subtitle { get; set; }
        public string? ExtraCss { get; set; }

        // Paragraph
        public string? Text { get; set; }

        // KeyValueGrid
        public int GridCols { get; set; } = 2; // 1..4
        public List<PrintKeyValue> Items { get; set; } = new();

        // Table
        public List<PrintTableColumn> Columns { get; set; } = new();
        public List<Dictionary<string, object?>> Rows { get; set; } = new();
    }

    // “Doc”  
    public class PrintDocConfig
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public PrintDocType Type { get; set; }

        public string Dir { get; set; } = "rtl";
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Icon { get; set; }
        public PrintTone Tone { get; set; } = PrintTone.Neutral;
        public PrintDocSize Size { get; set; } = PrintDocSize.Md;
        public PrintDocVariant Variant { get; set; } = PrintDocVariant.Outline;

        // States
        public bool IsLoading { get; set; } = false;
        public bool IsEmpty { get; set; } = false;
        public string? EmptyMessage { get; set; } = "لا توجد بيانات";
        public string? ErrorMessage { get; set; }

        // إعدادات الورقة
        public string Paper { get; set; } = "A4";
        public string Orientation { get; set; } = "portrait";
        public int MarginMm { get; set; } = 12;

        // Payload للتقرير A4PortraitReport
        public PrintLogo? Logo { get; set; }
        public PrintHeaderBlock HeaderRight { get; set; } = new();
        public PrintHeaderBlock HeaderLeft { get; set; } = new();
        public PrintFooter Footer { get; set; } = new();
        public List<PrintBlock> Blocks { get; set; } = new();
    }

    
    public class SmartPrintConfig
    {
        public string PrintId { get; set; } = "smartPrint";
        public string? Title { get; set; }
        public string Dir { get; set; } = "rtl";

        public List<PrintAction> Actions { get; set; } = new();
        public List<PrintDocConfig> Docs { get; set; } = new();

        
        public string? ColCss { get; set; }

        public string GetResolvedColCss()
        {
            var raw = (ColCss ?? "").Trim();
            if (string.IsNullOrWhiteSpace(raw))
                return "col-span-12";

            var tokens = Regex.Split(raw, @"\s+").Where(t => !string.IsNullOrWhiteSpace(t)).ToList();
            return string.Join(" ", tokens.Distinct());
        }
    }
}
