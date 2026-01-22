using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports
{
    public static class LetterBlocksComponent
    {
        public static void Compose(IContainer container, ReportResult report)
        {
            var blocks = report.LetterBlocks ?? new();

            container.Column(col =>
            {
                foreach (var b in blocks)
                {
                    var item = col.Item();

                    // ✅ 1) الإزاحة (Padding)
                    item = item
                        .PaddingTop(b.PaddingTop)
                        .PaddingBottom(b.PaddingBottom)
                        .PaddingRight(b.PaddingRight)
                        .PaddingLeft(b.PaddingLeft);

                    // ✅ 2) مكان البلوك داخل الصفحة
                    item = b.Align switch
                    {
                        TextAlign.Left => item.AlignLeft(),
                        TextAlign.Center => item.AlignCenter(),
                        TextAlign.Right => item.AlignRight(),
                        _ => item
                    };

                    // ✅ 3) النص نفسه
                    item.Text(txt =>
                    {
                        txt.DefaultTextStyle(x => x.FontSize(b.FontSize));

                        if (b.Align == TextAlign.Left) txt.AlignLeft();
                        else if (b.Align == TextAlign.Center) txt.AlignCenter();
                        else txt.AlignRight();

                        var span = txt.Span(b.Text ?? "")
                                      .DirectionFromRightToLeft();

                        if (b.Bold) span.SemiBold();
                    });
                }
            });
        }

    }

}
