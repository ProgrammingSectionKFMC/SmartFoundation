using SmartFoundation.UI.ViewModels.SmartForm;
using System.Linq;
namespace SmartFoundation.UI.ViewModels.SmartTable
{

    public class TableBadgeConfig    {
        public Dictionary<string, string> Map { get; set; } = new();

        public string DefaultClass { get; set; } = "bg-gray-100 text-gray-700";
    }

    public class TableColumnFilter
    {
        public string Type { get; set; } = "text";
        public List<OptionItem> Options { get; set; } = new();
        public string? Placeholder { get; set; }
        public bool Enabled { get; set; } = true;
        public string? DefaultValue { get; set; }
    }

    public class TableGroupConfig
    {
        public string Field { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public bool Expanded { get; set; } = true;
        public bool ShowCount { get; set; } = true;
        public List<string> AggregateFields { get; set; } = new();
        public Dictionary<string, string> AggregateTypes { get; set; } = new();
    }

    //public class TableExportConfig
    //{
    //    //public bool EnableExcel { get; set; } = true;
    //    public bool EnableCsv { get; set; } = true;
    //    public bool EnablePdf { get; set; } = false;
    //    public bool EnablePrint { get; set; } = true;
    //    public string? ExcelTemplate { get; set; }
    //    public string? PdfTemplate { get; set; }
    //    public List<string> ExcludeColumns { get; set; } = new();
    //    public string? Filename { get; set; }


    //}

    public class TableExportConfig
    {
        public bool EnableCsv { get; set; } = true;
        public bool EnablePdf { get; set; } = false;
        public bool EnablePrint { get; set; } = true;

        public string? ExcelTemplate { get; set; }
        public string? PdfTemplate { get; set; }

        public List<string> ExcludeColumns { get; set; } = new();
        public string? Filename { get; set; }

        // NEW: endpoint + defaults
        public string? PdfEndpoint { get; set; } = "/exports/pdf/table";
        public string? PdfTitle { get; set; }
        public string? PdfLogoUrl { get; set; }
        public string? PdfPaper { get; set; } = "A4";
        public string? PdfOrientation { get; set; } = "portrait"; // portrait | landscape
        public bool PdfShowPageNumbers { get; set; } = true;
        public bool PdfShowGeneratedAt { get; set; } = true; // يعرض تاريخ التوليد في الهيدر 
        public bool PdfShowSerial { get; set; } = false; // تفعيل أو تعطيل الرقم التسلسلي
        public string PdfSerialLabel { get; set; } = "#";
        
        public string? RightHeaderLine1 { get; set; } // المملكة العربية السعودية
        public string? RightHeaderLine2 { get; set; } 
        public string? RightHeaderLine3 { get; set; } 
        public string? RightHeaderLine4 { get; set; } 
        public string? RightHeaderLine5 { get; set; } 
    }




    public class TableStyleRule
    {
        
        // "row" = صف كامل
        // "cell" = خلية واحدة (حسب Field)
        // "column" = عمود كامل (حسب Field)
        public string Target { get; set; } = "cell";

        // اسم الحقل (مطلوب للـ cell/column، وممكن للـ row)
        public string? Field { get; set; }

        // نوع المقارنة: eq, neq, gt, gte, lt, lte, contains, startswith, endswith, in
        public string Op { get; set; } = "eq";
        // "eq"    يساوي
        //"neq"   لا يساوي
        //"gt"    أكبر من (أرقام)
        //"lt"    أصغر من
        //"gte"   أكبر أو يساوي
        //"lte"   أصغر أو يساوي
        //"contains"  يحتوي نص

        // القيمة المراد مقارنتها (نخليها object عشان تدعم نص/رقم/بول)
        public object? Value { get; set; }

        // CSS class تُطبق عند تحقق الشرط
        public string CssClass { get; set; } = "";

        // (اختياري) ترتيب التنفيذ: الأقل أولاً
        public int Priority { get; set; } = 0;

        // (اختياري) إذا true: أول Rule ينطبق يوقف
        public bool StopOnMatch { get; set; } = false;


        // ✅ NEW: Pill / Badge
        public bool PillEnabled { get; set; } = false;

        // بأي عمود تنعرض الكبسولة؟ (إذا null -> نفس Field)
        public string? PillField { get; set; }

        // نص ثابت للكبسولة (اختياري)
        public string? PillText { get; set; }

        // أو جيب النص من حقل في الـ row (اختياري)
        public string? PillTextField { get; set; }

        // كلاس CSS للكبسولة (مثلاً: pill-green)
        public string? PillCssClass { get; set; }

