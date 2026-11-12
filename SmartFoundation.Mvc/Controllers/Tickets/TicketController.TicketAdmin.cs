using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.DataLoad;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;


namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        public async Task<IActionResult> TicketAdmin([FromServices] RequestScopedDataLoadService requestDataLoad)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out var redirect))
                return redirect!;

            ControllerName = "Ticket";
            PageName = string.IsNullOrWhiteSpace(PageName) ? "TicketAdmin" : PageName;

            var ddlParameters = new Dictionary<string, object?>(
               StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName ?? "TicketAdmin"
            };

            if (IdaraId != null)
                ddlParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                ddlParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                ddlParameters["hostname"] = HostName;

            // معاملات تحميل بيانات الصفحة.
            var pageParameters = new Dictionary<string, object?>(
                ddlParameters,
                StringComparer.OrdinalIgnoreCase);

            // Masters_DataLoad -> [Tickets].[TicketAdminDL]
            // [0] الصلاحيات  [1] الخدمات  [2] فئات التذاكر (DDL)  [3] الأولويات (DDL)
            // [4] قواعد التوجيه  [5] سياسات SLA  [6] اقتراحات الخدمات  [7] قائمة الخدمات
            // [8] فئات التذاكر  [9] الأولويات  [10] حالات التذكرة  [11] أسباب الإيقاف
            // [12] أسباب التحكيم  [13] نتائج مراجعة الجودة  [14] قضايا التحكيم المفتوحة  [15] الجهات (DDL)
            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);


            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            //  التحقق من الصلاحيات
            if (permissionTable is null || permissionTable.Rows.Count == 0)
            {
                TempData["Error"] = "تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة";
                return RedirectToAction("Index", "Home");
            }

            DataTable? dt10 = ds.Tables.Count > 10 ? ds.Tables[10] : null;
            DataTable? dt11 = ds.Tables.Count > 11 ? ds.Tables[11] : null;
            DataTable? dt12 = ds.Tables.Count > 12 ? ds.Tables[12] : null;
            DataTable? dt13 = ds.Tables.Count > 13 ? ds.Tables[13] : null;
            DataTable? dt14 = ds.Tables.Count > 14 ? ds.Tables[14] : null;
            DataTable? dt18 = ds.Tables.Count > 18 ? ds.Tables[18] : null;

            string rowIdField = "";
            bool canINSERTSERVICE = false;
            bool canUPDATESERVICE = false;
            bool canDELETESERVICE = false;
            bool canINSERTTICKETCLASS = false;
            bool canUPDATETICKETCLASS = false;
            bool canDELETETICKETCLASS = false;
            bool canINSERTPRIORITY = false;
            bool canUPDATEPRIORITY = false;
            bool canDELETEPRIORITY = false;
            bool canINSERTTICKETSTATUS = false;
            bool canUPDATETICKETSTATUS = false;
            bool canDELETETICKETSTATUS = false;
            bool canINSERTPAUSEREASON = false;
            bool canUPDATEPAUSEREASON = false;
            bool canDELETEPAUSEREASON = false;
            bool canINSERTARBITRATIONREASON = false;
            bool canUPDATEARBITRATIONREASON = false;
            bool canDELETEARBITRATIONREASON = false;
            bool canINSERTQUALITYREVIEWRESULT = false;
            bool canUPDATEQUALITYREVIEWRESULT = false;
            bool canDELETEQUALITYREVIEWRESULT = false;
            bool canDECIDE_ARBITRATION = false;
            bool canCANCEL_ARBITRATION = false;

            var rowsList = new List<Dictionary<string, object?>>();
            var dynamicColumns = new List<TableColumn>();
            var rowsList_dt8 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt8 = new List<TableColumn>();
            var rowsList_dt9 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt9 = new List<TableColumn>();
            var rowsList_dt10 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt10 = new List<TableColumn>();
            var rowsList_dt11 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt11 = new List<TableColumn>();
            var rowsList_dt12 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt12 = new List<TableColumn>();
            var rowsList_dt13 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt13 = new List<TableColumn>();
            var rowsList_dt14 = new List<Dictionary<string, object?>>();
            var dynamicColumns_dt14 = new List<TableColumn>();


            List<OptionItem> TicketClassOptions = new();
            List<OptionItem> PriorityOptions = new();
            List<OptionItem> DsdOptions = new();
            List<OptionItem> DepartmentOptions = new();


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

            TicketClassOptions = ReadOptions(
                ddlDs,
                2,
                "ticketClassName_A",
                "ticketClassID");

            PriorityOptions = ReadOptions(
                ddlDs,
                3,
                "priorityName_A",
                "priorityID");

            DsdOptions = ReadOptions(
                ddlDs,
                15,
                "dsdName_A",
                "DSDID");

            DepartmentOptions = ReadOptions(
                ddlDs,
                16,
                "deptName_A",
                "DSDID");

            // الفرع والشعبة تُحمَّل حسب الاختيار السابق من شجرة الجهات [17]
            const string unitListUrl = "/crud/DDLFiltered?FK=parentDSDID&textcol=nodeName_A&ValueCol=DSDID&PageName=TicketAdmin&TableIndex=17";

            // END DDL

            // نوع العمود حسب نوع البيانات (نفس قاعدة صفحات الإسكان)
            static string ColumnType(DataColumn c)
            {
                var t = c.DataType;
                if (t == typeof(bool)) return "bool";
                if (t == typeof(DateTime)) return "date";
                if (t == typeof(byte) || t == typeof(short) || t == typeof(int) || t == typeof(long)
                    || t == typeof(float) || t == typeof(double) || t == typeof(decimal))
                    return "number";
                return "text";
            }

            const string systemCodes = " — الأكواد الإنجليزية الكاملة ثابتة للنظام";

            try
            {
                if (ds != null && ds.Tables.Count > 0 && permissionTable!.Rows.Count > 0)
                {
                    // صلاحيات
                    foreach (DataRow row in permissionTable.Rows)
                    {
                        var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();

                        if (permissionName == "INSERTSERVICE") canINSERTSERVICE = true;
                        if (permissionName == "UPDATESERVICE") canUPDATESERVICE = true;
                        if (permissionName == "DELETESERVICE") canDELETESERVICE = true;
                        if (permissionName == "INSERTTICKETCLASS") canINSERTTICKETCLASS = true;
                        if (permissionName == "UPDATETICKETCLASS") canUPDATETICKETCLASS = true;
                        if (permissionName == "DELETETICKETCLASS") canDELETETICKETCLASS = true;
                        if (permissionName == "INSERTPRIORITY") canINSERTPRIORITY = true;
                        if (permissionName == "UPDATEPRIORITY") canUPDATEPRIORITY = true;
                        if (permissionName == "DELETEPRIORITY") canDELETEPRIORITY = true;
                        if (permissionName == "INSERTTICKETSTATUS") canINSERTTICKETSTATUS = true;
                        if (permissionName == "UPDATETICKETSTATUS") canUPDATETICKETSTATUS = true;
                        if (permissionName == "DELETETICKETSTATUS") canDELETETICKETSTATUS = true;
                        if (permissionName == "INSERTPAUSEREASON") canINSERTPAUSEREASON = true;
                        if (permissionName == "UPDATEPAUSEREASON") canUPDATEPAUSEREASON = true;
                        if (permissionName == "DELETEPAUSEREASON") canDELETEPAUSEREASON = true;
                        if (permissionName == "INSERTARBITRATIONREASON") canINSERTARBITRATIONREASON = true;
                        if (permissionName == "UPDATEARBITRATIONREASON") canUPDATEARBITRATIONREASON = true;
                        if (permissionName == "DELETEARBITRATIONREASON") canDELETEARBITRATIONREASON = true;
                        if (permissionName == "INSERTQUALITYREVIEWRESULT") canINSERTQUALITYREVIEWRESULT = true;
                        if (permissionName == "UPDATEQUALITYREVIEWRESULT") canUPDATEQUALITYREVIEWRESULT = true;
                        if (permissionName == "DELETEQUALITYREVIEWRESULT") canDELETEQUALITYREVIEWRESULT = true;
                        if (permissionName == "DECIDE_ARBITRATION") canDECIDE_ARBITRATION = true;
                        if (permissionName == "CANCEL_ARBITRATION") canCANCEL_ARBITRATION = true;
                    }

                    // ===================== [1] الخدمات =====================
                    if (dt1 != null && dt1.Columns.Count > 0)
                    {
                        // RowId
                        rowIdField = "serviceID";
                        var possibleIdNames = new[] { "serviceID", "ServiceID", "Id", "ID" };
                        rowIdField = possibleIdNames.FirstOrDefault(n => dt1.Columns.Contains(n))
                                     ?? dt1.Columns[0].ColumnName;

                        // عناوين الأعمدة بالعربي
                        var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["serviceID"] = "رقم الخدمة",
                            ["serviceCode"] = "كود الخدمة",
                            ["serviceName_A"] = "اسم الخدمة",
                            ["serviceName_E"] = "اسم الخدمة (إنجليزي)",
                            ["serviceDesc"] = "الوصف",
                            ["ticketClassName_A"] = "فئة التذكرة",
                            ["priorityName_A"] = "الأولوية الافتراضية",
                            ["requiresLocation"] = "يتطلب موقع",
                            ["allowsChildTickets"] = "تذاكر فرعية",
                            ["requiresQualityReview"] = "مراجعة جودة",
                            ["serviceActive"] = "نشط"
                        };

                        // الأعمدة
                        foreach (DataColumn c in dt1.Columns)
                        {
                            string colType = ColumnType(c);
                            bool isserviceID = c.ColumnName.Equals("serviceID", StringComparison.OrdinalIgnoreCase);
                            bool isidaraID_FK = c.ColumnName.Equals("idaraID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isticketClassID_FK = c.ColumnName.Equals("ticketClassID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isdefaultPriorityID_FK = c.ColumnName.Equals("defaultPriorityID_FK", StringComparison.OrdinalIgnoreCase);
                            bool isserviceName_E = c.ColumnName.Equals("serviceName_E", StringComparison.OrdinalIgnoreCase);
                            bool isticketClassName_E = c.ColumnName.Equals("ticketClassName_E", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityName_E = c.ColumnName.Equals("priorityName_E", StringComparison.OrdinalIgnoreCase);
                            bool isserviceActive = c.ColumnName.Equals("serviceActive", StringComparison.OrdinalIgnoreCase);
                            bool isserviceCode = c.ColumnName.Equals("serviceCode", StringComparison.OrdinalIgnoreCase);

                            bool isticketClassName_A = c.ColumnName.Equals("ticketClassName_A", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityName_A = c.ColumnName.Equals("priorityName_A", StringComparison.OrdinalIgnoreCase);

                            //  جهز خيارات الفلتر من نفس بيانات الجدول (عشان التطابق يكون صحيح)
                            List<OptionItem> filterOpts = new();
                            if (isticketClassName_A || ispriorityName_A)
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
                                Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = colType,
                                Sortable = true
                                //if u want to hide any column
                                ,
                                Visible = !(isserviceID || isidaraID_FK || isticketClassID_FK || isdefaultPriorityID_FK
                                || isserviceName_E || isticketClassName_E || ispriorityName_E || isserviceActive),

                                // شرح اختصار الكود
                                Tooltip = isserviceCode ? "SRV = Service = خدمة" : null,

                                //  فلتر لفئة التذكرة + الأولوية
                                Filter = (isticketClassName_A || ispriorityName_A)
                                    ? new TableColumnFilter
                                    {
                                        Enabled = true,
                                        Type = "select",
                                        Options = filterOpts,
                                    }
                                    : new TableColumnFilter
                                    {
                                        Enabled = false
                                    }
                            });


                        }

                        // الجهة المسؤولة: عمود عرض بعد اسم الخدمة (البيانات من الجدول [18])
                        var serviceNameIndex = dynamicColumns.FindIndex(col => col.Field.Equals("serviceName_A", StringComparison.OrdinalIgnoreCase));
                        dynamicColumns.Insert(serviceNameIndex >= 0 ? serviceNameIndex + 1 : dynamicColumns.Count, new TableColumn
                        {
                            Field = "responsibleUnit",
                            Label = "الجهة المسؤولة",
                            Type = "text",
                            Sortable = true,
                            Visible = true
                        });

                        // serviceID -> صف الجهة الحالية للخدمة
                        var serviceUnits = new Dictionary<string, DataRow>(StringComparer.OrdinalIgnoreCase);
                        if (dt18 != null && dt18.Columns.Contains("serviceID"))
                        {
                            foreach (DataRow u in dt18.Rows)
                            {
                                var serviceKey = u["serviceID"]?.ToString()?.Trim();
                                if (!string.IsNullOrEmpty(serviceKey))
                                    serviceUnits[serviceKey] = u;
                            }
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

                            // الجهة المسؤولة + قسم/فرع/شعبة لتعبئة نموذج التعديل (p11..p13)
                            serviceUnits.TryGetValue(r["serviceID"]?.ToString()?.Trim() ?? "", out var unitRow);
                            object? Unit(string key) => unitRow == null || unitRow[key] == DBNull.Value ? null : unitRow[key];
                            dict["responsibleUnit"] = Unit("responsibleUnit") ?? "-";
                            dict["p11"] = Unit("unitDeptDSDID");
                            dict["p12"] = Unit("unitSecDSDID");
                            dict["p13"] = Unit("unitDivDSDID");

                            // p01..p10
                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("serviceID");
                            dict["p02"] = Get("serviceCode");
                            dict["p03"] = Get("serviceName_A");
                            dict["p04"] = Get("serviceName_E");
                            dict["p05"] = Get("serviceDesc");
                            dict["p06"] = Get("ticketClassID_FK");
                            dict["p07"] = Get("defaultPriorityID_FK");
                            dict["p08"] = Get("requiresLocation");
                            dict["p09"] = Get("allowsChildTickets");
                            dict["p10"] = Get("requiresQualityReview");

                            rowsList.Add(dict);
                        }
                    }

                    // ===================== [8] فئات التذاكر =====================
                    if (dt8 != null && dt8.Columns.Count > 0)
                    {
                        var headerMap_dt8 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ticketClassID"] = "رقم الفئة",
                            ["ticketClassCode"] = "الكود",
                            ["ticketClassName_A"] = "الاسم (عربي)",
                            ["ticketClassName_E"] = "الاسم (إنجليزي)",
                            ["ticketClassDesc"] = "الوصف",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt8.Columns)
                        {
                            bool isticketClassID = c.ColumnName.Equals("ticketClassID", StringComparison.OrdinalIgnoreCase);
                            bool isticketClassName_E = c.ColumnName.Equals("ticketClassName_E", StringComparison.OrdinalIgnoreCase);
                            bool isticketClassCode = c.ColumnName.Equals("ticketClassCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt8.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt8.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(isticketClassID || isticketClassName_E),
                                Tooltip = isticketClassCode ? "CLS = Class = فئة التذكرة" : null
                            });
                        }

                        foreach (DataRow r in dt8.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt8.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ticketClassID");
                            dict["p02"] = Get("ticketClassCode");
                            dict["p03"] = Get("ticketClassName_A");
                            dict["p04"] = Get("ticketClassName_E");
                            dict["p05"] = Get("ticketClassDesc");

                            rowsList_dt8.Add(dict);
                        }
                    }

                    // ===================== [9] الأولويات =====================
                    if (dt9 != null && dt9.Columns.Count > 0)
                    {
                        var headerMap_dt9 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["priorityID"] = "رقم الأولوية",
                            ["priorityCode"] = "الكود",
                            ["priorityName_A"] = "الاسم (عربي)",
                            ["priorityName_E"] = "الاسم (إنجليزي)",
                            ["priorityDesc"] = "الوصف",
                            ["priorityLevel"] = "المستوى",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt9.Columns)
                        {
                            bool ispriorityID = c.ColumnName.Equals("priorityID", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityName_E = c.ColumnName.Equals("priorityName_E", StringComparison.OrdinalIgnoreCase);
                            bool ispriorityCode = c.ColumnName.Equals("priorityCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt9.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt9.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(ispriorityID || ispriorityName_E),
                                Tooltip = ispriorityCode ? "PRI = Priority = الأولوية" + systemCodes : null
                            });
                        }

                        foreach (DataRow r in dt9.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt9.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("priorityID");
                            dict["p02"] = Get("priorityCode");
                            dict["p03"] = Get("priorityName_A");
                            dict["p04"] = Get("priorityName_E");
                            dict["p05"] = Get("priorityDesc");
                            dict["p06"] = Get("priorityLevel");

                            rowsList_dt9.Add(dict);
                        }
                    }

                    // ===================== [10] حالات التذكرة =====================
                    if (dt10 != null && dt10.Columns.Count > 0)
                    {
                        var headerMap_dt10 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["ticketStatusID"] = "رقم الحالة",
                            ["ticketStatusCode"] = "الكود",
                            ["ticketStatusName_A"] = "الاسم (عربي)",
                            ["ticketStatusName_E"] = "الاسم (إنجليزي)",
                            ["ticketStatusDesc"] = "الوصف",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt10.Columns)
                        {
                            bool isticketStatusID = c.ColumnName.Equals("ticketStatusID", StringComparison.OrdinalIgnoreCase);
                            bool isticketStatusName_E = c.ColumnName.Equals("ticketStatusName_E", StringComparison.OrdinalIgnoreCase);
                            bool isticketStatusCode = c.ColumnName.Equals("ticketStatusCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt10.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt10.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(isticketStatusID || isticketStatusName_E),
                                Tooltip = isticketStatusCode ? "STS = Status = حالة التذكرة" + systemCodes : null
                            });
                        }

                        foreach (DataRow r in dt10.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt10.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("ticketStatusID");
                            dict["p02"] = Get("ticketStatusCode");
                            dict["p03"] = Get("ticketStatusName_A");
                            dict["p04"] = Get("ticketStatusName_E");
                            dict["p05"] = Get("ticketStatusDesc");

                            rowsList_dt10.Add(dict);
                        }
                    }

                    // ===================== [11] أسباب الإيقاف =====================
                    if (dt11 != null && dt11.Columns.Count > 0)
                    {
                        var headerMap_dt11 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["pauseReasonID"] = "رقم السبب",
                            ["pauseReasonCode"] = "الكود",
                            ["pauseReasonName_A"] = "الاسم (عربي)",
                            ["pauseReasonName_E"] = "الاسم (إنجليزي)",
                            ["pauseReasonDesc"] = "الوصف",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt11.Columns)
                        {
                            bool ispauseReasonID = c.ColumnName.Equals("pauseReasonID", StringComparison.OrdinalIgnoreCase);
                            bool ispauseReasonName_E = c.ColumnName.Equals("pauseReasonName_E", StringComparison.OrdinalIgnoreCase);
                            bool ispauseReasonCode = c.ColumnName.Equals("pauseReasonCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt11.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt11.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(ispauseReasonID || ispauseReasonName_E),
                                Tooltip = ispauseReasonCode ? "PSR = Pause Reason = سبب الإيقاف" + systemCodes : null
                            });
                        }

                        foreach (DataRow r in dt11.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt11.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("pauseReasonID");
                            dict["p02"] = Get("pauseReasonCode");
                            dict["p03"] = Get("pauseReasonName_A");
                            dict["p04"] = Get("pauseReasonName_E");
                            dict["p05"] = Get("pauseReasonDesc");

                            rowsList_dt11.Add(dict);
                        }
                    }

                    // ===================== [12] أسباب التحكيم =====================
                    if (dt12 != null && dt12.Columns.Count > 0)
                    {
                        var headerMap_dt12 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["arbitrationReasonID"] = "رقم السبب",
                            ["arbitrationReasonCode"] = "الكود",
                            ["arbitrationReasonName_A"] = "الاسم (عربي)",
                            ["arbitrationReasonName_E"] = "الاسم (إنجليزي)",
                            ["arbitrationReasonDesc"] = "الوصف",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt12.Columns)
                        {
                            bool isarbitrationReasonID = c.ColumnName.Equals("arbitrationReasonID", StringComparison.OrdinalIgnoreCase);
                            bool isarbitrationReasonName_E = c.ColumnName.Equals("arbitrationReasonName_E", StringComparison.OrdinalIgnoreCase);
                            bool isarbitrationReasonCode = c.ColumnName.Equals("arbitrationReasonCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt12.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt12.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(isarbitrationReasonID || isarbitrationReasonName_E),
                                Tooltip = isarbitrationReasonCode ? "ARB = Arbitration = سبب التحكيم" : null
                            });
                        }

                        foreach (DataRow r in dt12.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt12.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("arbitrationReasonID");
                            dict["p02"] = Get("arbitrationReasonCode");
                            dict["p03"] = Get("arbitrationReasonName_A");
                            dict["p04"] = Get("arbitrationReasonName_E");
                            dict["p05"] = Get("arbitrationReasonDesc");

                            rowsList_dt12.Add(dict);
                        }
                    }

                    // ===================== [13] نتائج مراجعة الجودة =====================
                    if (dt13 != null && dt13.Columns.Count > 0)
                    {
                        var headerMap_dt13 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["qualityReviewResultID"] = "رقم النتيجة",
                            ["qualityReviewResultCode"] = "الكود",
                            ["qualityReviewResultName_A"] = "الاسم (عربي)",
                            ["qualityReviewResultName_E"] = "الاسم (إنجليزي)",
                            ["qualityReviewResultDesc"] = "الوصف",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt13.Columns)
                        {
                            bool isqualityReviewResultID = c.ColumnName.Equals("qualityReviewResultID", StringComparison.OrdinalIgnoreCase);
                            bool isqualityReviewResultName_E = c.ColumnName.Equals("qualityReviewResultName_E", StringComparison.OrdinalIgnoreCase);
                            bool isqualityReviewResultCode = c.ColumnName.Equals("qualityReviewResultCode", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt13.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt13.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !(isqualityReviewResultID || isqualityReviewResultName_E),
                                Tooltip = isqualityReviewResultCode ? "QRR = Quality Review Result = نتيجة مراجعة الجودة" + systemCodes : null
                            });
                        }

                        foreach (DataRow r in dt13.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt13.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("qualityReviewResultID");
                            dict["p02"] = Get("qualityReviewResultCode");
                            dict["p03"] = Get("qualityReviewResultName_A");
                            dict["p04"] = Get("qualityReviewResultName_E");
                            dict["p05"] = Get("qualityReviewResultDesc");

                            rowsList_dt13.Add(dict);
                        }
                    }

                    // ===================== [14] قضايا التحكيم المفتوحة =====================
                    if (dt14 != null && dt14.Columns.Count > 0)
                    {
                        var headerMap_dt14 = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                        {
                            ["arbitrationCaseID"] = "رقم حالة التحكيم",
                            ["ticketID_FK"] = "معرف التذكرة",
                            ["ticketNo"] = "رقم التذكرة",
                            ["title"] = "العنوان",
                            ["arbitrationReasonName_A"] = "سبب التحكيم",
                            ["arbitrationStatus"] = "حالة التحكيم",
                            ["entryDate"] = "تاريخ الإنشاء"
                        };

                        foreach (DataColumn c in dt14.Columns)
                        {
                            bool isticketID_FK = c.ColumnName.Equals("ticketID_FK", StringComparison.OrdinalIgnoreCase);

                            dynamicColumns_dt14.Add(new TableColumn
                            {
                                Field = c.ColumnName,
                                Label = headerMap_dt14.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                                Type = ColumnType(c),
                                Sortable = true,
                                Visible = !isticketID_FK
                            });
                        }

                        foreach (DataRow r in dt14.Rows)
                        {
                            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            foreach (DataColumn c in dt14.Columns)
                            {
                                var val = r[c];
                                dict[c.ColumnName] = val == DBNull.Value ? null : val;
                            }

                            object? Get(string key) => dict.TryGetValue(key, out var v) ? v : null;
                            dict["p01"] = Get("arbitrationCaseID");

                            // حالة التحكيم بالعربي
                            if (Get("arbitrationStatus")?.ToString()?.Trim().ToUpper() == "OPEN")
                                dict["arbitrationStatus"] = "مفتوحة";

                            rowsList_dt14.Add(dict);
                        }
                    }
                }
            }
            catch (Exception)
            {
                ViewBag.BuildingTypeDataSetError = "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
            }


            var currentUrl = Request.Path;
            var requestToken = Request.Headers["RequestVerificationToken"].FirstOrDefault() ?? "";


            // =====================================================================
            //                          [1] الخدمات
            // =====================================================================

            // INSERT fields
            var InsertServiceFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTSERVICE" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },

                // كود الخدمة يولده ServiceSP تلقائيا (SRV-00042)
                new FieldConfig { Name = "p03", Label = "اسم الخدمة (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "اسم الخدمة (إنجليزي) — اختياري", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                new FieldConfig { Name = "p06", Label = "فئة التذكرة", Type = "select", ColCss = "6", Required = true, Options = TicketClassOptions },
                new FieldConfig { Name = "p07", Label = "الأولوية الافتراضية", Type = "select", ColCss = "6", Options = PriorityOptions },
                new FieldConfig { Name = "p08", Label = "يتطلب موقع", Type = "checkbox", ColCss = "4" },
                new FieldConfig { Name = "p09", Label = "يسمح بتذاكر فرعية", Type = "checkbox", ColCss = "4" },
                new FieldConfig { Name = "p10", Label = "يتطلب مراجعة جودة", Type = "checkbox", ColCss = "4" },

                // الجهة المسؤولة عن الخدمة: القسم ثم الفرع والشعبة إن وجدت
                new FieldConfig { Name = "p11", Label = "القسم", Type = "select", ColCss = "4", Required = true, Select2 = true, Options = DepartmentOptions,
                                  HelpText = "الجهة المسؤولة عن الخدمة: اختر القسم، ثم الفرع والشعبة إن وجدت." },
                new FieldConfig { Name = "p12", Label = "الفرع (اختياري)", Type = "select", ColCss = "4", Select2 = true, Options = new List<OptionItem>(),
                                  DependsOn = "p11", DependsUrl = unitListUrl },
                new FieldConfig { Name = "p13", Label = "الشعبة (اختياري)", Type = "select", ColCss = "4", Select2 = true, Options = new List<OptionItem>(),
                                  DependsOn = "p12", DependsUrl = unitListUrl },

            };

            // UPDATE fields
            var UpdateServiceFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATESERVICE" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "serviceID" },

                new FieldConfig { Name = "p02", Label = "كود الخدمة (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "SRV = Service = خدمة" },
                new FieldConfig { Name = "p03", Label = "اسم الخدمة (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "اسم الخدمة (إنجليزي) — اختياري", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
                new FieldConfig { Name = "p06", Label = "فئة التذكرة", Type = "select", ColCss = "6", Required = true, Options = TicketClassOptions },
                new FieldConfig { Name = "p07", Label = "الأولوية الافتراضية", Type = "select", ColCss = "6", Options = PriorityOptions },
                new FieldConfig { Name = "p08", Label = "يتطلب موقع", Type = "checkbox", ColCss = "4" },
                new FieldConfig { Name = "p09", Label = "يسمح بتذاكر فرعية", Type = "checkbox", ColCss = "4" },
                new FieldConfig { Name = "p10", Label = "يتطلب مراجعة جودة", Type = "checkbox", ColCss = "4" },

                // الجهة المسؤولة عن الخدمة: القسم ثم الفرع والشعبة إن وجدت
                new FieldConfig { Name = "p11", Label = "القسم", Type = "select", ColCss = "4", Required = true, Select2 = true, Options = DepartmentOptions,
                                  HelpText = "الجهة المسؤولة عن الخدمة: اختر القسم، ثم الفرع والشعبة إن وجدت." },
                new FieldConfig { Name = "p12", Label = "الفرع (اختياري)", Type = "select", ColCss = "4", Select2 = true, Options = new List<OptionItem>(),
                                  DependsOn = "p11", DependsUrl = unitListUrl },
                new FieldConfig { Name = "p13", Label = "الشعبة (اختياري)", Type = "select", ColCss = "4", Select2 = true, Options = new List<OptionItem>(),
                                  DependsOn = "p12", DependsUrl = unitListUrl },

            };

            // DELETE fields
            var DeleteServiceFields = new List<FieldConfig>
            {

                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETESERVICE" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                // selection context
                new FieldConfig { Name = rowIdField, Type = "hidden" },
                // hidden p01 actually posted to SP
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "serviceID" },

                new FieldConfig { Name = "p02", Label = "كود الخدمة", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "اسم الخدمة", Type = "text", ColCss = "8", Readonly = true },

            };


            var dsModel = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns,
                Rows = rowsList,
                RowIdField = rowIdField,
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "دليل الخدمات",
                EnableCellCopy = true,
                ShowColumnVisibility = true,
                HeaderMode = SmartTableHeaderMode.Smart,
                EnableColumnHeaderMenu = true,
                ShowFilter = false,
                ShowAdvancedFilter = true,
                FilterRow = true,
                FilterDebounce = 250,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "services",
                TabLabel = "الخدمات",
                TabIcon = "fa-solid fa-concierge-bell",
                TabDefaultActive = true,
                ShowTabCount = false,
                TabOrder = 1,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTSERVICE,
                    ShowEdit = canUPDATESERVICE,
                    ShowDelete = canDELETESERVICE,
                    ShowBulkDelete = false,


                    Add = new TableAction
                    {
                        Label = "إضافة خدمة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة خدمة جديدة",
                        ModalMessage = "ملاحظة: كود الخدمة يُولَّد تلقائياً عند الحفظ",
                        ModalMessageClass = "bg-sky-100 text-sky-700",
                        ModalMessageIcon = "fa-solid fa-circle-info",

                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertServiceFields
                        },
                    },


                    Edit = new TableAction
                    {
                        Label = "تعديل خدمة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل خدمة",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateServiceFields
                        },

                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },


                    Delete = new TableAction
                    {
                        Label = "حذف خدمة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف خدمة",
                        ModalMessage = "هل أنت متأكد من حذف هذه الخدمة؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",

                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",

                        OpenForm = new FormConfig
                        {
                            FormId = "ServiceDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeleteServiceFields
                        },

                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                }
            };


            dsModel.StyleRules = new List<TableStyleRule>
                        {
                            new TableStyleRule
                            {
                                Target="row", Field="priorityName_A", Op="eq", Value="حرج", Priority=1,
                                PillEnabled=true,
                                PillField="priorityName_A",
                                PillTextField="priorityName_A",
                                PillCssClass="pill pill-red",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="priorityName_A", Op="eq", Value="عالي", Priority=1,
                                PillEnabled=true,
                                PillField="priorityName_A",
                                PillTextField="priorityName_A",
                                PillCssClass="pill pill-orange",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="priorityName_A", Op="eq", Value="متوسط", Priority=1,
                                PillEnabled=true,
                                PillField="priorityName_A",
                                PillTextField="priorityName_A",
                                PillCssClass="pill pill-blue",
                                PillMode="replace"
                            },
                            new TableStyleRule
                            {
                                Target="row", Field="priorityName_A", Op="eq", Value="منخفض", Priority=1,
                                PillEnabled=true,
                                PillField="priorityName_A",
                                PillTextField="priorityName_A",
                                PillCssClass="pill pill-green",
                                PillMode="replace"
                            },
                        };


            // =====================================================================
            //                          [8] فئات التذاكر
            // =====================================================================

            var InsertTicketClassFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTTICKETCLASS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketClassID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdateTicketClassFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATETICKETCLASS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketClassID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ticketClassID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "CLS = Class = فئة التذكرة" },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeleteTicketClassFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETETICKETCLASS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketClassID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ticketClassID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel1 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt8,
                Rows = rowsList_dt8,
                RowIdField = "ticketClassID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt8.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "فئات التذاكر",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "ticket-classes",
                TabLabel = "فئات التذاكر",
                TabIcon = "fa-solid fa-layer-group",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 2,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTTICKETCLASS,
                    ShowEdit = canUPDATETICKETCLASS,
                    ShowDelete = canDELETETICKETCLASS,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة فئة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة فئة تذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketClassInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertTicketClassFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل فئة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل فئة تذكرة",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketClassEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateTicketClassFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف فئة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف فئة تذكرة",
                        ModalMessage = "هل أنت متأكد من حذف هذه الفئة؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketClassDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeleteTicketClassFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };


            // =====================================================================
            //                          [9] الأولويات
            // =====================================================================

            var InsertPriorityFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTPRIORITY" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "priorityID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "4", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "4", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p06", Label = "المستوى", Type = "text", ColCss = "4", TextMode = "number" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdatePriorityFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEPRIORITY" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "priorityID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "priorityID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "4", Readonly = true, Tooltip = "PRI = Priority = الأولوية" + systemCodes },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "4", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "4", MaxLength = 200 },
                new FieldConfig { Name = "p06", Label = "المستوى", Type = "text", ColCss = "4", TextMode = "number" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeletePriorityFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEPRIORITY" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "priorityID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "priorityID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel2 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt9,
                Rows = rowsList_dt9,
                RowIdField = "priorityID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt9.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "الأولويات",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "priorities",
                TabLabel = "الأولويات",
                TabIcon = "fa-solid fa-signal",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 3,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTPRIORITY,
                    ShowEdit = canUPDATEPRIORITY,
                    ShowDelete = canDELETEPRIORITY,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة أولوية",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة أولوية",
                        OpenForm = new FormConfig
                        {
                            FormId = "PriorityInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertPriorityFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل أولوية",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل أولوية",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "PriorityEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdatePriorityFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف أولوية",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف أولوية",
                        ModalMessage = "هل أنت متأكد من حذف هذه الأولوية؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "PriorityDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeletePriorityFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };

            dsModel2.StyleRules = new List<TableStyleRule>
                        {
                            new TableStyleRule { Target="row", Field="priorityCode", Op="eq", Value="CRITICAL", Priority=1,
                                PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A", PillCssClass="pill pill-red", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="priorityCode", Op="eq", Value="HIGH", Priority=1,
                                PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A", PillCssClass="pill pill-orange", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="priorityCode", Op="eq", Value="MEDIUM", Priority=1,
                                PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A", PillCssClass="pill pill-blue", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="priorityCode", Op="eq", Value="LOW", Priority=1,
                                PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A", PillCssClass="pill pill-green", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="priorityCode", Op="eq", Value="PLANNED", Priority=1,
                                PillEnabled=true, PillField="priorityName_A", PillTextField="priorityName_A", PillCssClass="pill pill-gray", PillMode="replace" },
                        };


            // =====================================================================
            //                          [10] حالات التذكرة
            // =====================================================================

            var InsertTicketStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTTICKETSTATUS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketStatusID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdateTicketStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATETICKETSTATUS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketStatusID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ticketStatusID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "STS = Status = حالة التذكرة" + systemCodes },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeleteTicketStatusFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETETICKETSTATUS" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "ticketStatusID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "ticketStatusID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel3 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt10,
                Rows = rowsList_dt10,
                RowIdField = "ticketStatusID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt10.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "حالات التذكرة",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "statuses",
                TabLabel = "حالات التذكرة",
                TabIcon = "fa-solid fa-circle-half-stroke",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 4,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTTICKETSTATUS,
                    ShowEdit = canUPDATETICKETSTATUS,
                    ShowDelete = canDELETETICKETSTATUS,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة حالة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة حالة تذكرة",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketStatusInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertTicketStatusFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل حالة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل حالة تذكرة",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketStatusEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateTicketStatusFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف حالة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف حالة تذكرة",
                        ModalMessage = "هل أنت متأكد من حذف هذه الحالة؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "TicketStatusDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeleteTicketStatusFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };

            dsModel3.StyleRules = new List<TableStyleRule>
                        {
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="NEW", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-gray", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="IN_PROGRESS", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-green", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="RESOLVED", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-green", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="CLOSED", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-gray", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="REJECTED", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-red", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="ARBITRATION", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-purple", PillMode="replace" },
                            new TableStyleRule { Target="row", Field="ticketStatusCode", Op="eq", Value="PAUSED", Priority=1,
                                PillEnabled=true, PillField="ticketStatusName_A", PillTextField="ticketStatusName_A", PillCssClass="pill pill-orange", PillMode="replace" },
                        };


            // =====================================================================
            //                          [11] أسباب الإيقاف
            // =====================================================================

            var InsertPauseReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTPAUSEREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "pauseReasonID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdatePauseReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEPAUSEREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "pauseReasonID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "pauseReasonID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "PSR = Pause Reason = سبب الإيقاف" + systemCodes },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeletePauseReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEPAUSEREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "pauseReasonID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "pauseReasonID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel4 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt11,
                Rows = rowsList_dt11,
                RowIdField = "pauseReasonID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt11.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "أسباب الإيقاف",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "pause-reasons",
                TabLabel = "أسباب الإيقاف",
                TabIcon = "fa-solid fa-pause-circle",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 5,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTPAUSEREASON,
                    ShowEdit = canUPDATEPAUSEREASON,
                    ShowDelete = canDELETEPAUSEREASON,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة سبب",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة سبب إيقاف",
                        OpenForm = new FormConfig
                        {
                            FormId = "PauseReasonInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertPauseReasonFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل سبب",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل سبب إيقاف",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "PauseReasonEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdatePauseReasonFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف سبب",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف سبب إيقاف",
                        ModalMessage = "هل أنت متأكد من حذف هذا السبب؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "PauseReasonDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeletePauseReasonFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };


            // =====================================================================
            //                          [12] أسباب التحكيم
            // =====================================================================

            var InsertArbitrationReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTARBITRATIONREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "arbitrationReasonID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdateArbitrationReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEARBITRATIONREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "arbitrationReasonID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "arbitrationReasonID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "ARB = Arbitration = سبب التحكيم" },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeleteArbitrationReasonFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEARBITRATIONREASON" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "arbitrationReasonID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "arbitrationReasonID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel5 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt12,
                Rows = rowsList_dt12,
                RowIdField = "arbitrationReasonID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt12.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "أسباب التحكيم",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "arbitration-reasons",
                TabLabel = "أسباب التحكيم",
                TabIcon = "fa-solid fa-gavel",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 6,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTARBITRATIONREASON,
                    ShowEdit = canUPDATEARBITRATIONREASON,
                    ShowDelete = canDELETEARBITRATIONREASON,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة سبب",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة سبب تحكيم",
                        OpenForm = new FormConfig
                        {
                            FormId = "ArbitrationReasonInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertArbitrationReasonFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل سبب",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل سبب تحكيم",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "ArbitrationReasonEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateArbitrationReasonFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف سبب",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف سبب تحكيم",
                        ModalMessage = "هل أنت متأكد من حذف هذا السبب؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "ArbitrationReasonDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeleteArbitrationReasonFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };


            // =====================================================================
            //                          [13] نتائج مراجعة الجودة
            // =====================================================================

            var InsertQualityReviewResultFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERTQUALITYREVIEWRESULT" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "qualityReviewResultID", Type = "hidden" },

                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200, TextMode = "arabic" },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200, TextMode = "english" },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var UpdateQualityReviewResultFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "UPDATEQUALITYREVIEWRESULT" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "qualityReviewResultID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "qualityReviewResultID" },

                new FieldConfig { Name = "p02", Label = "الكود (تلقائي)", Type = "text", ColCss = "6", Readonly = true, Tooltip = "QRR = Quality Review Result = نتيجة مراجعة الجودة" + systemCodes },
                new FieldConfig { Name = "p03", Label = "الاسم (عربي)", Type = "text", ColCss = "6", Required = true, MaxLength = 200 },
                new FieldConfig { Name = "p04", Label = "الاسم (إنجليزي)", Type = "text", ColCss = "6", MaxLength = 200 },
                new FieldConfig { Name = "p05", Label = "الوصف", Type = "textarea", ColCss = "12", MaxLength = 1000 },
            };

            var DeleteQualityReviewResultFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DELETEQUALITYREVIEWRESULT" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "qualityReviewResultID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "qualityReviewResultID" },

                new FieldConfig { Name = "p02", Label = "الكود", Type = "text", ColCss = "4", Readonly = true },
                new FieldConfig { Name = "p03", Label = "الاسم", Type = "text", ColCss = "8", Readonly = true },
            };

            var dsModel6 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt13,
                Rows = rowsList_dt13,
                RowIdField = "qualityReviewResultID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt13.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "نتائج المراجعة",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "quality-review-results",
                TabLabel = "نتائج المراجعة",
                TabIcon = "fa-solid fa-clipboard-check",
                TabDefaultActive = false,
                ShowTabCount = false,
                TabOrder = 7,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowAdd = canINSERTQUALITYREVIEWRESULT,
                    ShowEdit = canUPDATEQUALITYREVIEWRESULT,
                    ShowDelete = canDELETEQUALITYREVIEWRESULT,
                    ShowBulkDelete = false,

                    Add = new TableAction
                    {
                        Label = "إضافة نتيجة",
                        Icon = "fa fa-plus",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "إضافة نتيجة مراجعة",
                        OpenForm = new FormConfig
                        {
                            FormId = "QualityReviewResultInsertForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/insert",
                            SubmitText = "حفظ",
                            CancelText = "إلغاء",
                            Fields = InsertQualityReviewResultFields
                        },
                    },

                    Edit = new TableAction
                    {
                        Label = "تعديل نتيجة",
                        Icon = "fa-solid fa-pen",
                        Color = "info",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "تعديل نتيجة مراجعة",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "QualityReviewResultEditForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ التعديلات",
                            CancelText = "إلغاء",
                            Fields = UpdateQualityReviewResultFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Delete = new TableAction
                    {
                        Label = "حذف نتيجة",
                        Icon = "fa fa-trash",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "حذف نتيجة مراجعة",
                        ModalMessage = "هل أنت متأكد من حذف هذه النتيجة؟",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "QualityReviewResultDeleteForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/delete",
                            SubmitText = "حذف",
                            CancelText = "إلغاء",
                            Fields = DeleteQualityReviewResultFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };


            // =====================================================================
            //                          [14] صندوق التحكيم
            // =====================================================================

            // Masters_CRUD DECIDE_ARBITRATION: p01 القضية، p02 نوع القرار، p03 الجهة، p04 المبررات
            var DecideArbitrationFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "DECIDE_ARBITRATION" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "arbitrationCaseID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "arbitrationCaseID" },

                new FieldConfig
                {
                    Name = "p02", Label = "القرار", Type = "select", ColCss = "12", Required = true, Value = "UPHOLD",
                    Options = new List<OptionItem>
                    {
                        new() { Value = "UPHOLD", Text = "تأييد — تستمر التذكرة في نفس الجهة" },
                        new() { Value = "REDIRECT", Text = "تحويل — تُحوَّل التذكرة إلى جهة أخرى" }
                    },
                    ShowFieldsWhen = new Dictionary<string, List<string>> { ["REDIRECT"] = new() { "p03" } }
                },
                new FieldConfig
                {
                    Name = "p03", Label = "الجهة المحوَّل إليها", Type = "select", ColCss = "12", Required = true, Select2 = true,
                    Options = DsdOptions,
                    HelpText = "تُعاد التذكرة إلى حالة «موجّه» بدون موظف، ليعيّنها مشرف الجهة الجديدة."
                },
                new FieldConfig { Name = "p04", Label = "مبررات القرار", Type = "textarea", ColCss = "12", Required = true, MaxLength = 2000 },
            };

            // Masters_CRUD CANCEL_ARBITRATION: p01 القضية، p02 سبب الإلغاء
            var CancelArbitrationFields = new List<FieldConfig>
            {
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = PageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "CANCEL_ARBITRATION" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = PageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = ControllerName },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },
                new FieldConfig { Name = "arbitrationCaseID", Type = "hidden" },
                new FieldConfig { Name = "p01", Type = "hidden", MirrorName = "arbitrationCaseID" },

                new FieldConfig { Name = "p02", Label = "سبب الإلغاء", Type = "textarea", ColCss = "12", Required = true, MaxLength = 2000 },
            };

            var dsModel7 = new SmartTableDsModel
            {
                PageTitle = "إعدادات التذاكر",
                Columns = dynamicColumns_dt14,
                Rows = rowsList_dt14,
                RowIdField = "arbitrationCaseID",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50, 200, },
                QuickSearchFields = dynamicColumns_dt14.Select(c => c.Field).Take(4).ToList(),
                Searchable = true,
                AllowExport = true,
                ShowPageSizeSelector = true,
                PanelTitle = "صندوق التحكيم",
                EnableCellCopy = true,
                ShowColumnVisibility = true,

                RenderMode = SmartTableRenderMode.Tab,
                RenderAsToggle = false,
                RenderAsSection = false,
                RenderAsTab = true,
                TabGroupKey = "ticket-admin",
                TabKey = "arbitration-inbox",
                TabLabel = "صندوق التحكيم",
                TabIcon = "fa-solid fa-scale-balanced",
                TabDefaultActive = false,
                ShowTabCount = true,
                TabOrder = 8,

                Toolbar = new TableToolbarConfig
                {
                    ShowRefresh = false,
                    ShowColumns = true,
                    ShowExportCsv = false,
                    ShowExportExcel = false,

                    ShowEdit = canDECIDE_ARBITRATION,
                    ShowEdit1 = canCANCEL_ARBITRATION,
                    ShowBulkDelete = false,

                    Edit = new TableAction
                    {
                        Label = "قرار التحكيم",
                        Icon = "fa-solid fa-scale-balanced",
                        Color = "success",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "قرار التحكيم",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "DecideArbitrationForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "حفظ القرار",
                            CancelText = "إلغاء",
                            Fields = DecideArbitrationFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },

                    Edit1 = new TableAction
                    {
                        Label = "إلغاء التحكيم",
                        Icon = "fa-solid fa-ban",
                        Color = "danger",
                        IsEdit = true,
                        OpenModal = true,
                        ModalTitle = "إلغاء التحكيم",
                        ModalMessageClass = "bg-red-50 text-red-700",
                        ModalMessageIcon = "fa-solid fa-triangle-exclamation",
                        OnBeforeOpenJs = "sfRouteEditForm(table, act);",
                        OpenForm = new FormConfig
                        {
                            FormId = "CancelArbitrationForm",
                            Title = "",
                            Method = "post",
                            ActionUrl = "/crud/update",
                            SubmitText = "إلغاء التحكيم",
                            CancelText = "رجوع",
                            Fields = CancelArbitrationFields
                        },
                        RequireSelection = true,
                        MinSelection = 1,
                        MaxSelection = 1,
                    },
                }
            };

            // صندوق التحكيم يظهر فقط لمن يملك قرار التحكيم أو إلغاءه
            bool canViewArbitrationInbox = canDECIDE_ARBITRATION || canCANCEL_ARBITRATION;


            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PageTitle,
                PanelIcon = "fa-solid fa-sliders",
                Panel = new SmartPagePanelConfig
                {
                    Show = true,
                    ShowIcon = true,
                    ShowSubtitle = true,
                    ShowDescription = true,
                    ShowBadges = true,
                    Layout = "compact",
                    Title = "إعدادات التذاكر",
                    Subtitle = "الخدمات وقوائم نظام التذاكر.",
                    Description = "تُستخدم هذه الصفحة لإدارة الخدمات التي تُرفع عليها التذاكر، وفئات التذاكر، والأولويات، والحالات، وأسباب الإيقاف والتحكيم، ونتائج مراجعة الجودة، وقرارات التحكيم.",
                    Icon = "fa-sliders",
                    Badges = new List<SmartPagePanelBadge>
                    {
                        new() { Label = "الأكواد", Value = "تُولَّد تلقائياً عند الإضافة", Icon = "fa-solid fa-hashtag", Tone = "info" },
                        new() { Label = "الحذف", Value = "إيقاف السجل دون حذف بياناته", Icon = "fa-solid fa-ban", Tone = "default" },
                    }
                },
                TableDS = dsModel,
                TableDS1 = dsModel1,
                TableDS2 = dsModel2,
                TableDS3 = dsModel3,
                TableDS4 = dsModel4,
                TableDS5 = dsModel5,
                TableDS6 = dsModel6,
                TableDS7 = canViewArbitrationInbox ? dsModel7 : null
            };


            return View("TicketAdmin", page);
        }
    }
}
