using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class DynamicTableComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        container.Table(table =>
        {
            table.ColumnsDefinition(cols =>
            {
                foreach (var c in report.Columns)
                {
                    if (c.Width.HasValue && c.Width.Value > 0)
                        cols.ConstantColumn(c.Width.Value);
                    else
                        cols.RelativeColumn(c.Weight <= 0 ? 1 : c.Weight);
                }
            });


            // Header row
            table.Header(header =>
            {
                foreach (var c in report.Columns)
                {
                    var hcell = header.Cell().Element(CellHeader).AlignMiddle();

                    hcell = c.Align.ToLowerInvariant() switch
                    {
                        "right" => hcell.AlignRight(),
                        "center" => hcell.AlignCenter(),
                        _ => hcell.AlignLeft()
                    };

                    hcell.Text(c.Title).FontSize(10).SemiBold();
                }
            });




            // Data rows
            foreach (var row in report.Rows)
            {
                foreach (var c in report.Columns)
                {
                    var val = row.TryGetValue(c.Key, out var v) ? v : null;

                    var cell = table.Cell().Element(CellBody).AlignMiddle();

                    // محاذاة أفقية حسب العمود
                    cell = c.Align.ToLowerInvariant() switch
                    {
                        "right" => cell.AlignRight(),
                        "center" => cell.AlignCenter(),
                        _ => cell.AlignLeft()
                    };

                    // بدون Wrap() لأن نسختك لا تدعمها
                    cell.Text(FormatCell(val, c.Format))
                        .FontSize(c.FontSize ?? report.TableFontSize ?? 9);

                }
            }


        });
    }

    static IContainer CellHeader(IContainer c) =>
        c.Border(1).Padding(4);

    static IContainer CellBody(IContainer c) =>
        c.Border(1).Padding(3);

    static HorizontalAlignment GetAlign(string align) =>
        align.ToLowerInvariant() switch
        {
            "right" => HorizontalAlignment.Right,
            "center" => HorizontalAlignment.Center,
            _ => HorizontalAlignment.Left
        };

    static string FormatCell(object? val, string? format)
    {
        if (val == null || val == DBNull.Value) return "";

        if (val is DateTime dt)
        {
            return format == "date"
                ? dt.ToString("yyyy-MM-dd")
                : dt.ToString("yyyy-MM-dd HH:mm:ss");
        }

        if (format == "number" && decimal.TryParse(val.ToString(), out var d))
            return d.ToString("0.##");

        return val.ToString() ?? "";
    }
}
