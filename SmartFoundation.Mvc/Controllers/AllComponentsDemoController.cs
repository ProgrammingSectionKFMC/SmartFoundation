using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.UI.ViewModels.SmartDatePicker;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using Microsoft.AspNetCore.Identity;
using SmartFoundation.Mvc.Models;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using System.Text.RegularExpressions;
using static System.Net.Mime.MediaTypeNames;


namespace SmartFoundation.Mvc.Controllers
{
    [Route("[controller]")]
    public class AllComponentsDemoController : Controller
    {

        private readonly MastersServies _mastersServies;


        public AllComponentsDemoController(MastersServies mastersServies)
        {
            _mastersServies = mastersServies;
        }


        string? ControllerName;
        string? PageName;
        int userID;
        string? fullName;
        int IdaraID;
        string? DepartmentName;
        string? ThameName;
        string? DeptCode;
        string? IDNumber;
        string? HostName;

        DataSet ds;

        DataTable? permissionTable;
        DataTable? dt1;
        DataTable? dt2;
        DataTable? dt3;
        DataTable? dt4;
        DataTable? dt5;
        DataTable? dt6;
        DataTable? dt7;
        DataTable? dt8;
        DataTable? dt9;


        [HttpGet("")]
        [HttpGet("Form")]
        public IActionResult Form()

