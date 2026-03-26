using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class OfficialLetterHeaderComponent
{
    public static void Compose(IContainer container, ReportResult report)
    {
        string Get(string key) => report.HeaderFields.TryGetValue(key, out var v) ? v : "";

        var leftNo = Get("no");
        var leftDate = Get("date");
        var leftAttach = Get("attach");
        var leftSubject = Get("subject");

        var right1 = Get("right1");
        var right2 = Get("right2");
        var right3 = Get("right3");
        var right4 = Get("right4");
        var right5 = Get("right5");

        var bismillah = Get("bismillah");
        var midCaption = Get("midCaption");

        container
            .PaddingTop(8)
            .PaddingBottom(2)
            .Column(col =>
            {
                col.Item()
                    .PaddingHorizontal(24)
                    .MinHeight(120)
                    .Layers(layers =>
                    {
                        // الطبقة الأساسية: اليمين واليسار
                        layers.PrimaryLayer().Row(row =>
                        {
                            // الجهة الرسمية
                            row.RelativeItem(1)
                                .PaddingTop(16)   // ✅ إنزال العمود الأيمن
                                .Column(right =>
                                {
                                    right.Spacing(1);

                                    void RightRow(string text, bool bold = false, float size = 10.5f)
                                    {
                                        if (string.IsNullOrWhiteSpace(text))
                                            return;

                                        var item = right.Item()
                                            .AlignCenter()
                                            .Text(text)
                                            .FontSize(size)
                                            .FontColor("#222222");

                                        if (bold)
                                            item.SemiBold();
                                    }

                                    RightRow(right1);
                                    RightRow(right2);
                                    RightRow(right3);
                                    RightRow(right4);
                                    RightRow(right5, true);
                                });

                            // فراغ للوسط
                            row.ConstantItem(170);

                            // بيانات الخطاب
                            row.RelativeItem(1)
                                .PaddingTop(16)   // ✅ إنزال العمود الأيسر
                                .Column(left =>
                                {
                                    left.Spacing(1);

                                    void LeftRow(string label, string value, bool bold = false)
                                    {
                                        if (string.IsNullOrWhiteSpace(value))
                                            return;

                                        left.Item()
                                            .AlignRight()
                                            .Text(t =>
                                            {
                                                t.DefaultTextStyle(x => x.FontSize(10).FontColor("#222222"));
                                                t.Span(label).SemiBold();

                                                var valueSpan = t.Span(value);
                                                if (bold)
                                                    valueSpan.SemiBold();
                                            });
                                    }

                                    LeftRow("الرقم: ", leftNo);
                                    LeftRow("التاريخ: ", leftDate);
                                    LeftRow("المرفقات: ", leftAttach);
                                    LeftRow("الموضوع: ", leftSubject, true);
                                });
                        });

                        // طبقة الشعار والبسملة
                        layers.Layer()
                            .AlignCenter()
                            .AlignTop()
                            .Column(mid =>
                            {
                                mid.Spacing(2);

                                if (!string.IsNullOrWhiteSpace(bismillah))
                                {
                                    mid.Item()
                                        .AlignCenter()
                                        .Text(bismillah)
                                        .FontSize(11)
                                        .SemiBold()
                                        .FontColor("#222222");
                                }

                                if (!string.IsNullOrWhiteSpace(report.LogoPath))
                                {
                                    mid.Item()
                                        .PaddingTop(4)
                                        .AlignCenter()
                                        .MaxWidth(80)
                                        .MaxHeight(80)
                                        .Image(report.LogoPath);
                                }

                                if (!string.IsNullOrWhiteSpace(midCaption))
                                {
                                    mid.Item()
                                        .AlignCenter()
                                        .Text(midCaption)
                                        .FontSize(8.5f)
                                        .FontColor("#555555");
                                }
                            });
                    });

                col.Item()
                    .PaddingTop(6)
                    .PaddingHorizontal(18)
                    .LineHorizontal(1f)
                    .LineColor("#1F1F1F");
            });
    }
}