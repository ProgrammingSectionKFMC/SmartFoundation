using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> MonthlyBillingMonitor(int? year, int? month, long? idaraID)
        {
            if (!InitPageContext(out var redirectResult)) return redirectResult!;
            ControllerName = nameof(Housing);
            PageName = nameof(MonthlyBillingMonitor);
            var target = DateTime.Today.AddMonths(-1);
            year ??= target.Year;
            month ??= target.Month;

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
                { PageName, IdaraId, usersId, HostName, year, month, idaraID });
            SplitDataSet(ds);
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            bool canRetry = permissionTable.AsEnumerable().Any(r =>
                string.Equals(r["permissionTypeName_E"]?.ToString()?.Trim(), "RETRYMONTHLYBILLING", StringComparison.OrdinalIgnoreCase));

            static List<Dictionary<string, object?>> MapRows(DataTable? table, bool aliases = false)
            {
                var result = new List<Dictionary<string, object?>>();
                if (table is null) return result;
                foreach (DataRow row in table.Rows)
                {
                    var item = table.Columns.Cast<DataColumn>().ToDictionary(c => c.ColumnName,
                        c => row[c] == DBNull.Value ? null : row[c], StringComparer.OrdinalIgnoreCase);
                    if (aliases)
                    {
                        item["p01"] = item.GetValueOrDefault("MonthlyBillingRunID");
                        item["p02"] = item.GetValueOrDefault("PeriodYear");
                        item["p03"] = item.GetValueOrDefault("PeriodMonth");
                        item["p04"] = item.GetValueOrDefault("IdaraID_FK");
                    }
                    result.Add(item);
                }
                return result;
            }

            static List<TableColumn> MapColumns(DataTable? table, Dictionary<string, string> labels, params string[] hidden)
            {
                if (table is null) return new();
                return table.Columns.Cast<DataColumn>().Select(c => new TableColumn
                {
                    Field = c.ColumnName,
                    Label = labels.GetValueOrDefault(c.ColumnName, c.ColumnName),
                    Type = c.DataType == typeof(DateTime) ? "date" : c.DataType == typeof(bool) ? "bool" :
                        c.DataType == typeof(decimal) || c.DataType == typeof(int) || c.DataType == typeof(long) ? "number" : "text",
                    Sortable = true,
                    Visible = !hidden.Contains(c.ColumnName, StringComparer.OrdinalIgnoreCase)
                }).ToList();
            }

            var runLabels = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["idaraLongName_A"]="الإدارة", ["BillingTypeName_A"]="نوع الرصد", ["meterServiceTypeName_A"]="الخدمة",
                ["CalculationMethodName_A"]="طريقة الحساب", ["RunStatusName_A"]="الحالة", ["ProposedCount"]="المقترح",
                ["CreatedCount"]="المرصود", ["ExistingCount"]="الموجود", ["SkippedCount"]="المتجاوز",
                ["FailedCount"]="الفاشل", ["AmountBeforeTax"]="قبل الضريبة", ["TaxAmount"]="الضريبة",
                ["TotalAmount"]="الإجمالي", ["AttemptCount"]="المحاولات", ["StartedAt"]="البداية",
                ["FinishedAt"]="النهاية", ["LastError"]="آخر خطأ"
            };
            var detailLabels = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["BillNumber"]="رقم الفاتورة", ["GeneralNo_FK"]="الرقم العام", ["buildingDetailsNo"]="رقم المنزل",
                ["meterNo"]="رقم العداد", ["FromDate"]="من", ["ToDate"]="إلى", ["ResultStatusName_A"]="النتيجة",
                ["ReasonMessage"]="السبب", ["AmountBeforeTax"]="قبل الضريبة", ["TaxAmount"]="الضريبة", ["TotalAmount"]="الإجمالي"
            };

            var retryFields = new List<FieldConfig>
            {
                new() { Name="redirectAction", Type="hidden", Value=PageName }, new() { Name="redirectController", Type="hidden", Value=ControllerName },
                new() { Name="pageName_", Type="hidden", Value=PageName }, new() { Name="ActionType", Type="hidden", Value="RETRYMONTHLYBILLING" },
                new() { Name="__RequestVerificationToken", Type="hidden" }, new() { Name="MonthlyBillingRunID", Type="hidden" },
                new() { Name="p01", Type="hidden", MirrorName="MonthlyBillingRunID" },
                new() { Name="p02", Label="السنة", Type="text", Readonly=true, ColCss="4" },
                new() { Name="p03", Label="الشهر", Type="text", Readonly=true, ColCss="4" }, new() { Name="p04", Type="hidden" }
            };

            var runsTable = new SmartTableDsModel
            {
                PageTitle="متابعة الرصد الشهري", PanelTitle="ملخص عمليات الرصد", Columns=MapColumns(dt1, runLabels,
                    "MonthlyBillingRunID","IdaraID_FK","PeriodYear","PeriodMonth","BillingType","MeterServiceTypeID_FK",
                    "CalculationMethod","RunStatus","entryData","hostName","entryDate","LastHeartbeatAt"),
                Rows=MapRows(dt1, true), RowIdField="MonthlyBillingRunID", PageSize=10, PageSizes=new(){10,25,50,100},
                QuickSearchFields=new(){"idaraLongName_A","BillingTypeName_A","meterServiceTypeName_A","RunStatusName_A"}, Searchable=true, AllowExport=true,
                Toolbar=new TableToolbarConfig
                {
                    ShowColumns=true, ShowRefresh=false, ShowAdd=false, ShowDelete=false, ShowEdit=canRetry,
                    Edit=new TableAction
                    {
                        Label="إعادة تشغيل النطاق", Icon="fa fa-rotate", Color="warning", IsEdit=true, OpenModal=true,
                        RequireSelection=true, MinSelection=1, MaxSelection=1, ModalTitle="إعادة تشغيل نطاق الرصد",
                        OpenForm=new FormConfig
                        {
                            FormId="monthlyBillingRetryForm", Title="تأكيد إعادة التشغيل", Method="post", ActionUrl="/crud/update", Fields=retryFields,
                            Buttons=new(){new(){Text="إعادة التشغيل",Type="submit",Color="warning"},new(){Text="إلغاء",Type="button",Color="secondary",OnClickJs="this.closest('.sf-modal').__x.$data.closeModal();"}}
                        }
                    }
                }
            };
            var detailsTable = new SmartTableDsModel
            {
                PageTitle="تفاصيل الرصد", PanelTitle="الفواتير والحالات المتجاوزة", Columns=MapColumns(dt2, detailLabels,
                    "MonthlyBillingRunDetailsID","MonthlyBillingRunID_FK","BillsID_FK","ResidentInfoID_FK","BuildingDetailsID_FK","MeterID_FK","ResultStatus","ReasonCode"),
                Rows=MapRows(dt2), RowIdField="MonthlyBillingRunDetailsID", PageSize=25, PageSizes=new(){25,50,100,250},
                QuickSearchFields=new(){"BillNumber","GeneralNo_FK","buildingDetailsNo","ReasonMessage"}, Searchable=true, AllowExport=true,
                Toolbar=new TableToolbarConfig{ShowColumns=true,ShowRefresh=false,ShowAdd=false,ShowEdit=false,ShowDelete=false}
            };

            var monthOptions = Enumerable.Range(1,12).Select(v => new OptionItem{Value=v.ToString(),Text=v.ToString()}).ToList();
            var idaraOptions = dt3?.AsEnumerable().Select(r => new OptionItem{Value=r["idaraID"].ToString()!,Text=r["idaraLongName_A"].ToString()!}).ToList() ?? new();
            idaraOptions.Insert(0,new OptionItem{Value="",Text="جميع الإدارات المتاحة"});
            var filter = new FormConfig
            {
                FormId="monthlyBillingMonitorFilter", Method="get", ActionUrl="/Housing/MonthlyBillingMonitor",
                Fields=new(){new(){Name="year",Label="السنة",Type="number",Value=year.ToString(),Required=true,ColCss="3"},
                    new(){Name="month",Label="الشهر",Type="select",Value=month.ToString(),Options=monthOptions,Required=true,ColCss="3"},
                    new(){Name="idaraID",Label="الإدارة",Type="select",Value=idaraID?.ToString(),Options=idaraOptions,ColCss="4",Select2=true}},
                Buttons=new(){new(){Text="عرض",Type="submit",Color="primary"}}
            };

            return View("HousingProcedures/MonthlyBillingMonitor", new SmartPageViewModel
            {
                PageTitle="متابعة الرصد الشهري", PanelTitle="متابعة الرصد الشهري", PanelIcon="fa-file-invoice-dollar",
                Form=filter, TableDS=runsTable, TableDS2=detailsTable
            });
        }
    }
}
