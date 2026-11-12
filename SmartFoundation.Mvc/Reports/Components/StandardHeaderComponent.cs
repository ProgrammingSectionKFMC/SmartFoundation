using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class StandardHeaderComponent
{
        public static void Compose(IContainer container, ReportResult report)
        {
            if (string.IsNullOrWhiteSpace(report.Title) && (report.HeaderFields == null || report.HeaderFields.Count == 0))
                return;

            container.PaddingBottom(8).Column(col =>
            {
                col.Item().Row(row =>
                {
                    row.RelativeItem().Text(report.Title).FontSize(16).SemiBold();
                    row.ConstantItem(220).AlignRight().Column(r =>
                    {
                        if (report.HeaderFields != null)
                        {
                            foreach (var kv in report.HeaderFields)
                                r.Item().AlignRight().Text($"{kv.Key}: {kv.Value}").FontSize(10);
                        }
                    });
                });

                col.Item().LineHorizontal(1);
            });
        }
}
