using System.Data;

namespace SmartFoundation.MVC.Reports;

public static class DataTableReportBuilder
{
    public static ReportResult FromDataTable(
     string reportId,
     string title,
     DataTable table,
     IEnumerable<ReportColumn>? columns = null,
     Dictionary<string, string>? headerFields = null,
     Dictionary<string, string>? footerFields = null,
     ReportOrientation orientation = ReportOrientation.Auto,
     ReportHeaderType headerType = ReportHeaderType.Standard,
     string? logoPath = null,
     ReportHeaderRepeat headerRepeat = ReportHeaderRepeat.AllPages)

    {
        var cols = columns?.ToList() ?? InferColumns(table);

        var rows = new List<Dictionary<string, object?>>(table.Rows.Count);
        foreach (DataRow dr in table.Rows)
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (var col in cols)
                row[col.Key] = table.Columns.Contains(col.Key) ? dr[col.Key] : null;

            rows.Add(row);
        }

        return new ReportResult
        {
            ReportId = reportId,
            Title = title,
            Orientation = orientation,

            HeaderType = headerType,
            HeaderRepeat = headerRepeat,
            LogoPath = logoPath,

            HeaderFields = headerFields ?? new(),
            FooterFields = footerFields ?? new(),
            Columns = cols,
            Rows = rows
        };

    }

    private static List<ReportColumn> InferColumns(DataTable table)
    {
        var list = new List<ReportColumn>();
        foreach (DataColumn c in table.Columns)
        {
            var (align, weight, format, wrap) = Guess(c);
            list.Add(new ReportColumn(
                Key: c.ColumnName,
                Title: c.ColumnName,
                Format: format,
                Align: align,
                Weight: weight
                //Wrap: wrap
            ));
        }
        return list;
    }

    private static (string align, int weight, string? format, bool wrap) Guess(DataColumn c)
    {
        var t = Nullable.GetUnderlyingType(c.DataType) ?? c.DataType;

        if (t == typeof(DateTime)) return ("center", 2, "datetime", false);

        if (t == typeof(int) || t == typeof(long) || t == typeof(short) ||
            t == typeof(decimal) || t == typeof(double) || t == typeof(float))
            return ("right", 1, "number", false);

        var name = c.ColumnName.ToLowerInvariant();
        if (name.Contains("note") || name.Contains("desc") || name.Contains("address") || name.Contains("ملاحظ"))
            return ("left", 3, null, true);

        return ("left", 2, null, false);
    }
}
