using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Tickets
{
    public partial class TicketController : Controller
    {
        /// <summary>
        /// Fields for the "تذكرة جديدة" form. The user only answers who is reporting, what the
        /// problem is and where; Tickets.TicketSP (INSERT_TICKET) derives class, title,
        /// description, priority and the resident's location.
        /// </summary>
        /// <remarks>
        /// Masters_CRUD INSERT_TICKET mapping: p02 requesterType, p03 requesterUser, p04 resident,
        /// p05 service, p07 description, p12 building, p14 location text, p17 reason,
        /// p18 reporter name, p19 reporter phone, p20 urgent.
        /// </remarks>
        private async Task<List<FieldConfig>> BuildCreateTicketFieldsAsync(string? requesterUserValue)
        {
            var requesterTypes = ResolveUsableTable(
                await _mastersServies.GetDataLoadDataSetAsync("RequesterTypeDDL", IdaraId, usersId, HostName),
                "requesterTypeCode");

            string? TypeId(string code) => requesterTypes?.Rows.Cast<DataRow>()
                .FirstOrDefault(r => string.Equals(r["requesterTypeCode"]?.ToString(), code, StringComparison.OrdinalIgnoreCase))?["requesterTypeID"]?.ToString();

            var employeeType = TypeId("INTERNAL");
            var residentType = TypeId("RESIDENT");
            var publicType = TypeId("PUBLIC");

            var reporterOptions = new List<OptionItem>();
            if (employeeType != null) reporterOptions.Add(new OptionItem { Value = employeeType, Text = "أنا (موظف) — أبلّغ عن مشكلة" });
            if (residentType != null) reporterOptions.Add(new OptionItem { Value = residentType, Text = "ساكن — بلاغ عن سكنه" });
            if (publicType != null) reporterOptions.Add(new OptionItem { Value = publicType, Text = "بلاغ عام عن موقع (شارع، حي، مرفق)" });

            var showWhen = new Dictionary<string, List<string>>();
            if (employeeType != null) showWhen[employeeType] = new() { "p12", "p14" };
            if (residentType != null) showWhen[residentType] = new() { "p04" };
            if (publicType != null) showWhen[publicType] = new() { "p14", "p18", "p19" };

            return new List<FieldConfig>
            {
                new() { Name = "pageName_",          Type = "hidden", Value = "TicketDetails" },
                new() { Name = "ActionType",         Type = "hidden", Value = "INSERT_TICKET" },
                new() { Name = "idaraID",            Type = "hidden", Value = IdaraId },
                new() { Name = "entrydata",          Type = "hidden", Value = usersId },
                new() { Name = "hostname",           Type = "hidden", Value = HostName },
                new() { Name = "redirectAction",     Type = "hidden", Value = "TicketList" },
                new() { Name = "redirectController", Type = "hidden", Value = "Ticket" },
                new() { Name = "p03",                Type = "hidden", Value = requesterUserValue },

                new()
                {
                    Label = "من صاحب البلاغ؟", Name = "p02", Type = "select", Required = true, ColCss = "6",
                    Options = reporterOptions, Value = employeeType, ShowFieldsWhen = showWhen
                },
                new()
                {
                    Label = "الساكن", Name = "p04", Type = "select", Required = true, ColCss = "6", Select2 = true,
                    Options = await GetTicketDdlOptionsAsync("FullName_A", "residentInfoID", "1", "ResidentDDL"),
                    Placeholder = "ابحث بالاسم أو رقم الهوية",
                    HelpText = "يُحدَّد موقع البلاغ تلقائياً من سكن الساكن."
                },
                new() { Label = "اسم المبلّغ", Name = "p18", Type = "text", ColCss = "6", MaxLength = 200, Placeholder = "اختياري" },
                new() { Label = "جوال المبلّغ", Name = "p19", Type = "text", ColCss = "6", MaxLength = 15, TextMode = "number", Placeholder = "اختياري — 05xxxxxxxx" },

                new()
                {
                    Label = "نوع المشكلة", Name = "p05", Type = "select", Required = true, ColCss = "6", Select2 = true,
                    Options = await BuildGroupedServiceOptionsAsync(),
                    Placeholder = "ابحث عن المشكلة، مثل: سباكة، كهرباء، إنترنت"
                },
                new()
                {
                    Label = "السبب", Name = "p17", Type = "select", ColCss = "6", Select2 = true,
                    Options = new List<OptionItem>(),
                    DependsOn = "p05",
                    DependsUrl = "/crud/DDLFiltered?FK=serviceID_FK&textcol=ticketReasonName_A&ValueCol=ticketReasonID&PageName=TicketReasonDDL&TableIndex=1",
                    HelpText = "اختياري — يساعد على تحديد الأولوية."
                },
                new()
                {
                    Label = "تفاصيل المشكلة", Name = "p07", Type = "textarea", ColCss = "6", MaxLength = 2000,
                    Placeholder = "اكتب ما تلاحظه بإيجاز (اختياري)"
                },

                new()
                {
                    Label = "المبنى", Name = "p12", Type = "select", ColCss = "6", Select2 = true,
                    Options = await GetTicketDdlOptionsAsync("buildingDetailsNo", "buildingDetailsNo", "1", "BuildingDDL"),
                    Placeholder = "اختياري"
                },
                new()
                {
                    Label = "الموقع", Name = "p14", Type = "text", ColCss = "6", MaxLength = 200,
                    Placeholder = "الحي، الشارع، أقرب معلم",
                    HelpText = "مطلوب للبلاغ العام."
                },
                new() { Label = "الحالة عاجلة", Name = "p20", Type = "checkbox", ColCss = "6" }
            };
        }

        /// <summary>
        /// All active services as one searchable list, labelled "الفئة — الخدمة".
        /// </summary>
        private async Task<List<OptionItem>> BuildGroupedServiceOptionsAsync()
        {
            var services = ResolveUsableTable(
                await _mastersServies.GetDataLoadDataSetAsync("ServiceDDL", IdaraId, usersId, HostName),
                "serviceID");
            var classes = ResolveUsableTable(
                await _mastersServies.GetDataLoadDataSetAsync("TicketClassDDL", IdaraId, usersId, HostName),
                "ticketClassID");

            var classNames = classes?.Rows.Cast<DataRow>().ToDictionary(
                r => r["ticketClassID"]?.ToString() ?? "",
                r => r["ticketClassName_A"]?.ToString() ?? "") ?? new Dictionary<string, string>();

            if (services == null)
                return new List<OptionItem>();

            return services.Rows.Cast<DataRow>()
                .Select(r => new
                {
                    Value = r["serviceID"]?.ToString() ?? "",
                    Service = r["serviceName_A"]?.ToString()?.Trim() ?? "",
                    Class = classNames.TryGetValue(r["ticketClassID_FK"]?.ToString() ?? "", out var name) ? name : ""
                })
                .Where(x => x.Value != "")
                .OrderBy(x => x.Class).ThenBy(x => x.Service)
                .Select(x => new OptionItem { Value = x.Value, Text = x.Class == "" ? x.Service : $"{x.Class} — {x.Service}" })
                .ToList();
        }
    }
}
