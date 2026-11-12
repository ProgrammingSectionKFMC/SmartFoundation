using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using SmartFoundation.Application.Services;
using SmartFoundation.Mvc.Controllers;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Text;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        private readonly MastersServies _mastersServies;
        private readonly CrudController _CrudController;
        private readonly IWebHostEnvironment _env;

        protected string? ControllerName;
        protected string? PageName;

        protected string? usersId;
        protected string? FullName;
        protected string? OrganizationId;
        protected string? OrganizationName;
        protected string? IdaraId;
        protected string? IdaraName;
        protected string? DepartmentId;
        protected string? DepartmentName;
        protected string? SectionId;
        protected string? SectionName;
        protected string? DivisionId;
        protected string? DivisionName;
        protected string? PhotoBase64;
        protected string? ThameName;
        protected string? DeptCode;
        protected string? NationalId;
        protected string? IdNumber;
        protected string? UserActive;
        protected string? HostName;
        protected string? LastActivityUtc;

        protected DataTable? permissionTable;
        protected DataTable? dt1;
        protected DataTable? dt2;
        protected DataTable? dt3;
        protected DataTable? dt4;
        protected DataTable? dt5;
        protected DataTable? dt6;
        protected DataTable? dt7;
        protected DataTable? dt8;
        protected DataTable? dt9;

        public TicketController(MastersServies mastersServies, CrudController crudController, IWebHostEnvironment env)
        {
            _mastersServies = mastersServies;
            _CrudController = crudController;
            _env = env;
        }

        public IActionResult Index()
        {
            return View();
        }

        protected bool InitPageContext(out IActionResult? redirectResult)
        {
            redirectResult = null;

            if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
            {
                redirectResult = RedirectToAction("Index", "Login", new { logout = 1 });
                return false;
            }

            usersId = HttpContext.Session.GetString("usersID");
            FullName = HttpContext.Session.GetString("fullName");
            OrganizationId = HttpContext.Session.GetString("OrganizationID");
            OrganizationName = HttpContext.Session.GetString("OrganizationName");
            IdaraId = HttpContext.Session.GetString("IdaraID");
            IdaraName = HttpContext.Session.GetString("IdaraName");
            DepartmentId = HttpContext.Session.GetString("DepartmentID");
            DepartmentName = HttpContext.Session.GetString("DepartmentName");
            SectionId = HttpContext.Session.GetString("SectionID");
            SectionName = HttpContext.Session.GetString("SectionName");
            DivisionId = HttpContext.Session.GetString("DivisonID");
            DivisionName = HttpContext.Session.GetString("DivisonName");
            PhotoBase64 = HttpContext.Session.GetString("photoBase64");
            ThameName = HttpContext.Session.GetString("ThameName");
            DeptCode = HttpContext.Session.GetString("DeptCode");
            NationalId = HttpContext.Session.GetString("nationalID");
            IdNumber = HttpContext.Session.GetString("IDNumber") ?? NationalId;
            UserActive = HttpContext.Session.GetString("useractive");
            HostName = HttpContext.Session.GetString("HostName");
            LastActivityUtc = HttpContext.Session.GetString("LastActivityUtc");

            return true;
        }

        protected string GetDefaultConnectionString()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(_env.ContentRootPath)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                .AddJsonFile($"appsettings.{_env.EnvironmentName}.json", optional: true, reloadOnChange: true);

            var configuration = builder.Build();
            return configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Default connection string is not configured.");
        }

        protected void SplitDataSet(DataSet ds)
        {
            permissionTable = (ds?.Tables?.Count ?? 0) > 0 ? ds.Tables[0] : null;
            dt1 = (ds?.Tables?.Count ?? 0) > 1 ? ds.Tables[1] : null;
            dt2 = (ds?.Tables?.Count ?? 0) > 2 ? ds.Tables[2] : null;
            dt3 = (ds?.Tables?.Count ?? 0) > 3 ? ds.Tables[3] : null;
            dt4 = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;
            dt5 = (ds?.Tables?.Count ?? 0) > 5 ? ds.Tables[5] : null;
            dt6 = (ds?.Tables?.Count ?? 0) > 6 ? ds.Tables[6] : null;
            dt7 = (ds?.Tables?.Count ?? 0) > 7 ? ds.Tables[7] : null;
            dt8 = (ds?.Tables?.Count ?? 0) > 8 ? ds.Tables[8] : null;
            dt9 = (ds?.Tables?.Count ?? 0) > 9 ? ds.Tables[9] : null;
        }

        private static List<Dictionary<string, object?>> ConvertTableToDictionaryList(DataTable? table)
        {
            var items = new List<Dictionary<string, object?>>();
            if (table == null)
                return items;

            foreach (DataRow row in table.Rows)
            {
                var item = new Dictionary<string, object?>();
                foreach (DataColumn column in table.Columns)
                {
                    var rawValue = row[column] == DBNull.Value ? null : row[column];
                    item[column.ColumnName] = rawValue is string textValue
                        ? NormalizeResidentText(textValue)
                        : rawValue;
                }
                items.Add(item);
            }

            return items;
        }

        // نص عربي محفوظ بترميز خاطئ (UTF-8 مقروء كـ Windows-1252) يُصحَّح عند العرض.
        private static string NormalizeResidentText(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty;

            var trimmedValue = value.Trim();
            if (ContainsArabicCharacters(trimmedValue) || !LooksLikeUtf8Mojibake(trimmedValue))
                return trimmedValue;

            try
            {
                var decodedValue = DecodeUtf8Mojibake(trimmedValue).Trim();
                return ContainsArabicCharacters(decodedValue) ? decodedValue : trimmedValue;
            }
            catch
            {
                return trimmedValue;
            }
        }

        private static string DecodeUtf8Mojibake(string value)
        {
            var bytes = new byte[value.Length];

            for (var index = 0; index < value.Length; index++)
            {
                var mappedByte = TryGetWindows1252Byte(value[index]);
                if (!mappedByte.HasValue)
                    return value;

                bytes[index] = mappedByte.Value;
            }

            return Encoding.UTF8.GetString(bytes);
        }

        private static byte? TryGetWindows1252Byte(char character)
        {
            if (character <= 0x00FF)
                return (byte)character;

            return character switch
            {
                '\u20AC' => 0x80,
                '\u201A' => 0x82,
                '\u0192' => 0x83,
                '\u201E' => 0x84,
                '\u2026' => 0x85,
                '\u2020' => 0x86,
                '\u2021' => 0x87,
                '\u02C6' => 0x88,
                '\u2030' => 0x89,
                '\u0160' => 0x8A,
                '\u2039' => 0x8B,
                '\u0152' => 0x8C,
                '\u017D' => 0x8E,
                '\u2018' => 0x91,
                '\u2019' => 0x92,
                '\u201C' => 0x93,
                '\u201D' => 0x94,
                '\u2022' => 0x95,
                '\u2013' => 0x96,
                '\u2014' => 0x97,
                '\u02DC' => 0x98,
                '\u2122' => 0x99,
                '\u0161' => 0x9A,
                '\u203A' => 0x9B,
                '\u0153' => 0x9C,
                '\u017E' => 0x9E,
                '\u0178' => 0x9F,
                _ => null
            };
        }

        private static bool LooksLikeUtf8Mojibake(string value)
        {
            return value.IndexOf('Ø') >= 0 || value.IndexOf('Ù') >= 0 || value.IndexOf('Ã') >= 0;
        }

        private static bool ContainsArabicCharacters(string value)
        {
            return value.Any(character => character >= '\u0600' && character <= '\u06FF');
        }
    }
}
