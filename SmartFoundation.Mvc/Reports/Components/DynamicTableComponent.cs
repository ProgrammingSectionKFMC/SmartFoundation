using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class DynamicTableComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        container.PaddingTop(16).Table(table =>
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

                    hcell.Text(c.Title).FontSize(10).SemiBold().FontColor("#FFFFFF");
                }
            });

            int rowIndex = 0;
            foreach (var row in report.Rows)
            {
                bool isEven = rowIndex % 2 == 0;
                rowIndex++;

                foreach (var c in report.Columns)
                {
                    var val = row.TryGetValue(c.Key, out var v) ? v : null;

                    var cell = table.Cell()
                                    .Element(cont => CellBody(cont, isEven))
                                    .AlignMiddle();

                    cell = c.Align.ToLowerInvariant() switch
                    {
                        "right" => cell.AlignRight(),
                        "center" => cell.AlignCenter(),
                        _ => cell.AlignLeft()
                    };

                    cell.Text(FormatCell(val, c.Format))
                        .FontSize(c.FontSize ?? report.TableFontSize ?? 9)
                        .FontColor("#333333");
                }
            }
        });
    }

    static IContainer CellHeader(IContainer c) =>
        c.Background("#5A5A5A")
         .BorderBottom(2).BorderColor("#9E9E9E")
         .Padding(5);

    static IContainer CellBody(IContainer c, bool isEven) =>
        c.Background(isEven ? "#F5F5F5" : "#FFFFFF")
         .Border(0.5f).BorderColor("#DDDDDD")
         .Padding(4);

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