        // طريقة العرض: append | prepend | replace
        public string PillMode { get; set; } = "replace";
    }



    public class TableColumn
    {
        public string Field { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public bool Sortable { get; set; } = true;
        public bool Visible { get; set; } = true;
        public bool Resizable { get; set; } = true;
        public bool Reorderable { get; set; } = true;
        public string? Width { get; set; }
        public string? MinWidth { get; set; } = "80px";
        public string? MaxWidth { get; set; }
        public string? Align { get; set; } = "right";
        public string? Type { get; set; } = "text";
        public string? FormatString { get; set; }
        public string? FormatterJs { get; set; }
        public bool ShowInModal { get; set; } = true;
        
        public bool ShowInExport { get; set; } = true;
        public bool Frozen { get; set; } = false;
        public string? FrozenSide { get; set; } = "left";
        public TableBadgeConfig? Badge { get; set; }
        public TableColumnFilter? Filter { get; set; }
        public bool Aggregatable { get; set; } = false;
        public string? AggregateType { get; set; }
        public string? LinkTemplate { get; set; }
        public string? ImageTemplate { get; set; }
        public bool truncate { get; set; } = false; 
        

        public Dictionary<string, object> CustomProperties { get; set; } = new();
    }

    public enum TableActionPlacement
    {
        Button,       // زر مباشر في التولبار (الافتراضي)
        ActionsMenu   // داخل قائمة "الإجراءات"
    }

    public class TableAction
    {

        //public string TabelLabel { get; set; } = "";

        //public bool ShowToolbar { get; set; } = true;
        public string Label { get; set; } = "";
        public string Icon { get; set; } = "";
        public string Color { get; set; } = "secondary";

        public TableActionPlacement Placement { get; set; } = TableActionPlacement.Button;

        public string? OnClickJs { get; set; }

        public string? OnBeforeOpenJs { get; set; }
        public Dictionary<string, object?>? Meta { get; set; }

        public bool Show { get; set; } = true;
        public bool OpenModal { get; set; } = false;
        public string? ModalSp { get; set; }
        public string? ModalOp { get; set; } = "detail";
        public string? ModalTitle { get; set; }

        public string? ModalMessage { get; set; }
        // NEW: تخصيص رسالة المودال
        public string? ModalMessageClass { get; set; }     // Tailwind/Bootstrap classes
        public string? ModalMessageIcon { get; set; }      // FontAwesome class
        public bool ModalMessageIsHtml { get; set; } = false; // افتراضي نص (آمن)
        public List<TableColumn>? ModalColumns { get; set; }
        public string? ConfirmText { get; set; }
        public bool IsEdit { get; set; } = false;
        public string? SaveSp { get; set; }
        public string? SaveOp { get; set; } = "update";
        public FormConfig? OpenForm { get; set; }
        public string? FormUrl { get; set; }
        public bool RequireSelection { get; set; } = false;
        public int MinSelection { get; set; } = 0;
        public int MaxSelection { get; set; } = 0;
        public string? Tooltip { get; set; }
        public string? KeyboardShortcut { get; set; }
        public List<string> Roles { get; set; } = new();
        public string? Condition { get; set; }
        public TableActionGuards? Guards { get; set; }

    }

    public class TableToolbarConfig
    {
        public bool ShowAdd { get; set; } = false;
        public bool ShowAdd1 { get; set; } = false;
        public bool ShowAdd2 { get; set; } = false;
        public bool ShowRefresh { get; set; } = true;
        public bool ShowColumns { get; set; } = true;
        public bool ShowExportCsv { get; set; } = true;
        public bool ShowExportExcel { get; set; } = true;
        public bool ShowExportPdf { get; set; } = false;
        public bool ShowPrint { get; set; } = true;
        public bool ShowPrint1 { get; set; } = true;
        public bool ShowPrint2 { get; set; } = true;
        public bool ShowPrint3 { get; set; } = true;
        public bool ShowAdvancedFilter { get; set; } = false;
        public bool ShowBulkDelete { get; set; } = false;
        public bool ShowFullscreen { get; set; } = true;
        public bool ShowDensityToggle { get; set; } = true;
        public bool ShowThemeToggle { get; set; } = false;

