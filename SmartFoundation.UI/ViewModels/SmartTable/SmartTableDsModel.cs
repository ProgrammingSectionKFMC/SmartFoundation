using System.Collections.Generic;
using SmartFoundation.UI.ViewModels.SmartForm;
using System.Linq;

namespace SmartFoundation.UI.ViewModels.SmartTable
{


    public enum TableViewMode
    {
        Table,
        Profile,
        
    }

    public class SmartTableDsModel
    {
        public string? PageTitle { get; set; } = "النظام الموحد";
        public string? PanelTitle { get; set; } = "";
        // ===== بيانات الجدول من الـ DataSet =====
        public List<TableColumn> Columns { get; set; } = new();
        public List<Dictionary<string, object?>> Rows { get; set; } = new();
        public string RowIdField { get; set; } = "Id";

        public string TabelLabel { get; set; } = "";
        public string? TabelLabelIcon { get; set; } = null;

        public bool ShowToolbar { get; set; } = true;

        // ===== إعدادات عامة (من TableConfig) =====
        public string? Endpoint { get; set; }
        public string StoredProcedureName { get; set; } = "";
        public string Operation { get; set; } = "select";

        public int PageSize { get; set; } = 10;
        public List<int> PageSizes { get; set; } = new() { 10, 25, 50, 100 };
        public int MaxPageSize { get; set; } = 1000;

        public bool ShowHeader { get; set; } = true;
        public bool ShowFooter { get; set; } = true;

        public bool EnablePagination { get; set; } = true;

        public bool ShowPageSizeSelector { get; set; } = true;

        public bool Searchable { get; set; } = true;
        public string? SearchPlaceholder { get; set; } = "بحث…";
        public List<string>? QuickSearchFields { get; set; } = new();

        public bool AllowExport { get; set; } = true;
        public bool AutoRefreshOnSubmit { get; set; } = true;

        public List<TableAction> RowActions { get; set; } = new();

        public bool Selectable { get; set; } = true;
        public string? GroupBy { get; set; }
        public string? StorageKey { get; set; }

        public TableToolbarConfig Toolbar { get; set; } = new();

        public bool ClientSideMode { get; set; } = false;
        public bool VirtualScrolling { get; set; } = false;

        public TableActionPlacement Placement { get; set; } = TableActionPlacement.Button;
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

        public bool EnableCellCopy { get; set; } = true;

        //  طريقة العرض (Table / Profile)
        //  
        public TableViewMode ViewMode { get; set; } = TableViewMode.Table;

        // إعدادات Profile
        public string? ProfileTitleField { get; set; } = null;
        public string? ProfileSubtitleField { get; set; } = null;
        public List<string> ProfileFields { get; set; } = new();
        public string? ProfileCssClass { get; set; } = null;
        public int ProfileColumns { get; set; } = 2;
        public bool ProfileShowHeader { get; set; } = true;
        public string? ProfileIcon { get; set; } = "fa-solid fa-id-card";
        public string? ProfileTitleText { get; set; } = null; // اختياري: عنوان ثابت فوق
        public List<object> ProfileMetaFields { get; set; } = new(); // chips أعلى البروفايل (اختياري)

        public bool RenderAsToggle { get; set; } = false;         // يفعّل وضع الزر
        public string ToggleLabel { get; set; } = "عرض";          // نص الزر
        public string? ToggleIcon { get; set; } = "fa-solid fa-table";
        public bool ToggleDefaultOpen { get; set; } = false;      // مفتوح افتراضياً؟

        public bool ShowToggleCount { get; set; } = false;   // عرض العداد؟

        public int ToggleCount => Rows?.Count() ?? 0;  // يحسب عدد الصفوف في الجدول ويظهر العداد في التوقل


        public bool ShowFilter { get; set; } = false;     // زر "فلترة" + صف الفلاتر
        public bool FilterRow { get; set; } = true;       // صف الفلاتر تحت الهيدر
        public int FilterDebounce { get; set; } = 250;    // تأخير الكتابة

        public List<ProfileBadge> ProfileBadges { get; set; } = new();

        public List<TableStyleRule> StyleRules { get; set; } = new();

    }

    public class ProfileBadge
    {
        public string Field { get; set; } = "";
        public string Label { get; set; } = "";
    }


}
