using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.MVC.Reports;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.ComponentModel;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text.Json;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> Assign([FromServices] RequestScopedDataLoadService requestDataLoad, int pdf = 0)
        {

            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
            {
                return RedirectToAction("Index", "Login", new { logout = 4 });
            }

            string? waitingClassID_ = Request.Query["U"].FirstOrDefault();

            waitingClassID_ = string.IsNullOrWhiteSpace(waitingClassID_) ? null : waitingClassID_.Trim();

            bool ready = false;

            ready = !string.IsNullOrWhiteSpace(waitingClassID_);




            // Sessions 

            ControllerName = nameof(Housing);
            PageName = nameof(Assign);

            var ddlParameters = new Dictionary<string, object?>(
                StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName ?? "FinancialAuditForExtendAndEvictions"
            };

            if (IdaraId != null)
                ddlParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                ddlParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                ddlParameters["hostname"] = HostName;

            // معاملات تحميل بيانات الصفحة.
            // تمرير المستفيد والمنزل المحددين معًا.
            var pageParameters = new Dictionary<string, object?>(
                ddlParameters,
                StringComparer.OrdinalIgnoreCase);

            if (ready)
            {
                pageParameters["parameter_01"] = waitingClassID_;
                
            }

            


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);



            SplitDataSet(ds);

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string? AssignPeriodID = null;  // تعريف المتغير هنا
            if (ready == true)
            {
            
                if (dt3 != null && dt3.Rows.Count > 0 && ready == true)
            {
                var value = dt3.Rows[0]["AssignPeriodID"];
                AssignPeriodID = dt3.Rows[0]["AssignPeriodID"].ToString();
                var AssignPeriodStartdate = dt3.Rows[0]["AssignPeriodStartdate"];
                var FullName = dt3.Rows[0]["FullName"];
                var waitingClassName_A = dt3.Rows[0]["waitingClassName_A"];

                TempData["AssignPeriodAvaliable"] = $"محضر التخصيص رقم {value} مخصص لـ {waitingClassName_A} منشئ بواسطة {FullName} نشط منذ {AssignPeriodStartdate} ";
            }
            else
            {
                if(dt3 != null && dt3.Rows.Count > 0)
                {
                    AssignPeriodID = dt3.Rows[0]["AssignPeriodID"].ToString();
                }
                else
                {
                    AssignPeriodID = "0";
                }
                TempData["NoAssignPeriod"] = $"لا يوجد محضر تخصيص نشط";
            }
            }

            bool AssignPeriodActive = false;

            if(ready == true && Convert.ToInt32(AssignPeriodID) > 0)
            {
                AssignPeriodActive = true; 
            }
            


            string rowIdField = "";
            bool canOPENASSIGNPERIOD = false;
            bool canCLOSEASSIGNPERIOD = false;
            bool canASSIGNHOUSE = false;
            bool canCANCLEASSIGNHOUSE = false;
            bool canUPDATEASSIGNHOUSE = false;




            List<OptionItem> WaitingListOptions = new();
            List<OptionItem> buildingDetailsNoOptions = new();




            FormConfig form = new();


            try
            {

                // ---------------------- DDLValues ----------------------




                DataSet ddlDs = await requestDataLoad
                   .GetDataLoadDataSetAsync(ddlParameters);

                static List<OptionItem> ReadOptions(
                    DataSet source,
                    int tableIndex,
                    string textColumn,
                    string valueColumn)
                {
                    if (tableIndex < 0 ||
                        tableIndex >= source.Tables.Count)
                    {
                        throw new InvalidOperationException(
                            $"DDL table index {tableIndex} not found.");
                    }

                    DataTable table = source.Tables[tableIndex];

                    if (!table.Columns.Contains(textColumn) ||
                        !table.Columns.Contains(valueColumn))
                    {
                        throw new InvalidOperationException(
                            $"DDL columns mismatch at table {tableIndex}.");
                    }

                    var options = new List<OptionItem>();

                    foreach (DataRow row in table.Rows)
                    {
                        string value = row[valueColumn]
                            ?.ToString()?.Trim() ?? "";

                        string text = row[textColumn]
                            ?.ToString()?.Trim() ?? "";

                        if (!string.IsNullOrEmpty(value))
                        {
                            options.Add(new OptionItem
                            {
                                Value = value,
                                Text = text
                            });
                        }
                    }

                    if (options.Count == 0)
                    {
                        options.Add(new OptionItem
                        {
                            Value = "-1",
                            Text = "لاتوجد خيارات"
                        });
                    }

                    return options;
                }

                WaitingListOptions = ReadOptions(
                ddlDs,
                2,
                "waitingClassName_A",
                "waitingClassID");

                buildingDetailsNoOptions = ReadOptions(
                    ddlDs,
                    4,
                    "buildingDetailsNo",
                    "buildingDetailsID");

                


                // ----------------------END DDLValues ----------------------


                // Determine which fields should be visible based on SearchID_

                form = new FormConfig
                            {
                                 Fields = new List<FieldConfig>
                                {

                                    new FieldConfig
                                    {
                                        SectionTitle = "اختيار فئة قائمة الانتظار",
                                        Name = "WaitingList",
                                        Type = "select",
                                        Select2 = true,
                                        Options = WaitingListOptions,
                                        ColCss = "3",
                                        Placeholder = "اختر فئة سجلات الانتظار",
                                        Icon = "fa fa-user",
                                        Value = waitingClassID_,
                                        OnChangeJs = "sfNav(this)",
                                        NavUrl = "/Housing/Assign",
                                        NavKey = "U",
                                    },
                                },

                    Buttons = new List<FormButtonConfig>
                    {
                        //           new FormButtonConfig
                        //  {
                        //      Text="بحث",
                        //      Icon="fa-solid fa-search",
                        //      Type="button",
                        //      Color="success",
                        //      // Replace the OnClickJs of the "تجربة" button with this:
                        //      OnClickJs = "(function(){"
                        //+ "var hidden=document.querySelector('input[name=Users]');"
                        //+ "if(!hidden){toastr.error('لا يوجد حقل مستخدم');return;}"
                        //+ "var userId = (hidden.value||'').trim();"
                        //+ "var anchor = hidden.parentElement.querySelector('.sf-select');"
                        //+ "var userName = anchor && anchor.querySelector('.truncate') ? anchor.querySelector('.truncate').textContent.trim() : '';"
                        //+ "if(!userId){toastr.info('اختر مستخدم أولاً');return;}"
                        //+ "var url = '/ControlPanel/Permission?Q1=' + encodeURIComponent(userId);"
                        //+ "window.location.href = url;"
                        //+ "})();"
                        //  },

                    }


                };

                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // اقرأ الجدول الأول


                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "ASSIGNHOUSE")
                            canASSIGNHOUSE = true;
                        if (permissionName == "OPENASSIGNPERIOD")
                            canOPENASSIGNPERIOD = true;
                        if (permissionName == "CLOSEASSIGNPERIOD")
                            canCLOSEASSIGNPERIOD = true;
                        if (permissionName == "CANCLEASSIGNHOUSE")
                            canCANCLEASSIGNHOUSE = true;
                        if (permissionName == "UPDATEASSIGNHOUSE")
                            canUPDATEASSIGNHOUSE = true;

                       
                    }


                    if (ds != null && ds.Tables.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "permissionID";
                        var possibleIdNames = new[] { "permissionID", "PermissionID", "Id", "ID" };

                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "رقم الاكشن",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ActionDecisionNo"] = "رقم الطلب",
                            ["ActionDecisionDate"] = "تاريخ الطلب",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["WaitingOrderTypeName"] = "نوع سجل الانتظار",
                            ["ActionNote"] = "ملاحظات",
                            ["FullName_A"] = "الاسم",
                            ["rankNameA"] = "الرتبة",
                            ["buildingActionTypeResidentAlias"] = "الحالة",
                            ["buildingDetailsNo"] = "رقم المنزل (إن وجد)",
                            ["WaitingListOrder"] = "الترتيب"
                        };


                        // build columns from DataTable schema
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = "text";
                            var t = c.DataType;
                            if (t == typeof(bool)) colType = "bool";
                            else if (t == typeof(DateTime)) colType = "date";
                            else if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                                     || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                                colType = "number";

                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingOrderTypeID = c.ColumnName.Equals("WaitingOrderTypeID", StringComparison.OrdinalIgnoreCase);
                            bool iswaitingClassSequence = c.ColumnName.Equals("waitingClassSequence", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID_FK = c.ColumnName.Equals("residentInfoID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignPeriodID = c.ColumnName.Equals("AssignPeriodID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingDetailsID = c.ColumnName.Equals("buildingDetailsID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            bool isAssignStatus = c.ColumnName.Equals("AssignStatus", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingActionTypeResidentAlias = c.ColumnName.Equals("buildingActionTypeResidentAlias", StringComparison.OrdinalIgnoreCase);
                            bool isAssignmentBlocked =c.ColumnName.Equals("IsAssignmentBlocked",StringComparison.OrdinalIgnoreCase);
                            bool isAssignmentBlockReason =c.ColumnName.Equals("AssignmentBlockReason",StringComparison.OrdinalIgnoreCase);


                            List<OptionItem> filterOpts = new();
                            if (isbuildingActionTypeResidentAlias)
                            {
                                var field = c.ColumnName;

                                var distinctVals = dt1.AsEnumerable()
                                    .Select(r => (r[field] == DBNull.Value ? "" : r[field]?.ToString())?.Trim())
                                    .Where(s => !string.IsNullOrWhiteSpace(s))
                                    .Distinct()
                                    .OrderBy(s => s)
                                    .ToList();

                                filterOpts = distinctVals
                                    .Select(s => new OptionItem { Value = s!, Text = s! })
                                    .ToList();
                            }


                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label)
                                    ? label
                                    : c.ColumnName,

                                Type = colType,
                                Sortable = true,

                                // Text wrapping
                                WrapText = isbuildingActionTypeResidentAlias,
                                Width = isbuildingActionTypeResidentAlias ? "450px" : null,
                                MinWidth = isbuildingActionTypeResidentAlias ? "450px" : "80px",
                                MaxWidth = isbuildingActionTypeResidentAlias ? "450px" : null,
                                truncate = false,

                                // Hidden columns
                                Visible = !(isActionID || isWaitingClassID ||
                                    isWaitingOrderTypeID || iswaitingClassSequence ||
                                    isresidentInfoID_FK || isIdaraId || isresidentInfoID ||
                                    isLastActionTypeID || isAssignPeriodID ||
                                    isbuildingDetailsID || isLastActionID ||
                                    isAssignStatus || isAssignmentBlocked ||
                                    isAssignmentBlockReason),

                                Filter = isbuildingActionTypeResidentAlias
                                    ? new TableColumnFilter
                                    {
                                        Enabled = true,
                                        Type = "select",
                                        Options = filterOpts
                                    }
                                    : new TableColumnFilter
                                    {
                                        Enabled = false
                                    }
                            });

                        }



                        // build rows (plain dictionaries) so JSON serialization is clean
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // Ensure the row id key actually exists with correct casing
                            if (!dict.ContainsKey(rowIdField))
                            {
                                // Try to copy from a differently cased variant
                                if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("permissionID", out var alt))
                                    dict["permissionID"] = alt;
                                else if (rowIdField.Equals("permissionID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("permissionID", out var alt2))
                                    dict["permissionID"] = alt2;
                            }

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ActionID") ?? Get("actionID");
                            dict["p02"] = Get("residentInfoID");
                            dict["p03"] = Get("NationalID");
                            dict["p04"] = Get("GeneralNo");
                            dict["p05"] = Get("ActionDecisionNo");
                            dict["p06"] = Get("ActionDecisionDate");
                            dict["p07"] = Get("WaitingClassID");
                            dict["p08"] = Get("WaitingClassName");
                            dict["p09"] = Get("WaitingOrderTypeID");
                            dict["p10"] = Get("WaitingOrderTypeName");
                            dict["p11"] = Get("waitingClassSequence");
                            dict["p12"] = Get("ActionNote");
                            dict["p13"] = Get("IdaraId");
                            dict["p14"] = Get("WaitingListOrder");
                            dict["p15"] = Get("FullName_A");
                            dict["p16"] = Get("LastActionTypeID");
                            dict["p17"] = Get("buildingActionTypeResidentAlias");
                            dict["p18"] = Get("buildingDetailsID");
                            dict["p19"] = Get("buildingDetailsNo");
                            dict["p20"] = Get("AssignPeriodID");
                            dict["p21"] = Get("LastActionID");


                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception)
            {
                ViewBag.DataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }

            //ADD

            var currentUrl = Request.Path + Request.QueryString;


            var OpenAssignPeriodFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "OPENASSIGNPERIOD" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
               
                new FieldConfig { Name = "p01", Label = "وصف محضر التخصيص", Type = "textarea", ColCss = "6", Required = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "6",Value =AssignPeriodID },
                new FieldConfig { Name = "p21", Label = "WaitingClassID_FK", Type = "hidden", ColCss = "6",Value =waitingClassID_ },


            };


            var CloseAssignPeriodFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "CLOSEASSIGNPERIOD" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
               
                new FieldConfig { Name = "p01", Label = "ملاحظات اغلاق محضر التخصيص", Type = "textarea", ColCss = "6", Required = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "6",Value =AssignPeriodID },
                new FieldConfig { Name = "p21", Label = "WaitingClassID_FK", Type = "hidden", ColCss = "6",Value =waitingClassID_ },

            };





            //Delete fields: show confirmation as a label(not textbox) and show ID as label while still posting p01
            var ASSIGNHOUSEFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "ASSIGNHOUSE" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "text", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                  new FieldConfig
                {
                    Name = "p18",
                    Label = "المبنى",
                    Type = "select",
                    Options = buildingDetailsNoOptions,
                    ColCss = "3",
                    Select2 = true,
                    Required = true,
                    MirrorName = "buildingDetailsID"  // إضافة هذا السطر
                },
                new FieldConfig { Name = "p32", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },




            };

            var UPDATEASSIGNHOUSEFields = new List<FieldConfig>
            {


                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEASSIGNHOUSE" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "text", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "text", ColCss = "3", Readonly = true,Icon = "fa fa-calendar" },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                  new FieldConfig
                {
                    Name = "p18",
                    Label = "المبنى",
                    Type = "select",
                    Options = buildingDetailsNoOptions,
                    ColCss = "3",
                    Select2 = true,
                    Required = true,
                    MirrorName = "buildingDetailsID"  // إضافة هذا السطر
                },
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "buildingDetailsNo", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },





            };

            var CancleASSIGNHOUSEFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "CANCLEASSIGNHOUSE" },

                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },


                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

              

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Label = "residentInfoID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p14", Label = "الترتيب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p15", Label = "الاسم", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p05", Label = "رقم الطلب", Type = "text", ColCss = "3", Readonly = true  },
                new FieldConfig { Name = "p06", Label = "تاريخ الطلب", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p07", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p08", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p19", Label = "المبنى", Type = "text", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p09", Label = "WaitingOrderTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p10", Label = "نوع سجل الانتظار", Type = "hidden", ColCss = "3", Readonly = true },
                //  new FieldConfig
                //{
                //    Name = "p18",
                //    Label = "المبنى",
                //    Type = "select",
                //    Options = buildingDetailsNoOptions,
                //    ColCss = "3",
                //    Select2 = false,
                //    Required = true,
                //    MirrorName = "buildingDetailsID"  // إضافة هذا السطر
                //},
                new FieldConfig { Name = "p12", Label = "ملاحظات", Type = "textarea", ColCss = "6",Required = true },
                new FieldConfig { Name = "p13", Label = "IdaraId", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p16", Label = "LastActionTypeID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p17", Label = "buildingActionTypeResidentAlias", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p18", Label = "buildingDetailsID", Type = "hidden", ColCss = "3", Readonly = true },
                
                new FieldConfig { Name = "p20", Label = "AssignPeriodID", Type = "hidden", ColCss = "3", Readonly = true },
                new FieldConfig { Name = "p21", Label = "LastActionID", Type = "hidden", ColCss = "3", Readonly = true },




            };



            int dt3rowcount = 0;

            if (dt3 != null)
            {
                dt3rowcount = dt3.Rows.Count;
            }
            


            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartTableDsModel
            {

                Columns = AssignPeriodActive ? dynamicColumns : null,
                Rows = AssignPeriodActive ? rowsList : null,
                //Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "اجراءات التخصيص",
                PanelTitle = "اجراءات التخصيص",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                ShowFilter = true,
                FilterRow = true,
                FilterDebounce = 250,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowDelete = canASSIGNHOUSE && Convert.ToInt32(AssignPeriodID) != 0,
                    ShowDelete1 = canCANCLEASSIGNHOUSE && Convert.ToInt32(AssignPeriodID) != 0,
                    ShowEdit = canUPDATEASSIGNHOUSE && Convert.ToInt32(AssignPeriodID) != 0,
                    ShowAdd = canOPENASSIGNPERIOD && dt3rowcount == 0,
                    ShowAdd1 = canCLOSEASSIGNPERIOD && dt3rowcount != 0,
                    // طباعة محضر التخصيص الحالي للفئة المفتوحة، مستقلة عن تصدير PDF العام.
                    ShowPrint1 = AssignPeriodActive && rowsList.Count > 0,
                    ShowPrint = false,
                    ShowBulkDelete = false,
                    ShowExportPdf = false,



                    Add = new TableAction
                    {
                        Label = "إنشاء محضر تخصيص جديد",
                        Icon = "fa fa-newspaper",
                        Color = "info",
                       // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "إنشاء محضر تخصيص جديد",
                        ModalMessage = "ملاحظة : لايمكن التراجع عن هذا الاجراء",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات محضر التخصيص ",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = OpenAssignPeriodFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },

                         Guards = new TableActionGuards
                         {
                             AppliesTo = "any",
                             DisableWhenAny = new List<TableActionRule>
                            {

                                new TableActionRule
                                {
                                    Field = "AssignPeriodID",
                                    Op = "neq",
                                    Value = "0",
                                    Message = "يوجد محضر تخصيص نشط !!",
                                    Priority = 3
                                }
                            }
                         }
                    },

                    Add1 = new TableAction
                    {
                        Label = "اغلاق محضر التخصيص",
                        Icon = "fa fa-newspaper",
                        Color = "info",
                        // Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "اغلاق محضر تخصيص نشط",
                        ModalMessage = "هل أنت متأكد من اغلاق محضر التخصيص ؟ لايمكن التراجع عن هذا الاجراء !",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "buildingClassInsertForm",
                            Title = "بيانات محضر التخصيص ",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = CloseAssignPeriodFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ",   Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        },

                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                new TableActionRule
                                {
                                    Field = "ActionID",
                                    Op = "eq",
                                    Value = "0",
                                    Message = "لايوجد محضر تخصيص نشط !!",
                                    Priority = 3
                                }
                            }
                        }
                    },

                   
                    Edit = new TableAction
                    {
                        Label = "تخصيص منزل",
                        Icon = "fa fa-check",
                        Color = "success",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "تخصيص منزل للمستفيد",
                        ModalMessage = "ملاحظة : تظهر فقط المباني التي حالتها جاهزة للتسكين وتم اضافة لها فراغات بشرط اضافة غرفة نوم واحده على الاقل",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد تخصيص منزل للمستفيد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = ASSIGNHOUSEFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                new TableActionRule
                                {
                                    Field = "IsAssignmentBlocked",
                                    Op = "eq",
                                    Value = "1",
                                    Message = "غير مؤهل للتخصيص؛ راجع عمود الحالة لمعرفة جميع أسباب المنع.",
                                    Priority = 1
                                },

                                new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "38",
                                    Message = "تم التخصيص للمستفيد مسبقا",
                                    Priority = 3
                                },
                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "40",
                                    Message = "تم التخصيص للمستفيد مسبقا",
                                    Priority = 3
                                },
                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "41",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "42",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                   new TableActionRule
                                {
                                    Field = "AssignStatus",
                                    Op = "eq",
                                    Value = "1",
                                    Message = "تم التخصيص للمستفيد مسبقا",
                                    Priority = 3
                                }
                            }
                        }
                    },


                    Delete = new TableAction
                    {
                        Label = "تعديل تخصيص منزل",
                        Icon = "fa fa-edit",
                        Color = "warning",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "تعديل تخصيص منزل للمستفيد",
                        ModalMessage = "ملاحظة : لايمكن التراجع عن هذا الاجراء",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد تعديل تخصيص منزل للمستفيد",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = UPDATEASSIGNHOUSEFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,


                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                new TableActionRule
                                {
                                    Field = "IsAssignmentBlocked",
                                    Op = "eq",
                                    Value = "1",
                                    Message = "لا يمكن تعديل التخصيص؛ راجع حالة المستفيد وأسباب المنع.",
                                    Priority = 1
                                },


                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "41",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "42",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                   new TableActionRule
                                {
                                    Field = "AssignStatus",
                                    Op = "eq",
                                    Value = "0",
                                    Message = "لم يتم التخصيص للمستفيد",
                                    Priority = 3
                                }
                            }
                        }
                    },

                    Delete1 = new TableAction
                    {
                        Label = "الغاء تخصيص منزل",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من الغاء تخصيص منزل؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد الغاء تخصيص منزل",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "استبعاد", Type = "submit", Color = "danger", },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = CancleASSIGNHOUSEFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {

                                 new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "41",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                  new TableActionRule
                                {
                                    Field = "LastActionTypeID",
                                    Op = "eq",
                                    Value = "42",
                                    Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                                    Priority = 3
                                },
                                  new TableActionRule
                                {
                                    Field = "AssignStatus",
                                    Op = "eq",
                                    Value = "0",
                                    Message = "لم يتم التخصيص للمستفيد",
                                    Priority = 3
                                }
                            }
                        }
                    },

                    //Delete1 = new TableAction
                    //{
                    //    Label = "الغاء التخصيص / أحقية السكن",
                    //    Icon = "fa fa-close",
                    //    Color = "danger",
                    //    //Placement = TableActionPlacement.ActionsMenu, //   أي زر بعد ما نسويه ونبيه يظهر في الاجراءات نحط هذا السطر فقط عشان ما يصير زحمة في التيبل اكشن
                    //    IsEdit = true,
                    //    OpenModal = true,
                    //    //ModalTitle = "رسالة تحذيرية",
                    //    ModalTitle = "الغاء تخصيص منزل للمستفيد او الغاء احقية السكن",
                    //    ModalMessage = "ملاحظة : في حال تجاوز المستفيد عدد المرات المسموحة له في التخصيص سيتم الغاء أحقيته بالسكن مباشرة",
                    //    ModalMessageClass = "bg-red-50 text-red-700",
                    //    ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                    //    OpenForm = new FormConfig
                    //    {
                    //        FormId = "employeeDeleteForm",
                    //        Title = "تأكيد الغاء تخصيص منزل للمستفيد او الغاء احقية السكن",
                    //        Method = "post",
                    //        ActionUrl = "/crud/delete",
                    //        Buttons = new List<FormButtonConfig>
                    //        {
                    //            new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", Icon = "fa fa-check" },
                    //            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                    //        },
                    //        Fields = CancleASSIGNHOUSEFields
                    //    },
                    //    RequireSelection = true,
                    //    MinSelection = 1,
                    //    MaxSelection = 1,


                    //    //Guards = new TableActionGuards
                    //    //{
                    //    //    AppliesTo = "any",
                    //        //DisableWhenAny = new List<TableActionRule>
                    //        //{

                    //        //      new TableActionRule
                    //        //    {
                    //        //        Field = "LastActionTypeID",
                    //        //        Op = "eq",
                    //        //        Value = "38",
                    //        //        Message = "تم التخصيص للمستفيد مسبقا",
                    //        //        Priority = 3
                    //        //    },
                    //        //     new TableActionRule
                    //        //    {
                    //        //        Field = "LastActionTypeID",
                    //        //        Op = "eq",
                    //        //        Value = "40",
                    //        //        Message = "تم التخصيص للمستفيد مسبقا",
                    //        //        Priority = 3
                    //        //    },
                    //        //     new TableActionRule
                    //        //    {
                    //        //        Field = "LastActionTypeID",
                    //        //        Op = "eq",
                    //        //        Value = "41",
                    //        //        Message = "تجاوز المستفيد مرات التخصيص المسموحة نظاما",
                    //        //        Priority = 3
                    //        //    }
                    //        //}
                    //    //}
                    //},

                    Print1 = new TableAction
                    {
                        Label = "طباعة محضر التخصيص",
                        Icon = "fa fa-print",
                        Color = "primary",
                        RequireSelection = false,
                        OnClickJs = $@"
                            sfPrintWithBusy(table, {{
                                pdf: 3,
                                extraParams: {{ U: {JsonSerializer.Serialize(waitingClassID_ ?? string.Empty)} }},
                                busy: {{ title: 'طباعة محضر التخصيص' }}
                            }});
                        "

                    },


                    //ExportConfig = new TableExportConfig
                    //{
                    //    EnablePdf = true,
                    //    PdfEndpoint = "/exports/pdf/table",
                    //    PdfTitle = "المستفيدين",
                    //    PdfPaper = "A4",
                    //    PdfOrientation = "landscape",
                    //    PdfShowPageNumbers = true,
                    //    Filename = "Residents",
                    //    PdfShowGeneratedAt = true,
                    //    PdfShowSerial = true,
                    //    PdfSerialLabel = "م",
                    //    RightHeaderLine1 = "المملكة العربية السعودية",
                    //    RightHeaderLine2 = "وزارة الدفاع",
                    //    RightHeaderLine3 = "القوات البرية الملكية السعودية",
                    //    RightHeaderLine4 = "الإدارة الهندسية للتشغيل والصيانة",
                    //    RightHeaderLine5 = "مدينة الملك فيصل العسكرية",
                    //    PdfLogoUrl = "/img/Royal_Saudi_Land_Forces.png",


                    //},

                    CustomActions = new List<TableAction>
                            {
                            //  Excel "
                            //new TableAction
                            //{
                            //    Label = "تصدير Excel",
                            //    Icon = "fa-regular fa-file-excel",
                            //    Color = "info",
                            //    Placement = TableActionPlacement.ActionsMenu,
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('excel');"
                            //},

                            //  PDF "
                            //new TableAction
                            //{
                            //    Label = "تصدير PDF",
                            //    Icon = "fa-regular fa-file-pdf",
                            //    Color = "danger",
                            //   // Placement = TableActionPlacement.ActionsMenu,
                            //    RequireSelection = false,
                            //    OnClickJs = "table.exportData('pdf');"
                            //},

                             //  details "       
                            new TableAction
                            {
                                Label = "عرض التفاصيل",
                                ModalTitle = "<i class='fa-solid fa-circle-info text-emerald-600 text-xl mr-2'></i> تفاصيل المستفيد",
                                Icon = "fa-regular fa-file",
                                OpenModal = true,
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,


                            },
                        },
                }
            };


            /*
            dsModel.StyleRules = new List<TableStyleRule>
                    {
                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "38",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-green",
                            PillMode     = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "40",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-yellow",
                            PillMode     = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "45",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-yellow",
                            PillMode     = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "39",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-yellow",
                            PillMode     = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "41",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-yellow",
                            PillMode     = "replace"
                        },

                        new TableStyleRule
                        {
                            Target = "row",
                            Field  = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "42",
                            Priority = 1,

                            PillEnabled  = true,
                            PillField    = "buildingActionTypeResidentAlias",
                            PillTextField= "buildingActionTypeResidentAlias",
                            PillCssClass = "pill pill-red",
                            PillMode     = "replace"
                        }
                    };
            */

            dsModel.StyleRules = new List<TableStyleRule>
                    {

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field = "buildingActionTypeResidentAlias",
                            ConditionField = "IsAssignmentBlocked",
                            Op = "eq",
                            Value = "1",
                            Priority = 0,
                            CssClass = "cell-red",
                            StopOnMatch = true
                        },

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "38",
                            Priority = 1,
                            CssClass = "cell-green",
                            StopOnMatch = true
                        },
                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "40",
                            Priority = 1,
                            CssClass = "cell-green",
                            StopOnMatch = true
                        },

                        

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "45",
                            Priority = 1,
                            CssClass = "cell-yellow",
                            StopOnMatch = true
                        },

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "39",
                            Priority = 1,
                            CssClass = "cell-yellow",
                            StopOnMatch = true
                        },

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "41",
                            Priority = 1,
                            CssClass = "cell-yellow",
                            StopOnMatch = true
                        },

                        new TableStyleRule
                        {
                            Target = "cell",
                            Field  = "buildingActionTypeResidentAlias",
                            ConditionField = "LastActionTypeID",
                            Op     = "eq",
                            Value  = "42",
                            Priority = 1,
                            CssClass = "cell-red",
                            StopOnMatch = true
                        }
                    };


            var vm = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-home",

                Panel = new SmartPagePanelConfig
                {
                    Show = true,
                    ShowIcon = true,
                    ShowSubtitle = true,
                    ShowDescription = true,
                    ShowBadges = true,
                    Layout = "compact",
                    Title = "اجراءات تخصيص المنازل للمستفيدين",
                    Subtitle = "شاشه مخصصه لتخصيص المنازل للمستفيدين بعد نقلهم من قوائم الانتظار",
                    Description = " تُستخدم هذه الصفحة لانشاء محاضر التخصيص ومن ثم تخصيص المنازل للمستفيدين حسب المنازل المتاحه ",
                    Icon = "fa-user-group",
                    Badges = new List<SmartPagePanelBadge>
                    {
                        new() { Label = "اختيار فئة الانتظار", Value = "اختيار الفئة المراد البدء بالتخصيص للمنتمين لها", Icon = "fa-solid fa-search", Tone = "success" },
                        new() { Label = "انشاء محضر التخصيص", Value = "انشاء محضر تخصيص جديد للبدء بالتخصيص للمستفيدين المؤهلين", Icon = "fa-solid fa-pen-to-square", Tone = "info" },
                        new() { Label = "استعراض قوائم المستفيدين المنقولين من قوائم الانتظار للتخصيص", Value = "البدء بتخصيص المنازل", Icon = "fa-solid fa-list", Tone = "info" },
                        new() { Label = "اغلاق محضر التخصيص", Value = "بعد الانتهاء من اجراءات التخصيص للمستفيدين المؤهلين يتم اغلاق محضر التخصيص للبدء بمعالجة محضر التخصيص وابلاغ المستفيدين في صفحه معالجة محاضر التخصيص", Icon = "fa-solid fa-shield-halved", Tone = "default" },
                    }
                },

                Form = form,
                TableDS = ready ? dsModel : null
            };



            if (pdf == 3)
            {
                if (!AssignPeriodActive || dt1 == null || dt1.Rows.Count == 0)
                    return Content("لا توجد بيانات تخصيص قابلة للطباعة لهذه الفئة.");

                string GetValue(DataRow row, string columnName)
                {
                    if (!dt1.Columns.Contains(columnName) || row[columnName] == DBNull.Value)
                        return string.Empty;

                    if (row[columnName] is DateTime date)
                        return date.ToString("yyyy/MM/dd");

                    return row[columnName]?.ToString() ?? string.Empty;
                }

                var printTable = new DataTable();

                printTable.Columns.Add("NationalID", typeof(string));
                printTable.Columns.Add("FullName_A", typeof(string));
                printTable.Columns.Add("GeneralNo", typeof(string));
                printTable.Columns.Add("WaitingClassName", typeof(string));
                printTable.Columns.Add("WaitingOrderTypeName", typeof(string));
                printTable.Columns.Add("WaitingListOrder", typeof(string));
                printTable.Columns.Add("ActionDecisionNo", typeof(string));
                printTable.Columns.Add("ActionDecisionDate", typeof(string));
                printTable.Columns.Add("buildingDetailsNo", typeof(string));
                printTable.Columns.Add("buildingActionTypeResidentAlias", typeof(string));
                printTable.Columns.Add("ActionNote", typeof(string));

                foreach (DataRow row in dt1.Rows)
                {
                    printTable.Rows.Add(
                        GetValue(row, "NationalID"),
                        GetValue(row, "FullName_A"),
                        GetValue(row, "GeneralNo"),
                        GetValue(row, "WaitingClassName"),
                        GetValue(row, "WaitingOrderTypeName"),
                        GetValue(row, "WaitingListOrder"),
                        GetValue(row, "ActionDecisionNo"),
                        GetValue(row, "ActionDecisionDate"),
                        GetValue(row, "buildingDetailsNo"),
                        GetValue(row, "buildingActionTypeResidentAlias"),
                        GetValue(row, "ActionNote")
                    );
                }

                var reportColumns = new List<ReportColumn>
    {
        new("WaitingListOrder", "الترتيب", Align: "center", Weight: 2, FontSize: 8),
        new("NationalID", "رقم الهوية", Align: "center", Weight: 2, FontSize: 8),
        new("FullName_A", "الاسم", Align: "center", Weight: 4, FontSize: 8),
        new("GeneralNo", "الرقم العام", Align: "center", Weight: 2, FontSize: 8),
        new("WaitingClassName", "فئة الانتظار", Align: "center", Weight: 3, FontSize: 8),
        new("WaitingOrderTypeName", "نوع السجل", Align: "center", Weight: 2, FontSize: 8),
        new("ActionDecisionNo", "رقم الطلب", Align: "center", Weight: 2, FontSize: 8),
        new("ActionDecisionDate", "تاريخ الطلب", Align: "center", Weight: 2, FontSize: 8),
        new("buildingDetailsNo", "رقم المنزل", Align: "center", Weight: 2, FontSize: 8),
        new("buildingActionTypeResidentAlias", "الحالة", Align: "center", Weight: 3, FontSize: 8),
        new("ActionNote", "ملاحظات", Align: "center", Weight: 3, FontSize: 8)
    };

                var waitingClassName = GetValue(dt1.Rows[0], "WaitingClassName");

                var logo = Path.Combine(
                    _env.WebRootPath,
                    "img",
                    "Royal_Saudi_Land_Forces.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = AssignPeriodID ?? "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "—",
                    ["subject"] = $"قائمة {waitingClassName} تحت اجراءات التخصيص",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = OrganizationName,
                    ["right5"] = IdaraName,
                    ["midCaption"] = ""
                };

                var report = DataTableReportBuilder.FromDataTable(
                    reportId: $"AssignPeriod_{AssignPeriodID}",
                    title: $"محضر تخصيص المساكن لفئة {waitingClassName}",
                    table: printTable,
                    columns: reportColumns,
                    headerFields: header,
                    footerFields: new Dictionary<string, string>
                    {
                        ["عدد السجلات"] = printTable.Rows.Count.ToString(),
                        ["تمت الطباعة بواسطة"] = FullName ?? "",
                        ["تاريخ ووقت الطباعة"] = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss")
                    },
                    orientation: ReportOrientation.Landscape,
                    headerType: ReportHeaderType.LetterOfficial,
                    logoPath: logo,
                    headerRepeat: ReportHeaderRepeat.AllPages
                );

                var pdfBytes = QuestPdfReportRenderer.Render(report);

                Response.Headers["Content-Disposition"] =
                    $"inline; filename=AssignPeriod_{AssignPeriodID}.pdf";

                return File(pdfBytes, "application/pdf");
            }

            if (pdf == 2)
            {
                var logo = Path.Combine(_env.WebRootPath, "img", "Royal_Saudi_Land_Forces.png");

                var header = new Dictionary<string, string>
                {
                    ["no"] = AssignPeriodID ?? "",
                    ["date"] = DateTime.Now.ToString("yyyy/MM/dd"),
                    ["attach"] = "بيان بأسماء المستفيدين المخصص لهم",
                    ["subject"] = "محضر تخصيص مساكن",

                    ["right1"] = "المملكة العربية السعودية",
                    ["right2"] = "وزارة الدفاع",
                    ["right3"] = "القوات البرية الملكية السعودية",
                    ["right4"] = OrganizationName,
                    ["right5"] = IdaraName,

                    ["bismillah"] = "بسم الله الرحمن الرحيم",
                    ["midCaption"] = ""
                };

                var report = new ReportResult
                {
                    ReportId = "OfficialLetter01",
                    Title = "خطاب رسمي",
                    Kind = ReportKind.Letter,

                    // هنا اختَر الاتجاه اللي تبيه للخطاب
                    Orientation = ReportOrientation.Portrait, // أو Landscape

                    HeaderType = ReportHeaderType.LetterOfficial,
                    LogoPath = logo,
                    ShowFooter = false,

                    HeaderFields = header,

                    LetterBlocks = new List<LetterBlock>
        {
            new LetterBlock
            {
                Text = "سعادة قائد إدارة مدينة الملك فيصل العسكرية حفظه الله",
                FontSize = 13,
                Bold = true,
                PaddingBottom = 12,
                PaddingTop = 30,
                Align = TextAlign.Center
            },

            new LetterBlock
            {
                Text = "السلام عليكم ورحمة الله وبركاته،",
                FontSize = 12,
                PaddingBottom = 10,
                PaddingTop = 15,
                Align = TextAlign.Right
            },

            new LetterBlock
            {
                Text = "نفيد سعادتكم بأنه بناءً على توجيهاتكم الكريمة ...",
                FontSize = 12,
                Align = TextAlign.Justify,
                LineHeight = 1.8f,
                PaddingBottom = 16
            },

            new LetterBlock
            {
                Text = "وتفضلوا بقبول فائق الاحترام والتقدير،",
                FontSize = 12,
                PaddingTop = 20,
                Align = TextAlign.Right
            },

            new LetterBlock
            {
                Text = "مدير الإدارة الهندسية\nالاسم / ..................\nالتوقيع / ...............",
                FontSize = 11,
                Align = TextAlign.Left,
                PaddingTop = 30,
                PaddingLeft = 120
            }
        }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                Response.Headers["Content-Disposition"] = "inline; filename=Letter.pdf";
                return File(pdfBytes, "application/pdf");
            }



            return View("WaitingList/Assign", vm);
        }
    }
}
