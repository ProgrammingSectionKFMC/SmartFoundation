namespace SmartFoundation.Mvc.Services.Exports.Pdf
{
    public interface IPdfExportService
    {
        byte[] BuildTestPdf(string title);
        
        /// <summary>
        /// Builds a dynamic PDF table report from columns and rows data
        /// </summary>
        byte[] BuildTablePdf(PdfTableRequest request);
    }

    public class PdfTableRequest
    {
        public string Title { get; set; } = "تقرير";
        public string? LogoUrl { get; set; }
        public string Paper { get; set; } = "A4";
        public string Orientation { get; set; } = "portrait";
        public bool ShowPageNumbers { get; set; } = true;
        public bool ShowGeneratedAt { get; set; } = true;
        public bool ShowSerial { get; set; } = false;
        public string SerialLabel { get; set; } = "#";

        
        public string? RightHeaderLine1 { get; set; }
        public string? RightHeaderLine2 { get; set; }
        public string? RightHeaderLine3 { get; set; }
        public string? RightHeaderLine4 { get; set; }
        public string? RightHeaderLine5 { get; set; }

        public List<PdfTableColumn> Columns { get; set; } = new();
        public List<Dictionary<string, object?>> Rows { get; set; } = new();
        public string? HeaderTitle { get; set; }
        public string? HeaderSubtitle { get; set; }
        public string? GeneratedBy { get; set; }
        public DateTime GeneratedAt { get; set; } = DateTime.Now;
    }


    public class PdfTableColumn
    {
        public string Field { get; set; } = "";
        public string Label { get; set; } = "";
        public string? Width { get; set; }
        public string Align { get; set; } = "right";
    }
}
