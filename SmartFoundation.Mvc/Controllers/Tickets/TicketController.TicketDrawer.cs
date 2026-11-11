using Microsoft.AspNetCore.Mvc;
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
        public async Task<IActionResult> TicketDrawer(int id)
        {
            if (!InitPageContext(out _) || string.IsNullOrWhiteSpace(usersId))
                return Unauthorized();

            if (id <= 0)
                return BadRequest();

            // "TicketDetails" stays the DB page that owns ticket read permissions and data.
            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(
                "TicketDetails", IdaraId, usersId, HostName, id.ToString());

            var permissions = (ds?.Tables?.Count ?? 0) > 0 ? ds!.Tables[0] : null;
            if (permissions is null || permissions.Rows.Count == 0)
                return StatusCode(StatusCodes.Status403Forbidden);

            var ticketTable = ResolveUsableTable(ds, "ticketID", "ticketNo");
            if (ticketTable is null || ticketTable.Rows.Count == 0)
                return NotFound();

            var model = new TicketDrawerViewModel
            {
                Ticket = ConvertTableToDictionaryList(ticketTable)[0],
                History = ConvertTableToDictionaryList(
                    await LoadTicketDataTableAsync("TicketHistory", id, "actionTypeCode", "actionDate")),
                ChildTickets = ConvertTableToDictionaryList(
                    await LoadTicketDataTableAsync("ChildTickets", id, "ticketID", "ticketNo")),
                PauseSessions = ConvertTableToDictionaryList(
                    await LoadTicketDataTableAsync("PauseSessions", id, "ticketPauseSessionID", "pauseStart")),
                QualityReviews = ConvertTableToDictionaryList(
                    await LoadTicketDataTableAsync("QualityReviews", id, "qualityReviewID", "entryDate")),
                ClarificationRequests = ConvertTableToDictionaryList(
                    await LoadClarificationRequestsFallbackAsync(id)),
                Attachments = ConvertTableToDictionaryList(
                    await LoadTicketDataTableAsync("TicketAttachments", id, "ticketAttachmentID", "fileName"))
            };

            return PartialView("_TicketDrawer", model);
        }
    }
}
