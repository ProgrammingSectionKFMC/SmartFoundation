using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class QuestPdfReportRenderer
{
    public static byte[] Render(ReportResult report)
    {
        var (orientation, fontSize) = DecideLayout(report);

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(orientation == ReportOrientation.Landscape
                    ? PageSizes.A4.Landscape()
                    : PageSizes.A4);

                page.Margin(20);

                // Arabic defaults
                page.DefaultTextStyle(x => x.FontFamily("Tajawal").FontSize(fontSize));
                page.ContentFromRightToLeft();

                if (report.HeaderRepeat == ReportHeaderRepeat.FirstPageOnly)
                {
                    page.Header().ShowOnce().Element(c => HeaderFactory.Compose(c, report));
                }
                else
                {
                    page.Header().Element(c => HeaderFactory.Compose(c, report));
                }
                page.Content().Element(c =>
                {
                    // ✅ Letter
                    if (report.Kind == ReportKind.Letter)
                    {
                        LetterBlocksComponent.Compose(c, report);   // (اسم الكومبوننت حسب اللي عندك)
                        return;
                    }

                    // ✅ Table (default)
                    if (report.Columns != null && report.Columns.Count > 0)
                    {
                        DynamicTableComponent.Compose(c, report);
                        return;
                    }

                    // ✅ fallback
                    c.Text("لا يوجد محتوى للطباعة").FontSize(12);
                });
                if (report.FooterFields != null && report.FooterFields.Count > 0)
                    page.Footer().Element(c => StandardFooterComponent.Compose(c, report));



            });
        }).GeneratePdf();
    }

    private static (ReportOrientation orientation, float fontSize) DecideLayout(ReportResult report)
    {
        if (report.Orientation != ReportOrientation.Auto)
            return (report.Orientation, 10);

        var colCount = report.Columns.Count;
        var weightSum = report.Columns.Sum(c => c.Weight);

        // قواعد عملية
        if (colCount > 12 || weightSum > 22)
            return (ReportOrientation.Landscape, 9);

        if (colCount > 8 || weightSum > 16)
            return (ReportOrientation.Landscape, 10);

        return (ReportOrientation.Portrait, 11);
    }
}