        {
            var form = new FormConfig
            {
                FormId = "dynamicForm",
                Title = "نموذج الإدخال",
                Method = "POST",
                ActionUrl = "/AllComponentsDemo/ExecuteDemo",
                SubmitText = "حفظ",
                ResetText = "تفريغ",
                ShowPanel = true,
                ShowReset = true,
                StoredProcedureName = "sp_SaveDemoForm",
                Operation = "insert",
                StoredSuccessMessageField = "Message",
                StoredErrorMessageField = "Error",

                Fields = new List<FieldConfig>
                {
                    // ========= البيانات الشخصية =========
                    new FieldConfig
                    {

                        SectionTitle="البيانات",
                        Name="FullName",
                        Label="إدخال نص",
                        Type="text",
                        Required=true,
                        Placeholder="حقل عربي فقط",
                        Icon="fa-solid fa-user",
                        ColCss="col-span-12 md:col-span-3",
                        MaxLength=50,
                        TextMode="arsentence",
                    },
                    new FieldConfig
                    {

                        Name="Email",
                        Label = "البريد الإلكتروني",
                        Type = "text",
                        Required = true,
                        Placeholder = "example@example.com",
                        Icon = "fa-solid fa-envelope",
                        ColCss = "col-span-12 md:col-span-3",
                        MaxLength = 100,
                        TextMode = "email",
                        Autocomplete = "email",
                        Autocapitalize = "none",
                        Autocorrect = "on",
                        Spellcheck = true,
                        HelpText="أدخل بريد إلكتروني صحيح"
                    },


                    new FieldConfig
                    {
                        Name="password",
                        Label="كلمة المرور",
                        Type="password",
                        Required=true,
                        Icon="fa-solid fa-lock",
                        MaxLength=20,
                        ColCss="col-span-12 md:col-span-3",
                        Autocomplete="new-password",
                        Placeholder="اكتب كلمة المرور",
                        HelpText="الحد الأدنى 6 خانات"
                    },
                    new FieldConfig
                    {
                        Name="Age",
                        Label="عداد رقمي",
                        Type="number",
                        Min=1,
                        Max=120,
                        InputLang="number",
                        Icon="fa-solid fa-calculator",
                        MaxLength=3,
                        ColCss="col-span-12 md:col-span-3",
                    },
                    new FieldConfig
                    {
                        Name="NationalId",
                        Label="رقم الهوية",
                        Type="text",
                        Required=true,
                        Placeholder="1234567890",
                        InputLang="number",
                        InputPattern=@"^[0-9]{10}$",
                        Icon="fa-solid fa-id-card",
                        ColCss="col-span-12 md:col-span-3",
                        IsNumericOnly=true,
                        MaxLength=10,
                        HelpText="10 أرقام فقط",
                        Autocomplete="off",
                    },

                    // ========= الاتصال والحساب =========
                    new FieldConfig
                    {
                        Name="User",
                        Label="رقم الجوال",
                        Type="phone",
                        Required=true,
                        Placeholder="05xxxxxxxx",
                        Icon="fa-solid fa-phone",
                        IsNumericOnly=true,
                        MaxLength=20,
                        ColCss="col-span-12 md:col-span-3",
                        Autocomplete="off",
                        HelpText="أدخل رقم جوال يبدأ بـ 05"
                    },
                    new FieldConfig
                    {
                        Name="IBAN",
                        Label="الحساب البنكي (IBAN)",
                        Type="iban",
                        Required=true,
                        Placeholder="SAxxxxxxxxxxxxxxxxxxxx",
                        Icon="fa-solid fa-money-bill-transfer",
                        IsIban=true,
                        MaxLength=20,
                        ColCss="3",
                        HelpText="يجب أن يبدأ بـ SA"
                    },

                    // ========= الموقع =========
                    new FieldConfig
                    {
                        Name="Country",
                        Label="الدولة",
                        Type="select",
                        Select2=true,
                        Required=true,
                        Options=new List<OptionItem>
                        {
                            new OptionItem { Value="SA", Text="السعودية" },
                            new OptionItem { Value="EG", Text="مصر" },
                            new OptionItem { Value="JO", Text="الأردن" }
                        },
                        ColCss="col-span-3 md:col-span-3",
                    },
                    new FieldConfig
                    {
                        Name="City",
                        Label="المدينة",
                        Type="select",
                        Select2=true,
                        Required=true,
                        DependsOn="Country",
                        DependsUrl="/api/location/cities",
                        ColCss="col-span-3 md:col-span-3",
                    },
                    new FieldConfig
                    {
                        Name="District",
                        Label="الحي",
                        Type="text",
                        ColCss="col-span-12 md:col-span-3",
                        MaxLength=50,
                        Placeholder="اسم الحي",
                        HelpText="أدخل اسم الحي فقط",
                        Icon="fa-solid fa-city"
                    },
                    new FieldConfig
                    {
                        Name="readonlyField",
                        Label="للقراءة فقط",
                        Type="text",
                        Readonly=true,
                        Placeholder="حقل للقراءة فقط",
                        ColCss="col-span-12 md:col-span-3",
                        Value="نص ثابت",
                        HelpText="هذا الحقل للعرض فقط",
                        Icon="fa-solid fa-eye"
                    },
                    new FieldConfig
                    {
                        Name="Address",
                        Label="العنوان الكامل",
                        Type="text",
                        MaxLength=200,
                        Placeholder="اكتب عنوانك بالتفصيل",
                        Icon="fa-solid fa-location-dot",
                        ColCss="col-span-12 md:col-span-3",
                        HelpText="الرجاء إدخال العنوان الكامل",
                    },

                    // ========= التواريخ =========
                    new FieldConfig
                    {
                        Name="date",
                        Label="تاريخ ميلادي",
                        Type="date",
                        Placeholder="YYYY-MM-DD",
                        Icon="fa-regular fa-calendar",
                        Calendar="both",
                        DateInputCalendar="gregorian",
                        MirrorName="BirthDateHijri",
                        MirrorCalendar="hijri",
                        DateDisplayLang="ar",
                        DateNumerals="latn",
                        ShowDayName=true,
                        DefaultToday=false,
                        MinDateStr="1950-01-01",
                        MaxDateStr="2025-12-31",
                        DisplayFormat="yyyy-mm-dd",
                        ColCss="col-span-12 md:col-span-3",
                        HelpText="اختر تاريخ ميلاد صحيح"
                    },
                    new FieldConfig
                    {
                        Name="Vacation",
                        Label="الإجازة (من - إلى)",
                        Type="date-range",
                        Calendar="both",
                        DateInputCalendar="gregorian",
                        MirrorName="VacationHijri",
                        MirrorCalendar="hijri",
                        DateDisplayLang="ar",
                        DateNumerals="latn",
                        ShowDayName=true,
                        MinDateStr="1990-01-01",
                        MaxDateStr="2025-12-31",
                        DisplayFormat="yyyy-mm-dd",
                        HelpText="سيتم حساب عدد الأيام تلقائيًا",
                        Icon="fa-regular fa-calendar-days",
                        ColCss="col-span-12 md:col-span-6",
                    },

                    // ========= الملاحظات =========
                    new FieldConfig
                    {

                        SectionTitle="ملاحظات",
                        Name="Bio",
                        Label="ملاحظات",
                        Type="textarea",
                        MaxLength=500,
                        Placeholder="يسمح بكتابة 500 حرف",
                        ColCss="col-span-12 md:col-span-5",
                        Spellcheck=true,
                        Autocapitalize="sentences",
                        HelpText="يمكنك إدخال وصف مختصر هنا"
                    },

                    // ========= جدول للتجربة =========
                    
new FieldConfig
{
    SectionTitle = "جدول بيانات",
    Name = "DemoTable",
    Type = "datatable",
    ColCss = "col-span-12",
    Table = new TableConfig
    {
        Endpoint = "/AllComponentsDemo/ExecuteDemo",
        StoredProcedureName = "sp_GetDemoData",
        Operation = "select",
        PageSize = 6,
        PageSizes = new List<int> { 5, 10, 25, 50, 100 },
        ShowHeader = true,
        ShowFooter = true,
        Searchable = true,
        SearchPlaceholder = "اكتب للبحث...",
        QuickSearchFields = new List<string> { "FullName", "Email" },
        AllowExport = false,
        AutoRefreshOnSubmit = true,
        Selectable = true,
        RowIdField = "Id",
        GroupBy = null,
        StorageKey = "demo_table_storage",

        Columns = new List<TableColumn>
        {
            new TableColumn { Field="Id", Label="رقم", Sortable=true, Visible=true, Width="80px", Align="center", Type="number", ShowInModal=true },
            new TableColumn { Field="FullName", Label="الاسم الكامل", Sortable=true, Align="right", Type="text", ShowInModal=true },
            new TableColumn { Field="Email", Label="البريد الإلكتروني", Sortable=true, Align="left", Type="text", ShowInModal=true },
            new TableColumn { Field="CreatedAt", Label="تاريخ الإدخال", Sortable=true, Type="datetime", FormatString="yyyy-MM-dd HH:mm", ShowInModal=true },
            new TableColumn { Field="Status", Label="الحالة", Sortable=false, Type="badge", Badge=new TableBadgeConfig {
                Map = new Dictionary<string,string> {
                    { "نشط", "bg-green-100 text-green-800" },
                    { "موقوف", "bg-red-100 text-red-800" }
                },
                DefaultClass = "bg-gray-100 text-gray-600"
            }, ShowInModal=true }
        },

        //RowActions = new List<TableAction>
        //{
        //    new TableAction
        //    {
        //        Label="حذف",
        //        Icon="fa fa-trash",
        //        Color="danger",
        //        Show=true,
        //        ConfirmText="هل أنت متأكد من حذف هذا السجل؟",
        //        OnClickJs="alert('تنفيذ حذف للسجل رقم: ' + row.Id)"
        //    },
        //    new TableAction
        //    {
        //        Label="تنبيه",
        //        Icon="fa fa-bell",
        //        Color="warning",
        //        Show=true,
        //        OnClickJs="alert('تم الضغط على تنبيه للسجل: ' + row.Id)"
        //    }
        //},

        Toolbar = new TableToolbarConfig
        {
            ShowAdd = true,
            ShowEdit = false,
            ShowRefresh = false,
            ShowColumns = true,
            ShowExportCsv = false,
            ShowExportExcel = false,
            ShowAdvancedFilter = true,
            ShowBulkDelete = true,

            // زر الإضافة
            Add = new TableAction
            {
                Label = "إضافة",
                Icon = "fa fa-plus",
                Color = "success",
                Show = true,
                OpenModal = true,
                ModalTitle = "إضافة سجل جديد",
                ModalSp = "sp_AddDemoData",
                ModalOp = "insert",
                SaveSp = "sp_AddDemoData",
                SaveOp = "insert",
                ModalColumns = new List<TableColumn>
                {
                    new TableColumn { Field="FullName", Label="الاسم الكامل" },
                    new TableColumn { Field="Email", Label="البريد الإلكتروني" },
                    new TableColumn { Field="Phone", Label="الهاتف" }
                }
            },

            // زر التعديل
            Edit = new TableAction
            {
                Label = "تعديل",
                Icon = "fa fa-edit",
                Color = "info",
                Show = false,
                OpenModal = true,
                IsEdit = true,  // ✅ يحدد أنه زر تعديل
                ModalTitle = "تعديل بيانات المستخدم",
                ModalSp = "sp_GetUserDetail",   // SP لجلب البيانات للتعديل
                ModalOp = "detail",
                SaveSp = "sp_UpdateUser",       // SP لحفظ التعديلات
                SaveOp = "update",
                ModalColumns = new List<TableColumn>
                {
                    new TableColumn { Field="Id", Label="رقم", Visible=false }, // رقم معرف فقط
                    new TableColumn { Field="FullName", Label="الاسم الكامل" },
                    new TableColumn { Field="Email", Label="البريد الإلكتروني" },
                    new TableColumn { Field="Phone", Label="الهاتف" },
                    new TableColumn { Field="Address", Label="العنوان" }
                }
            }
        }
    }
},
                    // ========= إقرار =========
                    new FieldConfig
                    {
                        SectionTitle="إقرار",
                        Name="AgreeTerms",
                        Label="أوافق على الشروط والأحكام",
                        Type="checkbox",
                        Required=true,
                        Icon="fa-solid fa-check",
                        ColCss="col-span-12 md:col-span-3"
                    },

                    new FieldConfig
                    {
                        SectionTitle="رفع صورة",
                        Name="Emg",
                        Label="أوافق على الشروط والأحكام",
                        Type="file",
                        Required=true,
                        Icon="fa-solid fa-check",
                        ColCss="col-span-12 md:col-span-3"
                    },
                    


                    

                    // ========= حقل مخفي =========
                    new FieldConfig
                    {
                        Name="HiddenToken",
                        Type="hidden",
                        Value="xyz-123",
                        IsHidden=true
                    }
                },

                Buttons = new List<FormButtonConfig>
                {
                    new FormButtonConfig
                    {
                        Text="طباعة",
                        Icon="fa-solid fa-print",
                        Type="button",
                        Color="danger",
                        OnClickJs="window.print();"
                    },


                    new FormButtonConfig
                    {
                        Text="رجوع",
                        Icon="fa-solid fa-arrow-left",
                        Type="button",
                        Color="info",
                        OnClickJs="history.back();"
                    },

                }
            };

            var vm = new SmartPageViewModel
            {
                PageTitle = "جميع المكونات",
                PanelTitle = "عرض ",
                SpName = "sp_SaveDemoForm",
                Operation = "insert",
                Form = form
            };




            return View(vm);
        }


