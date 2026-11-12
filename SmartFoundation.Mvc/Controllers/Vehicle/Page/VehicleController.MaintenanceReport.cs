using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Data;
using System.Linq;
using SmartFoundation.MVC.Reports;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [Route("Vehicle/MaintenanceReport")]
        public async Task<IActionResult> MaintenanceReport(int pdf = 0, int? month = null, int? year = null)
        {
            if (!InitPageContext(out IActionResult? redirectResult))
                return redirectResult!;

            if (string.IsNullOrWhiteSpace(usersId))
                return RedirectToAction("Index", "Login", new { logout = 4 });

            ControllerName = "Vehicle";
            PageName = "MaintenanceReport";

            #region Workshop Lookup

            var workshopLookup = new Dictionary<string, string>();
            try
            {
                var wsDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { "GeneralMaintenance", IdaraId, usersId, HostName, "LIST_WORKSHOPS" });
                DataTable? wsTable = (wsDs?.Tables?.Count ?? 0) > 1 ? wsDs!.Tables[1] : null;
                if (wsTable != null)
                {
                    foreach (DataRow r in wsTable.Rows)
                    {
                        string id = r["typesID"]?.ToString() ?? "";
                        string name = r["typesName_A"]?.ToString() ?? "";
                        if (!string.IsNullOrEmpty(id))
                            workshopLookup[id] = name;
                    }
                }
            }
            catch { }

            #endregion

            #region Calculate Date Filter

            DateTime? fromDate = null;
            DateTime? toDate = null;
            if (month.HasValue && year.HasValue)
            {
                fromDate = new DateTime(year.Value, month.Value, 1);
                toDate = new DateTime(year.Value, month.Value, DateTime.DaysInMonth(year.Value, month.Value));
            }

            #endregion

            #region Load Data

            DataSet? ddlDs = null;
            try
            {
                ddlDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { PageName, IdaraId, usersId, HostName,
                        "LIST_MONTHLY_REPORT", null, null, null, null, null,
                        fromDate, toDate });
            }
            catch { }

            SplitDataSet(ddlDs);

            bool canAccess = false;
            bool canSelect = false;
            bool canPrint = false;

            if (permissionTable != null && permissionTable.Rows.Count > 0)
            {
                foreach (DataRow row in permissionTable.Rows)
                {
                    var p = row["permissionTypeName_E"]?.ToString()?.Trim().ToUpper();
                    if (p == "ACCESS") canAccess = true;
                    if (p == "SELECT") canSelect = true;
                    if (p == "PRINT") canPrint = true;
                }
            }

            #endregion

            #region Month / Year Options (from SP result tables)

            var monthOptions = new List<OptionItem>
            {
                new OptionItem { Value = "", Text = "— الكل —" }
            };
            for (int i = 1; i <= 12; i++)
            {
                monthOptions.Add(new OptionItem
                {
                    Value = i.ToString(),
                    Text = i.ToString("D2"),
                    Selected = month.HasValue && month.Value == i
                });
            }

            var yearOptions = new List<OptionItem>
            {
                new OptionItem { Value = "", Text = "— الكل —" }
            };

            DataTable? yearsTable = (ddlDs?.Tables?.Count ?? 0) > 3 ? ddlDs!.Tables[3] : null;
            if (yearsTable != null)
            {
                foreach (DataRow r in yearsTable.Rows)
                {
                    var yVal = r["YearNum"]?.ToString() ?? "";
                    if (!string.IsNullOrEmpty(yVal))
                    {
                        yearOptions.Add(new OptionItem
                        {
                            Value = yVal,
                            Text = yVal,
                            Selected = year.HasValue && yVal == year.Value.ToString()
                        });
                    }
                }
            }
            else
            {
                int currentYear = DateTime.Today.Year;
                for (int y = currentYear - 5; y <= currentYear + 1; y++)
                {
                    yearOptions.Add(new OptionItem
                    {
                        Value = y.ToString(),
                        Text = y.ToString(),
                        Selected = year.HasValue && y == year.Value
                    });
                }
            }

            #endregion

            #region Filter Form

            var filterForm = new FormConfig
            {
                FormId = "reportFilterForm",
                Title = "",
                Method = "GET",
                ActionUrl = "",
                ShowSubmit = false,
                ShowReset = false,
                Fields = new List<FieldConfig>
                {
                    new FieldConfig { Name = "month", Label = "الشهر", Type = "select", ColCss = "2",
                        Options = monthOptions },
                    new FieldConfig { Name = "year", Label = "السنة", Type = "select", ColCss = "2",
                        Options = yearOptions }
                },
                Buttons = new List<FormButtonConfig>
                {
                    new FormButtonConfig
                    {
                        Text = "عرض التقرير",
                        Type = "button",
                        Color = "info",
                        Icon = "fa fa-search",
                        OnClickJs = @"
                            const f = document.getElementById('reportFilterForm');
                            const m = f.querySelector('[name=""month""]');
                            const y = f.querySelector('[name=""year""]');
                            const url = new URL(window.location.pathname, window.location.origin);
                            if (m && m.value) url.searchParams.set('month', m.value);
                            if (y && y.value) url.searchParams.set('year', y.value);
                            window.location.href = url.toString();
                        "
                    },
                    new FormButtonConfig
                    {
                        Text = "تفريغ",
                        Type = "button",
                        Color = "secondary",
                        Icon = "fa fa-eraser",
                        OnClickJs = @"window.location.href = window.location.pathname;"
                    }
                }
            };

            #endregion

            #region Build Grid Columns

            var visibleFields = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "jobOrderNumber", "vehicleDesc", "workRequestedBy",
                "armyNumber", "correctiveSummary",
                "dateReceived", "dateRepairStarted", "dateRepairFinished",
                "manHours", "costLabor", "costParts", "totalCost"
            };

            var headerMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["jobOrderNumber"] = "رقم أمر العمل",
                ["vehicleDesc"] = "الكمية والتسمية",
                ["workRequestedBy"] = "جهة طلب العمل",
                ["armyNumber"] = "رقم التسجيل أو التسلسل",
                ["correctiveSummary"] = "بيان موجز للعمل أو ملاحظات",
                ["dateReceived"] = "تاريخ استلام أمر العمل",
                ["dateRepairStarted"] = "تاريخ الإصلاح - البدء",
                ["dateRepairFinished"] = "تاريخ الإصلاح - الانتهاء",
                ["manHours"] = "ساعات العمل",
                ["costLabor"] = "التكاليف - العمل",
                ["costParts"] = "التكاليف - القطع",
                ["totalCost"] = "التكاليف الكلية للعمل"
            };

            #endregion

            #region Process Grid Rows

            var rowsList = new List<Dictionary<string, object?>>();
            List<TableColumn> columns = new();

            if (dt1 != null && dt1.Columns.Count > 0)
            {
                foreach (DataRow r in dt1.Rows)
                {
                    var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                    foreach (DataColumn c in dt1.Columns)
                    {
                        var val = r[c];
                        dict[c.ColumnName] = val == DBNull.Value ? null : val;
                    }

                    string Get(string key) => dict.TryGetValue(key, out var v) ? v?.ToString() ?? "" : "";

                    var wsIds = dict.TryGetValue("workshopIDs", out var wsVal) ? wsVal?.ToString() : null;
                    if (!string.IsNullOrEmpty(wsIds))
                    {
                        var names = wsIds.Split(',')
                            .Select(id => workshopLookup.TryGetValue(id.Trim(), out var n) ? n : id.Trim())
                            .Where(n => !string.IsNullOrEmpty(n));
                        dict["workshopNames"] = string.Join("، ", names);
                    }

                    string letters = Get("plateLetters");
                    string numbers = Get("plateNumbers");
                    dict["vehicleDesc"] = string.Join(" ", new[] { letters, numbers }.Where(p => !string.IsNullOrEmpty(p)));

                    dict["workRequestedBy"] = "";

                    string typeId = Get("MaintOrdTypeID_FK").Trim();
                    dict["totalCost"] = typeId == "265" ? "زيت"
                        : typeId == "266" ? (dict.TryGetValue("workshopNames", out var wn) ? wn?.ToString() ?? "" : "")
                        : "";

                    string FmtDate(object? val)
                    {
                        if (val is DateTime dt) return dt.ToString("yyyy/MM/dd");
                        if (val != null && DateTime.TryParse(val.ToString(), out var parsed)) return parsed.ToString("yyyy/MM/dd");
                        return "";
                    }

                    dict["dateReceived"] = FmtDate(dict.GetValueOrDefault("MaintOrdStartDate"));
                    dict["dateRepairStarted"] = FmtDate(dict.GetValueOrDefault("MaintOrdStartDate"));
                    dict["dateRepairFinished"] = FmtDate(dict.GetValueOrDefault("MaintOrdEndDate"));
                    dict["manHours"] = "";
                    dict["costLabor"] = "";
                    dict["costParts"] = "";

                    var txt = Get("correctiveSummary");
                    if (string.IsNullOrEmpty(txt)) txt = Get("faultSummary");
                    if (string.IsNullOrEmpty(txt)) txt = Get("MaintOrdDesc");
                    if (txt.Length > 100) txt = txt.Substring(0, Math.Min(95, txt.Length)) + "...";
                    dict["correctiveSummary"] = txt;

                    rowsList.Add(dict);
                }

                columns = BuildReportColumns(dt1, visibleFields, headerMap);
            }

            #endregion

            #region Toolbar

            var toolbar = new TableToolbarConfig
            {
                ShowRefresh = true,
                ShowColumns = true,
                ShowPrint1 = canPrint,
                Print1 = new TableAction
                {
                    Label = "طباعة سجل الصيانة",
                    Icon = "fa fa-print",
                    Color = "info",
                    OnClickJs = @"
                        sfPrintWithBusy(table, {
                            pdf: 2,
                            busy: { title: 'طباعة سجل طلبات الصيانة' }
                        });
                    "
                }
            };

            #endregion

            #region SmartTableDsModel

            var dsModel = new SmartTableDsModel
            {
                Columns = columns,
                Rows = rowsList,
                RowIdField = "MaintOrdID",
                PageSize = 100,
                PageSizes = new List<int> { 50, 100, 500 },
                Searchable = true,
                AllowExport = true,
                PageTitle = "سجل طلبات الصيانة الشهري",
                PanelTitle = "سجل طلبات الصيانة",
                Toolbar = toolbar
            };

            #endregion

            var page = new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-clipboard-list",
                Form = filterForm,
                TableDS = dsModel
            };

            #region Print PDF (pdf = 2)

            if (pdf == 2)
            {
                DateTime? pdfFrom = null;
                DateTime? pdfTo = null;
                string periodLabel;

                if (month.HasValue && year.HasValue)
                {
                    pdfFrom = new DateTime(year.Value, month.Value, 1);
                    pdfTo = new DateTime(year.Value, month.Value, DateTime.DaysInMonth(year.Value, month.Value));
                    periodLabel = $"{month.Value:D2}/{year}";
                }
                else
                {
                    periodLabel = "الكل";
                }

                var pdfDs = await _mastersServies.GetDataLoadDataSetAsync(
                    new object?[] { PageName, IdaraId, usersId, HostName,
                        "LIST_MONTHLY_REPORT", null, null, null, null, null,
                        pdfFrom, pdfTo });

                DataTable? pdfTable = (pdfDs?.Tables?.Count ?? 0) > 1 ? pdfDs!.Tables[1] : null;

                var pdfRows = new List<Dictionary<string, object?>>();

                if (pdfTable != null)
                {
                    foreach (DataRow r in pdfTable.Rows)
                    {
                        var dict = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                        foreach (DataColumn c in pdfTable.Columns)
                        {
                            var val = r[c];
                            dict[c.ColumnName] = val == DBNull.Value ? null : val;
                        }

                        var wsIds = dict.TryGetValue("workshopIDs", out var wsVal) ? wsVal?.ToString() : null;
                        if (!string.IsNullOrEmpty(wsIds))
                        {
                            var names = wsIds.Split(',')
                                .Select(id => workshopLookup.TryGetValue(id.Trim(), out var n) ? n : id.Trim())
                                .Where(n => !string.IsNullOrEmpty(n));
                            dict["workshopNames"] = string.Join("، ", names);
                        }

                        pdfRows.Add(dict);
                    }
                }

                string GetVal(Dictionary<string, object?> d, string key)
                    => d.TryGetValue(key, out var v) ? v?.ToString() ?? "" : "";

                string FmtDatePdf(object? val)
                {
                    if (val is DateTime dt) return dt.ToString("yyyy/MM/dd");
                    if (val != null && DateTime.TryParse(val.ToString(), out var parsed)) return parsed.ToString("yyyy/MM/dd");
                    return "";
                }

                string TotalCost(Dictionary<string, object?> row)
                {
                    var t = row.TryGetValue("MaintOrdTypeID_FK", out var tv) ? tv?.ToString()?.Trim() : "";
                    if (t == "265") return "زيت";
                    if (t == "266") return GetVal(row, "workshopNames");
                    return "";
                }

                string VehicleDesc(Dictionary<string, object?> row)
                {
                    var letters = GetVal(row, "plateLetters");
                    var numbers = GetVal(row, "plateNumbers");
                    var parts = new[] { letters, numbers }.Where(p => !string.IsNullOrEmpty(p));
                    return string.Join(" ", parts);
                }

                LetterTableCell HD(string text, int span = 1, float size = 5.5f) => new LetterTableCell
                {
                    Text = text,
                    Bold = true,
                    Align = TextAlign.Center,
                    BackgroundColor = "#D9E1F2",
                    FontSize = size,
                    ColumnSpan = span
                };

                LetterTableCell V(string text = "", int span = 1, TextAlign align = TextAlign.Center, float size = 6.5f) => new LetterTableCell
                {
                    Text = text,
                    Bold = false,
                    Align = align,
                    BackgroundColor = "#FFFFFF",
                    FontSize = size,
                    ColumnSpan = span
                };

                var register = ReportTableFactory.CreateOfficialTable(
                    new List<float> { 1.4f, 2.4f, 1.6f, 1.4f, 2.6f, 1.3f, 1.3f, 1.3f, 0.9f, 1.0f, 1.0f, 1.4f }
                );

                register.ExtendVertical = false;
                register.BorderWidth = 1.0f;
                register.BorderColor = "#000000";
                register.CellPadding = 1.5f;
                register.MinRowHeight = 18f;

                register.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        new LetterTableCell
                        {
                            Text = $"سجل طلبات الصيانة — {periodLabel}\nMAINTENANCE REQUEST REGISTER\nSAA TM (38-750)",
                            Bold = true,
                            Align = TextAlign.Center,
                            ColumnSpan = 12,
                            FontSize = 8f,
                            BackgroundColor = "#FFFFFF"
                        }
                    }
                });

                register.Rows.Add(new LetterTableRow
                {
                    Cells = new()
                    {
                        HD("رقم أمر العمل\nJOB ORDER\nNUMBER", size: 4.5f),
                        HD("الكمية والتسمية\nQUANTITY AND\nNOMENCLATURE", size: 4.5f),
                        HD("جهة طلب العمل\nWORK REQUESTED\nBY", size: 4.5f),
                        HD("رقم التسجيل\nأو التسلسل\nSERIAL/REG. NO.", size: 4.5f),
                        HD("بيان موجز للعمل\nأو ملاحظات\nBRIEF DESC. OF WORK", size: 4.5f),
                        HD("تاريخ استلام\nأمر العمل\nDATE JOB ORDER\nRECEIVED", size: 4.5f),
                        HD("تاريخ الإصلاح\n- البدء\nDATE REPAIR\nSTARTED", size: 4.5f),
                        HD("تاريخ الإصلاح\n- الانتهاء\nDATE REPAIR\nFINISHED", size: 4.5f),
                        HD("ساعات\nالعمل\nMANHOURS", size: 4.5f),
                        HD("التكاليف\n- العمل\nLABOR", size: 4.5f),
                        HD("التكاليف\n- القطع\nPARTS", size: 4.5f),
                        HD("التكاليف الكلية\nللعمل\nTOTAL COST\nOF JOB", size: 4.5f)
                    }
                });

                foreach (var row in pdfRows)
                {
                    string desc = GetVal(row, "correctiveSummary");
                    if (string.IsNullOrEmpty(desc))
                        desc = GetVal(row, "faultSummary");
                    if (string.IsNullOrEmpty(desc))
                        desc = GetVal(row, "MaintOrdDesc");

                    register.Rows.Add(new LetterTableRow
                    {
                        Cells = new()
                        {
                            V(GetVal(row, "jobOrderNumber"), size: 6f),
                            V(VehicleDesc(row), align: TextAlign.Right, size: 6f),
                            V("", size: 6f),
                            V(GetVal(row, "armyNumber"), size: 6f),
                            V(desc, align: TextAlign.Right, size: 5.5f),
                            V(FmtDatePdf(row.GetValueOrDefault("MaintOrdStartDate")), size: 5.5f),
                            V(FmtDatePdf(row.GetValueOrDefault("MaintOrdStartDate")), size: 5.5f),
                            V(FmtDatePdf(row.GetValueOrDefault("MaintOrdEndDate")), size: 5.5f),
                            V("", size: 6f),
                            V("", size: 6f),
                            V("", size: 6f),
                            V(TotalCost(row), align: TextAlign.Right, size: 5.5f)
                        }
                    });
                }

                if (pdfRows.Count == 0)
                {
                    register.Rows.Add(new LetterTableRow
                    {
                        Cells = new()
                        {
                            new LetterTableCell
                            {
                                Text = "لا توجد بيانات صيانة",
                                ColumnSpan = 12,
                                Align = TextAlign.Center,
                                FontSize = 8f,
                                BackgroundColor = "#FFFFFF"
                            }
                        }
                    });
                }

                var report = new ReportResult
                {
                    ReportId = "MonthlyMaintenanceReport",
                    Title = "",
                    Kind = ReportKind.Letter,
                    Orientation = ReportOrientation.Landscape,
                    HeaderType = ReportHeaderType.Standard,
                    HeaderFields = new Dictionary<string, string>(),
                    ShowFooter = true,
                    LetterBlocks = new List<LetterBlock>
                    {
                        LetterBlockFactory.TextBlock(
                            "سجل طلبات الصيانة",
                            fontSize: 10f,
                            bold: true,
                            align: TextAlign.Right,
                            paddingTop: 2,
                            paddingBottom: 0),

                        LetterBlockFactory.TextBlock(
                            "MAINTENANCE REQUEST REGISTER — SAA TM (38-750)",
                            fontSize: 7f,
                            bold: true,
                            align: TextAlign.Left,
                            paddingTop: 0,
                            paddingBottom: 2),

                        LetterBlockFactory.TableBlock(
                            register,
                            paddingTop: 4,
                            paddingBottom: 0,
                            paddingRight: 0,
                            paddingLeft: 0),

                        LetterBlockFactory.FooterBlock(
                            right: $"سجل طلبات الصيانة — {periodLabel}",
                            center: $"عدد الأوامر: {pdfRows.Count}",
                            left: "MAINTENANCE REQUEST REGISTER",
                            fontSize: 6f,
                            paddingTop: 4)
                    }
                };

                var pdfBytes = QuestPdfReportRenderer.Render(report);
                string filename = month.HasValue && year.HasValue
                    ? $"MaintenanceReport_{year}_{month:D2}.pdf"
                    : $"MaintenanceReport_All.pdf";
                Response.Headers["Content-Disposition"] = $"inline; filename={filename}";
                return File(pdfBytes, "application/pdf");
            }

            #endregion

            return View("Page/MaintenanceReport", page);
        }

        #region Helpers

        List<TableColumn> BuildReportColumns(DataTable data, HashSet<string> fields, Dictionary<string, string> headerMap)
        {
            var cols = new List<TableColumn>();
            foreach (DataColumn c in data.Columns)
            {
                if (!fields.Contains(c.ColumnName)) continue;
                cols.Add(new TableColumn
                {
                    Field = c.ColumnName,
                    Label = headerMap.TryGetValue(c.ColumnName, out var label) ? label : c.ColumnName,
                    Type = "text",
                    Sortable = true,
                    Visible = true
                });
            }

            foreach (var fieldName in fields)
            {
                if (cols.Any(c => c.Field.Equals(fieldName, StringComparison.OrdinalIgnoreCase))) continue;
                cols.Add(new TableColumn
                {
                    Field = fieldName,
                    Label = headerMap.TryGetValue(fieldName, out var label) ? label : fieldName,
                    Type = "text",
                    Sortable = true,
                    Visible = true
                });
            }

            return cols;
        }

        #endregion
    }
}
