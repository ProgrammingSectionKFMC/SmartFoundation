﻿using System.Text.RegularExpressions;

namespace SmartFoundation.UI.ViewModels.SmartForm
{
    public class OptionItem
    {
        public string Value { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
        public bool Selected { get; set; } = false;
        public bool Disabled { get; set; } = false;
        public string? TextEn { get; set; }
        public string? Icon { get; set; }
    }

    public class FieldConfig
    {
        // أساسية
        public string Name { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public string Type { get; set; } = "text";
        public string? Placeholder { get; set; }
        public string? HelpText { get; set; }
        public string? Value { get; set; }
        public bool Required { get; set; } = false;
        public bool Readonly { get; set; } = false;
        public bool Disabled { get; set; } = false;
        public bool Multiple { get; set; } = false;
        public bool IsHidden { get; set; } = false;

        // قيود عامة
        public int? Min { get; set; }
        public int? Max { get; set; }
        public int? MaxLength { get; set; }
        public string? Pattern { get; set; }
        public string? InputPattern { get; set; }
        public string? InputLang { get; set; }

        // تنسيق / واجهة
        public string? ColCss { get; set; }
        public string? ExtraCss { get; set; }
        public string? Icon { get; set; }
        public string? OnChangeJs { get; set; }
        public string? DependsOn { get; set; }
        public string? DependsUrl { get; set; }
        public string? SectionTitle { get; set; }
        public List<OptionItem> Options { get; set; } = new();

        // أنواع خاصة
        public bool IsNumericOnly { get; set; } = false;
        public bool IsIban { get; set; } = false;

        public string? TextMode { get; set; }
        /* القيم الممكنة:
           - arabic        => أحرف عربية فقط
           - english       => أحرف إنجليزية فقط
           - numeric       => أرقام فقط
           - alphanumeric  => إنجليزي + أرقام
           - arabicnum     => عربي + أرقام
           - engsentence   => إنجليزي (حروف + مسافات + علامات بسيطة)
           - arsentence    => عربي (حروف + مسافات + علامات بسيطة)
           - email         => بريد إلكتروني
           - url           => روابط
           - custom        => Regex مخصّص في Pattern
        */

        // خصائص المتصفح
        public string? Autocomplete { get; set; } = "off"; 
        public bool? Spellcheck { get; set; }
        public string? Autocapitalize { get; set; }
        public string? Autocorrect { get; set; }

        // ===== التاريخ المتقدم =====
        public string? Calendar { get; set; } = "gregorian"; 
        public string? DateInputCalendar { get; set; } = "gregorian";
        public string? MirrorName { get; set; }
        public string? MirrorCalendar { get; set; } = "hijri";
        public string? DateDisplayLang { get; set; } = "ar";
        public string? DateNumerals { get; set; } = "latn";
        public bool ShowDayName { get; set; } = true;
        public bool DefaultToday { get; set; } = false;
        public string? MinDateStr { get; set; }
        public string? MaxDateStr { get; set; }
        public string? DisplayFormat { get; set; }

        public string? ColCssFrom { get; set; }       
        public string? ColCssTo { get; set; }

        // ===== Inline Button (زر داخل الحقل) =====
        public bool InlineButton { get; set; } = false;          // تفعيل الزر جنب الحقل
        public string? InlineButtonText { get; set; }            // نص الزر
        public string? InlineButtonIcon { get; set; }            // أيقونة (اختياري)
        public string? InlineButtonCss { get; set; }             // كلاس إضافي (اختياري)
        public string? InlineButtonOnClickJs { get; set; }       // كود JS عند الضغط
        public string InlineButtonPosition { get; set; } = "end"; // end | start (يمين/يسار)

        public bool Select2 { get; set; } = false;          //  تفعيل select2 من الكنترول
        public int? Select2MinResultsForSearch { get; set; } // اختياري: متى يظهر مربع البحث
        public string? Select2Placeholder { get; set; }      // اختياري



        public string? NavUrl { get; set; }        // رابط الانتقال حق الصفحة
        public string? NavKey { get; set; }        // اسم الباراميتر في QueryString
        public string? NavKey2 { get; set; }
        public string? NavVal2 { get; set; }
        public string? NavKey3 { get; set; }
        public string? NavVal3 { get; set; }
        public string? NavKey4 { get; set; }
        public string? NavVal4 { get; set; }
        public string? NavKey5 { get; set; }
        public string? NavVal5 { get; set; }
        public string? RequiredMsg { get; set; }   // رسالة مطلوب
        public string? PatternMsg { get; set; }    // رسالة Regex
        public string? RejectValue { get; set; }   // قيمة مرفوضة مثل -1
        public string? RejectMsg { get; set; }     // رسالة رفض
        public string? ToastType { get; set; }     // info / error
        public string? NavField3 { get; set; }  // اسم حقل يجيب منه قيمة NavKey3
        public string? NavField4 { get; set; }
        public string? NavField5 { get; set; }
        public string? ToggleGroup { get; set; }     // اسم مجموعة الحقول اللي بتنخفي/تظهر
        public string? ToggleMap { get; set; }       // خريطة العرض "1:Users|2:Distributors|..."
        public string? ToggleMode { get; set; }

        public bool SubmitOnEnter { get; set; } = false;



        public SmartTable.TableConfig? Table { get; set; }

        public string GetResolvedColCss()
        {
            var raw = (ColCss ?? "").Trim();
            if (string.IsNullOrWhiteSpace(raw))
                return "col-span-12 md:col-span-6"; // افتراضي: نصف الشاشة

            var tokens = Regex.Split(raw, @"\s+")
                              .Where(t => !string.IsNullOrWhiteSpace(t))
                              .ToList();

            var outTokens = new List<string>();
            var hasBase = false;

            foreach (var t in tokens)
            {
                // 1) sm|md|lg|xl|2xl:number  =>  sm|md|..:col-span-N
                var mBpNum = Regex.Match(t, @"^(sm|md|lg|xl|2xl):(\d{1,2})$");
                if (mBpNum.Success)
                {
                    var bp = mBpNum.Groups[1].Value;
                    var val = Clamp(int.Parse(mBpNum.Groups[2].Value), 1, 12);
                    outTokens.Add($"{bp}:col-span-{val}");
                    continue;
                }

                // 2) col-span-N 
                var mBase = Regex.Match(t, @"^col-span-(\d{1,2})$");
                if (mBase.Success)
                {
                    var val = Clamp(int.Parse(mBase.Groups[1].Value), 1, 12);
                    outTokens.Add($"col-span-{val}");
                    hasBase = true;
                    continue;
                }

                // 3) sm|md|..:col-span-N –
                var mBpCol = Regex.Match(t, @"^(sm|md|lg|xl|2xl):col-span-(\d{1,2})$");
                if (mBpCol.Success)
                {
                    var bp = mBpCol.Groups[1].Value;
                    var val = Clamp(int.Parse(mBpCol.Groups[2].Value), 1, 12);
                    outTokens.Add($"{bp}:col-span-{val}");
                    continue;
                }

                // 4)  رقم (1–12) → col-span-12 md:col-span-N
                var mNum = Regex.Match(t, @"^0*(\d{1,2})$");
                if (mNum.Success)
                {
                    var val = Clamp(int.Parse(mNum.Groups[1].Value), 1, 12);
                    outTokens.Add("col-span-12");
                    outTokens.Add($"md:col-span-{val}");
                    hasBase = true;
                    continue;
                }

                
                outTokens.Add(t);
            }

            
            if (!hasBase)
                outTokens.Insert(0, "col-span-12");

            
            var result = string.Join(" ", outTokens.Distinct());
            return Regex.Replace(result, @"\s+", " ").Trim();
        }

        private static int Clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);
    }

