using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class StandardHeaderComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        container.PaddingBottom(8).Column(col =>
        {
            col.Item().Row(row =>
            {
                row.RelativeItem().Text(report.Title).FontSize(16).SemiBold();
                row.ConstantItem(220).AlignRight().Column(r =>
                {
                    foreach (var kv in report.HeaderFields)
                        r.Item().AlignRight().Text($"{kv.Key}: {kv.Value}").FontSize(10);
                });
            });

            col.Item().LineHorizontal(1);
        });
    }
}
