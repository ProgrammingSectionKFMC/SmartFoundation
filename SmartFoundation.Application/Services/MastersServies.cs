using Microsoft.Extensions.Logging;
using SmartFoundation.Application.Mapping;
using SmartFoundation.Application.Services.Models;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.DataEngine.Core.Services;
using System;
using System.Data;
using System.Text.Json;
using static System.Collections.Specialized.BitVector32;

namespace SmartFoundation.Application.Services
{
    public class MastersServies : BaseService
    {
        public MastersServies(
            ISmartComponentService dataEngine,
            ILogger<MastersServies> logger)
            : base(dataEngine, logger)
        {
        }


        /// <summary>
        /// Gets the user menu tree using ProcedureMapper: menu:tree -> dbo.GetUserMenuTree.
        /// Required parameter: UserID (string/int).
        /// Logs raw JSON response for debugging.
        /// </summary>
        public async Task<string> GetUserMenuTree(Dictionary<string, object?> parameters)
        {
            var json = await ExecuteOperation("menu", "tree", parameters);

            // Print in console and log for verification
            Console.WriteLine($"[GetUserMenuTree] Raw JSON: {json}");
            _logger.LogInformation("GetUserMenuTree raw JSON: {Json}", json);

            // Optionally, also log a preview of the first item if JSON data array exists
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.TryGetProperty("success", out var successProp) && successProp.GetBoolean() &&
                    root.TryGetProperty("data", out var dataProp) && dataProp.ValueKind == JsonValueKind.Array)
                {
                    var first = dataProp.EnumerateArray().FirstOrDefault();
                    if (first.ValueKind == JsonValueKind.Object)
                    {
                        _logger.LogInformation("First menu row sample: {Row}", first.ToString());
                        Console.WriteLine($"[GetUserMenuTree] First row: {first}");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to parse JSON for preview in GetUserMenuTree");
            }

            return json;
        }


        /// <summary>
        /// Retrieves all available menu items (admin function).
        /// </summary>
        /// <param name="parameters">
        /// Dictionary containing request parameters:
        /// - includeInactive (bool, optional): Include inactive menu items (default: false)
        /// </param>
        /// <returns>JSON string with all menu items</returns>
        public async Task<string> GetAllMenus(Dictionary<string, object?> parameters)
        {
            return await ExecuteOperation("menu", "listAll", parameters);
        }


        // END OF MenuService

        /// <summary>
        /// Masters_CrudServies
        /// </summary>
        /// <param name="args"></param>
        /// <returns></returns>


        public async Task<DataSet> GetCrudDataSetAsync(params object?[] args)
        {
            string pageName = args.Length > 0 ? args[0]?.ToString() ?? "" : "";
            string? actionType = args.Length > 1 ? args[1]?.ToString() : null;
            int? idaraID = args.Length > 2 ? SafeInt(args[2]) : null;
            int? entryData = args.Length > 3 ? SafeInt(args[3]) : null;
            string? hostName = args.Length > 4 ? args[4]?.ToString() : null;

            var extraParams = args.Skip(5).ToArray();

            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = pageName,
                ["ActionType"] = actionType,
                ["idaraID"] = idaraID,
                ["entrydata"] = entryData,
                ["hostname"] = hostName
            };

            for (int i = 0; i < Math.Min(extraParams.Length, 50); i++)
            {
                var v = extraParams[i];
                if (v == null || v == DBNull.Value) continue;
                dict[$"parameter_{(i + 1):00}"] = v;
            }

            _logger.LogInformation("CRUD PARAMS (pre-SP): {Params}", JsonSerializer.Serialize(dict));

            var ds = await ExecuteMappedAsync(dict);

            _logger.LogInformation("CRUD RESULT: Tables={TableCount} FirstTableCols={Cols} FirstTableRows={Rows}",
                ds.Tables.Count,
                ds.Tables.Count > 0 ? string.Join(",", ds.Tables[0].Columns.Cast<DataColumn>().Select(c => c.ColumnName)) : "<none>",
                ds.Tables.Count > 0 ? ds.Tables[0].Rows.Count : 0);