    public class FormButtonConfig
    {
        public string? Text { get; set; }
        public string Type { get; set; } = "button";
        public string? CssClass { get; set; }
        public string? Icon { get; set; }
        public string? OnClickJs { get; set; }
        public bool Show { get; set; } = true;
        public string? StoredProcedureName { get; set; }
        public string? Operation { get; set; } = "custom";
        public string? Color { get; set; }

        public string? SectionTitle { get; set; }  // اسم ال
    }

    public class FormConfig
    {
        public string FormId { get; set; } = "smartForm";
        public string Title { get; set; } = "نموذج الإدخال";
        public string LabelText { get; set; } = string.Empty; // Initialized to avoid CS8618
        public string Method { get; set; } = "POST";
        public string ActionUrl { get; set; } = "/SmartComponent/Execute";
        public string SubmitText { get; set; } = "حفظ";
        public string CancelText { get; set; } = "إلغاء";
        public string? ResetText { get; set; } = "تفريغ";
        public bool ShowPanel { get; set; } = true;
        public bool ShowReset { get; set; } = false;
        public bool ShowSubmit { get; set; } = false;
        public string? StoredProcedureName { get; set; }
        public string? Operation { get; set; } = "insert";
        public string? StoredSuccessMessageField { get; set; } = "Message";
        public string? StoredErrorMessageField { get; set; } = "Error";
        public string? SuccessMessage { get; set; }
        public string? ErrorMessage { get; set; }
        public string? RedirectUrl { get; set; }
        public List<FieldConfig> Fields { get; set; } = new();
        public List<FormButtonConfig> Buttons { get; set; } = new();
    }
}
