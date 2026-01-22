using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class OfficialLetterHeaderComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        string Get(string key) => report.HeaderFields.TryGetValue(key, out var v) ? v : "";

        // Block A (رقم/تاريخ/مرفقات/موضوع)
        var left_no = Get("no");
        var left_date = Get("date");
        var left_attach = Get("attach");
        var left_subject = Get("subject");

        // Block B (الجهة/الوزارة/القوات...)
        var right_l1 = Get("right1");
        var right_l2 = Get("right2");
        var right_l3 = Get("right3");
        var right_l4 = Get("right4");
        var right_l5 = Get("right5");

        var bismillah = Get("bismillah");
        var midCaption = Get("midCaption");

        container.PaddingBottom(6).Column(col =>
        {
            col.Item().Row(row =>
            {
                // ✅ 1) يمين الصفحة (الجهة) - مرن + سنتر
                // ملاحظة: مع RTL قد يبدو هذا أول عنصر في أقصى اليمين (وهذا المطلوب عندك سابقاً)
                row.RelativeItem(3).AlignRight().Column(right =>
                {
                    right.Spacing(2);

                    void CenterLine(string s)
                    {
                        if (!string.IsNullOrWhiteSpace(s))
                            right.Item().AlignCenter().Text(s).FontSize(11);
                    }

                    CenterLine(right_l1);
                    CenterLine(right_l2);
                    CenterLine(right_l3);
                    CenterLine(right_l4);
                    CenterLine(right_l5);
                });

                // ✅ 2) الوسط (الشعار) - ثابت صغير وآمن
                row.ConstantItem(160).AlignCenter().Column(mid =>
                {
                    mid.Spacing(2);

                    if (!string.IsNullOrWhiteSpace(bismillah))
                        mid.Item().AlignCenter().Text(bismillah).FontSize(11);

                    if (!string.IsNullOrWhiteSpace(report.LogoPath))
                        mid.Item().AlignCenter().Width(90).Height(90).Image(report.LogoPath);

                    if (!string.IsNullOrWhiteSpace(midCaption))
                        mid.Item().AlignCenter().Text(midCaption).FontSize(9);
                });

                // ✅ 3) يسار الصفحة (الرقم/التاريخ/الموضوع) - مرن
                row.RelativeItem(3).AlignCenter().Column(meta =>
                {
                    meta.Spacing(2);

                    meta.Item().PaddingTop(6).AlignRight().Text(t =>
                    {
                        t.Span("الرقم: ").FontSize(10).SemiBold();
                        t.Span(left_no).FontSize(10);
                    });

                    meta.Item().PaddingTop(6).AlignRight().Text(t =>
                    {
                        t.Span("التاريخ: ").FontSize(10).SemiBold();
                        t.Span(left_date).FontSize(10);
                    });

                    meta.Item().PaddingTop(6).AlignRight().Text(t =>
                    {
                        t.Span("المرفقات: ").FontSize(10).SemiBold();
                        t.Span(left_attach).FontSize(10);
                    });

                    meta.Item().PaddingTop(6).AlignRight().Text(t =>
                    {
                        t.Span("الموضوع: ").FontSize(10).SemiBold();
                        t.Span(left_subject).FontSize(10);
                    });
                });
            });

            col.Item().PaddingTop(6).LineHorizontal(1);
        });
    }
}
