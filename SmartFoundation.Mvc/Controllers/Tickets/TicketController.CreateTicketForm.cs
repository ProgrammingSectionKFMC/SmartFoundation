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
        /// description, priority and the resident's location. The requester employee is taken
        /// from the session by TicketSP, not from the form.
        /// </summary>
        /// <remarks>
        /// All lists come from the TicketList page DataSet (Tickets.TicketListDL):
        /// [14] requester types, [15] residents, [3] services + [8] classes, [16] buildings,
        /// [17] reasons (loaded by service through /crud/DDLFiltered).
        /// Masters_CRUD INSERT_TICKET mapping: p02 requesterType, p04 resident,
        /// p05 service, p07 description, p12 building, p14 location text, p17 reason,
        /// p18 reporter name, p19 reporter phone, p20 urgent.
        /// </remarks>
        private List<FieldConfig> BuildCreateTicketFields(
            string? pageName,
            string currentUrl,
            string requestToken,
            DataTable? requesterTypes,
            List<OptionItem> residentOptions,
            List<OptionItem> serviceOptions,
            List<OptionItem> buildingOptions)
        {
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
                new FieldConfig { Name = "pageName_",          Type = "hidden", Value = pageName },
                new FieldConfig { Name = "ActionType",         Type = "hidden", Value = "INSERT_TICKET" },
                new FieldConfig { Name = "redirectUrl",     Type = "hidden", Value = currentUrl },
                new FieldConfig { Name = "redirectAction",     Type = "hidden", Value = pageName },
                new FieldConfig { Name = "redirectController", Type = "hidden", Value = "Ticket" },
                new FieldConfig { Name = "__RequestVerificationToken", Type = "hidden", Value = requestToken },

                new FieldConfig
                {
                    Label = "من صاحب البلاغ؟", Name = "p02", Type = "select", Required = true, ColCss = "6",
                    Options = reporterOptions, Value = employeeType, ShowFieldsWhen = showWhen
                },
                new FieldConfig
                {
                    Label = "الساكن", Name = "p04", Type = "select", Required = true, ColCss = "6", Select2 = true,
                    Options = residentOptions,
                    Placeholder = "ابحث بالاسم أو رقم الهوية",
                    HelpText = "يُحدَّد موقع البلاغ تلقائياً من سكن الساكن."
                },
                new FieldConfig { Label = "اسم المبلّغ", Name = "p18", Type = "text", ColCss = "6", MaxLength = 200, Placeholder = "اختياري" },
                new FieldConfig { Label = "جوال المبلّغ", Name = "p19", Type = "text", ColCss = "6", MaxLength = 15, TextMode = "number", Placeholder = "اختياري — 05xxxxxxxx" },

                new FieldConfig
                {
                    Label = "نوع المشكلة", Name = "p05", Type = "select", Required = true, ColCss = "6", Select2 = true,
                    Options = serviceOptions,
                    Placeholder = "ابحث عن المشكلة، مثل: سباكة، كهرباء، إنترنت"
                },
                new FieldConfig
                {
                    Label = "السبب", Name = "p17", Type = "select", ColCss = "6", Select2 = true,
                    Options = new List<OptionItem>(),
                    DependsOn = "p05",
                    DependsUrl = "/crud/DDLFiltered?FK=serviceID_FK&textcol=ticketReasonName_A&ValueCol=ticketReasonID&PageName=TicketList&TableIndex=17",
                    HelpText = "اختياري — يساعد على تحديد الأولوية."
                },
                new FieldConfig
                {
                    Label = "تفاصيل المشكلة", Name = "p07", Type = "textarea", ColCss = "6", MaxLength = 2000,
                    Placeholder = "اكتب ما تلاحظه بإيجاز (اختياري)"
                },

                new FieldConfig
                {
                    Label = "المبنى", Name = "p12", Type = "select", ColCss = "6", Select2 = true,
                    Options = buildingOptions,
                    Placeholder = "اختياري"
                },
                new FieldConfig
                {
                    Label = "الموقع", Name = "p14", Type = "text", ColCss = "6", MaxLength = 200,
                    Placeholder = "الحي، الشارع، أقرب معلم",
                    HelpText = "مطلوب للبلاغ العام."
                },
                new FieldConfig { Label = "الحالة عاجلة", Name = "p20", Type = "checkbox", ColCss = "6" }
            };
        }

        /// <summary>
        /// All active services as one searchable list, labelled "الفئة — الخدمة".
        /// </summary>
        private static List<OptionItem> BuildGroupedServiceOptions(DataTable? services, DataTable? classes)
        {
            var classNames = new Dictionary<string, string>();
            if (classes != null && classes.Columns.Contains("ticketClassID") && classes.Columns.Contains("ticketClassName_A"))
            {
                foreach (DataRow r in classes.Rows)
                    classNames[r["ticketClassID"]?.ToString() ?? ""] = r["ticketClassName_A"]?.ToString() ?? "";
            }

            if (services == null || !services.Columns.Contains("serviceID"))
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