        public TableAction? Add { get; set; }
        public TableAction? Add1 { get; set; }
        public TableAction? Add2 { get; set; }
        public bool ShowEdit { get; set; } = false;
        public bool ShowEdit1 { get; set; } = false;
        public bool ShowEdit2 { get; set; } = false;
        public bool ShowDelete { get; set; } = false;
        public bool ShowDelete1 { get; set; } = false;
        public bool ShowDelete2 { get; set; } = false;
        public TableAction? Edit { get; set; }
        public TableAction? Edit1 { get; set; }
        public TableAction? Edit2 { get; set; }
        public TableAction? Delete { get; set; }
        public TableAction? Delete1 { get; set; }
        public TableAction? Delete2 { get; set; }
        public List<TableAction> CustomActions { get; set; } = new();
        public TableExportConfig ExportConfig { get; set; } = new();
        public bool ShowSearch { get; set; } = true;
        public string? SearchPosition { get; set; } = "left";
        public TableAction? Print { get; set; }
        public TableAction? Print1 { get; set; }
        public TableAction? Print2 { get; set; }
        public TableAction? Print3 { get; set; }

    }

    public class TableConfig
    {
        public string? Endpoint { get; set; }
        public string StoredProcedureName { get; set; } = "";
        public string Operation { get; set; } = "select";
        public int PageSize { get; set; } = 10;
        public List<int> PageSizes { get; set; } = new() { 10, 25, 50, 100 };
        public int MaxPageSize { get; set; } = 1000;
        public bool ShowHeader { get; set; } = true;
        public bool ShowFooter { get; set; } = true;
        public bool Searchable { get; set; } = false;
        public string? SearchPlaceholder { get; set; } = "بحث…";
        public List<string>? QuickSearchFields { get; set; }
        public bool AllowExport { get; set; } = false;
        public bool AutoRefreshOnSubmit { get; set; } = true;
        public List<TableColumn> Columns { get; set; } = new();
        public List<TableAction> RowActions { get; set; } = new();
        public bool Selectable { get; set; } = false;
        public string? RowIdField { get; set; } = "Id";
        public string? GroupBy { get; set; }
        public string? StorageKey { get; set; }
        public TableToolbarConfig Toolbar { get; set; } = new();
        public bool ClientSideMode { get; set; } = false;
        public bool VirtualScrolling { get; set; } = false;
        public bool ResponsiveMode { get; set; } = true;
        public string? ResponsiveBreakpoint { get; set; } = "md";
        public bool ShowRowNumbers { get; set; } = false;
        public bool ShowRowBorders { get; set; } = true;
        public bool HoverHighlight { get; set; } = true;
        public bool StripedRows { get; set; } = false;
        public string? Density { get; set; } = "normal";
        public string? Theme { get; set; } = "light";
        public bool InlineEditing { get; set; } = false;
        public bool AutoSave { get; set; } = false;
        public int AutoSaveDelay { get; set; } = 2000;
        public TableGroupConfig? GroupConfig { get; set; }
        public bool EnableKeyboardNavigation { get; set; } = true;
        public bool EnableContextMenu { get; set; } = false;
        public Dictionary<string, object> CustomSettings { get; set; } = new();
        public bool LazyLoading { get; set; } = false;
        public int CacheTimeout { get; set; } = 300;
        public bool DebounceSearch { get; set; } = true;
        public int SearchDebounceDelay { get; set; } = 500;
        public bool EnableScreenReader { get; set; } = true;
        public string? AriaLabel { get; set; }
        public bool HighContrast { get; set; } = false;
        public string? Autocomplete { get; set; }


        //public bool ShowPageSizeSelector { get; set; } = true;
        public List<TableStyleRule> StyleRules { get; set; } = new();

    }

}


public class TableActionRule
{
    public string Field { get; set; } = "";
    public string Op { get; set; } = "eq";  // eq, neq, in, notin, contains, startswith, endswith
    public object? Value { get; set; }
    public string? Message { get; set; }
    public int Priority { get; set; } = 1;
}

public class TableActionGuards
{
    /// <summary>
    /// JavaScript expression that evaluates to true/false based on selected row
    /// Example: "row.meterForBuildingCount == 0"
    /// </summary>
    public string? RowCondition { get; set; }
    
    /// <summary>
    /// Message to show if guard fails
    /// </summary>
    public string? Message { get; set; }
    
    // لو تحقق أي شرط هنا => يتعطل الأكشن
    public List<TableActionRule> DisableWhenAny { get; set; } = new();

    // اختياري: الأكشن يكون معطل إلا إذا تحقق شرط من هذه القائمة
    public List<TableActionRule> EnableWhenAny { get; set; } = new();

    // تطبيق الشرط على أي صف من المحدد أو على كل الصفوف
    public string AppliesTo { get; set; } = "any"; // any | all
}

