using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class OfficialLetterHeaderComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        string Get(string key) => report.HeaderFields.TryGetValue(key, out var v) ? v : "";

        var left_no = Get("no");
        var left_date = Get("date");
        var left_attach = Get("attach");
        var left_subject = Get("subject");

        var right_l1 = Get("right1");
        var right_l2 = Get("right2");
        var right_l3 = Get("right3");
        var right_l4 = Get("right4");
        var right_l5 = Get("right5");

        var bismillah = Get("bismillah");
        var midCaption = Get("midCaption");

        container.PaddingTop(8).PaddingBottom(0).Column(col =>
        {
            col.Item()
                .PaddingBottom(12)
                .Background("#F5F5F5")
                .Border(0.5f)
                .BorderColor("#CCCCCC")
                .Padding(10)
                .Row(row =>
                {
                    row.RelativeItem(3).Column(right =>
                    {
                        right.Spacing(4);

                        void RightLine(string s, bool bold = false)
                        {
                            if (!string.IsNullOrWhiteSpace(s))
                            {
                                var txt = right.Item()
                                    .AlignCenter()
                                    .Text(s)
                                    .FontSize(11)
                                    .FontColor("#444444");
                                if (bold) txt.SemiBold();
                            }
                        }

                        RightLine(right_l1, bold: true);
                        RightLine(right_l2);
                        RightLine(right_l3);
                        RightLine(right_l4);
                        RightLine(right_l5);
                    });

                    row.RelativeItem(6).AlignCenter().Column(mid =>
                    {
                        mid.Spacing(4);

                        if (!string.IsNullOrWhiteSpace(bismillah))
                            mid.Item().AlignCenter().Text(bismillah).FontSize(12).SemiBold().FontColor("#333333");

                        if (!string.IsNullOrWhiteSpace(report.LogoPath))
                            mid.Item().AlignCenter().Width(90).Height(90).Image(report.LogoPath);

                        if (!string.IsNullOrWhiteSpace(midCaption))
                            mid.Item().AlignCenter().Text(midCaption).FontSize(9).FontColor("#555555");
                    });

                    row.RelativeItem(3).Column(meta =>
                    {
                        meta.Spacing(6);

                        void MetaRow(string label, string value)
                        {
                            meta.Item()
                                .AlignRight()
                                .Text(t =>
                                {
                                    t.Span(label).FontSize(10).SemiBold().FontColor("#333333");
                                    t.Span(value).FontSize(10).FontColor("#555555");
                                });
                        }

                        MetaRow("الرقم: ", left_no);
                        MetaRow("التاريخ: ", left_date);
                        MetaRow("المرفقات: ", left_attach);

                        meta.Item()
                            .AlignRight()
                            .Text(t =>
                            {
                                t.Span("الموضوع: ").FontSize(11).SemiBold().FontColor("#333333");
                                t.Span(left_subject).FontSize(11).SemiBold().FontColor("#333333");
                            });
                    });
                });

            //col.Item().LineHorizontal(1.5f).LineColor("#9E9E9E");
        });
    }
}