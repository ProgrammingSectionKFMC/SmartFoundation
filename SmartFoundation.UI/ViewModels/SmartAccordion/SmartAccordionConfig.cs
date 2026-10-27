using System.Collections.Generic;
using SmartFoundation.UI.ViewModels.SmartForm;

namespace SmartFoundation.UI.ViewModels.SmartAccordion
{
    // Reusable presentation component. Business rules, permissions, and financial writes
    // remain in the page controller and its SQL gateways.
    public sealed class SmartAccordionConfig
    {
        // Must be unique on the current HTML page (including drawers).
        public string Id { get; set; } = "sf-accordion";
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string EmptyText { get; set; } = "لا توجد سجلات للعرض";
        public string LoadingText { get; set; } = "جاري تحميل السجلات...";
        public bool AllowMultipleOpen { get; set; } = false;
        // Optional client-side tools. Default settings work for all pages.
        public bool Searchable { get; set; } = true;
        public string SearchPlaceholder { get; set; } = "بحث برقم العملية أو المستند أو المبلغ...";
        public bool EnableStatusFilter { get; set; } = true;
        public bool ShowSummary { get; set; } = true;
        public bool EnablePagination { get; set; } = true;
        public int PageSize { get; set; } = 5;
        public List<int> PageSizes { get; set; } = new() { 5, 10, 20 };

        // When true, render inside a native dialog (HTML top layer) instead of inline.
        // Generic table actions open it by accordion Id, without page-specific JS.
        public bool RenderInModal { get; set; } = false;
        public string? ModalTitle { get; set; }
        public List<SmartAccordionItem> Items { get; set; } = new();
        public SmartAccordionDataSource? DataSource { get; set; }
        // Optional actions are displayed per record. They emit sf-accordion:action,
        // but NEVER execute an update/delete on their own.
        public List<SmartAccordionAction> Actions { get; set; } = new();
    }

    public sealed class SmartAccordionItem
    {
        public string Id { get; set; } = "";
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? AmountText { get; set; }
        public string? StatusText { get; set; }
        public string StatusTone { get; set; } = "neutral";
        public bool InitiallyOpen { get; set; } = false;
        // Extra values for server-rendered action visibility conditions.
        public Dictionary<string, string> Values { get; set; } = new();
        public List<SmartAccordionField> Details { get; set; } = new();
    }

    public sealed class SmartAccordionField
    {
        public string Label { get; set; } = "";
        public string? Value { get; set; }
    }

    public sealed class SmartAccordionAction
    {
        // Application-defined action name, e.g. VIEW_REFUND.
        public string Key { get; set; } = "";
        public string Text { get; set; } = "";
        public string? Icon { get; set; }
        // Allowed: default, primary, danger.
        public string Tone { get; set; } = "default";
        // Optional equality condition for visible action buttons, presentation only.
        public string? VisibleWhenField { get; set; }
        public string? VisibleWhenEquals { get; set; }

        // Optional existing SmartForm rendered in the SAME accordion workspace.
        // No separate modal, API endpoint, or page-specific JavaScript.
        public FormConfig? OpenForm { get; set; }
        // SmartForm FIELD name -> selected accordion source-row FIELD name.
        // Example: { ["p22"] = "RefundID" }.
        public Dictionary<string, string> FormParamMap { get; set; } = new();
    }

    // Uses the existing /crud/extradataload gateway; server must enforce
    // user/session/department/page authorization and validate parameters.
    public sealed class SmartAccordionDataSource
    {
        public string Endpoint { get; set; } = "/crud/extradataload";
        public string PageName { get; set; } = "";
        public string ActionType { get; set; } = "";
        public int TableIndex { get; set; } = 0;
        // Request parameter names -> trusted drawer-context FIELD names.
        // Example: { ["parameter_01"] = "paymentID" }.
        public Dictionary<string, string> ParameterMap { get; set; } = new();
        // Optional fixed filters; never put trusted idaraID or permission here.
        public Dictionary<string, string> FixedParameters { get; set; } = new();
        public string IdField { get; set; } = "Id";
        public string TitleField { get; set; } = "Title";
        public string? SubtitleField { get; set; }
        public string? AmountField { get; set; }
        public string? StatusField { get; set; }
        public string? StatusToneField { get; set; }
        public List<SmartAccordionFieldMap> DetailFields { get; set; } = new();
        public bool LoadOnPageReady { get; set; } = false;
        public bool ReloadOnDrawerOpen { get; set; } = true;
    }

    public sealed class SmartAccordionFieldMap
    {
        public string Label { get; set; } = "";
        public string Field { get; set; } = "";
    }
}
