using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.Mvc.Models;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using System.Text.RegularExpressions;
using static System.Net.Mime.MediaTypeNames;
using Microsoft.Extensions.DependencyInjection;  // ✅ إضافة هذا




namespace SmartFoundation.Mvc.Controllers.ControlPanel
{
    public partial class ControlPanelController : Controller
    {

       // private readonly MastersDataLoadService _mastersDataLoadService;
        private readonly MastersServies _mastersServies;
        private readonly CrudController _CrudController;
        private readonly ILogger<ControlPanelController> _logger;  // ✅ إضافة Logger



        [ActivatorUtilitiesConstructor]
        public ControlPanelController(MastersServies mastersServies, CrudController crudController, ILogger<ControlPanelController> logger)
        {
            // _mastersDataLoadService = mastersDataLoadService;
            _mastersServies = mastersServies;
            _CrudController = crudController;
            _logger = logger;
        }

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
        protected DataTable? dt10;
        protected DataTable? dt11;
        protected DataTable? dt12;
        protected DataTable? dt13;



        protected bool InitPageContext(out IActionResult? redirectResult)
        {
            redirectResult = null;

            if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
            {
                redirectResult = RedirectToAction("Index", "Login", new { logout = 1 });
                return false;
            }

            usersId = HttpContext.Session.GetString("usersID") ?? "0";
            FullName = HttpContext.Session.GetString("fullName");
            OrganizationId = HttpContext.Session.GetString("OrganizationID");
            OrganizationName = HttpContext.Session.GetString("OrganizationName");
            IdaraId = HttpContext.Session.GetString("IdaraID") ?? "0";
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
            dt10 = (ds?.Tables?.Count ?? 0) > 10 ? ds.Tables[10] : null;
            dt11 = (ds?.Tables?.Count ?? 0) > 11 ? ds.Tables[11] : null;
            dt12 = (ds?.Tables?.Count ?? 0) > 12 ? ds.Tables[12] : null;
            dt13 = (ds?.Tables?.Count ?? 0) > 13 ? ds.Tables[13] : null;
        }

        public IActionResult Index()

        {
            return View();
        }

    

        // Add an endpoint that returns permissions options filtered by distributorID_FK
        //[HttpGet]
        //public async Task<IActionResult> PermissionsByDistributor1(string p01) // Changed from int distributorId
        //{


        //    if (string.IsNullOrWhiteSpace(HttpContext.Session.GetString("usersID")))
        //        return Unauthorized();

        //    if (!int.TryParse(p01, out int distributorId) || distributorId == -1)
        //        return Json(new List<object> { new { value = "-1", text = "الرجاء الاختيار" } });

        //    int userID = Convert.ToInt32(HttpContext.Session.GetString("usersID"));
        //    int IdaraID = Convert.ToInt32(HttpContext.Session.GetString("IdaraID"));
        //    string HostName = HttpContext.Session.GetString("HostName");

        //    var ds = await _mastersServies.GetDataLoadDataSetAsync("Permission", IdaraID, userID, HostName);
        //    var table = (ds?.Tables?.Count ?? 0) > 4 ? ds.Tables[4] : null;

        //    var items = new List<object>();
        //    if (table is not null && table.Rows.Count > 0 && table.Columns.Contains("distributorID_FK"))
        //    {
        //        foreach (DataRow row in table.Rows)
        //        {
        //            var fk = row["distributorID_FK"]?.ToString()?.Trim();
        //            if (fk == distributorId.ToString())
        //            {
        //                var value = row["distributorPermissionTypeID"]?.ToString()?.Trim() ?? "";
        //                var text = row["permissionTypeName_A"]?.ToString()?.Trim() ?? "";
        //                if (!string.IsNullOrEmpty(value))
        //                    items.Add(new { value, text });
        //            }
        //        }
        //    }

        //    if (!items.Any())
        //        items.Add(new { value = "-1", text = "لا توجد صلاحيات لهذا الموزع" });

        //    return Json(items);
        //}


    }
}