using SmartFoundation.UI.ViewModels.SmartForm;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController
    {
        private async Task<List<OptionItem>> GetClarificationReasonOptionsAsync(string? firstOption = "اختر سبب طلب التوضيح")
        {
            return await GetTicketDdlOptionsAsync(
                "clarificationReasonName_A",
                "clarificationReasonID",
                "1",
                "ClarificationReasonDDL",
                firstOption);
        }

        private async Task<Dictionary<long, long>> GetOpenClarificationRequestMapAsync(IEnumerable<long> ticketIds)
        {
            var ids = ticketIds
                .Where(id => id > 0)
                .Distinct()
                .ToList();

            if (ids.Count == 0)
                return new Dictionary<long, long>();

            var result = new Dictionary<long, long>();

            foreach (var ticketId in ids)
            {
                var table = await LoadClarificationRequestsFallbackAsync((int)ticketId);
                if (table.Rows.Count == 0)
                    continue;

                foreach (DataRow row in table.Rows)
                {
                    var status = row.Table.Columns.Contains("clarificationStatus")
                        ? row["clarificationStatus"]?.ToString()
                        : null;

                    if (!string.Equals(status, "OPEN", StringComparison.OrdinalIgnoreCase))
                        continue;

                    var rowTicketId = ticketId;
                    if (row.Table.Columns.Contains("ticketID_FK")
                        && long.TryParse(row["ticketID_FK"]?.ToString(), out var parsedTicketId)
                        && parsedTicketId > 0)
                    {
                        rowTicketId = parsedTicketId;
                    }

                    if (rowTicketId != ticketId)
                        continue;

                    if (!TryParseClarificationRequestId(row, out var clarificationRequestId))
                        continue;

                    result[rowTicketId] = clarificationRequestId;
                    break;
                }
            }

            return result;
        }

        private async Task<DataTable> LoadClarificationRequestsFallbackAsync(int ticketId)
        {
            try
            {
                DataSet dataSet = await _mastersServies.GetDataLoadDataSetAsync(
                    "ClarificationRequests",
                    IdaraId,
                    usersId,
                    HostName,
                    ticketId.ToString());

                var table = ResolveClarificationRequestsTable(dataSet);
                if (table != null)
                    return table;
            }
            catch
            {
                // Gateway route unavailable.
            }

            return new DataTable();
        }

        private static bool TryParseClarificationRequestId(DataRow row, out long clarificationRequestId)
        {
            clarificationRequestId = 0;

            if (row.Table.Columns.Contains("clarificationRequestID")
                && long.TryParse(row["clarificationRequestID"]?.ToString(), out clarificationRequestId)
                && clarificationRequestId > 0)
            {
                return true;
            }

            if (row.Table.Columns.Contains("clarificationRequestId")
                && long.TryParse(row["clarificationRequestId"]?.ToString(), out clarificationRequestId)
                && clarificationRequestId > 0)
            {
                return true;
            }

            return false;
        }

        private static DataTable? ResolveClarificationRequestsTable(DataSet? dataSet)
        {
            if (dataSet == null)
                return null;

            foreach (DataTable table in dataSet.Tables)
            {
                if (IsGatewayErrorTable(table))
                    continue;

                if (!table.Columns.Contains("clarificationRequestID")
                    || !table.Columns.Contains("clarificationStatus"))
                {
                    continue;
                }

                EnsureClarificationProjection(table);
                return table;
            }

            return null;
        }

        private static void EnsureClarificationProjection(DataTable table)
        {
            if (!table.Columns.Contains("entryDate") && table.Columns.Contains("requestDate"))
            {
                table.Columns.Add("entryDate", typeof(string));
                foreach (DataRow row in table.Rows)
                {
                    row["entryDate"] = row["requestDate"]?.ToString() ?? string.Empty;
                }
            }

            if (!table.Columns.Contains("targetDSDName_A"))
            {
                table.Columns.Add("targetDSDName_A", typeof(string));
            }

            foreach (DataRow row in table.Rows)
            {
                if (!string.IsNullOrWhiteSpace(row["targetDSDName_A"]?.ToString()))
                    continue;

                var parts = new List<string>();
                if (table.Columns.Contains("requestedFromDepartmentName")
                    && !string.IsNullOrWhiteSpace(row["requestedFromDepartmentName"]?.ToString()))
                {
                    parts.Add(row["requestedFromDepartmentName"]!.ToString()!);
                }

                if (table.Columns.Contains("requestedFromDivisionName")
                    && !string.IsNullOrWhiteSpace(row["requestedFromDivisionName"]?.ToString()))
                {
                    parts.Add(row["requestedFromDivisionName"]!.ToString()!);
                }

                if (table.Columns.Contains("requestedFromSectionName")
                    && !string.IsNullOrWhiteSpace(row["requestedFromSectionName"]?.ToString()))
                {
                    parts.Add(row["requestedFromSectionName"]!.ToString()!);
                }

                row["targetDSDName_A"] = parts.Count == 0 ? string.Empty : string.Join(" / ", parts);
            }
        }
    }
}