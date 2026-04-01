using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        public async Task<IActionResult> MaintenanceDetails(int? maintOrdID = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = string.IsNullOrWhiteSpace(PageName)
                ? "MaintenanceDetails_List"
                : PageName;

            if (!maintOrdID.HasValue || maintOrdID.Value <= 0)
            {
                TempData["Error"] = "رقم أمر الصيانة مطلوب";
                return RedirectToAction("MaintenanceOrders", "Vehicle");
            }

            var spParameters = new object?[]
            {
                "MaintenanceDetails_List",
                IdaraId,
                usersId,
                HostName,
                maintOrdID.Value
            };

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            List<OptionItem> detailsTypeOptions = new();
            List<OptionItem> checkStatusOptions = new();

            // DDL: بنود الصيانة
            var result = await _CrudController.GetDDLValues(
                "typesName_A",
                "typesID",
                "179",
                "TypesRoot_List",
                usersId,
                IdaraId,
                HostName
            ) as JsonResult;

            if (result?.Value != null)
            {
                var json = JsonSerializer.Serialize(result.Value);
                detailsTypeOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new();
            }

            // DDL: حالة الإنجاز
            result = await _CrudController.GetDDLValues(
                "typesName_A",
                "typesID",
                "196",
                "TypesRoot_List",
                usersId,
                IdaraId,
                HostName
            ) as JsonResult;

            if (result?.Value != null)
            {
                var json = JsonSerializer.Serialize(result.Value);
                checkStatusOptions = JsonSerializer.Deserialize<List<OptionItem>>(json) ?? new();
            }

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);
            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "لا تملك صلاحية الوصول";
                return RedirectToAction("Index", "Home");
            }

            bool canInsert = false, canUpdate = false, canDelete = false;
            bool isOrderOpen = true;
            string rowIdField = "MaintDetailesID";

            foreach (DataRow row in permissionTable.Rows)
            {
                var p = row["permissionTypeName_E"]?.ToString()?.ToUpper();
                if (p == "INSERT") canInsert = true;
                if (p == "UPDATE") canUpdate = true;
                if (p == "DELETE") canDelete = true;
            }

            // حالة أمر الصيانة
            var orderDs = await _mastersServies.GetDataLoadDataSetAsync(new object?[]
            {
                "MaintenanceOrder_Get",
                IdaraId,
                usersId,
                HostName,
                maintOrdID.Value
            });

            if (orderDs.Tables.Count > 1 && orderDs.Tables[1].Rows.Count > 0)
            {
                var active = orderDs.Tables[1].Rows[0]["MaintOrdActive"]?.ToString();
                isOrderOpen = active == "1";
            }

            var dataTable = dt2 ?? dt3 ?? dt1;

            if (dataTable != null)
            {
                dynamicColumns.Add(new TableColumn { Field = "typesName_A", Label = "اسم البند", Type = "text", Visible = true });
                dynamicColumns.Add(new TableColumn { Field = "CheckStatusName_A", Label = "الحالة", Type = "text", Visible = true });
                dynamicColumns.Add(new TableColumn { Field = "ActionState", Label = "الإجراء", Type = "text", Visible = true });
                dynamicColumns.Add(new TableColumn { Field = "CorrectiveAction", Label = "الإجراء التصحيحي", Type = "text", Visible = true });
                dynamicColumns.Add(new TableColumn { Field = "CurrentDate", Label = "التاريخ", Type = "date", Visible = true });
                dynamicColumns.Add(new TableColumn { Field = "Notes", Label = "ملاحظات", Type = "text", Visible = true });

                foreach (DataRow r in dataTable.Rows)
                {
                    var dict = new Dictionary<string, object?>();

                    foreach (DataColumn c in dataTable.Columns)
                        dict[c.ColumnName] = r[c] == DBNull.Value ? null : r[c];

                    var typeId = dict["typesID_FK"]?.ToString();
                    var statusId = dict["CheckStatus_FK"]?.ToString();

                    dict["typesName_A"] = detailsTypeOptions.FirstOrDefault(x => x.Value == typeId)?.Text ?? typeId;
                    dict["CheckStatusName_A"] = checkStatusOptions.FirstOrDefault(x => x.Value == statusId)?.Text ?? statusId;

                    dict["p01"] = dict["MaintDetailesID"];
                    dict["p02"] = dict["MaintOrdID_FK"];
                    dict["p03"] = dict["typesID_FK"];
                    dict["p04"] = null;
                    dict["p05"] = dict["CheckStatus_FK"];
                    dict["p06"] = dict["ActionState"];
                    dict["p07"] = dict["CorrectiveAction"];
                    dict["p08"] = dict["FSN"];
                    dict["p09"] = dict["MaintLevel"];
                    dict["p10"] = dict["CurrentDate"];
                    dict["p11"] = dict["Notes"];

                    rowsList.Add(dict);
                }
            }

            var currentUrl = Request.Path + Request.QueryString;

            var insertFields = new List<FieldConfig>
            {
                new FieldConfig { Name="pageName_", Type="hidden", Value="MaintenanceDetails_Upsert" },
                new FieldConfig { Name="ActionType", Type="hidden", Value="INSERT" },
                new FieldConfig { Name="idaraID", Type="hidden", Value=IdaraId },
                new FieldConfig { Name="entrydata", Type="hidden", Value=usersId },
                new FieldConfig { Name="hostname", Type="hidden", Value=HostName },
                new FieldConfig { Name="redirectUrl", Type="hidden", Value=currentUrl },
                new FieldConfig { Name="redirectAction", Type="hidden", Value="MaintenanceDetails" },
                new FieldConfig { Name="redirectController", Type="hidden", Value="Vehicle" },

                new FieldConfig { Name="p01", Type="hidden", Value=maintOrdID.Value.ToString() },

                new FieldConfig { Name="p02", Label="بند", Type="select", Options=detailsTypeOptions, Required=true },
                new FieldConfig { Name="p04", Label="الحالة", Type="select", Options=checkStatusOptions, Required=true },
                new FieldConfig { Name="p05", Label="الإجراء", Type="text" },
                new FieldConfig { Name="p06", Label="الإجراء التصحيحي", Type="textarea" },
                new FieldConfig { Name="p07", Label="FSN", Type="text" },
                new FieldConfig { Name="p08", Label="المستوى", Type="text" },
                new FieldConfig { Name="p09", Label="التاريخ", Type="date" },
                new FieldConfig { Name="p10", Label="ملاحظات", Type="textarea" }
            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "بنود الصيانة",
                PanelTitle = $"بنود أمر #{maintOrdID}",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                ShowToolbar = true,
                Toolbar = new TableToolbarConfig
                {
                    ShowAdd = canInsert && isOrderOpen,
                    ShowEdit = canUpdate && isOrderOpen,
                    ShowDelete = canDelete && isOrderOpen,
                    Add = new TableAction
                    {
                        Label = "إضافة",
                        OpenModal = true,
                        OpenForm = new FormConfig
                        {
                            FormId = "InsertForm",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = insertFields
                        }
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa fa-list-check",
                TableDS = dsModel
            };

            ViewBag.IsOrderOpen = isOrderOpen;

            return View("Vehicle/MaintenanceDetails", page);
        }
    }
}