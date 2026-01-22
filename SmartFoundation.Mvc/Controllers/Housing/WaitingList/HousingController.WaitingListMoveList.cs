using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.Housing
{
    public partial class HousingController : Controller
    {
        public async Task<IActionResult> WaitingListMoveList()
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = nameof(Housing);
            PageName = string.IsNullOrWhiteSpace(PageName) ? "WaitingListMoveList" : PageName;

            var spParameters = new object?[]
            {
             PageName ?? "WaitingListMoveList",
             IdaraId,
             usersId,
             HostName
            };

           

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canApprove = false;
            bool canReject = false;
       

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "MOVEWAITINGLISTAPPROVE") canApprove = true;
                        if (permissionName == "MOVEWAITINGLISTREJECT") canReject = true;
                      
                    }

                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "BuildingTypeID";
                        var possibleIdNames = new[] { "buildingTypeID", "BuildingTypeID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["ResidentFullName_A"] = "اسم المستفيد",
                            ["ActionDecisionNo"] = "رقم القرار",
                            ["ActionDecisionDate"] = "تاريخ القرار",
                            ["WaitingClassName"] = "فئة سجل الانتظار",
                            ["ActionStatus"] = "حالة الطلب",
                            ["entrydate"] = "تاريخ الاجراء",
                            ["entryDataName"] = "منفذ الاجراء"
                        };

                        // الأعمدة
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
                            bool isActionTypeID = c.ColumnName.Equals("ActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isActionTypeName = c.ColumnName.Equals("ActionTypeName", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isBuildingNo = c.ColumnName.Equals("BuildingNo", StringComparison.OrdinalIgnoreCase);
                            bool isActionDate = c.ColumnName.Equals("ActionDate", StringComparison.OrdinalIgnoreCase);
                            bool isActionNote = c.ColumnName.Equals("ActionNote", StringComparison.OrdinalIgnoreCase);
                            bool isWaitingClassID = c.ColumnName.Equals("WaitingClassID", StringComparison.OrdinalIgnoreCase);
                            bool isbuildingActionExtraInt1 = c.ColumnName.Equals("buildingActionExtraInt1", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                  ,
                                Visible = !( isActionTypeID || isActionTypeName || isresidentInfoID || isBuildingNo || isActionDate || isActionNote || isWaitingClassID  || isbuildingActionExtraInt1)
                            });
                        }

                        // الصفوف
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            // p01..p05
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ActionID") ?? Get("actionID");
                            dict["p02"] = Get("ActionTypeID");
                            dict["p03"] = Get("ActionTypeName");
                            dict["p04"] = Get("residentInfoID");
                            dict["p05"] = Get("ResidentFullName_A");
                            dict["p06"] = Get("NationalID");
                            dict["p07"] = Get("GeneralNo");
                            dict["p08"] = Get("BuildingNo");
                            dict["p09"] = Get("ActionDate");
                            dict["p10"] = Get("ActionDecisionNo");
                            dict["p11"] = Get("ActionDecisionDate");
                            dict["p12"] = Get("ActionNote");
                            dict["p13"] = Get("WaitingClassName");
                            dict["p14"] = Get("ActionStatus");
                            dict["p15"] = Get("entrydate");
                            dict["p16"] = Get("entryDataName");
                            dict["p17"] = Get("WaitingClassID");
                            dict["p18"] = Get("buildingActionExtraInt1");


                            rowsList.Add(dict);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;
            }


            // DELETE fields
            var approveFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p04", Label = "residentInfoID", Type = "hidden", ColCss = "3",Readonly =true},
                new FieldConfig { Name = "p05", Label = "الاسم", Type = "text", ColCss = "3",Readonly =true},
                new FieldConfig { Name = "p06", Label = "رقم الهوية الوطنية", Type = "text", ColCss = "3",Placeholder="1xxxxxxxxx",Readonly =true},
                new FieldConfig { Name = "p07", Label = "الرقم العام", Type = "text", ColCss = "3", Required = true,Readonly =true},

                new FieldConfig { Name = "p13", Label = "فئة سجل الانتظار", Type = "text", ColCss = "3", Required = true ,Readonly =true},

                new FieldConfig { Name = "p17", Label = "WaitingClassID", Type = "hidden", ColCss = "3", Required = true ,Readonly =true},



                new FieldConfig { Name = "p10", Label = "رقم قرار النقل", Type = "text", ColCss = "6", MaxLength = 50, TextMode = "number",Required=true ,Readonly =true},
                new FieldConfig { Name = "p11", Label = "تاريخ قرار النقل", Type = "text", ColCss = "6", MaxLength = 50, TextMode = "number",Required=true,Placeholder="YYYY-MM-DD" ,Readonly =true},


                new FieldConfig { Name = "p18", Label = "buildingActionExtraInt1 -New IdaraID", Type = "hidden", ColCss = "6", Required = true,Readonly =true },

            };

            var dsModel = new SmartTableDsModel
            {
                PageTitle = "انواع المباني",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "أنواع المباني",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,
                    ShowDelete = canApprove,
                    ShowDelete1 = canReject,
                    ShowBulkDelete = false,


                    


                    Delete = new TableAction
                    {
                        Label = "قبول الطلب",
                        //Icon = "fa fa-check",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "قبول الطلب",
                        ModalMessage = "هل أنت متأكد من قبول الطلب؟",
                        ModalMessageClass = "bg-green-50 text-green-700",
                        ModalMessageIcon = "fa-solid fa-circle-question",
                        OpenForm = new FormConfig
                        {
                            FormId = "WaitingListMoveListDeleteForm",
                            Title = "تأكيد قبول الطلب",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "قبول", Type = "submit", Color = "success" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = approveFields
                                },
                                RequireSelection = true,
                                MinSelection = 1,
                                MaxSelection = 1,

                        // اذا الحالة مرفوض امنع عنه الازرار
                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                            {
                                new TableActionRule
                                {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "مقبول",
                                    Message = "لا يمكن قبول طلب حالته بالفعل (مقبول).",
                                    Priority = 1
                                },
                                new TableActionRule
                                {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "مرفوض",
                                    Message = "لا يمكن قبول طلب حالته (مرفوض).",
                                    Priority = 2
                                },
                                new TableActionRule
                                {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "ملغى",
                                    Message = "لا يمكن قبول طلب حالته (ملغى).",
                                    Priority = 3
                                }
                            }
                        }
                    },



                    Delete1 = new TableAction
                    {
                        Label = "رفض الطلب",
                        Icon = "fa fa-close",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تحذير",
                        ModalMessage = "هل أنت متأكد من رفض الطلب؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OpenForm = new FormConfig
                        {
                            FormId = "WaitingListMoveListDeleteForm",
                            Title = "تأكيد رفض الطلب",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                        {
                            new FormButtonConfig { Text = "رفض", Type = "submit", Color = "danger" },
                            new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                        },
                            Fields = approveFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,

                        // اذا الحالة مرفوض امنع عنه الازرار "
                        Guards = new TableActionGuards
                        {
                            AppliesTo = "any",
                            DisableWhenAny = new List<TableActionRule>
                        {
                            new TableActionRule
                            {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "مرفوض",
                                    Message = "لا يمكن رفض طلب حالته بالفعل (مرفوض).",
                                    Priority = 1
                                },
                            new TableActionRule
                            {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "ملغى",
                                    Message = "لا يمكن رفض طلب حالته بالفعل (ملغى).",
                                    Priority = 2
                                },
                                new TableActionRule
                                {
                                    Field = "ActionStatus",
                                    Op = "eq",
                                    Value = "مقبول",
                                    Message = "لا يمكن رفض طلب حالته (مقبول).",
                                    Priority = 3
                                }
                            }
                        }
                    },
                }
            };





        dsModel.StyleRules = new List<TableStyleRule>
            {
                            
            
            new TableStyleRule
                          
            {
                                
                Target = "row",
                Field = "ActionStatus",
                Op = "eq",
                Value = "مرفوض",
                CssClass = "row-red",
                Priority = 1
            },
                           
            new TableStyleRule
                          
            {
                                
                Target = "row",
                Field = "ActionStatus",
                Op = "eq",
                Value = "ملغى",
                CssClass = "row-red",
                Priority = 1
            },
                           
            
            new TableStyleRule
            
            {
                 Target = "row",
                Field = "ActionStatus",
                Op = "eq",
                Value = "مقبول",
                CssClass = "row-green",
                Priority = 1
            },
        };

            //return View("HousingDefinitions/BuildingType", dsModel);

                    var page = new SmartPageViewModel
                    {
                        PageTitle = dsModel.PageTitle,
                        PanelTitle = dsModel.PanelTitle,
                        PanelIcon = "fa-layer-group",
                        TableDS = dsModel
                    };

                    return View("WaitingList/WaitingListMoveList", page);

        }
    }
}
