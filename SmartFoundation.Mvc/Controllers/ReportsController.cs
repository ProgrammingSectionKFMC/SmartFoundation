using Microsoft.AspNetCore.Mvc;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using SmartFoundation.MVC.Reports;
using System.Data;

namespace SmartFoundation.MVC.Controllers;

[Route("reports")]
public class ReportsController : Controller
{
    [HttpGet("test")]
    public IActionResult Test()
    {
        var pdf = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(20);

                page.DefaultTextStyle(x => x.FontFamily("Tajawal"));
                page.ContentFromRightToLeft();

                page.Header().Text(t =>
                {
                    t.Span("تقرير تجريبي").FontSize(16).SemiBold();
                });

                page.Content().Text(t =>
                {
                    t.Span("السلام عليكم — هذا اختبار لطباعة اللغة العربية بخط Tajawal داخل QuestPDF.")
                        .FontSize(12);
                });

                page.Footer().AlignCenter().Text(t =>
                {
                    t.Span("صفحة ");
                    t.CurrentPageNumber();
                    t.Span(" من ");
                    t.TotalPages();
                });
            });
        }).GeneratePdf();

        Response.Headers["Content-Disposition"] = "inline; filename=test.pdf";
        return File(pdf, "application/pdf");
    }

    [HttpGet("dynamic")]
    public IActionResult Dynamic()
    {
        // مثال DataTable للتجربة
        var dt = new DataTable();
        dt.Columns.Add("الرقم", typeof(int));
        dt.Columns.Add("الاسم", typeof(string));
        dt.Columns.Add("التاريخ", typeof(DateTime));
        dt.Columns.Add("ملاحظات", typeof(string));

        for (int i = 1; i <= 80; i++)
            dt.Rows.Add(i, $"مستفيد {i}", DateTime.Now.AddDays(-i),
                "ملاحظة طويلة لاختبار الجدول الديناميكي واتجاه الصفحة حسب عدد الأعمدة");

        var header = new Dictionary<string, string>
        {
            ["الجهة"] = "منظمة خيرية",
            ["التاريخ"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            ["المستخدم"] = User.Identity?.Name ?? ""
        };

        var report = DataTableReportBuilder.FromDataTable(
            reportId: "dynamic-demo",
            title: "تقرير ديناميكي تجريبي",
            table: dt,
            headerFields: header,
            footerFields: new Dictionary<string, string> { ["ملاحظة"] = "فوتر ثابت" }
        );

        var pdf = QuestPdfReportRenderer.Render(report);

        Response.Headers["Content-Disposition"] = "inline; filename=dynamic.pdf";
        return File(pdf, "application/pdf");
    }
}