        [HttpGet("Table")]
        public async Task<IActionResult> Table()
        {
            if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
                return RedirectToAction("Index", "Login", new { logout = 1 });


            ControllerName = ControllerContext.ActionDescriptor.ControllerName;
            PageName = ControllerContext.ActionDescriptor.ActionName;
            userID = Convert.ToInt32(HttpContext.Session.GetString("usersID"));
            fullName = HttpContext.Session.GetString("fullName");
            IdaraID = Convert.ToInt32(HttpContext.Session.GetString("IdaraID"));
            DepartmentName = HttpContext.Session.GetString("DepartmentName");
            ThameName = HttpContext.Session.GetString("ThameName");
            DeptCode = HttpContext.Session.GetString("DeptCode");
            IDNumber = HttpContext.Session.GetString("IDNumber");
            HostName = HttpContext.Session.GetString("HostName");


            var spParameters = new object?[] { PageName, IdaraID, userID, HostName };

            DataSet ds;

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);

            permissionTable = (ds?.Tables?.Count ?? 0) > 0 ? ds.Tables[0] : null;
            dt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            dt2 = (ds?.Tables?.Count ?? 0) > 2 ? ds.Tables[2] : null;
            dt3 = (ds?.Tables?.Count ?? 0) > 3 ? ds.Tables[3] : null;
            dt4 = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
            dt5 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;
            dt6 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[6] : null;
            dt7 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[7] : null;
            dt8 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[8] : null;
            dt9 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[9] : null;

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {

                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            string rowIdField = "";
            bool canInsert = false;
            bool canUpdate = false;
            bool canDelete = false;

            try
            {

                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    // اقرأ الجدول الأول


                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT")
                            canInsert = true;

                        if (permissionName == "UPDATE")
                            canUpdate = true;

                        if (permissionName == "DELETE")
                            canDelete = true;
                    }


                    if (ds != null && ds.Tables.Count > 0)
                    {

                        // Resolve a correct row id field (case sensitive match to actual DataTable column)
                        rowIdField = "BuildingTypeID";
                        var possibleIdNames = new[] { "buildingTypeID", "BuildingTypeID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        //For change table name to arabic 
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["buildingTypeID"] = "الرقم المرجعي",
                            ["buildingTypeCode"] = "رمز نوع المباني",
                            ["buildingTypeName_A"] = "اسم نوع المباني بالعربي",
                            ["buildingTypeName_E"] = "اسم نوع المباني بالانجليزي",
                            ["buildingTypeDescription"] = "ملاحظات"
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

                            bool isbuildingTypeCode = c.ColumnName.Equals("buildingTypeCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                //,Visible = !(isbuildingTypeCode)
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
                                if (rowIdField.Equals("buildingTypeID", StringComparison.OrdinalIgnoreCase) &&
                                    dict.TryGetValue("BuildingTypeID", out var alt))
                                    dict["buildingTypeID"] = alt;
                                else if (rowIdField.Equals("BuildingTypeID", StringComparison.OrdinalIgnoreCase) &&
                                         dict.TryGetValue("buildingTypeID", out var alt2))
                                    dict["BuildingTypeID"] = alt2;
                            }

                            // Prefill pXX fields on the row so Edit form (which uses pXX names) loads the selected row values
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("buildingTypeID") ?? Get("BuildingTypeID");
                            dict["p02"] = Get("buildingTypeCode");
                            dict["p03"] = Get("buildingTypeName_A");
                            dict["p04"] = Get("buildingTypeName_E");
                            dict["p05"] = Get("buildingTypeDescription");

                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception ex)
            {
                ViewBag.BuildingTypeDataSetError = ex.Message;

            }


            // Local helper: map TableColumn -> FieldConfig


            // Local helper: build Edit1 fields (prefer dataset column for general number or fallback)

            // build dynamic field lists
            // REPLACE Add form fields: hide dataset textboxes and use your own custom inputs

            //ADD
            var addFields = new List<FieldConfig>
            {
                // keep id hidden first so row id can flow when needed
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // your custom textboxes
                new FieldConfig { Name = "p01", Label = "رمز نوع المباني", Type = "text", ColCss = "3", Required = true },
                new FieldConfig { Name = "p02", Label = "اسم نوع المباني بالعربي", Type = "arabictext", ColCss = "3" , Required = true,TextMode = "arabic", InputPattern = @"^[\u0621-\u064A\u0640\s]+$", HelpText = "اكتب أحرف عربية فقط"},
                new FieldConfig { Name = "p03", Label = "اسم نوع المباني بالانجليزي", Type = "text", ColCss = "3" , Required = true},
                new FieldConfig { Name = "p04", Label = "ملاحظات", Type = "text", ColCss = "3", Required = false }
            };



            // Inject required hidden headers for the add (insert) form BEFORE building dsModel:
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = Request.Host.Value });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = userID.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraID.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" }); // upper-case
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = PageName });



            // Optional: help the generic endpoint know where to go back
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = PageName });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName });




            //UPDATE
            // Keep pXX as the visible inputs. They will now prefill automatically from the selected row
            // because we injected p01..p05 into each row above.
            // UPDATE fields: make pXX visible (so the binding engine can copy selected row[pXX] values).
            // Do NOT hide p01 if you need to see the selected id; keep it readonly instead of hidden.
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = ControllerName},
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraID.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = userID.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "الرقم المرجعي",             Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رمز نوع المباني",         Type = "number", Required = true,  ColCss = "3" },
                new FieldConfig { Name = "p03", Label = "اسم نوع المباني بالعربي", Type = "text",   ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "اسم نوع المباني بالانجليزي", Type = "text", Required = true, ColCss = "3" },
                new FieldConfig { Name = "p05", Label = "ملاحظات",            Type = "text",   ColCss = "6" }
            };


            // Delete fields: show confirmation as a label (not textbox) and show ID as label while still posting p01
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraID.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = userID.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = Request.Host.Value },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "BuildingTypeID" }
            };



            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
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
                PanelTitle = "عرض ",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = true,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة نوع مباني جديد",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إدخال بيانات نوع المباني الجديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeInsertForm",
                            Title = "بيانات نوع المباني الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success", /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            }
                        }
                    },

                    // Edit: opens populated form for single selection and saves via SP
                    Edit = new TableAction
                    {
                        Label = "تعديل نوع المباني",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات نوع مباني",
                        //ModalMessage = "بسم الله الرحمن الرحيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeEditForm",
                            Title = "تعديل بيانات نوع مباني",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                    },

                    Delete = new TableAction
                    {
                        Label = "حذف نوع مباني",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا نوع المباني؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "BuildingTypeDeleteForm",
                            Title = "تأكيد حذف نوع المباني",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };



            return View(PageName, dsModel);
        }

        [HttpGet("TableForm")]
        public async Task<IActionResult> TableForm()
        {


            if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
                return RedirectToAction("Index", "Login", new { logout = 1 });



             userID = Convert.ToInt32(HttpContext.Session.GetString("usersID"));
             fullName = HttpContext.Session.GetString("fullName");
             IdaraID = Convert.ToInt32(HttpContext.Session.GetString("IdaraID"));
             DepartmentName = HttpContext.Session.GetString("DepartmentName");
             ThameName = HttpContext.Session.GetString("ThameName");
             DeptCode = HttpContext.Session.GetString("DeptCode");
             IDNumber = HttpContext.Session.GetString("IDNumber");
             HostName = HttpContext.Session.GetString("HostName");


            var spParameters = new object?[] { nameof(TableForm), IdaraID, userID, HostName };

            


            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();


            ds = await _mastersServies.GetDataLoadDataSetAsync(spParameters);


            string? Q1 = Request.Query["Q1"].FirstOrDefault();
            string? Q2 = Request.Query["Q2"].FirstOrDefault();
            Q1 = string.IsNullOrWhiteSpace(Q1) ? null : Q1.Trim();
            Q2 = string.IsNullOrWhiteSpace(Q2) ? null : Q2.Trim();


            permissionTable = (ds?.Tables?.Count ?? 0) > 0 ? ds.Tables[0] : null;

            DataTable? rawDt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            
            if (rawDt1 != null)
            {
                if (!string.IsNullOrWhiteSpace(Q1))
                {
                    // Escape single quotes for DataView filter
                    var escaped = Q1.Replace("'", "''");

                    // Exact match (use LIKE '%value%' for contains)
                    var view = new DataView(rawDt1)
                    {
                        RowFilter = $"userID = '{escaped}'"
                        // RowFilter = $"buildingTypeName_A LIKE '%{escaped}%'" // contains alternative
                    };
                    dt1 = view.ToTable();
                }
                else
                {
                    dt1 = rawDt1.Clone();
                }
            }
            else
            {
                dt1 = null;
            }


             dt2 = (ds?.Tables?.Count ?? 0) > 2 ? ds.Tables[2] : null;
             dt3 = (ds?.Tables?.Count ?? 0) > 3 ? ds.Tables[3] : null;
             dt4 = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
             dt5 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;
             dt6 = (ds?.Tables?.Count ?? 0) > 6 ? ds.Tables[6] : null;
             dt7 = (ds?.Tables?.Count ?? 0) > 7 ? ds.Tables[7] : null;
             dt8 = (ds?.Tables?.Count ?? 0) > 8 ? ds.Tables[8] : null;
             dt9 = (ds?.Tables?.Count ?? 0) > 9 ? ds.Tables[9] : null;

            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }



            string rowIdField = "";
            bool canInsert = false;
            bool canUpdate = false;
            bool canDelete = false;



            List<OptionItem> UsersOptions = new();
            List<OptionItem> distributorOptions = new();
            List<OptionItem> permissionsOptions = new();






            FormConfig form = new();
            try
            {



                //To make User options list for dropdownlist later

                if (ds != null && ds.Tables.Count > 1 && ds.Tables[2].Rows.Count > 0)
                {
                    var userTable = ds.Tables[2];

                    foreach (DataRow row in userTable.Rows)
                    {
                        string value = row["userID_"]?.ToString()?.Trim() ?? "";
                        string text = row["FullName"]?.ToString()?.Trim() ?? "";

                        if (!string.IsNullOrEmpty(value))
                            UsersOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }



                //To make distributor options list for dropdownlist later

                if (ds != null && ds.Tables.Count > 1 && ds.Tables[3].Rows.Count > 0)
                {
                    var distributorTable = ds.Tables[3];
                    distributorOptions.Add(new OptionItem { Value = "-1", Text = "الرجاء اختيار الموزع" });
                    foreach (DataRow row in distributorTable.Rows)
                    {
                        string value = row["distributorID"]?.ToString()?.Trim() ?? "";
                        string text = row["distributorName_A"]?.ToString()?.Trim() ?? "";

                        if (!string.IsNullOrEmpty(value))
                            distributorOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }



                //To make permission options list for dropdownlist later

                if (ds != null && ds.Tables.Count > 1 && ds.Tables[4].Rows.Count > 0)
                {
                    var permissionsTable = ds.Tables[4];
                    permissionsOptions.Add(new OptionItem { Value = "-1", Text = "الرجاء اختيار الصلاحية" });
                    foreach (DataRow row in permissionsTable.Rows)
                    {
                        string value = row["distributorPermissionTypeID"]?.ToString()?.Trim() ?? "";
                        string text = row["permissionTypeName_A"]?.ToString()?.Trim() ?? "";

                        if (!string.IsNullOrEmpty(value))
                            permissionsOptions.Add(new OptionItem { Value = value, Text = text });
                    }
                }






                form = new FormConfig
                {
                    FormId = "dynamicForm",
                    Title = "نموذج الإدخال",
                    Method = "POST",
                    //   ActionUrl = "/AllComponentsDemo/ExecuteDemo",

                    StoredProcedureName = "sp_SaveDemoForm",
                    Operation = "insert",
                    StoredSuccessMessageField = "Message",
                    StoredErrorMessageField = "Error",

                    Fields = new List<FieldConfig>
                {
                    // ========= البيانات الشخصية =========
                    

                    

                     new FieldConfig {
                         SectionTitle = "البحث عن مستخدم",
                         Name = "Users",

                         Type = "select",
                         Options = UsersOptions,
                         ColCss = "6",
                         Placeholder = "اختر المستخدم",
                         Icon = "fa fa-user" ,
                         Value = Q1

                     },

                    //      new FieldConfig
                    //{


                    //    Name = "FullName",
                    //    Label = "إدخال نص",
                    //    Type = "text",
                    //    Required = true,
                    //    Placeholder = "حقل عربي فقط",
                    //    Icon = "fa-solid fa-user",
                    //    ColCss = "col-span-12 md:col-span-3",
                    //    MaxLength = 50,
                    //    TextMode = "text",
                    //    Value = filterNameAr,
                    //},


                        },


                    Buttons = new List<FormButtonConfig>
                {
                         new FormButtonConfig
                {
                    Text="بحث",
                    Icon="fa-solid fa-search",
                    Type="button",
                    Color="success",
                    // Replace the OnClickJs of the "تجربة" button with this:
                    OnClickJs = "(function(){"
              + "var hidden=document.querySelector('input[name=Users]');"
              + "if(!hidden){toastr.error('لا يوجد حقل مستخدم');return;}"
              + "var userId = (hidden.value||'').trim();"
              + "var anchor = hidden.parentElement.querySelector('.sf-select');"
              + "var userName = anchor && anchor.querySelector('.truncate') ? anchor.querySelector('.truncate').textContent.trim() : '';"
              + "if(!userId){toastr.info('اختر مستخدم أولاً');return;}"
              + "var url = '/ControlPanel/Permission?Q1=' + encodeURIComponent(userId);"
              + "window.location.href = url;"
              + "})();"
                },
             
    
                    }
                };

                if (ds != null && ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
                {
                    // اقرأ الجدول الأول


                    // نبحث عن صلاحيات محددة داخل الجدول
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERT")
                            canInsert = true;

                        if (permissionName == "UPDATE")
                            canUpdate = true;

                        if (permissionName == "DELETE")
                            canDelete = true;
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
                            ["permissionID"] = "المعرف",
                            ["menuName_A"] = "اسم الصفحة",
                            ["permissionTypeName_A"] = "الصلاحية",
                            ["permissionStartDate"] = "تاريخ بداية الصلاحية",
                            ["permissionEndDate"] = "تاريخ نهاية الصلاحية"
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

                            bool isuserID = c.ColumnName.Equals("userID", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column 
                                ,
                                Visible = !(isuserID)
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
                            dict["p01"] = Get("permissionID") ?? Get("permissionID") ?? Get("Id") ?? Get("ID");
                            dict["p02"] = Get("menuName_A");
                            dict["p03"] = Get("permissionTypeName_A");
                            dict["p04"] = Get("permissionStartDate");
                            dict["p05"] = Get("permissionStartDate");

                            rowsList.Add(dict);
                        }
                    }


                }
            }
            catch (Exception ex)
            {
                ViewBag.DataSetError = ex.Message;

            }


            // Local helper: map TableColumn -> FieldConfig


            // Local helper: build Edit1 fields (prefer dataset column for general number or fallback)

            // build dynamic field lists
            // REPLACE Add form fields: hide dataset textboxes and use your own custom inputs

            //ADD
            var addFields = new List<FieldConfig>
            {
                // keep id hidden first so row id can flow when needed
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // your custom textboxes
new FieldConfig
{
    Name = "p01",
    Label = "الموزع",
    Type = "select",
    Options = distributorOptions,
    ColCss = "3",
    Required = true
},

new FieldConfig
{
    Name = "p02",
    Label = "الصلاحية",
    Type = "select",
    Options = new List<OptionItem> { new OptionItem { Value = "-1", Text = "اختر الموزع أولاً" } }, // Initial empty state
    ColCss = "3",
    Required = true,
    DependsOn = "p01",              // When p01 changes, fetch new options
    //DependsUrl = "/crud/DDLFiltered" // Endpoint that returns filtered options
    DependsUrl = "/crud/DDLFiltered?FK=distributorID_FK&textcol=permissionTypeName_A&ValueCol=distributorPermissionTypeID&PageName=Permission&TableIndex=4"
},

                new FieldConfig { Name = "p03", Label = "ملاحظات", Type = "date", ColCss = "3", Required = false }
            };



            // Inject required hidden headers for the add (insert) form BEFORE building dsModel:
            addFields.Insert(0, new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") });
            addFields.Insert(0, new FieldConfig { Name = "hostname", Type = "hidden", Value = HostName });
            addFields.Insert(0, new FieldConfig { Name = "entrydata", Type = "hidden", Value = userID.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "idaraID", Type = "hidden", Value = IdaraID.ToString() });
            addFields.Insert(0, new FieldConfig { Name = "ActionType", Type = "hidden", Value = "INSERT" }); // upper-case
            addFields.Insert(0, new FieldConfig { Name = "pageName_", Type = "hidden", Value = nameof(TableForm) });



            // Optional: help the generic endpoint know where to go back
            addFields.Insert(0, new FieldConfig { Name = "redirectAction", Type = "hidden", Value = nameof(TableForm) });
            addFields.Insert(0, new FieldConfig { Name = "redirectController", Type = "hidden", Value = nameof(AllComponentsDemoController) });




            //UPDATE
            // Keep pXX as the visible inputs. They will now prefill automatically from the selected row
            // because we injected p01..p05 into each row above.
            // UPDATE fields: make pXX visible (so the binding engine can copy selected row[pXX] values).
            // Do NOT hide p01 if you need to see the selected id; keep it readonly instead of hidden.
            var updateFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",      Type = "hidden", Value = nameof(TableForm) },
                new FieldConfig { Name = "redirectController",  Type = "hidden", Value = nameof(AllComponentsDemoController) },
                new FieldConfig { Name = "pageName_",           Type = "hidden", Value = nameof(TableForm) },
                new FieldConfig { Name = "ActionType",          Type = "hidden", Value = "UPDATE" },
                new FieldConfig { Name = "idaraID",             Type = "hidden", Value = IdaraID.ToString() },
                new FieldConfig { Name = "entrydata",           Type = "hidden", Value = userID.ToString() },
                new FieldConfig { Name = "hostname",            Type = "hidden", Value = HostName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },
                new FieldConfig { Name = rowIdField,            Type = "hidden" },

                new FieldConfig { Name = "p01", Label = "المعرف",             Type = "hidden", Readonly = true, ColCss = "3" },
                new FieldConfig { Name = "p02", Label = "رمز المبنى",         Type = "number", Required = true,  ColCss = "3" },
                new FieldConfig { Name = "p03", Label = "اسم المبنى بالعربي", Type = "text",   ColCss = "3", TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "اسم المبنى بالانجليزي", Type = "text", Required = true, ColCss = "3" },
                new FieldConfig { Name = "p05", Label = "ملاحظات",            Type = "text",   ColCss = "6" }
            };


            // Delete fields: show confirmation as a label (not textbox) and show ID as label while still posting p01
            var deleteFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = nameof(TableForm) },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = nameof(AllComponentsDemoController) },
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = nameof(TableForm) },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETE" },
                new FieldConfig { Name = "idaraID",            Type = "hidden", Value = IdaraID.ToString() },
                new FieldConfig { Name = "entrydata",          Type = "hidden", Value = userID.ToString() },
                new FieldConfig { Name = "hostname",           Type = "hidden", Value = HostName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = (Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "") },

                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "BuildingTypeID" }
            };


            bool hasRows = dt1 is not null && dt1.Rows.Count > 0 && rowsList.Count > 0;
            ViewBag.HideTable = !hasRows;
            // then create dsModel (snippet shows toolbar parts that use the dynamic lists)
            var dsModel = new SmartFoundation.UI.ViewModels.SmartTable.SmartTableDsModel
            {
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 100 },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                PageTitle = "إدارة الصلاحيات",
                PanelTitle = "عرض ",
                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = true,
                    ShowExportExcel = false,
                    ShowAdd = canInsert,
                    ShowEdit = canUpdate,
                    ShowDelete = canDelete,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة صلاحية",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة صلاحية جديد",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeInsertForm",
                            Title = "بيانات الموظف الجديد",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            Fields = addFields,
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حفظ", Type = "submit", Color = "success" /*Icon = "fa fa-save"*/ },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", /*Icon = "fa fa-times",*/ OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" },

                            }
                        }
                    },

                    // Edit: opens populated form for single selection and saves via SP
                    Edit = new TableAction
                    {
                        Label = "تعديل صلاحية",
                        Icon = "fa fa-pen-to-square",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل بيانات الموظف",
                        //ModalMessage = "بسم الله الرحمن الرحيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeEditForm",
                            Title = "تعديل بيانات الموظف",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = updateFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1


                    },

                    Delete = new TableAction
                    {
                        Label = "ايقاف صلاحية",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        //ModalTitle = "رسالة تحذيرية",
                        ModalTitle = "<i class='fa fa-exclamation-triangle text-red-600 text-xl mr-2'></i> تحذير",
                        ModalMessage = "هل أنت متأكد من حذف هذا السجل؟",
                        OpenForm = new FormConfig
                        {
                            FormId = "employeeDeleteForm",
                            Title = "تأكيد حذف السجل",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            Buttons = new List<FormButtonConfig>
                            {
                                new FormButtonConfig { Text = "حذف", Type = "submit", Color = "danger", Icon = "fa fa-save" },
                                new FormButtonConfig { Text = "إلغاء", Type = "button", Color = "secondary", Icon = "fa fa-times", OnClickJs = "this.closest('.sf-modal').__x.$data.closeModal();" }
                            },
                            Fields = deleteFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1
                    },
                }
            };

            var vm = new SmartFoundation.UI.ViewModels.SmartPage.FormTableViewModel
            {
                Form = form,
                Table = dsModel,
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle
            };
            return View(nameof(TableForm), vm);
        }


        [HttpPost("Submit")]
        public IActionResult Submit()
        {
            TempData["Success"] = "تم تنفيذ العملية بنجاح!";
            return RedirectToAction("Index");
        }

        [HttpPost("ExecuteDemo")]
        public IActionResult ExecuteDemo([FromBody] SmartRequest req)
        {
            
            if (req.SpName == "sp_GetDemoData")
            {
                // تحديد عدد السجلات المطلوبة حسب الصفحة المطلوبة
                int pageSize = req.Paging?.Size ?? 10;
                int pageNumber = req.Paging?.Page ?? 1;
                int totalItems = 25; 
                
                // حساب السجلات المطلوبة للصفحة الحالية
                int startIndex = (pageNumber - 1) * pageSize;
                int endIndex = Math.Min(startIndex + pageSize, totalItems);
                int itemsToReturn = Math.Max(0, endIndex - startIndex);
                
                // إنشاء بيانات تجريبية
                var rows = Enumerable.Range(startIndex + 1, itemsToReturn).Select(i => new Dictionary<string, object?>
                {
                    ["Id"] = i,
                    ["FullName"] = $"مستخدم {i}",
                    ["Email"] = $"user{i}@example.com",
                    ["CreatedAt"] = DateTime.Now.AddDays(-i).ToString("yyyy-MM-dd")
                }).ToList();

                // فلترة حسب البحث إذا وجد
                if (req.Filters?.Count > 0)
                {
                   
                    var searchFilter = req.Filters.FirstOrDefault(f => f.Field == "q" || f.Field == "search");
                    if (searchFilter != null && searchFilter.Value != null)
                    {
                        string searchTerm = searchFilter.Value.ToString()?.ToLower() ?? "";
                        if (!string.IsNullOrWhiteSpace(searchTerm))
                        {
                            rows = rows.Where(r => 
                                r["FullName"]?.ToString()?.Contains(searchTerm, StringComparison.OrdinalIgnoreCase) == true ||
                                r["Email"]?.ToString()?.Contains(searchTerm, StringComparison.OrdinalIgnoreCase) == true
                            ).ToList();
                        }
                    }
                }

               
                if (req.Sort != null && !string.IsNullOrEmpty(req.Sort.Field))
                {
                   
                    bool isDesc = req.Sort.Dir?.ToLower() == "desc";
                    
                    if (req.Sort.Field == "Id")
                    {
                        rows = isDesc 
                            ? rows.OrderByDescending(r => Convert.ToInt32(r["Id"])).ToList() 
                            : rows.OrderBy(r => Convert.ToInt32(r["Id"])).ToList();
                    }
                    else if (req.Sort.Field == "FullName")
                    {
                        rows = isDesc
                            ? rows.OrderByDescending(r => r["FullName"]?.ToString()).ToList()
                            : rows.OrderBy(r => r["FullName"]?.ToString()).ToList();
                    }
                    else if (req.Sort.Field == "Email")
                    {
                        rows = isDesc
                            ? rows.OrderByDescending(r => r["Email"]?.ToString()).ToList()
                            : rows.OrderBy(r => r["Email"]?.ToString()).ToList();
                    }
                    else if (req.Sort.Field == "CreatedAt")
                    {
                        rows = isDesc
                            ? rows.OrderByDescending(r => r["CreatedAt"]?.ToString()).ToList()
                            : rows.OrderBy(r => r["CreatedAt"]?.ToString()).ToList();
                    }
                }

                return Ok(new SmartResponse
                {
                    Success = true,
                    Data = rows,
                    Total = totalItems,
                    Page = pageNumber,
                    Size = pageSize
                });
            }

            // أي طلب آخر
            return Ok(new SmartResponse
            {
                Success = false,
                Error = $"SP غير معروف: {req.SpName}"
            });
        }
    }
}
