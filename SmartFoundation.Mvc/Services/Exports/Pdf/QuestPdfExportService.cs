using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using SmartFoundation.Mvc.Services.Exports.Pdf.Helpers;

namespace SmartFoundation.Mvc.Services.Exports.Pdf
{
    public class QuestPdfExportService : IPdfExportService
    {
        public byte[] BuildTestPdf(string title)
        {
            var now = DateTime.Now.ToString("yyyy-MM-dd HH:mm");

            var doc = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(20);
                    page.PageColor(PdfDesign.PageBg);

                    page.DefaultTextStyle(_ => PdfDesign.BaseText());

                    page.Content().Element(root =>
                    {
                        PdfDesign.InFrame(root, frame =>
                        {
                            frame.Column(col =>
                            {
                                col.Spacing(10);

                                col.Item()
                                    .Background(PdfDesign.HeaderBand)
                                    .Border(1).BorderColor(PdfDesign.Border)
                                    .Padding(12)
                                    .AlignCenter()
                                    .Text(title ?? "")
                                    .Style(PdfDesign.TitleText());

                                col.Item()
                                    .Text($"Generated at: {now}")
                                    .Style(PdfDesign.SmallText());

                                col.Item()
                                    .LineHorizontal(1)
                                    .LineColor(PdfDesign.Border);

                                col.Item()
                                    .Text("PDF تجريبي للتأكد أن QuestPDF يعمل داخل مشروع SmartFoundation.")
                                    .Style(PdfDesign.BaseText());
                            });
                        });
                    });

                    page.Footer().Element(PdfDesign.BuildFooter);
                });
            });

            return doc.GeneratePdf();
        }

        public byte[] BuildTablePdf(PdfTableRequest request)
        {
            var doc = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(request.Orientation?.ToLower() == "landscape"
                        ? PageSizes.A4.Landscape()
                        : PageSizes.A4);

                    page.Margin(20);
                    page.PageColor(PdfDesign.PageBg);

                    page.DefaultTextStyle(_ => PdfDesign.BaseText());

                    page.Content().Element(root =>
                    {
                        PdfDesign.InFrame(root, frame =>
                        {
                            frame.Column(col =>
                            {
                                col.Spacing(12);

                                // Header
                                col.Item().Element(x => PdfDesign.BuildHeader(x, request));

                                // Table
                                col.Item()
                                    .PaddingTop(6)
                                    .Element(x => PdfDesign.BuildTable(x, request));
                            });
                        });
                    });

                    if (request.ShowPageNumbers)
                        page.Footer().Element(PdfDesign.BuildFooter);
                });
            });

            return doc.GeneratePdf();
        }
    }
}
