
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartAccordion;

namespace SmartFoundation.UI.ViewModels.SmartDrawer
{
    public enum SmartDrawerSide
    {
        Right,
        Left
    }

    public enum SmartDrawerSize
    {
        Small,
        Medium,
        Large,
        Full
    }

    public class SmartDrawerConfig
    {
        // General
        public string Id { get; set; } = "sf-drawer";
        public bool Show { get; set; } = true;

        // Header
        public string Title { get; set; } = "";
        public string? Subtitle { get; set; }
        public string? Icon { get; set; }

        // Appearance
        public SmartDrawerSide Side { get; set; }
            = SmartDrawerSide.Right;

        public SmartDrawerSize Size { get; set; }
            = SmartDrawerSize.Large;

        // Behavior
        public bool ShowBackdrop { get; set; } = true;
        public bool ShowCloseButton { get; set; } = true;
        public bool CloseOnEscape { get; set; } = true;
        public bool CloseOnBackdropClick { get; set; } = true;
        public bool LockBodyScroll { get; set; } = true;

        // Optional reusable content
        public SmartTableDsModel? Table { get; set; }
        public FormConfig? Form { get; set; }

        // Empty state
        public string EmptyText { get; set; }
            = "لا توجد بيانات للعرض";

        public SmartAccordionConfig? Accordion { get; set; }
    }
}
