// SmartResponse.cs
using System.Collections.Generic;

namespace SmartFoundation.DataEngine.Core.Models
{
    public sealed class SmartResponse
    {
        public bool Success { get; set; }
        public int Page { get; set; }
        public int Size { get; set; }
        public int Total { get; set; }

        // جدول واحد فقط
        public List<Dictionary<string, object?>> Data { get; set; } = [];

        //يرجع كل الجداول بالترتيب حسب البروسيجر 
        public List<List<Dictionary<string, object?>>> Datasets { get; set; } = [];

        /// <summary>
        /// Column names in reader order for each corresponding entry in Datasets,
        /// including result sets that contain no rows.
        /// </summary>
        public List<List<string>> DatasetSchemas { get; set; } = [];

        public Dictionary<string, object?> Meta { get; set; } = [];
        public string? Error { get; set; }
        public string? Message { get; set; }
        public long DurationMs { get; set; }
    }
}
