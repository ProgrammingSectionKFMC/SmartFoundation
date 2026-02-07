using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using SmartFoundation.UI.ViewModels.SmartTable;
using System.Text.Json;

namespace SmartFoundation.Mvc.Controllers.Housing
{

    public class UploadLabController : Controller
    {
        // ===============================
        // Services & Environment
        // ===============================
        private readonly IWebHostEnvironment _env;
        private readonly IAntiforgery _antiforgery;

        // ===============================
        // Constructor / DI
        // ===============================
        public UploadLabController(IWebHostEnvironment env, IAntiforgery antiforgery)
        {
            _env = env;
            _antiforgery = antiforgery;
        }

        // ===============================
        // Session key for uploaded rows
        // ===============================
        private const string SessionKey = "UploadLab.Rows";

        // ===============================
        // Read uploaded rows from session
        // ===============================
        private List<UploadLabRow> GetRows()
        {
            var json = HttpContext.Session.GetString(SessionKey);
            if (string.IsNullOrWhiteSpace(json)) return new List<UploadLabRow>();
            return JsonSerializer.Deserialize<List<UploadLabRow>>(json) ?? new List<UploadLabRow>();
        }

        // ===============================
        // Save uploaded rows to session
        // ===============================
        private void SaveRows(List<UploadLabRow> rows)
        {
            HttpContext.Session.SetString(SessionKey, JsonSerializer.Serialize(rows));
        }

        // ===============================
        // Standard JSON helpers (success / fail)
        // ===============================
        private IActionResult Fail(string msg) => BadRequest(new { ok = false, message = msg });
        private IActionResult OkMsg(string msg, object? data = null) => Ok(new { ok = true, message = msg, data });

        // ===============================
        // GET: Table + Upload modal
        // ===============================
        [HttpGet]
        public IActionResult Index()
        {
            // --- load rows ---
            var rows = GetRows();

            // --- table columns ---
            var columns = new List<TableColumn>
            {
                new TableColumn { Field = "Id", Label = "م", Type = "number", Sortable = true, Visible = true },
                new TableColumn { Field = "OriginalName", Label = "اسم الملف", Type = "text", Sortable = true, Visible = true, truncate = true },
                new TableColumn { Field = "RelativePath", Label = "المسار", Type = "text", Sortable = false, Visible = true, truncate = true },
                new TableColumn { Field = "UploadedAt", Label = "تاريخ الرفع", Type = "text", Sortable = true, Visible = true }
            };

            // --- map rows for SmartTable ---
            var rowsList = rows
                .OrderByDescending(x => x.Id)
                .Select(x => new Dictionary<string, object?>
                {
                    ["Id"] = x.Id,
                    ["OriginalName"] = x.OriginalName,
                    ["RelativePath"] = x.RelativePath,
                    ["UploadedAt"] = x.UploadedAt.ToString("yyyy/MM/dd HH:mm:ss")
                })
                .ToList();

            // --- antiforgery token ---
            var tokens = _antiforgery.GetAndStoreTokens(HttpContext);

            // ===============================
            // Upload form fields (modal)
            // ===============================
            var addFields = new List<FieldConfig>
            {
                // --- CSRF token ---
                new FieldConfig
                {
                    Name = "__RequestVerificationToken",
                    Type = "hidden",
                    Value = tokens.RequestToken ?? ""
                },

                // --- file upload field ---
                new FieldConfig
                {
                    Name = "attachments",
                    Label = "ارفع ملف",
                    Type = "fileupload",
                    ColCss = "6",

                    // allowed extensions
                    Accept = ".pdf,.xls,.xlsx",

                    // allowed mime types
                    AllowedMimeTypes = new List<string>
                    {
                        "application/pdf",
                        "application/vnd.ms-excel",
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    },

                    // validation messages
                    ErrorMessageType = "يجب رفع ملف PDF أو Excel فقط.",
                    ErrorMessageSize = "حجم الملف أكبر من 10MB.",
                    ErrorMessageCount = "يسمح برفع ملف واحد فقط.",
                    ErrorMessageTotal = "إجمالي الحجم أكبر من 10MB.",

                    // limits
                    Multiple = false,
                    MaxFiles = 1,
                    MaxFileSize = 10,
                    MaxTotalSize = 10,
                    AllowEmptyFile = false,
                    Required = true,

                    // preview
                    EnablePreview = true,
                    PreviewableTypes = ".pdf",

                    // storage
                    SaveMode = "physical",
                    UploadFolder = "uploads",
                    UploadSubFolder = "lab",

                    // naming & security
                    FileNameMode = "uuid",
                    KeepOriginalExtension = true,
                    SanitizeFileName = true,
                    BlockDoubleExtension = true,

                    // manual submit
                    AutoUpload = false
                }
            };

            // ===============================
            // SmartTable datasource config
            // ===============================
            var dsModel = new SmartTableDsModel
            {
                PageTitle = "رفع الملفات",
                PanelTitle = "رفع الملفات",
                Columns = columns,
                Rows = rowsList,
                RowIdField = "Id",
                PageSize = 10,
                PageSizes = new List<int> { 10, 25, 50 },
                Searchable = true,
                ShowFilter = false,
                FilterRow = true,
                ShowColumnVisibility = true,

                // --- toolbar actions ---
                Toolbar = new TableToolbarConfig
                {
                    ShowAdd = true,
                    ShowEdit = false,
                    ShowDelete = false,
                    ShowExportExcel = false,
                    ShowExportPdf = false,
                    ShowColumns = true,
                    ShowRefresh = false,

                    // add/upload action
                    Add = new TableAction
                    {
                        Label = "رفع ملف",
                        Icon = "fa-solid fa-upload",
                        Color = "success",
                        OpenModal = true,
                        ModalTitle = "رفع ملف",
                        OpenForm = new FormConfig
                        {
                            FormId = "UploadLabForm",
                            Method = "post",
                            Enctype = "multipart/form-data",
                            ActionUrl = Url.Action(nameof(Upload), "UploadLab")!,
                            Fields = addFields
                        }
                    }
                }
            };

            // ===============================
            // Render page
            // ===============================
            return View("Index", new SmartPageViewModel
            {
                PageTitle = dsModel.PageTitle,
                PanelTitle = dsModel.PanelTitle,
                PanelIcon = "fa-solid fa-cloud-arrow-up",
                TableDS = dsModel
            });
        }

