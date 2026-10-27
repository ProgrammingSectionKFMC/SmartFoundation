using SmartFoundation.UI.ViewModels.SmartDrawer;
using SmartFoundation.UI.ViewModels.SmartForm;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;

namespace SmartFoundation.UI.ViewModels.SmartTable
{
    public enum TableViewMode
    {
        Table,
        Profile,
    }

    public enum SmartTableRenderMode
    {
        Plain,
        Toggle,
        Section,
        Tab
    }

    public enum SmartTableHeaderMode
    {
        Simple,
        Smart
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
        public string? TabelLabelIcon { get; set; }

        public bool ShowToolbar { get; set; } = true;

        // ===== إعدادات عامة للجدول =====
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
        public string? Autocomplete { get; set; }

        public bool EnableCellCopy { get; set; } = true;

        // ===== طريقة عرض البيانات داخل الجدول =====
        public TableViewMode ViewMode { get; set; } = TableViewMode.Table;

        // ===== إعدادات Profile =====
        public string? ProfileTitleField { get; set; }
        public string? ProfileSubtitleField { get; set; }
        public List<string> ProfileFields { get; set; } = new();
        public string? ProfileCssClass { get; set; }
        public int ProfileColumns { get; set; } = 2;
        public bool ProfileShowHeader { get; set; } = true;
        public string? ProfileIcon { get; set; } = "fa-solid fa-id-card";
        public string? ProfileTitleText { get; set; }
        public List<object> ProfileMetaFields { get; set; } = new();

        // ===== Render Modes =====
        public SmartTableRenderMode RenderMode { get; set; } = SmartTableRenderMode.Plain;

        // ===== Toggle Mode =====
        public bool RenderAsToggle { get; set; } = false;
        public string ToggleLabel { get; set; } = "عرض";
        public string? ToggleIcon { get; set; } = "fa-solid fa-table";
        public bool ToggleDefaultOpen { get; set; } = false;
        public bool ShowToggleCount { get; set; } = false;
        public int ToggleCount => Rows?.Count() ?? 0;

        // ===== Section Mode =====
        public bool RenderAsSection { get; set; } = false;
        public string SectionLabel { get; set; } = "القسم";
        public string? SectionIcon { get; set; } = "fa-solid fa-table-list";
        public string? SectionDescription { get; set; }
        public bool SectionDefaultOpen { get; set; } = true;
        public bool ShowSectionCount { get; set; } = true;
        public int SectionCount => Rows?.Count() ?? 0;
        public int SectionOrder { get; set; }
        public string? SectionAccent { get; set; }

        // ===== Tab Mode =====
        public bool RenderAsTab { get; set; } = false;
        public string TabGroupKey { get; set; } = "default";
        public string TabKey { get; set; } = "";
        public string TabLabel { get; set; } = "جدول";
        public string? TabIcon { get; set; } = "fa-solid fa-table";
        public string? TabDescription { get; set; }
        public bool TabDefaultActive { get; set; } = false;
        public bool ShowTabCount { get; set; } = true;
        public int TabCount => Rows?.Count() ?? 0;
        public int TabOrder { get; set; }

        // ===== Filters =====
        public bool ShowFilter { get; set; } = false;
        public bool ShowAdvancedFilter { get; set; } = false;
        public bool FilterRow { get; set; } = true;
        public int FilterDebounce { get; set; } = 250;

        public bool ShowColumnVisibility { get; set; } = false;

        public bool EnableColumnReorder { get; set; } = true;

        // ===== Header UX =====
        public SmartTableHeaderMode HeaderMode { get; set; } = SmartTableHeaderMode.Smart;
        public bool EnableColumnHeaderMenu { get; set; } = true;

        // ===== Header Color =====
        public string? HeaderColor { get; set; }

        public List<ProfileBadge> ProfileBadges { get; set; } = new();
        public List<TableStyleRule> StyleRules { get; set; } = new();
    }

    public class ProfileBadge
    {
        public string Field { get; set; } = "";
        public string Label { get; set; } = "";
    }

    public class TableBadgeConfig
    {
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

    public class TableExportConfig
    {
        public bool EnableCsv { get; set; } = true;
        public bool EnablePdf { get; set; } = false;
        public bool EnablePrint { get; set; } = true;

        public string? ExcelTemplate { get; set; }
        public string? PdfTemplate { get; set; }

        public List<string> ExcludeColumns { get; set; } = new();
        public string? Filename { get; set; }

        public string? PdfEndpoint { get; set; } = "/exports/pdf/table";
        public string? PdfTitle { get; set; }
        public string? PdfLogoUrl { get; set; }
        public string? PdfPaper { get; set; } = "A4";
        public string? PdfOrientation { get; set; } = "portrait";
        public bool PdfShowPageNumbers { get; set; } = true;
        public bool PdfShowGeneratedAt { get; set; } = true;
        public bool PdfShowSerial { get; set; } = false;
        public string PdfSerialLabel { get; set; } = "#";

