using SmartFoundation.UI.ViewModels.SmartCharts;

namespace SmartFoundation.Mvc.Services.Chart
{
    /// <summary>
    /// Service لتوفير بيانات Charts للـ Dashboard والصفحات الأخرى.
    /// يحتوي على جميع الـ Chart configurations المستخدمة في النظام.
    /// </summary>
    public class Chart
    {
        private readonly ILogger<Chart> _logger;

        public Chart(ILogger<Chart> logger)
        {
            _logger = logger;
        }

        #region Main Charts

        /// <summary>
        /// StatsGrid: إحصائيات وأرقام تنفيذية
        /// </summary>
        public ChartCardConfig GetStatsGridChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.StatsGrid,
                Title = "إحصائيات وأرقام المساكن",
                Subtitle = "ملخص : إشغال / شواغر / صيانة / متابعة / نظافة",
                Icon = "fa-solid fa-chart-simple",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                StatsGridAnimate = true,
                StatsGridGroups = new List<StatsGridGroup>
                {
                    new StatsGridGroup
                    {
                        Title = "المساكن بقسم الاسكان",
                        Subtitle = "نتائج مباشرة",
                        Badge = "Live 🔴",
                        Items = new List<StatsGridItem>
                        {
                            new StatsGridItem
                            {
                                Label = "عدد المساكن المشغولة",
                                Value = "1826",
                                Unit = "منزل",
                                Icon = "fa-solid fa-house-circle-check",
                                Hint = "إجمالي المساكن المشغولة حالياً",
                                Delta = "82.22%",
                                DeltaPositive = true,
                                //Href = "/Housing/Occupancy?status=occupied"
                            },
                              new StatsGridItem
                            {
                                Label = "عدد المساكن الخالية",
                                Value = "79",
                                Unit = "منزل",
                                Icon = "fa-solid fa-house-circle-check",
                                Hint = "إجمالي المساكن الخالية بانتظار اتخاذ اجراء",
                                Delta = "3.56%",
                                DeltaPositive = false,
                                //Href = "/Housing/Occupancy?status=occupied"
                              
                            },
                            new StatsGridItem
                            {
                                Label = "عدد المساكن الجاهزة للتسكين",
                                Value = "131",
                                Unit = "%",
                                Icon = "fa-solid fa-percent",
                                Hint = "إجمالي المساكن الجاهزة للتسكين حالياً",
                                Delta = "5.90%",
                                DeltaPositive = false,
                                //Href = "/Housing/Occupancy"
                            },
                        }
                    },
                    new StatsGridGroup
                    {
                        Title = "المساكن بالاقسام الاخرى",
                        Subtitle = "نتائج مباشرة",
                        Badge = "Live 🔴",
                        Items = new List<StatsGridItem>
                        {
                            new StatsGridItem
                            {
                                Label = "عدد المساكن بقسم الصيانة",
                                Value = "185",
                                Unit = "منزل",
                                Icon = "fa-solid fa-house-circle-check",
                                Hint = "إجمالي المساكن تحت الصيانة حالياً",
                                Delta = "8.33%",
                                DeltaPositive = false,
                                //Href = "/Housing/Occupancy?status=occupied"
                            },
                              new StatsGridItem
                            {
                                Label = "عدد المساكن بقسم الجودة",
                                Value = "0",
                                Unit = "منزل",
                                Icon = "fa-solid fa-house-circle-check",
                                Hint = "إجمالي المساكن تحت اجراءات التقييم حالياً",
                                Delta = "0.00%",
                                DeltaPositive = true,
                                //Href = "/Housing/Occupancy?status=occupied"
                              
                            },
                            new StatsGridItem
                            {
                                Label = "عدد المساكن بقسم الخدمات العامة",
                                Value = "0",
                                Unit = "منزل",
                                Icon = "fa-solid fa-house-circle-check",
                                Hint = "إجمالي المساكن تحت اجراءات النظافة حالياً",
                                Delta = "0.00%",
                                DeltaPositive = true,
                                //Href = "/Housing/Occupancy"
                            },
                        }
                    },

                   
                    
                }
            };
        }



        /// <summary>
        /// Occupancy: حالة الوحدات السكنية
        /// </summary>
        public ChartCardConfig GetOccupancyChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Occupancy,
                Title = "مؤشرات تصنيف الوحدات السكنية",
                Subtitle = "حسب الفئات",
                Icon = "fa-solid fa-building-circle-check",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                OccupancyShowPercent = true,
                OccupancyStatuses = new List<OccupancyStatus>
                {
                    new OccupancyStatus { Key="generals",   Label="القادة",      Units=8, Color="#ef4444", Href="/Housing?status=occupied" },
                    new OccupancyStatus { Key="bigboss",    Label="كبار الضباط", Units=109, Color="#0ea5e9", Href="/Housing?status=vacant" },
                    new OccupancyStatus { Key="officer",    Label="ضباط",        Units=530,  Color="#f59e0b", Href="/Housing?status=maintenance" },
                    new OccupancyStatus { Key="bigsolider", Label="ضباط صف",     Units=878,  Color="#8b5cf6", Href="/Housing?status=reserved" },
                    new OccupancyStatus { Key="solider",    Label="جنود",        Units=211,   Color="#0ea5e9", Href="/Housing?status=inactive" },
                    new OccupancyStatus { Key="others",    Label="ضباط عزاب",        Units=14,   Color="#ef4444", Href="/Housing?status=inactive" },
                    new OccupancyStatus { Key="others1",    Label="ضباط صف عزاب",        Units=15,   Color="#ef4444", Href="/Housing?status=inactive" },
                    new OccupancyStatus { Key="others2",    Label="موظف بند تشغيل",        Units=277,   Color="#f59e0b", Href="/Housing?status=inactive" },
                    new OccupancyStatus { Key="others3",    Label="عمال",        Units=9,   Color="#8b5cf6", Href="/Housing?status=inactive" }



              
                }
            };
        }


        /// <summary>
        /// RadialRings: مؤشرات التشغيل
        /// </summary>
        public ChartCardConfig GetRadialRingsChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.RadialRings,
                Title = "مؤشرات التشغيل",
               
                Icon = "fa-solid fa-circle-nodes",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                RadialRingSize = 280,
                RadialRingThickness = 10,
                RadialRingGap = 8,
                RadialRingShowLegend = true,
                RadialRingValueFormat = "0",
                RadialRings = new List<RadialRingItem>
                {
                    new RadialRingItem { Key="generals",   Label="القادة",        Value=0.36M,   Max=100, ValueText="8" },
                    new RadialRingItem { Key="bigboss",    Label="كبار الضباط",   Value=4.91M, Max=100, ValueText="109" },
                    new RadialRingItem { Key="officer",    Label="ضباط",          Value=23.86M, Max=100, ValueText="530" },
                    new RadialRingItem { Key="bigsolider", Label="ضباط صف",       Value=39.53M, Max=100, ValueText="878" },
                    new RadialRingItem { Key="solider",    Label="جنود",          Value=9.50M, Max=100, ValueText="211" },
                    new RadialRingItem { Key="others",     Label="اخرى",          Value=21.84M, Max=100, ValueText="485" }
                }
            };
        }

        /// <summary>
        /// Pie3D: توزيع الوحدات حسب فئة المستفيد
        /// </summary>
        public ChartCardConfig GetPie3DChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Pie3D,
                Title = "توزيع الوحدات حسب فئة المستفيد",
                Subtitle = "3D Pie يوضح مزج الفئات + قابل للنقر للتفاصيل",
                Icon = "fa-solid fa-pizza-slice",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                Pie3DSize = 300,
                Pie3DHeight = 20,
                Pie3DInnerHole = 0,
                Pie3DShowLegend = true,
                Pie3DShowCenterTotal = true,
                Pie3DValueFormat = "0",
                Pie3DExplodeOnHover = true,
                Pie3DSlices = new List<Pie3DSlice>
                {
                    new Pie3DSlice { Key="leaders",  Label="منازل كبار القادة", Value=120,  Href="/Housing?segment=leaders",  Hint="سكن تنفيذي مخصص" },
                    new Pie3DSlice { Key="officers", Label="سكن الضباط",       Value=480,  Href="/Housing?segment=officers", Hint="وحدات للضباط" },
                    new Pie3DSlice { Key="ncos",     Label="سكن ضباط الصف",    Value=760,  Href="/Housing?segment=ncos",     Hint="NCO Housing" },
                    new Pie3DSlice { Key="enlisted", Label="سكن الأفراد",      Value=1320, Href="/Housing?segment=enlisted", Hint="Enlisted Housing" },
                    new Pie3DSlice { Key="singles",  Label="سكن العزاب",       Value=610,  Href="/Housing?segment=singles",  Hint="Singles Quarters" },
                    new Pie3DSlice { Key="families", Label="وحدات العوائل",    Value=2240, Href="/Housing?segment=families", Hint="Family Units" },
                    new Pie3DSlice { Key="guest",    Label="الضيافة/المؤقت",   Value=95,   Href="/Housing?segment=guest",    Hint="Temporary / Guest" },
                    new Pie3DSlice { Key="vip_hold", Label="محجوزة/حجز VIP",   Value=210,  Href="/Housing?segment=vip_hold", Hint="Reserved / Hold" }
                }
            };
        }

        /// <summary>
        /// ColumnPro: الوحدات حسب الحي
        /// </summary>
        public ChartCardConfig GetColumnProChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.ColumnPro,
                Title = "الوحدات حسب الحي",
                Subtitle = "مقارنة عدد الوحدات بين الأحياء",
                Icon = "fa-solid fa-city",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                ColumnProLabels = new List<string>
                {
                    "النرجس","الياسمين","الملقا","العارض","القيروان","حطين","الندى","الواحة"
                },
                ColumnProSeries = new List<ChartSeries>
                {
                    new ChartSeries
                    {
                        Name = "الوحدات",
                        Data = new List<decimal> { 1240, 980, 760, 540, 410, 390, 360, 200 }
                    }
                },
                ColumnProShowValues = true,
                ColumnProValueFormat = "0",
                ColumnProMinBarWidth = 56,
                ColumnProHrefs = new List<string>
                {
                    "/Housing?district=nargis",
                    "/Housing?district=yasmin",
                    "/Housing?district=malqa",
                    "/Housing?district=aredh",
                    "/Housing?district=qirawan",
                    "/Housing?district=hittin",
                    "/Housing?district=nada",
                    "/Housing?district=wahah"
                }
            };
        }

        /// <summary>
        /// OpsBoard: لوحة التشغيل اليومية
        /// </summary>
        public ChartCardConfig GetOpsBoardChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.OpsBoard,
                //Title = "متابعه تحصيل الايجارات وفواتير الخدمات ",
                //Subtitle = "تشغيل الصيانة + الساكنين + المباني + الإسكان (آخر 24 ساعة)",
                Icon = "fa-solid fa-layer-group",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                OpsBoardAnimate = true,
                OpsBoardCompact = false,
                OpsBoardColumns = 1,
                OpsBoardSections = new List<OpsBoardSection>
                {
                    new OpsBoardSection
                    {
                        Title = "تحصيل الايجارات وفواتير الخدمات اخر ستة اشهر",
                        //Subtitle = "شهر يناير 2025",
                        Icon = "fa-solid fa-screwdriver-wrench",
                        Badge = "2025",
                       // Href = "/Maintenance",
                        Kpis = new List<OpsBoardKpi>
                        {
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر يوليو",
                                Value="580258.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة أقل من المتوقع",
                                Delta="+89.2%",
                                DeltaPositive=false,
                                Progress=97.6M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر يوليو",
                                Value="390019.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+89.32%",
                                DeltaPositive=true,
                                Progress=89.32M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر اغسطس",
                                Value="580258.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+96.2%",
                                DeltaPositive=true,
                                Progress=96.2M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر اغسطس",
                                Value="402563.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+89.32%",
                                DeltaPositive=true,
                                Progress=81.32M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر سبتمبر",
                                Value="580258.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة أعلى من المتوقع",
                                Delta="+99.2%",
                                DeltaPositive=true,
                                Progress=99.2M
                                
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر سبتمبر",
                                Value="385261.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة أقل من المتوقع",
                                Delta="+79.15%",
                                DeltaPositive=false,
                                Progress=79.15M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر اكتوبر",
                                Value="580258.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+95.6%",
                                DeltaPositive=true,
                                Progress=95.6M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر اكتوبر",
                                Value="333698.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+86.32%",
                                DeltaPositive=true,
                                Progress=86.32M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر نوفمبر",
                                Value="580258.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+94.7%",
                                DeltaPositive=true,
                                Progress=94.7M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر نوفمبر",
                                Value="371196.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة اعلى من المتوقع",
                                Delta="+96.32%",
                                DeltaPositive=true,
                                Progress=96.32M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="ايجارات شهر ديسمبر",
                                Value="584889.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة بالحالة الطبيعية",
                                Delta="+98.2%",
                                DeltaPositive=true,
                                Progress=98.2M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },
                            new OpsBoardKpi
                            {
                                Label="كهرباء شهر ديسمبر",
                                Value="389562.00",
                                Unit="ريال",
                                Icon="fa-solid fa-circle-plus",
                                Hint="المبالغ المسددة اقل من المتوقع",
                                Delta="+73.32%",
                                DeltaPositive=false,
                                Progress=73.32M
                                //,
                                //Href="/Maintenance?range=24h&status=new"
                            },



                        },
                        //Events = new List<OpsBoardEvent>
                        //{
                        //    new OpsBoardEvent
                        //    {
                        //        Title="تسريب مياه - مبنى 12 / شقة 304",
                        //        Subtitle="إسناد لفريق السباكة • رقم البلاغ: MNT-10421",
                        //        Icon="fa-solid fa-droplet",
                        //        Time="منذ 18 دقيقة",
                        //        Status="قيد التنفيذ",
                        //        StatusTone="info",
                        //        Priority="عالية",
                        //        PriorityTone="warning",
                        //        Href="/Maintenance/Details?id=MNT-10421"
                        //    },
                        //    new OpsBoardEvent
                        //    {
                        //        Title="عطل كهربائي - غرفة مضخات",
                        //        Subtitle="تصعيد للمقاول • رقم البلاغ: MNT-10407",
                        //        Icon="fa-solid fa-bolt",
                        //        Time="منذ ساعتين",
                        //        Status="معلّق",
                        //        StatusTone="warning",
                        //        Priority="حرجة",
                        //        PriorityTone="danger",
                        //        Href="/Maintenance/Details?id=MNT-10407"
                        //    },
                        //    new OpsBoardEvent
                        //    {
                        //        Title="إغلاق بلاغ - تكييف (وحدة 88)",
                        //        Subtitle="تم الإغلاق والتحقق",
                        //        Icon="fa-solid fa-circle-check",
                        //        Time="اليوم 09:20",
                        //        Status="مغلق",
                        //        StatusTone="success",
                        //        Priority="عادية",
                        //        PriorityTone="neutral",
                        //        Href="/Maintenance/Details?id=MNT-10388"
                        //    }
                        //}
                    },
                    //new OpsBoardSection
                    //{
                    //    Title = "الساكنين والخدمات",
                    //    Subtitle = "حركة الطلبات والتوثيق",
                    //    Icon = "fa-solid fa-users",
                    //    Badge = "اليوم",
                    //    Href = "/Residents",
                    //    Kpis = new List<OpsBoardKpi>
                    //    {
                    //        new OpsBoardKpi
                    //        {
                    //            Label="طلبات نقل/تبديل",
                    //            Value="19",
                    //            Unit="طلب",
                    //            Icon="fa-solid fa-right-left",
                    //            Hint="طلبات تحويل وحدات",
                    //            Delta="+4",
                    //            DeltaPositive=false,
                    //            Progress=48,
                    //            Href="/Residents/Transfers?range=today"
                    //        },
                    //        new OpsBoardKpi
                    //        {
                    //            Label="بلاغات الساكنين المفتوحة",
                    //            Value="62",
                    //            Unit="بلاغ",
                    //            Icon="fa-solid fa-headset",
                    //            Hint="طلبات خدمة قيد المعالجة",
                    //            Delta="-5",
                    //            DeltaPositive=true,
                    //            Progress=71,
                    //            Href="/Residents/Requests?status=open"
                    //        },
                    //        new OpsBoardKpi
                    //        {
                    //            Label="تحديث بيانات الهوية",
                    //            Value="33",
                    //            Unit="سجل",
                    //            Icon="fa-solid fa-id-card",
                    //            Hint="تحديث/توثيق اليوم",
                    //            Delta="+9.0%",
                    //            DeltaPositive=true,
                    //            Progress=66,
                    //            Href="/Residents/Verification?range=today"
                    //        },
                    //        new OpsBoardKpi
                    //        {
                    //            Label="مستفيدون جدد",
                    //            Value="11",
                    //            Unit="شخص",
                    //            Icon="fa-solid fa-user-plus",
                    //            Hint="تسجيلات جديدة",
                    //            Delta="+2",
                    //            DeltaPositive=true,
                    //            Progress=55,
                    //            Href="/Residents/New?range=today"
                    //        }
                    //    },
                    //    Events = new List<OpsBoardEvent>
                    //    {
                    //        new OpsBoardEvent
                    //        {
                    //            Title="طلب نقل - من حي الياسمين إلى النرجس",
                    //            Subtitle="بانتظار اعتماد الإسكان • رقم: TR-2209",
                    //            Icon="fa-solid fa-route",
                    //            Time="منذ 35 دقيقة",
                    //            Status="بانتظار اعتماد",
                    //            StatusTone="warning",
                    //            Priority="عادية",
                    //            PriorityTone="neutral",
                    //            Href="/Residents/Transfers/Details?id=TR-2209"
                    //        },
                    //        new OpsBoardEvent
                    //        {
                    //            Title="طلب خدمة - تحديث عقد",
                    //            Subtitle="تمت المراجعة الأولية",
                    //            Icon="fa-solid fa-file-signature",
                    //            Time="اليوم 10:05",
                    //            Status="قيد المراجعة",
                    //            StatusTone="info",
                    //            Priority="متوسطة",
                    //            PriorityTone="info",
                    //            Href="/Residents/Requests/Details?id=RQ-8801"
                    //        }
                    //    }
                    //}
                }
            };
        }

        /// <summary>
        /// ExecWatch: لوحة مراقبة المدراء
        /// </summary>
        public ChartCardConfig GetExecWatchChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.ExecWatch,
                Title = "لوحة مراقبة المدراء",
                Subtitle = "مراقبة الورش + سير الأعمال + إنذارات رقابية",
                Icon = "fa-solid fa-shield-halved",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                ExecWatchAnimate = true,
             
                ExecWatchStages = new List<ExecWatchStage>
                {
                    new ExecWatchStage { Label="استقبال الطلب",   Count=420, Percent=34, AvgHours=2.1m,  Overdue=12, Tone="info"     },
                    new ExecWatchStage { Label="فرز وتوجيه",      Count=310, Percent=25, AvgHours=3.7m,  Overdue=19, Tone="warning" },
                    new ExecWatchStage { Label="قيد التنفيذ",     Count=260, Percent=21, AvgHours=11.4m, Overdue=27, Tone="warning" },
                    new ExecWatchStage { Label="بانتظار قطع",     Count=95,  Percent=8,  AvgHours=22.6m, Overdue=31, Tone="danger" },
                    new ExecWatchStage { Label="إغلاق وتحقق",     Count=155, Percent=12, AvgHours=4.2m,  Overdue=6,  Tone="success" }
                },
                ExecWatchWorkshops = new List<ExecWatchWorkshop>
                {
                    new ExecWatchWorkshop
                    {
                        Name="ورشة الكهرباء",
                        Icon="fa-solid fa-bolt",
                        Capacity=18, Load=78, Productivity=84, Backlog=46, Delayed=9,
                        Tone="warning"
                        //,
                        //Href="/Workshops/Electrical"
                    },
                    new ExecWatchWorkshop
                    {
                        Name="ورشة السباكة",
                        Icon="fa-solid fa-faucet-drip",
                        Capacity=14, Load=64, Productivity=88, Backlog=31, Delayed=4,
                        Tone="info"
                    },
                    new ExecWatchWorkshop
                    {
                        Name="ورشة التكييف",
                        Icon="fa-solid fa-fan",
                        Capacity=16, Load=86, Productivity=72, Backlog=58, Delayed=15,
                        Tone="danger"
                    },
                    new ExecWatchWorkshop
                    {
                        Name="ورشة النجارة",
                        Icon="fa-solid fa-hammer",
                        Capacity=10, Load=52, Productivity=90, Backlog=19, Delayed=2,
                        Tone="success"
                    }
                },
                ExecWatchRisks = new List<ExecWatchRisk>
                {
                     new ExecWatchRisk
                    {
                        Title="تجاوز عدد الوحدات الجاهزة للتسكين الحد الطبيعي",
                        Desc="131 منزلا تجاوزت الحد خلال 48هذا الشهر",
                        Tone="danger",
                        Time="الشهر الحالي"
                    },
                    new ExecWatchRisk
                    {
                        Title="تجاوز انجاز في بلاغات التكييف",
                        Desc="15 بلاغًا تجاوزت الحد خلال 48 ساعة",
                        Tone="danger",
                        Time="آخر 6 ساعات"
                    },
                    new ExecWatchRisk
                    {
                        Title="تراكم أعمال ورشة الكهرباء",
                        Desc="انهاء الاعمال أعلى من المتوسط الأسبوعي",
                        Tone="warning",
                        Time="اليوم"
                    },
                     new ExecWatchRisk
                    {
                        Title="انجاز عالي بقسم الجودة والخدمات العامة",
                        Desc="انهاء الاعمال أعلى من المتوسط الأسبوعي",
                        Tone="success",
                        Time="اليوم"
                    },
                    new ExecWatchRisk
                    {
                        Title="نقص في مخزون قطع (صمامات)",
                        Desc="قد يسبب تعليق بلاغات السباكة",
                        Tone="info",
                        Time="هذا الأسبوع"
                    }
                },
                ExecWatchSlaLabel = "التزام العمل (كافة الطلبات)",
                ExecWatchSlaValue = "83",
                ExecWatchSlaUnit = "%",
                ExecWatchSlaHint = "نسبة الإغلاق ضمن الطلبات خلال 7 أيام",
                ExecWatchSlaTone = "warning"
                //,
                //ExecWatchSlaHref = "/Maintenance/Sla"
            };
        }


        //public ChartCardConfig GetExecWatchChart()
        //{
        //    return new ChartCardConfig
        //    {
        //        Type = ChartCardType.ExecWatch,
        //        Title = "لوحة مراقبة المدراء",
        //        Subtitle = "مراقبة الورش + سير الأعمال + إنذارات رقابية",
        //        Icon = "fa-solid fa-shield-halved",
        //        Tone = ChartTone.Info,
        //        ColCss = "6 md:12",
        //        Dir = "rtl",
        //        ExecWatchAnimate = true,
        //        ExecWatchKpis = new List<ExecWatchKpi>
        //        {
        //            new ExecWatchKpi
        //            {
        //                Label="طلبات مفتوحة",
        //                Value="1,240",
        //                Unit="طلب",
        //                Icon="fa-solid fa-folder-open",
        //                Hint="إجمالي الطلبات قيد المعالجة",
        //                Delta="+3.2%",
        //                DeltaPositive=false,
        //                Tone="warning",
        //                Href="/Requests?status=open"
        //            },
        //            new ExecWatchKpi
        //            {
        //                Label="معدل إنجاز اليوم",
        //                Value="86",
        //                Unit="%",
        //                Icon="fa-solid fa-gauge-high",
        //                Hint="مقارنة بالخطة اليومية",
        //                Delta="+1.1%",
        //                DeltaPositive=true,
        //                Tone="success",
        //                Href="/Management/DailyPerformance"
        //            },
        //            new ExecWatchKpi
        //            {
        //                Label="متوسط زمن الإغلاق",
        //                Value="18.4",
        //                Unit="ساعة",
        //                Icon="fa-solid fa-clock",
        //                Hint="متوسط آخر 7 أيام",
        //                Delta="-0.9",
        //                DeltaPositive=true,
        //                Tone="info",
        //                Href="/Management/CycleTime"
        //            },
        //            new ExecWatchKpi
        //            {
        //                Label="التكلفة التشغيلية",
        //                Value="2.4M",
        //                Unit="ر.س",
        //                Icon="fa-solid fa-sack-dollar",
        //                Hint="مصروفات صيانة وتشغيل",
        //                Delta="+6.0%",
        //                DeltaPositive=false,
        //                Tone="danger",
        //                Href="/Finance/Opex"
        //            }
        //        },
        //        ExecWatchStages = new List<ExecWatchStage>
        //        {
        //            new ExecWatchStage { Label="استقبال الطلب",   Count=420, Percent=34, AvgHours=2.1m,  Overdue=12, Tone="info",    Href="/Requests?stage=intake" },
        //            new ExecWatchStage { Label="فرز وتوجيه",      Count=310, Percent=25, AvgHours=3.7m,  Overdue=19, Tone="warning", Href="/Requests?stage=triage" },
        //            new ExecWatchStage { Label="قيد التنفيذ",     Count=260, Percent=21, AvgHours=11.4m, Overdue=27, Tone="warning", Href="/Requests?stage=in_progress" },
        //            new ExecWatchStage { Label="بانتظار قطع",     Count=95,  Percent=8,  AvgHours=22.6m, Overdue=31, Tone="danger",  Href="/Requests?stage=waiting_parts" },
        //            new ExecWatchStage { Label="إغلاق وتحقق",     Count=155, Percent=12, AvgHours=4.2m,  Overdue=6,  Tone="success", Href="/Requests?stage=qa_close" }
        //        },
        //        ExecWatchWorkshops = new List<ExecWatchWorkshop>
        //        {
        //            new ExecWatchWorkshop
        //            {
        //                Name="ورشة الكهرباء",
        //                Icon="fa-solid fa-bolt",
        //                Capacity=18, Load=78, Productivity=84, Backlog=46, Delayed=9,
        //                Tone="warning",
        //                Href="/Workshops/Electrical"
        //            },
        //            new ExecWatchWorkshop
        //            {
        //                Name="ورشة السباكة",
        //                Icon="fa-solid fa-faucet-drip",
        //                Capacity=14, Load=64, Productivity=88, Backlog=31, Delayed=4,
        //                Tone="info",
        //                Href="/Workshops/Plumbing"
        //            },
        //            new ExecWatchWorkshop
        //            {
        //                Name="ورشة التكييف",
        //                Icon="fa-solid fa-fan",
        //                Capacity=16, Load=86, Productivity=72, Backlog=58, Delayed=15,
        //                Tone="danger",
        //                Href="/Workshops/HVAC"
        //            },
        //            new ExecWatchWorkshop
        //            {
        //                Name="ورشة النجارة",
        //                Icon="fa-solid fa-hammer",
        //                Capacity=10, Load=52, Productivity=90, Backlog=19, Delayed=2,
        //                Tone="success",
        //                Href="/Workshops/Carpentry"
        //            }
        //        },
        //        ExecWatchRisks = new List<ExecWatchRisk>
        //        {
        //            new ExecWatchRisk
        //            {
        //                Title="تجاوز SLA في بلاغات التكييف",
        //                Desc="15 بلاغًا تجاوزت الحد خلال 48 ساعة",
        //                Tone="danger",
        //                Time="آخر 6 ساعات",
        //                Href="/Maintenance/Sla?category=hvac"
        //            },
        //            new ExecWatchRisk
        //            {
        //                Title="تراكم أعمال ورشة الكهرباء",
        //                Desc="Backlog أعلى من المتوسط الأسبوعي",
        //                Tone="warning",
        //                Time="اليوم",
        //                Href="/Workshops/Electrical?view=backlog"
        //            },
        //            new ExecWatchRisk
        //            {
        //                Title="نقص مخزون قطع (صمامات)",
        //                Desc="قد يسبب تعليق بلاغات السباكة",
        //                Tone="info",
        //                Time="هذا الأسبوع",
        //                Href="/Inventory?item=valves"
        //            }
        //        },
        //        ExecWatchSlaLabel = "التزام SLA (كافة الطلبات)",
        //        ExecWatchSlaValue = "83",
        //        ExecWatchSlaUnit = "%",
        //        ExecWatchSlaHint = "نسبة الإغلاق ضمن SLA خلال 7 أيام",
        //        ExecWatchSlaTone = "warning",
        //        ExecWatchSlaHref = "/Maintenance/Sla"
        //    };
        //}


        /// <summary>
        /// Donut: توزيع أنواع الوحدات
        /// </summary>
        public ChartCardConfig GetDonutChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Donut,
                Title = "توزيع أنواع الوحدات",
                Subtitle = "حسب نوع العقار",
                Icon = "fa-solid fa-chart-pie",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                DonutMode = "donut",
                DonutThickness = 0.30m,
                DonutShowLegend = true,
                DonutShowCenterText = true,
                DonutValueFormat = "0",
                Slices = new List<DonutSlice>
                {
                    new DonutSlice { Label = "شقق سكنية", Value = 4200 },
                    new DonutSlice { Label = "فلل",       Value = 1800 },
                    new DonutSlice { Label = "أراضي",     Value = 950  },
                    new DonutSlice { Label = "تجاري",     Value = 400  },
                    new DonutSlice { Label = "وقف",       Value = 120  }
                }
            };
        }

        /// <summary>
        /// Gauge: التزام الإسكان بزمن معالجة الطلبات
        /// </summary>
        public ChartCardConfig GetGaugeChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Gauge,
                Title = "التزام الإسكان بزمن معالجة الطلبات",
                Subtitle = "طلبات الإسكان خلال 48 ساعة",
                Icon = "fa-solid fa-file-signature",
                Tone = ChartTone.Info,
                ColCss = "6 md:3",
                Dir = "rtl",
                GaugeLabel = "طلبات ضمن 48 ساعة",
                GaugeMin = 0,
                GaugeMax = 100,
                GaugeValue = 87,
                GaugeUnit = "%",
                GaugeWarnFrom = 80,
                GaugeGoodFrom = 92,
                GaugeValueText = "87%",
                GaugeShowThresholds = true
            };
        }

        /// <summary>
        /// StatusStack: توزيع حالة الوحدات
        /// </summary>
        public ChartCardConfig GetStatusStackChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.StatusStack,
                Title = "توزيع حالة الوحدات",
                Subtitle = "شاغرة / مشغولة / صيانة / موقوفة",
                Icon = "fa-solid fa-house-signal",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                StatusStackValueFormat = "0",
                StatusStackShowLegend = true,
                StatusStackItems = new List<StatusStackItem>
                {
                    new StatusStackItem { Key="occupied",    Label="مشغولة",      Value=8450, Href="/Housing?status=occupied" },
                    new StatusStackItem { Key="vacant",      Label="شاغرة جاهزة", Value=2150, Href="/Housing?status=vacant" },
                    new StatusStackItem { Key="maintenance", Label="تحت صيانة",   Value=980,  Href="/Housing?status=maintenance" },
                    new StatusStackItem { Key="blocked",     Label="موقوفة",      Value=420,  Href="/Housing?status=blocked" }
                }
            };
        }

        /// <summary>
        /// Bullet: الأداء مقابل الأهداف
        /// </summary>
        public ChartCardConfig GetBulletChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Bullet,
                Title = "ملخص مؤشرات التشغيل الرئيسية",
                //Subtitle = "ملخص مؤشرات التشغيل الرئيسية",
                Icon = "fa-solid fa-bullseye",
                Tone = ChartTone.Info,
                ColCss = "12 md:12",
                Dir = "rtl",
                BulletValueFormat = "0",
                BulletShowLegend = false,
                Bullets = new List<BulletItem>
                {
                    new BulletItem { Key="sla_close",   Label="إغلاق البلاغات", Actual=82.22M, Target=98, Max=100, OkFrom=70, GoodFrom=90, Unit="%" },
                    new BulletItem { Key="occupancy",   Label="نسبة إشغال المساكن",           Actual=92, Target=95, Max=100, OkFrom=85, GoodFrom=95, Unit="%" },
                    new BulletItem { Key="readiness",   Label="جاهزية الوحدات",         Actual=88.12M, Target=90, Max=100, OkFrom=80, GoodFrom=90, Unit="%" },
                    new BulletItem { Key="inspections", Label="سرعة إنجاز صيانة المساكن بقسم الصيانة",   Actual=52.90M, Target=80, Max=100, OkFrom=60, GoodFrom=80, Unit="%"},
                    new BulletItem { Key="inspections", Label="تحصيل المطالبات المالية",   Actual=93.12M, Target=90, Max=100, OkFrom=85, GoodFrom=90, Unit="%"}
                }
            };
        }

        /// <summary>
        /// Funnel: سير بلاغات الصيانة
        /// </summary>
        public ChartCardConfig GetFunnelChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Funnel,
                Title = "سير بلاغات الصيانة",
                Subtitle = "مراحل معالجة البلاغات",
                Icon = "fa-solid fa-screwdriver-wrench",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                FunnelValueFormat = "0",
                FunnelShowPercent = true,
                FunnelShowDelta = true,
                FunnelClickable = true,
                FunnelStages = new List<FunnelStage>
                {
                    new FunnelStage { Key="new",         Label="جديد",         Value=420, Href="/Maintenance?status=new" },
                    new FunnelStage { Key="assigned",    Label="تم الإسناد",   Value=310, Href="/Maintenance?status=assigned" },
                    new FunnelStage { Key="in_progress", Label="قيد التنفيذ",  Value=260, Href="/Maintenance?status=in_progress" },
                    new FunnelStage { Key="waiting",     Label="بانتظار قطع",  Value=95,  Href="/Maintenance?status=waiting" },
                    new FunnelStage { Key="closed",      Label="مغلق",         Value=180, Href="/Maintenance?status=closed" }
                }
            };
        }

        /// <summary>
        /// Waterfall: جسر تغيّر الإشغال الشهري
        /// </summary>
        public ChartCardConfig GetWaterfallChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Waterfall,
                Title = "جسر تغيّر الإشغال الشهري",
                Subtitle = "تفصيل الزيادة/النقصان المؤثر على إشغال الوحدات (بداية ⇢ نهاية الشهر)",
                Icon = "fa-solid fa-bridge-water",
                Tone = ChartTone.Info,
                ColCss = "6 md:6",
                Dir = "rtl",
                WaterfallValueFormat = "0",
                WaterfallHeight = 320,
                WaterfallMinBarWidth = 92,
                WaterfallShowValues = true,
                WaterfallSteps = new List<WaterfallStep>
                {
                    new WaterfallStep { Key="start", Label="إشغال بداية الشهر", IsTotal=true, Value=8120, Href="/Housing/Occupancy?point=start" },
                    new WaterfallStep { Key="new_allocations",       Label="تخصيص وحدات جديدة",    Value=+640, Href="/Housing/Allocations?period=month" },
                    new WaterfallStep { Key="contract_renewals",     Label="تجديد عقود",           Value=+310, Href="/Housing/Renewals?period=month" },
                    new WaterfallStep { Key="back_from_maintenance", Label="عودة وحدات من الصيانة", Value=+220, Href="/Maintenance/Completed?period=month" },
                    new WaterfallStep { Key="vacated_units",        Label="إخلاءات",              Value=-520, Href="/Housing/Vacations?period=month" },
                    new WaterfallStep { Key="sent_to_maintenance",  Label="تحويل وحدات للصيانة",  Value=-190, Href="/Maintenance/Inbound?period=month" },
                    new WaterfallStep { Key="end", Label="إشغال نهاية الشهر", IsTotal=true, Value=8580, Href="/Housing/Occupancy?point=end" }
                }
            };
        }

     

        /// <summary>
        /// Line: اتجاه طلبات الإسكان
        /// </summary>
        public ChartCardConfig GetLineChart()
        {
            return new ChartCardConfig
            {
                Type = ChartCardType.Line,
                Title = "مؤشر استهلاك الكهرباء بالواط",
                Subtitle = "12 شهر لعام 2024",
                Icon = "fa-solid fa-chart-line",
                Tone = ChartTone.Info,
                ColCss = "12 md:6",
                Dir = "rtl",
                XLabels = new List<string>
                {
                    "يناير","فبراير","مارس","أبريل","مايو","يونيو",
                    "يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"
                },
                LineSeries = new List<ChartSeries>
                {
                    new ChartSeries
                    {
                        Name = "استهلاك الكهرباء بالواط",
                        Data = new List<decimal> { 2143934, 1431144, 1932805, 1976154, 1164592, 2118532, 1890508, 1844325, 1843039, 3558787, 1514691, 1439459 }
                    }
                },
                LineFillArea = true,
                LineShowGrid = true,
                LineShowDots = true,
                LineValueFormat = "0",
                LineMaxXTicks = 6
            };
        }

        #endregion

        #region Helper Methods

        /// <summary>
        /// الحصول على جميع Charts الافتراضية للـ Dashboard
        /// </summary>
        public List<ChartCardConfig> GetAllDashboardCharts()
        {
            _logger.LogInformation("Getting all dashboard charts");

            return new List<ChartCardConfig>
            {
                GetStatsGridChart(),
                GetOccupancyChart(),
                GetRadialRingsChart(),
                GetPie3DChart(),
                GetColumnProChart(),
                GetOpsBoardChart(),
                GetExecWatchChart(),
                GetDonutChart(),
                GetGaugeChart(),
                GetStatusStackChart(),
                GetBulletChart(),
                GetFunnelChart(),
                GetWaterfallChart(),
                
                GetLineChart()
            };
        }

        /// <summary>
        /// الحصول على Charts محددة حسب الأسماء
        /// </summary>
        /// <param name="chartNames">أسماء الـ Charts المطلوبة (مثل: "StatsGrid", "Pie3D")</param>
        public List<ChartCardConfig> GetChartsByNames(params string[] chartNames)
        {
            var charts = new List<ChartCardConfig>();

            foreach (var name in chartNames)
            {
                var chart = name.ToLower() switch
                {
                    "statsgrid" => GetStatsGridChart(),
                    "occupancy" => GetOccupancyChart(),
                    "radialrings" => GetRadialRingsChart(),
                    "pie3d" => GetPie3DChart(),
                    "columnpro" => GetColumnProChart(),
                    "opsboard" => GetOpsBoardChart(),
                    "execwatch" => GetExecWatchChart(),
                    "donut" => GetDonutChart(),
                    "gauge" => GetGaugeChart(),
                    "statusstack" => GetStatusStackChart(),
                    "bullet" => GetBulletChart(),
                    "funnel" => GetFunnelChart(),
                    "waterfall" => GetWaterfallChart(),
                    
                    "line" => GetLineChart(),
                    _ => null
                };

                if (chart != null)
                {
                    charts.Add(chart);
                }
                else
                {
                    _logger.LogWarning("Chart not found: {ChartName}", name);
                }
            }

            return charts;
        }

        /// <summary>
        /// الحصول على Chart من اسم Method
        /// </summary>
        /// <param name="methodName">اسم الـ Method مثل: "GetStatsGridChart"</param>
        public ChartCardConfig? GetChartByMethodName(string methodName)
        {
            if (string.IsNullOrWhiteSpace(methodName))
                return null;

            return methodName.Trim() switch
            {
                "GetStatsGridChart" => GetStatsGridChart(),
                "GetOccupancyChart" => GetOccupancyChart(),
                "GetRadialRingsChart" => GetRadialRingsChart(),
                "GetPie3DChart" => GetPie3DChart(),
                "GetColumnProChart" => GetColumnProChart(),
                "GetOpsBoardChart" => GetOpsBoardChart(),
                "GetExecWatchChart" => GetExecWatchChart(),
                "GetDonutChart" => GetDonutChart(),
                "GetGaugeChart" => GetGaugeChart(),
                "GetStatusStackChart" => GetStatusStackChart(),
                "GetBulletChart" => GetBulletChart(),
                "GetFunnelChart" => GetFunnelChart(),
                "GetWaterfallChart" => GetWaterfallChart(),
                
                "GetLineChart" => GetLineChart(),
                _ => null
            };
        }

        /// <summary>
        /// الحصول على Charts من قائمة أسماء Methods
        /// </summary>
        /// <param name="methodNames">قائمة أسماء الـ Methods</param>
        public List<ChartCardConfig> GetChartsByMethodNames(IEnumerable<string> methodNames)
        {
            var charts = new List<ChartCardConfig>();

            foreach (var methodName in methodNames)
            {
                var chart = GetChartByMethodName(methodName);
                if (chart != null)
                {
                    charts.Add(chart);
                }
                else
                {
                    _logger.LogWarning("Chart method not found: {MethodName}", methodName);
                }
            }

            return charts;
        }

        #endregion
    }
}