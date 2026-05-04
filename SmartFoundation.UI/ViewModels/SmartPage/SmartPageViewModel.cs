using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartDatePicker;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartPrint;

namespace SmartFoundation.UI.ViewModels.SmartPage
{
    public class SmartPageAlert
    {
        public bool Visible { get; set; } = true;
        public string Tone { get; set; } = "info";
        public string? Title { get; set; }
        public string Message { get; set; } = "";
        public string? Icon { get; set; }
        public bool Dismissible { get; set; } = false;
        public int AutoDismissMs { get; set; } = 0;
    }

    public class SmartPagePanelBadge
    {
        public bool Visible { get; set; } = true;
        public string Label { get; set; } = "";
        public string? Value { get; set; }
        public string? Icon { get; set; }
        public string Tone { get; set; } = "default";
    }

    public class SmartPagePanelConfig
    {
        public bool Show { get; set; } = true;
        public bool ShowIcon { get; set; } = true;
        public bool ShowSubtitle { get; set; } = true;
        public bool ShowDescription { get; set; } = true;
        public bool ShowBadges { get; set; } = true;
        public string Layout { get; set; } = "hero";
        public string? Title { get; set; }
        public string? Subtitle { get; set; }
        public string? Description { get; set; }
        public string? Icon { get; set; }
        public List<SmartPagePanelBadge> Badges { get; set; } = new();
    }

    public class SmartPageViewModel
    {
        public string? PageTitle { get; set; } = "Smart Demo";
        public string? PanelTitle { get; set; } = "Smart Demo";

        public string? PanelIcon { get; set; } //جديد
        public SmartPagePanelConfig? Panel { get; set; }
        public List<SmartPageAlert> Alerts { get; set; } = new();

        public string SpName { get; set; } = "";
        public string Operation { get; set; } = "select";

        public FormConfig? Form { get; set; }
        public TableConfig? Table { get; set; }

        public SmartTableDsModel? TableDS { get; set; } 
        public SmartTableDsModel? TableDS1 { get; set; } 
        public SmartTableDsModel? TableDS2 { get; set; } 
        public SmartTableDsModel? TableDS3 { get; set; } 
        public SmartTableDsModel? TableDS4 { get; set; } 
        public SmartTableDsModel? TableDS5 { get; set; } 
        public DatepickerViewModel? DatePicker { get; set; }
        public SmartChartsConfig? Charts { get; set; }
        public SmartPrintConfig? Print { get; set; }



    }
}
