using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartCharts;
using SmartFoundation.UI.ViewModels.SmartForm;
using SmartFoundation.UI.ViewModels.SmartPage;
using System.Data;

namespace SmartFoundation.Mvc.Controllers.Vehicle
{
    public partial class VehicleController : Controller
    {
        [HttpGet]
        [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
        public async Task<IActionResult> VehicleDetailsDrawer(string? chassisNumber)
        {
            if (!InitPageContext(out _))
                return Unauthorized();

            if (string.IsNullOrWhiteSpace(usersId))
                return Unauthorized();

            if (string.IsNullOrWhiteSpace(chassisNumber))
                return BadRequest("رقم الهيكل مطلوب");

            try
            {
                var details = await BuildVehicleDetailsPageAsync(chassisNumber.Trim());
                if (details is null)
                    return NotFound("لم يتم العثور على بيانات المركبة");

                return ViewComponent(
                    "SmartRenderer",
                    new { model = details });
            }
            catch
            {
                return StatusCode(
                    StatusCodes.Status500InternalServerError,
                    "تعذر تحميل تفاصيل المركبة");
            }
        }

        private async Task<SmartPageViewModel?> BuildVehicleDetailsPageAsync(string chassisNumber)
        {
            ControllerName = "Vehicle";
            PageName = "VehicleDetails";

            var profileParams = new object?[]
            {
                "Vehicle_Profile_Get", IdaraId, usersId, HostName,
                usersId,
                null,
                1,
                chassisNumber,
                20,
                20,
                10,
                50,
                IdaraId
            };

            DataSet ds = await _mastersServies.GetDataLoadDataSetAsync(profileParams);
            SplitDataSet(ds);

            if (dt1 == null || dt1.Rows.Count == 0)
                return null;

            var summaryRow = dt1.Rows[0];
            var summary = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (DataColumn column in dt1.Columns)
            {
                var value = summaryRow[column];
                summary[column.ColumnName] = value == DBNull.Value ? null : value;
            }

            object? Get(string key) => summary.TryGetValue(key, out var value) ? value : null;

            var vehicleStatusId = Get("vehicleStatusID_FK")?.ToString();
            var hasCustodyUser = !string.IsNullOrWhiteSpace(Get("CurrentUserID")?.ToString());
            var custodyStatusText = hasCustodyUser ? "عهدة نشطة" : "بدون عهدة";
            var currentUserDisplay = Get("CurrentUserDisplay")?.ToString();
            var custodyNote = hasCustodyUser
                ? $"المستخدم: {(string.IsNullOrWhiteSpace(currentUserDisplay) ? "لا يوجد مستخدم" : currentUserDisplay)}"
                : "لا توجد عهدة نشطة";

            var documentsCount = Get("DocumentsCount")?.ToString() ?? "0";
            var insuranceCount = Get("InsuranceCount")?.ToString() ?? "0";
            var maintenanceCount = Get("MaintenanceCount")?.ToString() ?? "0";
            var violationsCount = Get("ViolationsCount")?.ToString() ?? "0";

            var isActive = Get("isActive")?.ToString() == "1";
            var isActiveText = isActive ? "مفعل" : "موقوف";

            var chassisDisplay = Get("chassisNumber")?.ToString() ?? chassisNumber;
            var plateLetters = Get("plateLetters")?.ToString();
            var plateNumbers = Get("plateNumbers")?.ToString();
            var plateDisplay = (!string.IsNullOrWhiteSpace(plateLetters) ||
                                !string.IsNullOrWhiteSpace(plateNumbers))
                ? $"{plateLetters} {plateNumbers}".Trim()
                : null;

            var statusTone = vehicleStatusId switch
            {
                "260" => ChartTone.Success,
                "261" => ChartTone.Warning,
                "262" => ChartTone.Danger,
                _ => ChartTone.Neutral
            };

            var vehicleStatusText = Get("vehicleStatusName")?.ToString()
                ?? Get("VehicleStatusName")?.ToString()
                ?? vehicleStatusId switch
                {
                    "260" => "نشطة",
                    "261" => "غير نشطة",
                    "262" => "تالفة",
                    _ => "غير محددة"
                };

            string DisplayValue(string nameField, string idField)
            {
                var display = Get(nameField)?.ToString();
                if (!string.IsNullOrWhiteSpace(display))
                    return display;

                var id = Get(idField)?.ToString();
                return string.IsNullOrWhiteSpace(id) ? "—" : id;
            }

            var charts = new SmartChartsConfig
            {
                ChartsId = "vehicleDetailsKpi",
                Dir = "rtl",
                Cards = new List<ChartCardConfig>
                {
                    new ChartCardConfig
                    {
                        Id = "kpi_vehicle",
                        Type = ChartCardType.Kpi,
                        Title = "رقم الهيكل",
                        Tone = statusTone,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-car",
                        BigValue = chassisDisplay,
                        Note = plateDisplay != null ? $"اللوحة: {plateDisplay}" : isActiveText
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_custody",
                        Type = ChartCardType.Kpi,
                        Title = "حالة العهدة",
                        Tone = hasCustodyUser ? ChartTone.Success : ChartTone.Neutral,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-user-check",
                        BigValue = custodyStatusText,
                        Note = custodyNote
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_vehicle_status",
                        Type = ChartCardType.Kpi,
                        Title = "حالة المركبة",
                        Tone = statusTone,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-car-side",
                        BigValue = vehicleStatusText,
                        Note = $"حالة السجل: {(isActive ? "مفعلة" : "موقوفة")}"
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_documents",
                        Type = ChartCardType.Kpi,
                        Title = "الوثائق",
                        Tone = ChartTone.Info,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-file-lines",
                        BigValue = documentsCount,
                        Note = "وثائق مسجلة"
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_insurance",
                        Type = ChartCardType.Kpi,
                        Title = "التأمينات",
                        Tone = ChartTone.Info,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-shield-halved",
                        BigValue = insuranceCount,
                        Note = "سجلات التأمين"
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_maintenance",
                        Type = ChartCardType.Kpi,
                        Title = "الصيانة",
                        Tone = ChartTone.Warning,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-wrench",
                        BigValue = maintenanceCount,
                        Note = "أوامر الصيانة"
                    },
                    new ChartCardConfig
                    {
                        Id = "kpi_violations",
                        Type = ChartCardType.Kpi,
                        Title = "المخالفات",
                        Tone = ChartTone.Danger,
                        ColCss = "col-span-2",
                        Size = ChartCardSize.Sm,
                        Dir = "rtl",
                        Icon = "fa-solid fa-gavel",
                        BigValue = violationsCount,
                        Note = "المخالفات المسجلة"
                    }
                }
            };

            var detailsForm = new FormConfig
            {
                FormId = "vehicleDetailsForm",
                Title = "تفاصيل المركبة",
                LabelText = "جميع البيانات للعرض فقط",
                ShowPanel = false,
                ShowSubmit = false,
                ShowReset = false,
                Fields = new List<FieldConfig>
                {
                    new()
                    {
                        Name = "vehicleDetailsChassisNumber",
                        Label = "رقم الهيكل",
                        Type = "text",
                        Value = chassisDisplay,
                        Readonly = true,
                        ColCss = "6",
                        Icon = "fa-solid fa-car",
                        SectionTitle = "بيانات التعريف",
                        InlineButton = true,
                        InlineButtonText = "نسخ",
                        InlineButtonIcon = "fa-regular fa-copy",
                        InlineButtonCss = "btn btn-success",
                        InlineButtonPosition = "end",
                        InlineButtonOnClickJs = "void(async()=>{const i=document.getElementById(this.dataset.sfField);if(!i?.value)return;const l=this.querySelector('span'),c=this.querySelector('i');try{if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(i.value);}else{i.focus();i.select();document.execCommand('copy');}if(l)l.textContent='تم النسخ';if(c)c.className='fa-solid fa-check text-[14px]';setTimeout(()=>{if(l)l.textContent='نسخ';if(c)c.className='fa-regular fa-copy text-[14px]';},1400);}catch{if(l)l.textContent='تعذر النسخ';}})()"
                    },
                    new()
                    {
                        Name = "vehicleDetailsPlate",
                        Label = "رقم اللوحة",
                        Type = "text",
                        Value = plateDisplay ?? "بدون لوحة",
                        Readonly = true,
                        ColCss = "6",
                        Icon = "fa-solid fa-id-card"
                    },
                    new()
                    {
                        Name = "vehicleDetailsRecordStatus",
                        Label = "حالة السجل",
                        Type = "text",
                        Value = isActive ? "مفعلة" : "موقوفة",
                        Readonly = true,
                        ColCss = "6",
                        Icon = "fa-solid fa-circle-check"
                    },
                    new()
                    {
                        Name = "vehicleDetailsCustodyStatus",
                        Label = "حالة العهدة",
                        Type = "text",
                        Value = custodyStatusText,
                        HelpText = custodyNote,
                        Readonly = true,
                        ColCss = "6",
                        Icon = "fa-solid fa-user-check"
                    },
                    new()
                    {
                        Name = "vehicleDetailsManufacturer",
                        Label = "الشركة المصنعة",
                        Type = "text",
                        Value = DisplayValue("manufacturerName", "ManufacturerNameID_FK"),
                        Readonly = true,
                        ColCss = "6",
                        SectionTitle = "البيانات الأساسية"
                    },
                    new()
                    {
                        Name = "vehicleDetailsModel",
                        Label = "الموديل",
                        Type = "text",
                        Value = DisplayValue("modelName", "vehicleModelID_FK"),
                        Readonly = true,
                        ColCss = "6"
                    },
                    new()
                    {
                        Name = "vehicleDetailsYearModel",
                        Label = "سنة الصنع",
                        Type = "text",
                        Value = Get("yearModel")?.ToString() ?? "—",
                        Readonly = true,
                        ColCss = "6"
                    },
                    new()
                    {
                        Name = "vehicleDetailsColor",
                        Label = "اللون",
                        Type = "text",
                        Value = DisplayValue("colorName", "vehicleColorID_FK"),
                        Readonly = true,
                        ColCss = "6"
                    },
                    new()
                    {
                        Name = "vehicleDetailsOwner",
                        Label = "المالك",
                        Type = "text",
                        Value = DisplayValue("ownerName", "ownerID_FK"),
                        Readonly = true,
                        ColCss = "6"
                    },
                    new()
                    {
                        Name = "vehicleDetailsArmyNumber",
                        Label = "الرقم العسكري",
                        Type = "text",
                        Value = Get("armyNumber")?.ToString() ?? "—",
                        Readonly = true,
                        ColCss = "6"
                    }
                }
            };

            var page = new SmartPageViewModel
            {
                PageTitle = "تفاصيل المركبة",
                PanelTitle = $"بيانات المركبة — {chassisDisplay}",
                PanelIcon = "fa-solid fa-car",
                Charts = charts,
                Form = detailsForm
            };

            return page;
        }
    }
}
