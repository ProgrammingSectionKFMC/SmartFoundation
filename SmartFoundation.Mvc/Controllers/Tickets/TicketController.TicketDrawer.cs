using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.DataLoad;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    /// <summary>
    /// Read-only ticket view rendered inside the TicketList SmartDrawer.
    /// </summary>
    public class TicketDrawerViewModel
    {
        public Dictionary<string, object?> Ticket { get; set; } = new();
        public List<Dictionary<string, object?>> History { get; set; } = new();
        public List<Dictionary<string, object?>> ChildTickets { get; set; } = new();
        public List<Dictionary<string, object?>> PauseSessions { get; set; } = new();
        public List<Dictionary<string, object?>> QualityReviews { get; set; } = new();
        public List<Dictionary<string, object?>> ClarificationRequests { get; set; } = new();
        public List<Dictionary<string, object?>> Attachments { get; set; } = new();
    }

    public partial class TicketController : Controller
    {
        /// <summary>
        /// Returns the ticket drawer content as a partial view for the given ticket.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> TicketDrawer([FromServices] RequestScopedDataLoadService requestDataLoad, int id)
        {
            //  قراءة السيشن والكونتكست
            if (!InitPageContext(out _) || string.IsNullOrWhiteSpace(usersId))
                return Unauthorized();

            if (id <= 0)
                return BadRequest();

            ControllerName = "Ticket";
            PageName = "TicketDrawer";

            var pageParameters = new Dictionary<string, object?>(
               StringComparer.OrdinalIgnoreCase)
            {
                ["pageName_"] = PageName,
                ["parameter_01"] = id
            };

            if (IdaraId != null)
                pageParameters["idaraID"] = Convert.ToInt32(IdaraId);

            if (usersId != null)
                pageParameters["entrydata"] = Convert.ToInt32(usersId);

            if (HostName != null)
                pageParameters["hostname"] = HostName;

            // Masters_DataLoad -> [Tickets].[TicketDrawerDL]
            // [0] الصلاحيات  [1] صلاحيات صفحة قائمة التذاكر  [2] بيانات التذكرة  [3] سجل الإجراءات
            // [4] التذاكر الفرعية  [5] فترات الإيقاف  [6] مراجعات الجودة  [7] طلبات التوضيح  [8] المرفقات
            DataSet ds = await requestDataLoad.GetDataLoadDataSetAsync(pageParameters);

            //  تقسيم الداتا سيت للجدول الأول + جداول أخرى
            SplitDataSet(ds);

            //  التحقق من الصلاحيات: النافذة تابعة لقائمة التذاكر وقراءة التذكرة تتطلب SELECT هناك
            //  (TicketDrawerDL لا يُرجع بيانات التذكرة أصلاً بدون هذه الصلاحية)
            bool canSELECT = false;
            if (dt1 != null && dt1.Columns.Contains("permissionTypeName_E"))
            {
                foreach (DataRow row in dt1.Rows)
                {
                    var permissionName = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (permissionName == "SELECT") canSELECT = true;
                }
            }

            if (!canSELECT)
                return StatusCode(StatusCodes.Status403Forbidden);

            if (dt2 == null || dt2.Rows.Count == 0)
                return NotFound();

            var model = new TicketDrawerViewModel
            {
                Ticket = ConvertTableToDictionaryList(dt2)[0],
                History = ConvertTableToDictionaryList(dt3),
                ChildTickets = ConvertTableToDictionaryList(dt4),
                PauseSessions = ConvertTableToDictionaryList(dt5),
                QualityReviews = ConvertTableToDictionaryList(dt6),
                ClarificationRequests = ConvertTableToDictionaryList(dt7),
                Attachments = ConvertTableToDictionaryList(dt8)
            };

            return PartialView("_TicketDrawer", model);
        }
    }
}
