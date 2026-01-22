using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.Exports.Pdf;

namespace SmartFoundation.Mvc.Controllers
{
    [ApiController]
    public class ExportsController : ControllerBase
    {
        private readonly IPdfExportService _pdf;

        public ExportsController(IPdfExportService pdf)
        {
            _pdf = pdf;
        }

        [HttpPost("/exports/pdf/table")]
        public IActionResult ExportPdf([FromBody] PdfReq req)
        {
            try
            {
                // Map request to service model
                var pdfRequest = new PdfTableRequest
                {
                    Title = req.Title ?? "تقرير PDF",
                    LogoUrl = req.LogoUrl, //   المسؤول عن تمرير رابط الشعار
                    Paper = req.Paper ?? "A4",
                    Orientation = req.Orientation ?? "portrait",
                    ShowPageNumbers = req.ShowPageNumbers,
                    ShowGeneratedAt = req.ShowGeneratedAt,
                    ShowSerial = req.ShowSerial,
                    SerialLabel = req.SerialLabel ?? "#",

                    
                    RightHeaderLine1 = req.RightHeaderLine1,
                    RightHeaderLine2 = req.RightHeaderLine2,
                    RightHeaderLine3 = req.RightHeaderLine3,
                    RightHeaderLine4 = req.RightHeaderLine4,
                    RightHeaderLine5 = req.RightHeaderLine5,

                    Columns = req.Columns.Select(c => new PdfTableColumn
                    {
                        Field = c.Field,
                        Label = c.Label,
                        Align = "right"
                    }).ToList(),
                    Rows = req.Rows
                };

                var bytes = _pdf.BuildTablePdf(pdfRequest);
                var filename = (req.Filename ?? "export") + ".pdf";
                
                return File(bytes, "application/pdf", filename);
            }
            catch (Exception ex)
            {
                return BadRequest(new { error = ex.Message });
            }
        }
    }

    public class PdfReq
    {
        public string? Title { get; set; }
        public string? Subtitle { get; set; }
        public string? Filename { get; set; }
        public string? LogoUrl { get; set; }
        public string? Paper { get; set; }
        public string? Orientation { get; set; }
        public bool ShowPageNumbers { get; set; } = true;
        public string? GeneratedBy { get; set; }
        public bool ShowGeneratedAt { get; set; } = false; // NEW
        public bool ShowSerial { get; set; } = false;
        public string? SerialLabel { get; set; } = "#";
        
        public string? RightHeaderLine1 { get; set; } // المملكة العربية السعودية
        public string? RightHeaderLine2 { get; set; } 
        public string? RightHeaderLine3 { get; set; } 
        public string? RightHeaderLine4 { get; set; } 
        public string? RightHeaderLine5 { get; set; } 

        public List<PdfCol> Columns { get; set; } = new();
        public List<Dictionary<string, object?>> Rows { get; set; } = new();
    }

    public class PdfCol
    {
        public string Field { get; set; } = "";
        public string Label { get; set; } = "";


    }
}