        // ===============================
        // POST: Handle file upload
        // ===============================
        [HttpPost]
        [ValidateAntiForgeryToken]
        [RequestSizeLimit(20 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 20 * 1024 * 1024)]
        public async Task<IActionResult> Upload()
        {
            // --- read uploaded file ---
            var file =
                Request.Form.Files.GetFile("attachments")
                ?? Request.Form.Files.GetFile("attachments[]")
                ?? Request.Form.Files.FirstOrDefault();

            if (file == null || file.Length == 0)
                return Fail("لم يتم اختيار ملف.");

            // --- extension validation ---
            var ext = (Path.GetExtension(file.FileName ?? "") ?? "").ToLowerInvariant();
            var allowedExt = new HashSet<string> { ".pdf", ".xls", ".xlsx" };
            if (!allowedExt.Contains(ext))
                return Fail("يجب رفع ملف PDF أو Excel فقط.");

            // --- mime validation ---
            var allowedMime = new HashSet<string>
            {
                "application/pdf",
                "application/vnd.ms-excel",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            };
            if (!allowedMime.Contains(file.ContentType ?? ""))
                return Fail("نوع الملف غير صحيح.");

            // --- size validation ---
            const long maxBytes = 10L * 1024L * 1024L;
            if (file.Length > maxBytes)
                return Fail("حجم الملف أكبر من 10MB.");

            // --- physical save ---
            var saveDir = Path.Combine(_env.WebRootPath, "uploads", "lab");
            Directory.CreateDirectory(saveDir);

            var storedName = Guid.NewGuid().ToString("N") + ext;
            var fullPath = Path.Combine(saveDir, storedName);

            await using (var fs = System.IO.File.Create(fullPath))
            {
                await file.CopyToAsync(fs);
            }

            // --- relative path ---
            var relative = $"/uploads/lab/{storedName}";

            // --- update session rows ---
            var rows = GetRows();
            var nextId = rows.Count == 0 ? 1 : rows.Max(x => x.Id) + 1;

            rows.Add(new UploadLabRow
            {
                Id = nextId,
                OriginalName = file.FileName ?? storedName,
                RelativePath = relative,
                UploadedAt = DateTime.Now
            });

            SaveRows(rows);

            return OkMsg("تم رفع الملف بنجاح.", new { relative });
        }

        // ===============================
        // Session row model
        // ===============================
        public class UploadLabRow
        {
            public int Id { get; set; }
            public string OriginalName { get; set; } = "";
            public string RelativePath { get; set; } = "";
            public DateTime UploadedAt { get; set; }
        }
    }
}