            return ds;

            static int? SafeInt(object? o)
            {
                if (o == null) return null;
                if (o is int i) return i;
                if (int.TryParse(o.ToString(), out var p)) return p;
                return null;
            }
        }

        // ADD dictionary overload (keeps existing positional version untouched)
        public async Task<DataSet> GetCrudDataSetAsync(Dictionary<string, object?> parameters)
        {
            if (!parameters.ContainsKey("pageName_"))
                throw new ArgumentException("Parameter 'pageName_' is required.");

            // Normalize names exactly as SP expects
            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = parameters["pageName_"],
                ["ActionType"] = parameters.TryGetValue("ActionType", out var act) ? act : null,
                ["idaraID"] = parameters.TryGetValue("idaraID", out var idara) ? idara : null,
                ["entrydata"] = parameters.TryGetValue("entrydata", out var entry) ? entry : null,
                ["hostname"] = parameters.TryGetValue("hostname", out var host) ? host : null
            };

            // Map any remaining (non-core) keys to parameter_01..parameter_50
            var extras = parameters
                .Where(kv => !new[] { "pageName_", "ActionType", "idaraID", "entrydata", "hostname" }
                    .Contains(kv.Key, StringComparer.OrdinalIgnoreCase))
                .Select(kv => kv.Value)
                .Take(50)
                .ToList();

            for (int i = 0; i < extras.Count; i++)
            {
                var v = extras[i];
                if (v == null || v == DBNull.Value) continue;
                dict[$"parameter_{(i + 1):00}"] = v;
            }

