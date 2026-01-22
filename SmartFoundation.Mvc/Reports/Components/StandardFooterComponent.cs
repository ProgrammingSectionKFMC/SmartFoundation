using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class StandardFooterComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        container.PaddingTop(6).Column(col =>
        {
            col.Item().LineHorizontal(1);

            col.Item().Row(row =>
            {
                // يسار: معلومات فوتر إضافية (اختياري)
                row.RelativeItem().Text(t =>
                {
                    var items = report.FooterFields
                        .Select(x => $"{x.Key}: {x.Value}")
                        .ToList();

                    if (items.Count == 0)
                        return;

                    t.Span(string.Join("  •  ", items)).FontSize(9);
                });

                // يمين: ترقيم الصفحات
                row.ConstantItem(180).AlignRight().Text(t =>
                {
                    t.Span("صفحة ").FontSize(9);
                    t.CurrentPageNumber();
                    t.Span(" من ").FontSize(9);
                    t.TotalPages();
                });
            });
        });
    }
}
