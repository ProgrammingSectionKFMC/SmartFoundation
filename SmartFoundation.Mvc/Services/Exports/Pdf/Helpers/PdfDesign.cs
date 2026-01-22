using QuestPDF.Fluent;
using QuestPDF.Infrastructure;
using QuestPDF.Helpers;
using System;
using System.IO;
using System.Linq;

namespace SmartFoundation.Mvc.Services.Exports.Pdf.Helpers
{
    public static class PdfDesign
    {
        // ===== Typography (الخطوط) =====
        public const string Font = "Arial";
        public const float TitleSize = 16;
        public const float SubtitleSize = 10;
        public const float BodySize = 10;
        public const float SmallSize = 9;

        // ===== Colors (الألوان الرسمية) =====
        public static readonly string PageBg = Colors.White;
        public static readonly string Border = Colors.Grey.Lighten2;
        public static readonly string BorderDark = "#2c3e50";

        public static readonly string HeaderBand = Colors.White;
        public static readonly string HeaderText = "#2c3e50";

        public static readonly string TableHeadBg = "#34495e";
        public static readonly string TableHeadFg = Colors.White;

        public static readonly string ZebraAlt = "#fcfcfc";

        public static TextStyle BaseText() =>
            TextStyle.Default.FontFamily(Font).FontSize(BodySize).FontColor(Colors.Black);

        public static TextStyle SmallText() =>
            TextStyle.Default.FontFamily(Font).FontSize(SmallSize).FontColor(Colors.Grey.Darken2);

        public static TextStyle TitleText() =>
            TextStyle.Default.FontFamily(Font).FontSize(TitleSize).FontColor(HeaderText).Bold();

        // ===== Header (الترويسة الرسمية) =====
        public static void BuildHeader(IContainer container, PdfTableRequest request)
        {
            container.PaddingBottom(10).Column(col =>
            {
                col.Item().Row(row =>
                {
                    // 1. اليسار: التاريخ والموضوع (مكانه يسار، النص محاذاته يمين)
                    row.RelativeItem().AlignLeft().Column(leftCol =>
                    {
                        if (request.ShowGeneratedAt)
                        {
                            leftCol.Item().AlignRight().Text($"التاريخ: {DateTime.Now:yyyy-MM-dd}").Style(SmallText());
                        }

                        leftCol.Item().AlignRight().Text($"الموضوع: {request.Title}").Style(SmallText());
                    });

                    // 2. المنتصف: الشعار
                    row.ConstantItem(150).AlignCenter().AlignMiddle().Column(centerCol =>
                    {
                        if (!string.IsNullOrEmpty(request.LogoUrl))
                        {
                            var logoPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", request.LogoUrl.TrimStart('/'));

                            if (File.Exists(logoPath))
                            {
                                centerCol.Item().Height(60).AlignCenter().Image(logoPath).FitHeight();
                            }
                        }
                    });

                    // 3. اليمين: البيانات الرسمية (مكانه يمين، النص محاذاته متوسطة)
                    row.RelativeItem().AlignRight().Column(rightCol =>
                    {
                        var headerLines = new[] {
                            request.RightHeaderLine1,
                            request.RightHeaderLine2,
                            request.RightHeaderLine3,
                            request.RightHeaderLine4,
                            request.RightHeaderLine5
                        };

                        foreach (var line in headerLines)
                        {
                            if (!string.IsNullOrEmpty(line))
                            {
                                // تم التعديل هنا إلى AlignCenter بناءً على طلبك
                                rightCol.Item().AlignCenter().Text(line).Style(BaseText().Bold().FontSize(9));
                            }
                        }
                    });
                });

                col.Item().PaddingTop(5).LineHorizontal(0.8f).LineColor(Colors.Black);
            });
        }

        // ===== Table Styling (تنسيق الجدول) =====
        public static void HeaderCell(IContainer cell, string text)
        {
            cell
                .Background(TableHeadBg)
                .Border(0.5f).BorderColor(Colors.BlueGrey.Darken3)
                .PaddingVertical(8)
                .AlignCenter()
                .AlignMiddle()
                .Text(text ?? "")
                    .Style(BaseText())
                    .FontColor(TableHeadFg)
                    .Bold();
        }

        public static void BodyCell(IContainer cell, string text, string bgColor)
        {
            cell
                .Background(bgColor)
                .Border(0.5f).BorderColor(Border)
                .PaddingVertical(6)
                .PaddingHorizontal(5)
                .AlignCenter()
                .AlignMiddle()
                .Text(text ?? "")
                    .Style(BaseText())
                    .FontSize(SmallSize);
        }

        public static void InFrame(IContainer container, Action<IContainer> content)
        {
            var framed = container.PaddingVertical(10).PaddingHorizontal(5);
            content(framed);
        }

        public static void BuildTable(IContainer container, PdfTableRequest request)
        {
            container.Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    foreach (var _ in request.Columns)
                        columns.RelativeColumn();

                    if (request.ShowSerial)
                        columns.ConstantColumn(35);
                });

                foreach (var c in request.Columns)
                    table.Cell().Element(cell => HeaderCell(cell, c.Label));

                if (request.ShowSerial)
                    table.Cell().Element(cell => HeaderCell(cell, request.SerialLabel));

                var rowIndex = 0;
                foreach (var dataRow in request.Rows)
                {
                    string bg = (rowIndex % 2 == 0) ? Colors.White : ZebraAlt;

                    foreach (var c in request.Columns)
                    {
                        var value = dataRow.ContainsKey(c.Field) ? dataRow[c.Field]?.ToString() ?? "" : "";
                        table.Cell().Element(cell => BodyCell(cell, value, bg));
                    }

                    if (request.ShowSerial)
                        table.Cell().Element(cell => BodyCell(cell, (rowIndex + 1).ToString(), bg));

                    rowIndex++;
                }
            });
        }

        public static void BuildFooter(IContainer container)
        {
            container
                .PaddingTop(10)
                .Row(row =>
                {
                    row.RelativeItem().AlignRight()
                        .Text(t =>
                        {
                            t.Span("صفحة ").Style(SmallText());
                            t.CurrentPageNumber();
                            t.Span(" من ").Style(SmallText());
                            t.TotalPages();
                        });
                });
        }
    }
}