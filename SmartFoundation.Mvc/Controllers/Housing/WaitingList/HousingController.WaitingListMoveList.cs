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

                    if (ds != null && ds.Tables.Count > 0)
                    {
                        // ✅ RowId الصحيح
                        rowIdField = "ActionID";
                        var possibleIdNames = new[] { "ActionID", "actionID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // ✅ عناوين الأعمدة بناءً على V_MoveWaitingList
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ActionID"] = "رقم الإجراء",
                            ["residentInfoID"] = "معرف المستفيد",
                            ["NationalID"] = "رقم الهوية",
                            ["GeneralNo"] = "الرقم العام",
                            ["fullname"] = "اسم المستفيد",
                            ["ActionDecisionNo"] = "رقم قرار النقل",
                            ["ActionDecisionDate"] = "تاريخ قرار النقل",
                            ["ActionDate"] = "تاريخ الإجراء",
                            ["IdaraId"] = "معرف الإدارة",
                            ["ActionIdaraName"] = "الإدارة المنقول منها",
                            ["ToIdaraID"] = "معرف الإدارة المنقول إليها",
                            ["Toidaraname"] = "الإدارة المنقول إليها",
                            ["WaitingListCount"] = "عدد سجلات الانتظار",
                            ["MainActionEntryData"] = "مُدخل الإجراء",
                            ["MainActionEntryDate"] = "تاريخ إدخال الإجراء",
                            ["ActionNote"] = "ملاحظات الإجراء",
                            ["LastActionID"] = "آخر إجراء",
                            ["LastActionTypeID"] = "نوع آخر إجراء",
                            ["LastActionIdaraID"] = "إدارة آخر إجراء",
                            ["LastActionIdaraName"] = "اسم إدارة آخر إجراء",
                            ["LastActionTypeName"] = "نوع الإجراء",
                            ["LastActionEntryDate"] = "تاريخ آخر إجراء",
                            ["LastActionNote"] = "ملاحظات",
                            ["LastActionEntryData"] = "مُدخل آخر إجراء",
                            ["ActionStatus"] = "حالة الطلب"
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

                            // ✅ إخفاء الأعمدة الداخلية (IDs و metadata فقط)
                            bool isActionID = c.ColumnName.Equals("ActionID", StringComparison.OrdinalIgnoreCase);
                            bool isresidentInfoID = c.ColumnName.Equals("residentInfoID", StringComparison.OrdinalIgnoreCase);
                            bool isNationalID = c.ColumnName.Equals("NationalID", StringComparison.OrdinalIgnoreCase);
                            bool isIdaraId = c.ColumnName.Equals("IdaraId", StringComparison.OrdinalIgnoreCase);
                            bool isToIdaraID = c.ColumnName.Equals("ToIdaraID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionID = c.ColumnName.Equals("LastActionID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionTypeID = c.ColumnName.Equals("LastActionTypeID", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionIdaraID = c.ColumnName.Equals("LastActionIdaraID", StringComparison.OrdinalIgnoreCase);
                            bool isMainActionEntryData = c.ColumnName.Equals("MainActionEntryData", StringComparison.OrdinalIgnoreCase);
                            bool isLastActionEntryData = c.ColumnName.Equals("LastActionEntryData", StringComparison.OrdinalIgnoreCase);
                            bool isActionDate = c.ColumnName.Equals("ActionDate", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true,
                                // ✅ اخفي IDs و metadata فقط
                                Visible = !(isActionID || isresidentInfoID || isNationalID || isIdaraId || 
                                           isToIdaraID || isLastActionID || isLastActionTypeID || 
                                           isLastActionIdaraID || isMainActionEntryData || 
                                           isLastActionEntryData || isActionDate)
                            });
                        }

                        // ✅ الصفوف - mapping صحيح بناءً على V_MoveWaitingList
                        foreach (DataRow r in dt1.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt1.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            
                            // ✅ Mapping صحيح للـ approve/reject forms
                            dict["p01"] = Get("ActionID");
                            dict["p02"] = Get("residentInfoID");
                            dict["p03"] = Get("NationalID");
                            dict["p04"] = Get("GeneralNo");
                            dict["p05"] = Get("fullname");
                            dict["p06"] = Get("ActionDecisionNo");
                            dict["p07"] = Get("ActionDecisionDate");
                            dict["p08"] = Get("ActionDate");
                            dict["p09"] = Get("IdaraId");
                            dict["p10"] = Get("ActionIdaraName");
                            dict["p11"] = Get("ToIdaraID");
                            dict["p12"] = Get("Toidaraname");
                            dict["p13"] = Get("WaitingListCount");
                            dict["p14"] = Get("MainActionEntryData");
                            dict["p15"] = Get("MainActionEntryDate");
                            dict["p16"] = Get("ActionNote");
                            dict["p17"] = Get("LastActionID");
                            dict["p18"] = Get("LastActionTypeID");
                            dict["p19"] = Get("LastActionIdaraID");
                            dict["p20"] = Get("LastActionIdaraName");
                            dict["p21"] = Get("LastActionTypeName");
                            dict["p22"] = Get("LastActionEntryDate");
                            dict["p23"] = Get("LastActionNote");
                            dict["p24"] = Get("LastActionEntryData");
                            dict["p25"] = Get("ActionStatus");

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
            // ✅ Approve/Reject fields (نفس الـ form للاثنين)
            var approveFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "MOVEWAITINGLISTAPPROVE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                
                // ✅ Hidden fields (IDs فقط)
                new FieldConfig { Name = rowIdField, Type = "hidden" },  // ActionID
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "residentInfoID" },
                //new FieldConfig { Name = "p09", Type = "hidden", MirrorName = "IdaraId" },
                new FieldConfig { Name = "p11", Type = "hidden", MirrorName = "ToIdaraID" },
                new FieldConfig { Name = "p17", Type = "hidden", MirrorName = "LastActionID" },
                new FieldConfig { Name = "p18", Type = "hidden", MirrorName = "LastActionTypeID" },
                
                // ✅ Readonly fields للعرض
                new FieldConfig { Name = "p05", Label = "اسم المستفيد", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p13", Label = "عدد سجلات الانتظار", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p06", Label = "رقم قرار النقل", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p07", Label = "تاريخ قرار النقل", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p10", Label = "الإدارة المنقول منها", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p12", Label = "الإدارة المنقول إليها", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p23", Label = "ملاحظات القبول", Type = "textarea", ColCss = "6", Readonly = false, Required =true },
                new FieldConfig { Name = "p09", Label = "sendidaraid", Type = "hidden", ColCss = "6", Readonly = false },
            };


            // ✅ Approve/Reject fields (نفس الـ form للاثنين)
            var rejectFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "MOVEWAITINGLISTREJECT" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraId.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = usersId.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                
                // ✅ Hidden fields (IDs فقط)
                new FieldConfig { Name = rowIdField, Type = "hidden" },  // ActionID
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ActionID" },
                new FieldConfig { Name = "p02", Type = "hidden", MirrorName = "residentInfoID" },
                //new FieldConfig { Name = "p09", Type = "hidden", MirrorName = "IdaraId" },
                new FieldConfig { Name = "p11", Type = "hidden", MirrorName = "ToIdaraID" },
                new FieldConfig { Name = "p17", Type = "hidden", MirrorName = "LastActionID" },
                new FieldConfig { Name = "p18", Type = "hidden", MirrorName = "LastActionTypeID" },
                
                // ✅ Readonly fields للعرض
                new FieldConfig { Name = "p05", Label = "اسم المستفيد", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "رقم الهوية", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p04", Label = "الرقم العام", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p13", Label = "عدد سجلات الانتظار", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p06", Label = "رقم قرار النقل", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p07", Label = "تاريخ قرار النقل", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p10", Label = "الإدارة المنقول منها", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p12", Label = "الإدارة المنقول إليها", Type = "text", ColCss = "6", Readonly = true },
                new FieldConfig { Name = "p23", Label = "ملاحظات الرفض", Type = "textarea", ColCss = "6", Readonly = false, Required =true },
                new FieldConfig { Name = "p09", Label = "sendidaraid", Type = "text", ColCss = "6", Readonly = false },

            };



            var dsModel = new SmartTableDsModel
            {
                PageTitle = "طلبات نقل سجلات الانتظار الواردة",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PanelTitle = "طلبات نقل سجلات الانتظار الواردة",
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
