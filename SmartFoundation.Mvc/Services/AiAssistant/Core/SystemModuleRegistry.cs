using System;
using System.Collections.Generic;
using System.Linq;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public static class SystemModuleRegistry
{
    public static IReadOnlyList<SystemModuleDefinition> All { get; } =
        new List<SystemModuleDefinition>
        {
            BuildHousingModule(),
            BuildIncomeSystemModule(),
            BuildElectronicBillSystemModule()
        };

    public static IEnumerable<SystemPageDefinition> GetAllPages()
        => All.SelectMany(m => m.Pages);

    public static SystemPageDefinition? FindPageByInternalName(string? internalPageName)
    {
        if (string.IsNullOrWhiteSpace(internalPageName))
            return null;

        return GetAllPages().FirstOrDefault(p =>
            p.InternalPageName.Equals(internalPageName, StringComparison.OrdinalIgnoreCase));
    }

    public static SystemModuleDefinition? FindModuleByKey(string? moduleKey)
    {
        if (string.IsNullOrWhiteSpace(moduleKey))
            return null;

        return All.FirstOrDefault(m =>
            m.Key.Equals(moduleKey, StringComparison.OrdinalIgnoreCase));
    }

    private static SystemModuleDefinition BuildHousingModule()
    {
        return new SystemModuleDefinition
        {
            Key = "Housing",
            ArabicName = "الإسكان",
            KeywordsArabic = new[]
            {
                "الإسكان", "السكن", "الوحدات السكنية", "المستفيدين", "الانتظار", "التخصيص", "الإخلاء"
            },
            Pages = new[]
            {
                new SystemPageDefinition
                {
                    Key = "Housing.Residents",
                    ModuleKey = "Housing",
                    InternalPageName = "Residents",
                    ArabicPageName = "المستفيدين",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "مستفيد", "المستفيد", "المستفيدين", "ساكن", "السكان", "بيانات المستفيد"
                    },
                    ArabicDescription = "إدارة بيانات المستفيدين والبحث عنهم وتعديلها.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف مستفيدًا؟",
                        "كيف أعدل بيانات مستفيد؟",
                        "كيف أبحث عن مستفيد؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة", "أنشئ", "سجل" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE", "UPDATENATIONALIDFORRESIDENT" }, new[] { "عدل", "تعديل", "حدّث", "غيّر" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف", "إزالة" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث", "اعثر", "وين" }),
                        CreateAction(ActionType.Print, "طباعة", Array.Empty<string>(), new[] { "اطبع", "طباعة", "تقرير" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.BuildingDetails",
                    ModuleKey = "Housing",
                    InternalPageName = "BuildingDetails",
                    ArabicPageName = "المباني",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "مبنى", "المباني", "الوحدة السكنية", "المنزل", "البيت"
                    },
                    ArabicDescription = "إدارة بيانات المباني والوحدات السكنية.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف مبنى؟",
                        "كيف أعدل بيانات مبنى؟",
                        "كيف أبحث عن مبنى؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة", "أنشئ" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" }),
                        CreateAction(ActionType.Print, "طباعة", Array.Empty<string>(), new[] { "اطبع", "طباعة" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.BuildingClass",
                    ModuleKey = "Housing",
                    InternalPageName = "BuildingClass",
                    ArabicPageName = "فئات المباني",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "فئة مبنى", "فئات المباني", "تصنيف مبنى", "تصنيفات المباني"
                    },
                    ArabicDescription = "إدارة فئات المباني.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف فئة مبنى؟",
                        "كيف أعدل فئة مبنى؟",
                        "كيف أحذف فئة مبنى؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.BuildingType",
                    ModuleKey = "Housing",
                    InternalPageName = "BuildingType",
                    ArabicPageName = "أنواع المباني",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "نوع مبنى", "أنواع المباني", "نوع البناء", "انواع المباني"
                    },
                    ArabicDescription = "إدارة أنواع المباني.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف نوع مبنى؟",
                        "كيف أعدل نوع مبنى؟",
                        "كيف أحذف نوع مبنى؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.BuildingUtilityType",
                    ModuleKey = "Housing",
                    InternalPageName = "BuildingUtilityType",
                    ArabicPageName = "خدمات المباني",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "خدمة مبنى", "خدمات المباني", "مرافق المباني", "مرفق"
                    },
                    ArabicDescription = "إدارة أنواع الخدمات والمرافق المرتبطة بالمباني.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف خدمة مبنى؟",
                        "كيف أعدل خدمة مبنى؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.MilitaryLocation",
                    ModuleKey = "Housing",
                    InternalPageName = "MilitaryLocation",
                    ArabicPageName = "المواقع العسكرية",
                    ModuleType = ModuleType.Reference,
                    KeywordsArabic = new[]
                    {
                        "موقع عسكري", "المواقع العسكرية", "مدينة عسكرية", "منطقة عسكرية","حي","احياء"
                    },
                    ArabicDescription = "إدارة المواقع والمدن والمناطق العسكرية.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف موقعًا عسكريًا؟",
                        "كيف أعدل حي سكني؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERT" }, new[] { "أضف", "إضافة" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETE" }, new[] { "احذف", "حذف" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.WaitingList",
                    ModuleKey = "Housing",
                    InternalPageName = "WaitingList",
                    ArabicPageName = "قوائم الانتظار",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "قائمة الانتظار", "قوائم الانتظار", "الانتظار", "ترتيب الانتظار", "فئة الانتظار"
                    },
                    ArabicDescription = "متابعة قوائم الانتظار وتحويل المستحقين إلى مراحل لاحقة.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أبحث في قوائم الانتظار؟",
                        "كيف أحوّل إلى التخصيص؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" }),
                        CreateAction(ActionType.Move, "نقل", new[] { "MOVETOASSIGNLIST" }, new[] { "انقل", "نقل", "حوّل" }),
                        CreateAction(ActionType.Print, "طباعة", Array.Empty<string>(), new[] { "اطبع", "طباعة" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.WaitingListByResident",
                    ModuleKey = "Housing",
                    InternalPageName = "WaitingListByResident",
                    ArabicPageName = "قوائم الانتظار حسب المستفيد",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "قائمة الانتظار حسب المستفيد", "سجل انتظار", "سجلات الانتظار",
                        "خطاب تسكين", "خطابات التسكين", "طلب نقل", "نقل سجل انتظار"
                    },
                    ArabicDescription = "إدارة سجلات الانتظار وخطابات التسكين وطلبات النقل حسب المستفيد.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف سجل انتظار؟",
                        "كيف أضيف خطاب تسكين؟",
                        "كيف أحذف طلب نقل؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "INSERTWAITINGLIST", "INSERTOCCUBENTLETTER" }, new[] { "أضف", "إضافة", "أنشئ", "سجل" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATEWAITINGLIST", "UPDATEOCCUBENTLETTER" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "حذف", new[] { "DELETEWAITINGLIST", "DELETEOCCUBENTLETTER", "DELETEMOVEWAITINGLIST", "DELETERESIDENTALLWAITINGLIST" }, new[] { "احذف", "حذف", "إلغاء" }),
                        CreateAction(ActionType.Move, "نقل", new[] { "MOVEWAITINGLIST" }, new[] { "انقل", "نقل", "حوّل" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" })
                    }
                },

                new SystemPageDefinition
                    {
                        Key = "Housing.WaitingListMoveList",
                        ModuleKey = "Housing",
                        InternalPageName = "WaitingListMoveList",
                        ArabicPageName = "طلبات نقل الانتظار",
                        ModuleType = ModuleType.Inquiry,
                        KeywordsArabic = new[]
                        {
                            "طلبات نقل الانتظار",
                            "طلبات النقل الواردة",
                            "طلب نقل",
                            "رفض طلب نقل",
                            "اعتماد طلب نقل",
                            "طلبات النقل",
                            "نقل الانتظار الوارد"
                        },
                        ArabicDescription = "مراجعة واعتماد أو رفض طلبات نقل قوائم الانتظار.",
                        RelatedToRegulations = true,
                        SuggestedQuestionsArabic = new[]
                        {
                            "كيف أعتمد طلب نقل؟",
                            "كيف أرفض طلب نقل؟",
                            "كيف أراجع طلبات النقل الواردة؟"
                        },
                        Actions = new[]
                        {
                            CreateAction(
                                ActionType.Approve,
                                "اعتماد",
                                new[] { "MOVEWAITINGLISTAPPROVE" },
                                new[] { "اعتمد", "اعتماد", "وافق", "موافقة", "قبول طلب نقل" }
                            ),
                            CreateAction(
                                ActionType.Reject,
                                "رفض",
                                new[] { "MOVEWAITINGLISTREJECT" },
                                new[] { "ارفض", "رفض", "عدم قبول", "رفض طلب نقل" }
                            ),
                            CreateAction(
                                ActionType.Search,
                                "بحث",
                                Array.Empty<string>(),
                                new[] { "ابحث", "بحث", "اعرض", "مراجعة الطلبات" }
                            )
                        }
                    }
                ,

                new SystemPageDefinition
                {
                    Key = "Housing.Assign",
                    ModuleKey = "Housing",
                    InternalPageName = "Assign",
                    ArabicPageName = "التخصيص",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                        {
                            "قائمة الانتظار حسب المستفيد",
                            "سجل انتظار",
                            "سجلات الانتظار",
                            "خطاب تسكين",
                            "خطابات التسكين",
                            "طلب نقل من مستفيد",
                            "نقل سجل انتظار",
                            "إدارة سجلات الانتظار"
                        },
                    ArabicDescription = "فتح محاضر التخصيص وتخصيص الوحدات السكنية للمستفيدين.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أفتح محضر تخصيص؟",
                        "كيف أغلق محضر التخصيص؟",
                        "كيف أخصص منزلًا لمستفيد؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.OpenPeriod, "فتح", new[] { "OPENASSIGNPERIOD" }, new[] { "افتح", "فتح", "أنشئ محضر" }),
                        CreateAction(ActionType.ClosePeriod, "إغلاق", new[] { "CLOSEASSIGNPERIOD" }, new[] { "أغلق", "إغلاق" }),
                        CreateAction(ActionType.Assign, "تخصيص", new[] { "ASSIGNHOUSE" }, new[] { "خصص", "تخصيص", "سكّن" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UPDATEASSIGNHOUSE" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Exclude, "استبعاد", new[] { "CANCLEASSIGNHOUSE" }, new[] { "استبعد", "استبعاد", "إلغاء تخصيص" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.AssignStatus",
                    ModuleKey = "Housing",
                    InternalPageName = "AssignStatus",
                    ArabicPageName = "حالة التخصيص",
                    ModuleType = ModuleType.Inquiry,
                    KeywordsArabic = new[]
                    {
                        "حالة التخصيص", "متابعة التخصيص", "المتبقي في المحضر", "حالة المحضر"
                    },
                    ArabicDescription = "متابعة حالة محاضر التخصيص وما تبقى من الإجراءات.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أعرف المتبقي في المحضر؟",
                        "كيف أتابع حالة التخصيص؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث", "تابع" }),
                        CreateAction(ActionType.Print, "طباعة", Array.Empty<string>(), new[] { "اطبع", "طباعة" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.HousingExit",
                    ModuleKey = "Housing",
                    InternalPageName = "HousingExit",
                    ArabicPageName = "الإخلاء",
                    ModuleType = ModuleType.Operational,
                   KeywordsArabic = new[]
                    {
                        "إخلاء",
                        "اخلاء",
                        "إنهاء السكن",
                        "خروج من السكن",
                        "إخلاء الوحدة",
                        "شروط الإخلاء",
                        "ضوابط الإخلاء",
                        "لائحة الإخلاء",
                        "ما معنى الإخلاء"
                    },
                    ArabicDescription = "إجراءات إخلاء الوحدة السكنية واعتمادها وربطها بالمطالبات المالية.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أسجل إخلاء؟",
                        "كيف أعتمد الإخلاء؟",
                        "كيف أرسل الإخلاء إلى المالية؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "HOUSINGHousingExit" }, new[] { "أضف", "إضافة", "سجل إخلاء" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "EDITHOUSINGHousingExit" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "إلغاء", new[] { "CANCELHOUSINGHousingExit" }, new[] { "إلغاء", "الغاء", "ألغِ" }),
                        CreateAction(ActionType.Review, "إرسال للمالية", new[] { "SENDHOUSINGHousingExitTOFINANCE" }, new[] { "ارسل للمالية", "إرسال للمالية" }),
                        CreateAction(ActionType.Approve, "اعتماد", new[] { "APPROVEHousingExit" }, new[] { "اعتمد", "اعتماد" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.HousingExtend",
                    ModuleKey = "Housing",
                    InternalPageName = "HousingExtend",
                    ArabicPageName = "التمديد",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "تمديد", "إمهال", "تمديد السكن", "تمديد مهلة"
                    },
                    ArabicDescription = "إجراءات التمديد والمهلة واعتمادها وربطها بالتسوية المالية.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أسجل تمديدًا؟",
                        "كيف أعتمد التمديد؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة", new[] { "HOUSINGEXTEND" }, new[] { "أضف", "إضافة", "سجل تمديد" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "EDITHOUSINGEXTEND" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Delete, "إلغاء", new[] { "CANCELHOUSINGEXTEND" }, new[] { "إلغاء", "الغاء" }),
                        CreateAction(ActionType.Review, "إرسال للمالية", new[] { "SENDHOUSINGEXTENDTOFINANCE" }, new[] { "ارسل للمالية", "إرسال للمالية" }),
                        CreateAction(ActionType.Approve, "اعتماد", new[] { "APPROVEEXTEND" }, new[] { "اعتمد", "اعتماد" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.HousingHandover",
                    ModuleKey = "Housing",
                    InternalPageName = "HousingHandover",
                    ArabicPageName = "التسليم",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "تسليم", "استلام", "تسليم الوحدة", "محضر تسليم"
                    },
                    ArabicDescription = "إجراءات تسليم واستلام الوحدات السكنية.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أسجل تسليم الوحدة؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض", new[] { "HousingHandover" }, new[] { "عرض", "افتح", "ادخل" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.HousingResident",
                    ModuleKey = "Housing",
                    InternalPageName = "HousingResident",
                    ArabicPageName = "السكان الحاليون",
                    ModuleType = ModuleType.Inquiry,
                    KeywordsArabic = new[]
                    {
                        "السكان الحاليون", "السكان", "شاغلو الوحدات", "المقيمون"
                    },
                    ArabicDescription = "استعراض بيانات الساكنين الحاليين في الوحدات.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أبحث عن السكان الحاليين؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Search, "بحث", new[] { "HOUSINGESRESIDENTS", "HOUSINGESRESIDENTSCUSTDY" }, new[] { "ابحث", "بحث", "اعرض" }),
                        CreateAction(ActionType.Print, "طباعة", Array.Empty<string>(), new[] { "اطبع", "طباعة" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.RentExemption",
                    ModuleKey = "Housing",
                    InternalPageName = "RentExemption",
                    ArabicPageName = "الإعفاء من الإيجار",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "إعفاء", "اعفاء", "إعفاء من الإيجار", "إعفاء الإيجار", "إسقاط الإيجار"
                    },
                    ArabicDescription = "إدارة طلبات الإعفاء من الإيجار للمستفيدين.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أسجل إعفاء من الإيجار؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" }),
                        CreateAction(ActionType.Add, "إضافة", Array.Empty<string>(), new[] { "أضف", "إضافة" }),
                        CreateAction(ActionType.Update, "تعديل", Array.Empty<string>(), new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Approve, "اعتماد", Array.Empty<string>(), new[] { "اعتمد", "اعتماد" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "Housing.OtherWaitingList",
                    ModuleKey = "Housing",
                    InternalPageName = "OtherWaitingList",
                    ArabicPageName = "قوائم الانتظار الأخرى",
                    ModuleType = ModuleType.Operational,
                    KeywordsArabic = new[]
                    {
                        "قوائم الانتظار الأخرى", "قائمة أخرى", "تحويل لإجراءات التسكين"
                    },
                    ArabicDescription = "متابعة القوائم الأخرى وتحويلها إلى الإجراءات المناسبة.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أنقل من القوائم الأخرى؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Move, "نقل", new[] { "MOVETOOCCUPENTPROCEDURES" }, new[] { "انقل", "نقل", "حوّل" }),
                        CreateAction(ActionType.Search, "بحث", Array.Empty<string>(), new[] { "ابحث", "بحث" })
                    }
                }
            }
        };
    }

    private static SystemModuleDefinition BuildIncomeSystemModule()
    {
        return new SystemModuleDefinition
        {
            Key = "IncomeSystem",
            ArabicName = "الإيرادات",
            KeywordsArabic = new[]
            {
                "الإيرادات", "المالية", "المطالبات", "المدفوعات", "التسوية", "المسيرات"
            },
            Pages = new[]
            {
                new SystemPageDefinition
                {
                    Key = "IncomeSystem.FinancialAuditForUser",
                    ModuleKey = "IncomeSystem",
                    InternalPageName = "FinancialAuditForUser",
                    ArabicPageName = "التدقيق المالي للمستخدم",
                    ModuleType = ModuleType.Audit,
                    KeywordsArabic = new[]
                    {
                        "التدقيق المالي للمستخدم", "مطالبات المستخدم", "مدفوعات المستخدم", "تسوية المستخدم"
                    },
                    ArabicDescription = "مراجعة المطالبات والمدفوعات والتسويات المالية الخاصة بالمستخدم.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أبحث عن التدقيق المالي للمستخدم؟",
                        "كيف أراجع المطالبات والمدفوعات للمستخدم؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض", new[] { "FinancialAuditForUser" }, new[] { "اعرض", "عرض", "افتح" }),
                        CreateAction(ActionType.Settlement, "تسوية", new[] { "FINANCIALSETTLEMENTFORUSER" }, new[] { "تسوية", "سوّ" }),
                        CreateAction(ActionType.Review, "مراجعة", new[] { "REVIEWCLAIMSANDPAYMENTSFORUSER" }, new[] { "راجع", "مراجعة" }),
                        CreateAction(ActionType.Payment, "سداد واسترداد", new[] { "PAYMENTANDREFUNDFORUSER" }, new[] { "سداد", "استرداد", "تحصيل", "إرجاع" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "IncomeSystem.FinancialAuditForExtendAndEvictions",
                    ModuleKey = "IncomeSystem",
                    InternalPageName = "FinancialAuditForExtendAndEvictions",
                    ArabicPageName = "التدقيق المالي للتمديد والإخلاء",
                    ModuleType = ModuleType.Audit,
                    KeywordsArabic = new[]
                    {
                        "التدقيق المالي للتمديد", "التدقيق المالي للإخلاء", "مطالبات التمديد", "مطالبات الإخلاء"
                    },
                    ArabicDescription = "مراجعة المطالبات والتسويات المالية المرتبطة بالتمديد والإخلاء.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أراجع التدقيق المالي للتمديد والإخلاء؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض", new[] { "FINANCIALAUDITFOREXTENDANDEVICTIONS" }, new[] { "اعرض", "عرض", "افتح" }),
                        CreateAction(ActionType.Settlement, "تسوية", new[] { "FINANCIALSETTLEMENT" }, new[] { "تسوية", "سوّ" }),
                        CreateAction(ActionType.Review, "مراجعة", new[] { "REVIEWCLAIMSANDPAYMENTS" }, new[] { "راجع", "مراجعة" }),
                        CreateAction(ActionType.Payment, "سداد واسترداد", new[] { "PAYMENTANDREFUNDFOREXTENDANDEXIT" }, new[] { "سداد", "استرداد", "تحصيل", "إرجاع" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "IncomeSystem.ImportExcelForBuildingPayment",
                    ModuleKey = "IncomeSystem",
                    InternalPageName = "ImportExcelForBuildingPayment",
                    ArabicPageName = "استيراد إكسل لمسيرات سداد المباني",
                    ModuleType = ModuleType.Import,
                    KeywordsArabic = new[]
                    {
                        "استيراد إكسل", "رفع ملف إكسل", "مسير سداد", "سداد المباني", "استيراد المسيرات"
                    },
                    ArabicDescription = "رفع ملفات إكسل واستعراض المعاينة قبل معالجة مسيرات السداد.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أرفع ملف إكسل للمسيرات؟",
                        "كيف أعاين ملف الإكسل قبل المعالجة؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض", new[] { "IMPORTEXCELFORBUILDINGPAYMENT" }, new[] { "اعرض", "افتح", "ادخل" }),
                        CreateAction(ActionType.ImportExcel, "استيراد", new[] { "IMPORTEXCELFORBUILDINGPAYMENT" }, new[] { "استورد", "استيراد", "ارفع ملف", "إكسل" })
                    }
                }
            }
        };
    }

    private static SystemModuleDefinition BuildElectronicBillSystemModule()
    {
        return new SystemModuleDefinition
        {
            Key = "ElectronicBillSystem",
            ArabicName = "الفوترة الإلكترونية",
            KeywordsArabic = new[]
            {
                "الفوترة الإلكترونية", "الفواتير", "العدادات", "قراءة العدادات", "الفترة"
            },
            Pages = new[]
            {
                new SystemPageDefinition
                {
                    Key = "ElectronicBillSystem.Meters",
                    ModuleKey = "ElectronicBillSystem",
                    InternalPageName = "Meters",
                    ArabicPageName = "العدادات",
                    ModuleType = ModuleType.Billing,
                    KeywordsArabic = new[]
                      {
                          "عداد",
                          "العدادات",
                          "ادارة العدادات",
                          "إدارة العدادات",
                          "نوع العداد",
                          "أنواع العدادات",
                          "ربط العداد",
                          "ربط عداد بمبنى",
                          "خدمة العداد"
                      },
                    ArabicDescription = "إدارة العدادات وأنواعها وربطها بالمباني.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أضيف عدادًا جديدًا؟",
                        "كيف أضيف نوع عداد؟",
                        "كيف أربط عدادًا بمبنى؟",
                        "كيف أعدل نوع عداد؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.Add, "إضافة عداد", new[] { "INSERTNEWMETER" }, new[] { "أضف عداد", "إضافة عداد", "اضافة عداد", "كيف أضيف عداد", "كيف اضيف عداد" }),
                        CreateAction(ActionType.Add, "إضافة نوع عداد", new[] { "INSERTNEWMETERTYPE" }, new[] { "أضف نوع عداد", "إضافة نوع عداد", "اضافة نوع عداد", "كيف أضيف نوع عداد", "كيف اضيف نوع عداد" }),
                        CreateAction(ActionType.Assign, "ربط عداد بمبنى", new[] { "INSERTNEWMETER" }, new[] { "ربط عداد بمبنى", "اربط عداد بمبنى", "ربط عداد", "ربط العدادات بالمباني" }),
                        CreateAction(ActionType.Update, "تعديل عداد", new[] { "UPDATENEWMETERTYPE" }, new[] { "عدل عداد", "تعديل عداد", "كيف أعدل عداد", "كيف اعدل عداد" }),
                        CreateAction(ActionType.Update, "تعديل نوع عداد", new[] { "UPDATENEWMETERTYPE" }, new[] { "عدل نوع عداد", "تعديل نوع عداد", "كيف أعدل نوع عداد", "كيف اعدل نوع عداد" }),
                        CreateAction(ActionType.Delete, "حذف عداد", new[] { "DELETENEWMETERTYPE" }, new[] { "احذف عداد", "حذف عداد", "كيف أحذف عداد", "كيف احذف عداد" }),
                        CreateAction(ActionType.Delete, "حذف نوع عداد", new[] { "DELETENEWMETERTYPE" }, new[] { "احذف نوع عداد", "حذف نوع عداد", "كيف أحذف نوع عداد", "كيف احذف نوع عداد" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "ElectronicBillSystem.AllMeterRead",
                    ModuleKey = "ElectronicBillSystem",
                    InternalPageName = "AllMeterRead",
                    ArabicPageName = "جميع قراءات العدادات",
                    ModuleType = ModuleType.Billing,
                    KeywordsArabic = new[]
                    {
                        "جميع قراءات العدادات",
                        "عرض جميع قراءات العدادات",
                        "قراءات العدادات",
                        "قراءة العدادات الدورية",
                        "فترة قراءة",
                        "فترة قراءة عدادات",
                        "فتح فترة عدادات",
                        "اغلاق فترة عدادات",
                        "اغلاق فترة قراءة العدادات",
                        "فتح فترة قراءة",
                        "اغلاق فترة قراءة",
                        "العدادات الدورية",
                        "قراءة الكهرباء",
                        "قراءة الماء",
                        "قراءة الغاز",
                        "اعتماد قراءة عداد"
                    },
                    ArabicDescription = "إنشاء ومتابعة فترات قراءة العدادات وإدخال القراءات.",
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أعرض جميع قراءات العدادات؟",
                        "كيف أفتح فترة قراءة عدادات؟",
                        "كيف أغلق فترة قراءة العدادات؟",
                        "كيف أعتمد قراءة عداد؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض جميع القراءات", Array.Empty<string>(), new[] { "اعرض جميع قراءات العدادات", "عرض جميع قراءات العدادات", "اعرض القراءات", "عرض القراءات" }),
                        CreateAction(ActionType.OpenPeriod, "فتح فترة", new[] { "OPENMETERREADPERIOD" }, new[] { "افتح فترة", "فتح فترة", "فتح فترة عدادات", "فتح فترة قراءة", "انشئ فترة", "ابدأ فترة" }),
                        CreateAction(ActionType.ClosePeriod, "إغلاق فترة", new[] { "CLOSEMETERREADPERIOD" }, new[] { "اغلق فترة", "إغلاق فترة", "اغلاق فترة", "اغلق فترة قراءة العدادات", "اقفل فترة", "انه فترة", "إنهاء فترة" }),
                        CreateAction(ActionType.ReadMeter, "قراءة عداد", Array.Empty<string>(), new[] { "قراءة عداد كهرباء", "قراءة الكهرباء", "قراءة عداد ماء", "قراءة الماء", "قراءة عداد غاز", "قراءة الغاز", "ادخل قراءة", "إضافة قراءة عداد", "اضافة قراءة عداد", "أضف قراءة عداد", "اضيف قراءة عداد" }),
                        CreateAction(ActionType.Approve, "اعتماد قراءة عداد", Array.Empty<string>(), new[] { "اعتمد قراءة عداد", "اعتماد قراءة عداد", "اعتماد القراءة", "اعتمد القراءة" })
                    }
                },

                new SystemPageDefinition
                {
                    Key = "ElectronicBillSystem.MeterReadForOccubentAndExit",
                    ModuleKey = "ElectronicBillSystem",
                    InternalPageName = "MeterReadForOccubentAndExit",
                    ArabicPageName = "قراءة عدادات الساكن والإخلاء",
                    ModuleType = ModuleType.Billing,
                    KeywordsArabic = new[]
                    {
                        "قراءة عدادات الساكن", "قراءة عدادات الإخلاء", "قراءة الساكن", "قراءة الإخلاء"
                    },
                    ArabicDescription = "تسجيل واعتماد قراءات العدادات المرتبطة بالتسكين أو الإخلاء.",
                    RelatedToRegulations = true,
                    SuggestedQuestionsArabic = new[]
                    {
                        "كيف أسجل قراءة عداد للساكن؟",
                        "كيف أعتمد قراءة العداد عند الإخلاء؟"
                    },
                    Actions = new[]
                    {
                        CreateAction(ActionType.View, "عرض", new[] { "MeterReadForOccubentAndExit" }, new[] { "اعرض", "افتح" }),
                        CreateAction(ActionType.Update, "تعديل", new[] { "UpdateMeterReadForOccubentAndExit" }, new[] { "عدل", "تعديل" }),
                        CreateAction(ActionType.Approve, "اعتماد", new[] { "APPROVEMETERREADFOROCCUBENTANDEXIT" }, new[] { "اعتمد", "اعتماد" })
                    }
                }
            }
        };
    }

    private static SystemActionDefinition CreateAction(
        ActionType actionType,
        string arabicLabel,
        IReadOnlyList<string> permissionNames,
        IReadOnlyList<string> keywords,
        IReadOnlyList<string>? exampleQuestionsArabic = null)
    {
        return new SystemActionDefinition
        {
            ActionType = actionType,
            ArabicLabel = arabicLabel,
            PermissionNames = permissionNames,
            Keywords = keywords,
            ExampleQuestionsArabic = exampleQuestionsArabic ?? Array.Empty<string>()
        };
    }
}