        public string? RightHeaderLine1 { get; set; }
        public string? RightHeaderLine2 { get; set; }
        public string? RightHeaderLine3 { get; set; }
        public string? RightHeaderLine4 { get; set; }
        public string? RightHeaderLine5 { get; set; }
    }

    public class TableStyleRule
    {
        public string Target { get; set; } = "cell";
        public string? Field { get; set; }
        public string? ConditionField { get; set; }
        public string Op { get; set; } = "eq";
        public object? Value { get; set; }
        public string CssClass { get; set; } = "";
        public int Priority { get; set; }
        public bool StopOnMatch { get; set; } = false;
        public bool PillEnabled { get; set; } = false;
        public string? PillField { get; set; }
        public string? PillText { get; set; }
        public string? PillTextField { get; set; }
        public string? PillCssClass { get; set; }
        public string? PillIcon { get; set; }
        public string PillMode { get; set; } = "replace";
        public bool IconOnly { get; set; } = false;
        public string? IconOnlyCssClass { get; set; }
        public string? PillSvg { get; set; }
        public string? PillTitle { get; set; }
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
        Button,
        ActionsMenu,
        RowEnd,
        RowEndMenu
    }

    public class TableAction
    {
        public string Label { get; set; } = "";
        public string Icon { get; set; } = "";
        public string Color { get; set; } = "secondary";
        public TableActionPlacement Placement { get; set; } = TableActionPlacement.Button;
        public string? OnClickJs { get; set; }
        public string? OnBeforeOpenJs { get; set; }
        public Dictionary<string, object?>? Meta { get; set; }
        public Dictionary<string, object?>? Meta1 { get; set; }
        public Dictionary<string, object?>? Meta2 { get; set; }
        public Dictionary<string, object?>? Meta3 { get; set; }
        public Dictionary<string, object?>? Meta4 { get; set; }


        public bool Show { get; set; } = true;

        // Existing Modal - unchanged
        public bool OpenModal { get; set; } = false;

        // SmartDrawer - optional
        public bool OpenDrawer { get; set; } = false;
        public string? DrawerId { get; set; }

        public Dictionary<string, string> DrawerParamMap { get; set; } = new();

        // SmartDrawer - Dynamic header
        public string? DrawerTitleTemplate { get; set; }
        public string? DrawerSubtitleTemplate { get; set; }



        


        // Existing Modal settings
        public string? ModalSp { get; set; }

        public string? ModalOp { get; set; } = "detail";
        public string? ModalTitle { get; set; }
        public string? ModalMessage { get; set; }
        public string? ModalMessageClass { get; set; }
        public string? ModalMessageIcon { get; set; }
        public bool ModalMessageIsHtml { get; set; } = false;
        public List<TableColumn>? ModalColumns { get; set; }
        public string? ConfirmText { get; set; }
        public bool IsEdit { get; set; } = false;
        public string? SaveSp { get; set; }
        public string? SaveOp { get; set; } = "update";
        public FormConfig? OpenForm { get; set; }
        public string? FormUrl { get; set; }
        public bool RequireSelection { get; set; } = false;
        public int MinSelection { get; set; }
        public int MaxSelection { get; set; }
        public string? Tooltip { get; set; }
        public string? KeyboardShortcut { get; set; }
        public List<string> Roles { get; set; } = new();
        public string? Condition { get; set; }
        public TableActionGuards? Guards { get; set; }
        public bool OpenAccordionModal { get; set; } = false;
        public string? AccordionId { get; set; }


    }

    public class TableToolbarConfig
    {
        public bool ShowAdd { get; set; } = false;
        public bool ShowAdd1 { get; set; } = false;
        public bool ShowAdd2 { get; set; } = false;
        public bool EnableAdd { get; set; } = true;
        public bool EnableAdd1 { get; set; } = true;
        public bool EnableAdd2 { get; set; } = true;
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
        public bool EnableEdit { get; set; } = true;
        public bool EnableEdit1 { get; set; } = true;
        public bool EnableEdit2 { get; set; } = true;
        public bool EnableDelete { get; set; } = true;
        public bool EnableDelete1 { get; set; } = true;
        public bool EnableDelete2 { get; set; } = true;
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


        [JsonIgnore]
        public List<SmartDrawerConfig> Drawers { get; set; } = new();

    }

    public class TableActionRule
    {
        public string Field { get; set; } = "";
        public string Op { get; set; } = "eq";
        public object? Value { get; set; }
        public string? Message { get; set; }
        public int Priority { get; set; } = 1;
    }

    public class TableActionGuards
    {
        public string? RowCondition { get; set; }
        public string? Message { get; set; }
        public List<TableActionRule> DisableWhenAny { get; set; } = new();
        public List<TableActionRule> EnableWhenAny { get; set; } = new();
        public string AppliesTo { get; set; } = "any";
    }
}
