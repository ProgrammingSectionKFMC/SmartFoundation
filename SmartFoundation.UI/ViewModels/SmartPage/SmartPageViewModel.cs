using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartDatePicker;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartTable;
using SmartFoundation.UI.ViewModels.SmartPrint;

namespace SmartFoundation.UI.ViewModels.SmartPage
{
    public class SmartPageViewModel
    {
        public string? PageTitle { get; set; } = "Smart Demo";
        public string? PanelTitle { get; set; } = "Smart Demo";

        public string? PanelIcon { get; set; } //جديد

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