            return await ExecuteMappedAsync(dict);
        }

        /// <summary>
        /// Executes the mapped stored procedure and converts SmartResponse to DataSet.
        /// Requires a ProcedureMapper entry: "MastersCrud:getData" (add if missing).
        /// </summary>
        private async Task<DataSet> ExecuteMappedAsync(Dictionary<string, object?> parameters)
        {
            _logger.LogInformation("MastersCrudServies executing with params: {Params}",
                JsonSerializer.Serialize(parameters));

            var spName = ProcedureMapper.GetProcedureName("MastersCrud", "crud");

            var request = new SmartRequest
            {
                Operation = "sp",
                SpName = spName,
                Params = parameters
            };

            SmartResponse response;
            try
            {
                response = await _dataEngine.ExecuteAsync(request);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error executing SP {SpName}", spName);
                throw new InvalidOperationException($"Failed to execute stored procedure '{spName}': {ex.Message}", ex);
            }

            if (!response.Success)
            {
                var msg = response.Message ?? response.Error ?? "Stored procedure execution failed";
                _logger.LogWarning("Stored procedure {SpName} returned failure: {Message}", spName, msg);
                throw new InvalidOperationException(msg);
            }

            var ds = new DataSet();

            if (response.Datasets is { Count: > 0 })
            {
                for (int i = 0; i < response.Datasets.Count; i++)
                {
                    var rows = response.Datasets[i];
                    ds.Tables.Add(CreateDataTableFromRowList(rows, $"Table{i}"));
                }
            }
            else if (response.Data is { Count: > 0 })
            {
                ds.Tables.Add(CreateDataTableFromRowList(response.Data, "Table0"));
            }
            else
            {
                ds.Tables.Add(new DataTable("Table0"));
            }

            return ds;
        }

        private static DataTable CreateDataTableFromRowList(List<Dictionary<string, object?>> rows, string tableName)
        {
            var dt = new DataTable(tableName);
            if (rows == null || rows.Count == 0) return dt;

            var allKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var row in rows)
                foreach (var k in row.Keys)
                    allKeys.Add(k);

            foreach (var col in allKeys)
                dt.Columns.Add(col, typeof(object));

            foreach (var row in rows)
            {
                var dr = dt.NewRow();
                foreach (var col in allKeys)
                    dr[col] = row.TryGetValue(col, out var val) && val != null ? val : DBNull.Value;
                dt.Rows.Add(dr);
            }
            return dt;
        }



        // END OF Masters_CrudServies



        /// <summary>
        /// MastersDataLoad
        /// </summary>
        /// <param name="args"></param>
        /// <returns></returns>


        public async Task<DataSet> GetDataLoadDataSetAsync(params object?[] args)
        {
            // الترتيب:
            // [0] pageName, [1] idaraID, [2] entryData, [3] hostName,
            // [4..] parameter_01..parameter_10 (فقط إلى 10 كما طلبت)

            string pageName = args.Length > 0 ? args[0]?.ToString() ?? "" : "";
            int? idaraID = args.Length > 1 ? (args[1] == null ? (int?)null : Convert.ToInt32(args[1])) : (int?)null;
            int? entryData = args.Length > 2 ? (args[2] == null ? (int?)null : Convert.ToInt32(args[2])) : (int?)null;
            string? hostName = args.Length > 3 ? args[3]?.ToString() : null;

            var extraParams = args.Skip(4).ToArray();

            // دالة مساعدة: تضيف المفتاح فقط إذا القيمة ليست null وليست DBNull
            void AddIfHasValue(IDictionary<string, object?> d, string key, object? val)
            {
                if (val == null || val == DBNull.Value) return;
                d[key] = val;
            }

            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

            // القيم الأساسية
            // pageName غالبًا إجباري – نرسله حتى لو كان فاضي
            dict["pageName_"] = pageName;

            // البقية نضيفها فقط عند وجود قيمة
            AddIfHasValue(dict, "idaraID", idaraID);
            AddIfHasValue(dict, "entrydata", entryData);
            AddIfHasValue(dict, "hostname", hostName);

            // parameter_01 .. parameter_10 حسب ما تم تمريره فقط
            int take = Math.Min(extraParams.Length, 20);
            for (int i = 1; i <= take; i++)
            {
                var val = extraParams[i - 1];
                if (val == DBNull.Value) val = null; // أمان إضافي
                AddIfHasValue(dict, $"parameter_{i:00}", val);
            }

            // الآن استدعِ النسخة التي تقبل Dictionary (كما لديك)
            return await GetDataLoadDataSetAsync(dict);
        }


        public async Task<DataSet> GetDataLoadDataSetAsync(Dictionary<string, object?> parameters)
        {
            _logger.LogInformation("GetDataLoadDataSetAsync called with parameters: {Params}", JsonSerializer.Serialize(parameters));

            // Resolve SP name via ProcedureMapper (no hard-coded SP name)
            var spName = ProcedureMapper.GetProcedureName("MastersDataLoad", "getData");

            var request = new SmartRequest
            {
                Operation = "sp",
                SpName = spName,
                Params = parameters ?? new Dictionary<string, object?>()
            };

            SmartResponse response;
            try
            {
                response = await _dataEngine.ExecuteAsync(request);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error executing stored procedure {SpName}", spName);
                throw new InvalidOperationException($"Failed to execute stored procedure '{spName}': {ex.Message}", ex);
            }

            if (!response.Success)
            {
                var msg = response.Message ?? response.Error ?? "Stored procedure execution failed";
                _logger.LogWarning("Stored procedure {SpName} returned failure: {Message}", spName, msg);
                throw new InvalidOperationException(msg);
            }

            // Convert SmartResponse (Datasets / Data) to DataSet
            var ds = new DataSet();

            if (response.Datasets is { Count: > 0 })
            {
                for (var i = 0; i < response.Datasets.Count; i++)
                {
                    var rows = response.Datasets[i];
                    var dt = CreateDataTableFromRowList(rows, $"Table{i}");
                    ds.Tables.Add(dt);
                }
            }
            else if (response.Data is { Count: > 0 })
            {
                var dt = CreateDataTableFromRowList(response.Data, "Table0");
                ds.Tables.Add(dt);
            }
            else
            {
                ds.Tables.Add(new DataTable("Table0"));
            }

            return ds;
        }


        //END OF MastersDataLoadService




        /// <summary>
        /// AuthDataLoadService
        /// </summary>
        /// <param name="args"></param>
        /// <returns></returns>


        public async Task<DataSet> GetLoginsDataSetAsync(params object?[] args)
        {
            string NationalID = args.Length > 0 ? args[0]?.ToString() ?? "" : "";
            string? password = args.Length > 1 ? args[1]?.ToString() : null;
            string? hostName = args.Length > 2 ? args[2]?.ToString() : null;

            var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
            {
                // ✅ Remove @ prefix - let DataEngine handle it
                ["NationalID"] = NationalID,
                ["Password"] = password,
                ["hostName"] = hostName  // lowercase 'h' to match SP exactly
            };

            return await GetLoginDataSetAsync(dict);
        }

        /// <summary>
        /// Convenience overload to keep existing controller calls working.
        /// </summary>
        //public async Task<DataSet> GetLoginDataSetAsync(string NationalID, string? password, string? hostName, CancellationToken ct = default)
        //{
        //    var parameters = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
        //    {
        //        ["NationalID"] = NationalID,
        //        ["Password"] = password,
        //        ["hostname"] = hostName
        //    };

        //    return await GetLoginDataSetAsync(parameters, ct);
        //}

        /// <summary>
        /// Executes the auth stored procedure using the same pattern as MastersDataLoadService:
        /// - Resolve SP via ProcedureMapper
        /// - Log, try/catch around DataEngine
        /// - Throw on response.Success == false
        /// - Convert SmartResponse to DataSet (always at least Table0)
        /// </summary>
        public async Task<DataSet> GetLoginDataSetAsync(Dictionary<string, object?> parameters, CancellationToken ct = default)
        {
            _logger.LogInformation("=== GetLoginDataSetAsync DEBUG START ===");
            _logger.LogInformation("GetLoginDataSetAsync called with parameters: {Params}", JsonSerializer.Serialize(parameters));
            _logger.LogInformation("Parameter count: {Count}", parameters.Count);
            
            foreach (var param in parameters)
            {
                _logger.LogInformation("  Parameter: [{Key}] = [{Value}] (Type: {Type})", 
                    param.Key, 
                    param.Value ?? "NULL", 
                    param.Value?.GetType().Name ?? "null");
            }

            var spName = ProcedureMapper.GetProcedureName("auth", "sessions_");
            _logger.LogInformation("Resolved SP name: {SpName}", spName);

            var request = new SmartRequest
            {
                Operation = "sp",
                SpName = spName,
                Params = parameters ?? new Dictionary<string, object?>()
            };

            _logger.LogInformation("SmartRequest created - Operation: {Op}, SpName: {Sp}, ParamCount: {Count}", 
                request.Operation, request.SpName, request.Params?.Count ?? 0);

            SmartResponse response;
            try
            {
                _logger.LogInformation("Calling _dataEngine.ExecuteAsync...");
                response = await _dataEngine.ExecuteAsync(request, ct);
                _logger.LogInformation("_dataEngine.ExecuteAsync completed - Success: {Success}", response.Success);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error executing stored procedure {SpName} with params: {Params}", 
                    spName, JsonSerializer.Serialize(parameters));
                _logger.LogInformation("=== GetLoginDataSetAsync DEBUG END (ERROR) ===");
                throw new InvalidOperationException($"Failed to execute stored procedure '{spName}': {ex.Message}", ex);
            }

            // ✅ CHANGE: Don't throw if Success = false, just log and continue
            // The SP might have returned valid data with a message
            if (!response.Success)
            {
                var msg = response.Message ?? response.Error ?? "Stored procedure execution failed";
                _logger.LogWarning("Stored procedure {SpName} returned Success=false with message: {Message}", spName, msg);
                // Don't throw - just log and continue processing the DataSet
            }

            _logger.LogInformation("=== GetLoginDataSetAsync DEBUG END (SUCCESS) ===");
            return ConvertResponseToDataSet(response);
        }

        /// <summary>
        /// Map first row into AuthInfo. Returns inactive AuthInfo if no data.
        /// </summary>
        public AuthInfo ExtractAuth(DataSet ds)
        {
            if (ds == null)
            {
                _logger.LogWarning("ExtractAuth called with null DataSet.");
                return new AuthInfo(
                    0,                           // usersActive
                    "لم يتم العثور على بيانات.", // Message_
                    null,                        // usersId
                    null,                        // fullName
                    null,                        // organizationID
                    null,                        // organizationName
                    null,                        // idaraID
                    null,                        // idaraName
                    null,                        // departmentID
                    null,                        // departmentName
                    null,                        // sectionID
                    null,                        // sectionName
                    null,                        // divisonID
                    null,                        // divisonName
                    null,                        // photoBase64
                    null,                        // ThameName
                    null,                        // deptCode
                    null,                        // nationalID
                    null,                        // GeneralNo
                    null,                        // AdminTypeID
                    null,                        // AdminTypeName
                    0                            // ✅ ChangedPassword
                );
            }

            if (ds.Tables.Count == 0)
            {
                _logger.LogWarning("ExtractAuth received DataSet with no tables.");
                return new AuthInfo(
                    0, 
                    "لم يتم العثور على بيانات.", 
                    null, null, null, null, null, null, null, null, 
                    null, null, null, null, null, null, null, null, 
                    null,
                    null,   // AdminTypeID
                    null,   // AdminTypeName
                    0       // ✅ ChangedPassword
                );
            }

            var t = ds.Tables[0];
            
            if (t.Rows.Count == 0)
            {
                _logger.LogInformation("ExtractAuth: first table has zero rows (likely invalid credentials).");
                return new AuthInfo(
                    0, 
                    "لايوجد حساب نشط لهذا المستخدم", 
                    null, null, null, null, null, null, null, null, 
                    null, null, null, null, null, null, null, null, 
                    null,
                    null,   // AdminTypeID
                    null,   // AdminTypeName
                    0       // ✅ ChangedPassword
                );
            }

            var r = t.Rows[0];

            int usersActive = ReadInt(r, new[] { "usersActive", "IsSuccessful", "Success", "Result", "Code", "userActive" }, 0);
            string? Message_ = ReadString(r, new[] { "Message_", "Message", "SuccessMessage" });
            
            string? usersId = ReadString(r, new[] { "usersID", "UsersID", "userId", "UserID" });
            string? nationalID = ReadString(r, new[] { "nationalID", "NationalID", "IDNumber", "IdNumber" });
            string? fullName = ReadString(r, new[] { "fullName", "FullName", "name", "Name" });
            
            string? organizationID = ReadString(r, new[] { "OrganizationID", "organizationID" });
            string? organizationName = ReadString(r, new[] { "OrganizationName", "organizationName" });
            
            string? idaraID = ReadString(r, new[] { "IdaraID", "idaraID" });
            string? idaraName = ReadString(r, new[] { "IdaraName", "idaraName" });
            
            string? departmentID = ReadString(r, new[] { "DepartmentID", "departmentID" });
            string? departmentName = ReadString(r, new[] { "DepartmentName", "departmentName" });
            
            string? sectionID = ReadString(r, new[] { "SectionID", "sectionID" });
            string? sectionName = ReadString(r, new[] { "SectionName", "sectionName" });
            
            string? divisonID = ReadString(r, new[] { "DivisonID", "divisonID", "DivisionID" });
            string? divisonName = ReadString(r, new[] { "DivisonName", "divisonName", "DivisionName" });

            string? deptCode = ReadString(r, new[] { "DeptCode", "DepartmentCode" });
            string? ThameName = ReadString(r, new[] { "ThameName", "ThemeName", "Theme" });
            string? GeneralNo = ReadString(r, new[] { "GeneralNo", "generalNo", "GNo" });
            string? AdminTypeID = ReadString(r, new[] { "AdminTypeID", "adminTypeID" });
            string? AdminTypeName = ReadString(r, new[] { "AdminTypeName", "adminTypeName" });

            string? photoBase64 = null;
            var photoObj = ReadObject(r, new[] { "Photo", "PhotoBase64" });
            if (photoObj is byte[] bytes && bytes.Length > 0)
                photoBase64 = Convert.ToBase64String(bytes);
            else if (photoObj is string s && !string.IsNullOrWhiteSpace(s))
                photoBase64 = s;

            // ✅ Read ChangedPassword from database
            int? ChangedPassword = ReadNullableInt(r, new[] { "ChangedPassword", "changedPassword", "PasswordChanged" });

            return new AuthInfo(
                usersActive,          // 1
                Message_,             // 2
                usersId,              // 3
                fullName,             // 4
                organizationID,       // 5
                organizationName,     // 6
                idaraID,              // 7
                idaraName,            // 8
                departmentID,         // 9
                departmentName,       // 10
                sectionID,            // 11
                sectionName,          // 12
                divisonID,            // 13
                divisonName,          // 14
                photoBase64,          // 15
                ThameName,            // 16
                deptCode,             // 17
                nationalID,           // 18
                GeneralNo,            // 19
                AdminTypeID,          // 20
                AdminTypeName,        // 21
                ChangedPassword ?? 0  // 22 ✅ ChangedPassword (default to 0 if not found)
            );
        }

        private static DataSet ConvertResponseToDataSet(SmartResponse response)
        {
            var ds = new DataSet();

            if (response.Datasets is { Count: > 0 })
            {
                for (var i = 0; i < response.Datasets.Count; i++)
                {
                    var rows = response.Datasets[i];
                    var dt = CreateDataTableFromRowList(rows, $"Table{i}");
                    ds.Tables.Add(dt);
                }
            }
            else if (response.Data is { Count: > 0 })
            {
                var dt = CreateDataTableFromRowList(response.Data, "Table0");
                ds.Tables.Add(dt);
            }
            else
            {
                ds.Tables.Add(new DataTable("Table0"));
            }

            return ds;
        }

      
        private static string? ReadString(DataRow r, string[] names)
        {
            foreach (var n in names)
                if (HasColumn(r.Table, n) && r[n] != DBNull.Value)
                    return r[n]?.ToString();
            return null;
        }

        private static int ReadInt(DataRow r, string[] names, int def)
        {
            foreach (var n in names)
            {
                if (!HasColumn(r.Table, n) || r[n] == DBNull.Value) continue;
                var v = r[n];

                if (v is int i) return i;
                if (v is bool b) return b ? 1 : 0;   // ✅ Add this
                if (v is byte by) return (int)by;     // ✅ Add this
                if (int.TryParse(v.ToString(), out var parsed)) return parsed;
            }
            return def;
        }

        private static int? ReadNullableInt(DataRow r, string[] names)
        {
            foreach (var n in names)
            {
                if (!HasColumn(r.Table, n) || r[n] == DBNull.Value) continue;
                var v = r[n];

                if (v is int i) return i;
                if (v is bool b) return b ? 1 : 0;  // ✅ Add this line to handle bit columns
                if (v is byte by) return (int)by;    // ✅ Sometimes bit comes as byte
                if (int.TryParse(v.ToString(), out var parsed)) return parsed;
            }
            return null;
        }

        private static object? ReadObject(DataRow r, string[] names)
        {
            foreach (var n in names)
                if (HasColumn(r.Table, n) && r[n] != DBNull.Value)
                    return r[n];
            return null;
        }

        private static bool HasColumn(DataTable t, string name) => t.Columns.Contains(name);


        // END OF AuthDataLoadService



        /// <summary>
        /// NotificationService
        /// </summary>
        /// <param name="args"></param>
        /// <returns></returns>
        /// 



        public async Task<int> GetUserNotificationCount(string userId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "Count" }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "count", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                if (response.GetProperty("success").GetBoolean() &&
                    response.GetProperty("data").ValueKind == JsonValueKind.Array)
                {
                    var firstRow = response.GetProperty("data").EnumerateArray().FirstOrDefault();
                    if (firstRow.ValueKind != JsonValueKind.Undefined)
                    {
                        return firstRow.TryGetProperty("NotificationCount", out var countProp)
                            ? countProp.GetInt32()
                            : 0;
                    }
                }
                return 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting notification count for user {UserId}", userId);
                return 0;
            }
        }

        public async Task<List<NotificationItem>> GetUserNotifications(string userId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "Body" }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "body", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                var notifications = new List<NotificationItem>();

                if (response.GetProperty("success").GetBoolean() &&
                    response.GetProperty("data").ValueKind == JsonValueKind.Array)
                {
                    foreach (var row in response.GetProperty("data").EnumerateArray())
                    {
                        notifications.Add(new NotificationItem
                        {
                            UserNotificationId = row.GetProperty("UserNotificationId").GetInt64(),
                            NotificationId_FK = row.GetProperty("NotificationId_FK").GetInt64(),
                            Title = row.TryGetProperty("Title", out var title) ? title.GetString() : null,
                            Body = row.TryGetProperty("Body", out var body) ? body.GetString() : null,
                            Url_ = row.TryGetProperty("Url_", out var url) ? url.GetString() : null,
                            DeliveredUtc = row.TryGetProperty("DeliveredUtc", out var delivered)
                                ? delivered.GetDateTime()
                                : null,
                            IsClicked = row.TryGetProperty("IsClicked", out var clicked) && clicked.GetBoolean(),
                            IsRead = row.TryGetProperty("IsRead", out var read) && read.GetBoolean()
                        });
                    }
                }

                return notifications;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting notifications for user {UserId}", userId);
                return new List<NotificationItem>();
            }
        }

        public async Task<bool> MarkNotificationAsClicked(string userId, long userNotificationId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "MarkClicked" },
        { "UserNotificationId", userNotificationId }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "markClicked", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                return response.GetProperty("success").GetBoolean();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking notification {NotificationId} as clicked for user {UserId}",
                    userNotificationId, userId);
                return false;
            }
        }

        public async Task<bool> MarkAllNotificationsAsRead(string userId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "MarkAllRead" }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "markAllRead", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                return response.GetProperty("success").GetBoolean();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking all notifications as read for user {UserId}", userId);
                return false;
            }
        }

        public async Task<bool> MarkAllNotificationsAsClicked(string userId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "MarkAllClicked" }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "markAllClicked", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                return response.GetProperty("success").GetBoolean();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking all notifications as clicked for user {UserId}", userId);
                return false;
            }
        }

        public async Task<bool> MarkNotificationAsRead(string userId, long userNotificationId)
        {
            var parameters = new Dictionary<string, object?>
    {
        { "UserID", userId },
        { "Type", "MarkRead" },
        { "UserNotificationId", userNotificationId }
    };

            try
            {
                var jsonResult = await ExecuteOperation("Notification", "markRead", parameters);
                var response = JsonSerializer.Deserialize<JsonElement>(jsonResult);

                return response.GetProperty("success").GetBoolean();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking notification {NotificationId} as read for user {UserId}",
                    userNotificationId, userId);
                return false;
            }
        }

        /// <summary>
        /// ChangePasswordService
        /// </summary>
        /// <param name="args"></param>
        /// <returns></returns>
        /// 

        /// <summary>
/// Change user password
/// </summary>
public async Task<DataSet> GetChangePasswordDataSetAsync(params object?[] args)
{
    string userId = args.Length > 0 ? args[0]?.ToString() ?? "" : "";
    string oldPassword = args.Length > 1 ? args[1]?.ToString() ?? "" : "";
    string newPassword = args.Length > 2 ? args[2]?.ToString() ?? "" : "";

    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
    {
        ["Action"] = "CHANGEUSERPASSWORD",
        ["usersID"] = userId,
        ["OldPassword"] = oldPassword,
        ["PlainPassword"] = newPassword
    };

    _logger.LogInformation("GetChangePasswordDataSetAsync called for user: {UserId}", userId);

    var spName = ProcedureMapper.GetProcedureName("auth", "changePassword");

    var request = new SmartRequest
    {
        Operation = "sp",
        SpName = spName,
        Params = dict
    };

    SmartResponse response;
    try
    {
        response = await _dataEngine.ExecuteAsync(request);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error executing change password stored procedure {SpName}", spName);
        throw new InvalidOperationException($"Failed to execute stored procedure '{spName}': {ex.Message}", ex);
    }

    return ConvertResponseToDataSet(response);
}
    }
}
