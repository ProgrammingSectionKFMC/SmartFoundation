using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class StandardFooterComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        container.AlignBottom().PaddingTop(8).Column(col =>
        {
            col.Item().Row(row =>
            {
                row.RelativeItem().AlignRight().Text(t =>
                {
                    var items = report.FooterFields
                        .Select(x => $"{x.Key}: {x.Value}")
                        .ToList();

                    if (items.Count == 0)
                        return;

                    t.AlignRight();
                    t.Span(string.Join("  •  ", items)).FontSize(9);
                });

                row.ConstantItem(120).AlignLeft().Text(t =>
                {
                    t.AlignLeft();
                    t.Span("صفحة ").FontSize(9);
                    t.CurrentPageNumber().FontSize(9);
                    t.Span(" من ").FontSize(9);
                    t.TotalPages().FontSize(9);
                });
            });
        });
    }
}