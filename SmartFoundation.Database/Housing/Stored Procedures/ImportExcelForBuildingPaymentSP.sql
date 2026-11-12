

CREATE   PROCEDURE [Housing].[ImportExcelForBuildingPaymentSP]
(
    @NationalIDs NVARCHAR(255) = NULL,
    @UnitNumbers NVARCHAR(255) = NULL,
    @GeneralNumbers NVARCHAR(255) = NULL,
    @Amounts NVARCHAR(255) = NULL,

    @BillChargeTypeID INT = NULL,  
    @IssueMonth NVARCHAR(255) = NULL,
    @IssueYear NVARCHAR(255) = NULL,
    @DeductListNo NVARCHAR(255) = NULL,
    @DeductListDate NVARCHAR(255) = NULL,
    @Notes NVARCHAR(255) = NULL,

    @IdaraId_FK NVARCHAR(255) = NULL,  
    @entryData NVARCHAR(255) = NULL,  
    @hostName NVARCHAR(255) = NULL,  
    @DeductListReportID BIGINT = NULL,

    @FileHash CHAR(64),
    @OriginalFileName NVARCHAR(260) = NULL,
    @Rows [Housing].[ImportExcelForBuildingPaymentRowType] READONLY
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedTran bit = 0;

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@FileHash)), N'') IS NULL
            THROW 50001, N'بصمة الملف غير موجودة.', 1;

            IF NULLIF(LTRIM(RTRIM(@BillChargeTypeID)), N'') IS NULL
            THROW 50001, N'الرجاء اختيار نوع المسير', 1;

        IF NOT EXISTS (SELECT 1 FROM @Rows)
            THROW 50001, N'لا توجد صفوف للإدخال.', 1;

        IF @DeductListReportID IS NOT NULL
           AND NOT EXISTS
           (
               SELECT 1 FROM Housing.DeductListReport reportRow
               WHERE reportRow.DeductListReportID=@DeductListReportID
                 AND reportRow.IdaraID_FK=TRY_CONVERT(BIGINT,@IdaraId_FK)
                 AND reportRow.ReportStatus=N'SENT'
                 AND reportRow.BillingType=CASE WHEN @BillChargeTypeID=1 THEN N'RENT' ELSE N'SERVICE' END
                 AND reportRow.PeriodMonth=TRY_CONVERT(INT,@IssueMonth)
                 AND reportRow.PeriodYear=TRY_CONVERT(INT,@IssueYear)
           )
            THROW 50001,N'المسير الصادر المحدد غير مرسل أو لا يطابق الإدارة والنوع والفترة.',1;

                /* فترة المسير: ميلادية أو هجرية، دون الاعتماد على تاريخ رفع الملف.
           المرجع الهجري هو جدول التقويم المعتمد dbo._GregorianHijriDate. */
        DECLARE @IssueMonthInt INT = TRY_CONVERT(INT, @IssueMonth);
        DECLARE @IssueYearInt INT = TRY_CONVERT(INT, @IssueYear);
        DECLARE @ImportIdaraID BIGINT = TRY_CONVERT(BIGINT, @IdaraId_FK);
        DECLARE @PeriodFrom DATE = NULL;
        DECLARE @PeriodTo DATE = NULL;

        IF @IssueMonthInt IS NULL OR @IssueMonthInt NOT BETWEEN 1 AND 12
           OR @IssueYearInt IS NULL
           OR @ImportIdaraID IS NULL OR @ImportIdaraID <= 0
            THROW 50001, N'شهر وسنة المسير وإدارة المستخدم مطلوبة وصحيحة.', 1;

        IF @IssueYearInt BETWEEN 1300 AND 1600
        BEGIN
            SELECT
                @PeriodFrom = MIN(CONVERT(DATE, g.gregorianDate)),
                @PeriodTo = MAX(CONVERT(DATE, g.gregorianDate))
            FROM dbo._GregorianHijriDate g
            WHERE g.yearH = @IssueYearInt
              AND g.monthH = @IssueMonthInt;
        END
        ELSE IF @IssueYearInt BETWEEN 1900 AND 9999
        BEGIN
            SET @PeriodFrom = DATEFROMPARTS(@IssueYearInt, @IssueMonthInt, 1);
            SET @PeriodTo = EOMONTH(@PeriodFrom);
        END
        ELSE
            THROW 50001, N'سنة المسير ليست سنة هجرية أو ميلادية مدعومة.', 1;

        IF @PeriodFrom IS NULL OR @PeriodTo IS NULL OR @PeriodFrom > @PeriodTo
            THROW 50001, N'تعذر تحديد أيام شهر المسير من التقويم المعتمد؛ لم يتم الاستيراد.', 1;

        IF @@TRANCOUNT = 0
        BEGIN
            SET @StartedTran = 1;
            BEGIN TRAN;
        END

        -- منع استيراد نفس الملف أكثر من مرة فقط
        IF EXISTS (SELECT 1 FROM [Housing].[UploadExcelImportLog] WHERE FileHash = @FileHash)
        BEGIN
            IF @StartedTran = 1 COMMIT;

            SELECT CAST(0 AS bit) AS IsSuccessful,
                   N'تم استيراد نفس الملف سابقاً، ولن يتم تكرار الإدخال.' AS Message_,
                   0 AS InsertedRows;
            RETURN;
        END



        DECLARE @BillChargeTypeName_AA NVARCHAR(100) =
(
    SELECT TOP (1) BillChargeTypeName_A
    FROM Housing.BillChargeType
    WHERE BillChargeTypeID = @BillChargeTypeID
);

DECLARE @DeductListName NVARCHAR(255) =
    CONCAT(
        N'مسير استقطاع ',
        ISNULL(@BillChargeTypeName_AA, N'غير محدد'),
        N' المساكن برقم ',
        @DeductListNo,
        N' وتاريخ ',
        CONVERT(NVARCHAR(10), TRY_CONVERT(date, @DeductListDate), 111),
        N' لشهر ',
        RIGHT(N'0' + CAST(@IssueMonth AS NVARCHAR(2)), 2),
        N' لعام ',
        @IssueYear,
        N' للإدارة ',
        ISNULL(
            (
                SELECT TOP (1) IdaraName
                FROM dbo.V_GetListIdara
                WHERE IdaraID = @IdaraId_FK
            ),
            N'غير محددة'
        )
    );




        INSERT INTO [DATACORE].[Housing].[DeductList]
        (
            [deductTypeID_FK],
            [DeductListStatusID_FK],
            [deductName],
            [amountTypeID_FK],
            [paymentTypeID_FK],
            [issueMonth],
            [issueYear],
            [paymentNo],
            [paymentDate],
            [description],
            [deductActive],
            [IdaraId_FK],
            [BillChargeTypeID_FK],
            [entryDate],
            [entryData],
            [hostName]
        )
        VALUES
        (
            1,
            2,
            @DeductListName,
            1,
            1,
            @IssueMonth,
            @IssueYear,
            @DeductListNo,
            @DeductListDate,
            @Notes,
            1,
            @IdaraId_FK,
            @BillChargeTypeID,
            GETDATE(),
            @entryData,
            @hostName
        );

        DECLARE @DeductRows int = @@ROWCOUNT;
        DECLARE @DedcutID bigint = TRY_CONVERT(bigint, SCOPE_IDENTITY());

        IF @DeductRows = 0 OR ISNULL(@DedcutID, 0) < 1
        BEGIN
            IF @StartedTran = 1 COMMIT;

            SELECT CAST(0 AS bit) AS IsSuccessful,
                   N'لم يتم إنشاء سجل الدفعة (DeductList).' AS Message_,
                   0 AS InsertedRows;
            RETURN;
        END

        -- =========================
        -- Clean rows into TEMP table (أفضل أداء من table variable)
        -- =========================
        IF OBJECT_ID('tempdb..#Clean') IS NOT NULL
            DROP TABLE #Clean;

        CREATE TABLE #Clean
        (
            RowNo        int           NOT NULL,
            IDNumber     nvarchar(255) NULL,
            unitID       nvarchar(255) NULL,
            generalNo_FK nvarchar(255) NULL,
            amount       decimal(10,2) NULL,
            amountRaw    nvarchar(255) NULL
        );

        INSERT INTO #Clean (RowNo, IDNumber, unitID, generalNo_FK, amount, amountRaw)
        SELECT
            r.RowNo,
            NULLIF(LTRIM(RTRIM(r.IDNumber)), N''),
            NULLIF(LTRIM(RTRIM(r.unitID)), N''),
            NULLIF(LTRIM(RTRIM(r.generalNo_FK)), N''),
            TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(r.amount)), N'')),
            NULLIF(LTRIM(RTRIM(r.amount)), N'')
        FROM @Rows r
        WHERE NOT
        (
            NULLIF(LTRIM(RTRIM(ISNULL(r.IDNumber,N''))), N'') IS NULL AND
            NULLIF(LTRIM(RTRIM(ISNULL(r.unitID,N''))), N'') IS NULL AND
            NULLIF(LTRIM(RTRIM(ISNULL(r.generalNo_FK,N''))), N'') IS NULL AND
            NULLIF(LTRIM(RTRIM(ISNULL(r.amount,N''))), N'') IS NULL
        );

        -- فهرس لتسريع الربط
        CREATE INDEX IX_Clean_generalNo ON #Clean(generalNo_FK);

        -- ❌ تحقق سريع جدًا: أول مبلغ غير صالح فقط
        IF EXISTS (SELECT 1 FROM #Clean WHERE amountRaw IS NOT NULL AND amount IS NULL)
        BEGIN
            DECLARE @BadRowNo int;
            DECLARE @BadValue nvarchar(255);

            SELECT TOP (1)
                @BadRowNo = RowNo,
                @BadValue = amountRaw
            FROM #Clean
            WHERE amountRaw IS NOT NULL AND amount IS NULL
            ORDER BY RowNo;

            DECLARE @Msg nvarchar(4000) =
                N'يوجد مبلغ غير صالح لا يمكن تحويله إلى رقم (decimal(10,2)). ' +
                N'أول خطأ عند الصف: ' + CAST(@BadRowNo AS nvarchar(20)) +
                N'، القيمة: ' + ISNULL(@BadValue, N'');

            THROW 50001, @Msg, 1;
        END

                -- ربط كل صف Excel بالسداد الذي أُنشئ له، حتى عند تكرار البيانات
        CREATE TABLE #ImportedRows
        (
            RowNo INT NOT NULL PRIMARY KEY,
            ExcelPaymentID BIGINT NOT NULL UNIQUE
        );

               /* تحديد الهوية الوطنية فقط؛ لا نستخدم الرقم العام لتعيين المستفيد.
           ثم فحص وجود ملف أساسي نشط وتفاصيل حالية نشطة،
           ثم فحص تاريخ التبعية للإدارة خلال أي يوم من شهر المسير. */
        CREATE TABLE #ExcelIdentity
        (
            IDNumber NVARCHAR(255) NOT NULL PRIMARY KEY,
            ResidentID BIGINT NULL,
            MatchCount BIGINT NOT NULL,
            ResidentActive BIT NOT NULL,
            HasActiveDetails BIT NOT NULL,
            InIdaraDuringPeriod BIT NOT NULL
        );

        ;WITH IdentityMatches AS
        (
            SELECT
                ids.IDNumber,
                CASE WHEN COUNT_BIG(ri.residentInfoID) = 1
                     THEN MIN(ri.residentInfoID)
                     ELSE NULL END AS ResidentID,
                COUNT_BIG(ri.residentInfoID) AS MatchCount
            FROM (SELECT DISTINCT IDNumber FROM #Clean WHERE IDNumber IS NOT NULL) ids
            LEFT JOIN Housing.ResidentInfo ri
                ON NULLIF(LTRIM(RTRIM(ri.NationalID)), N'') = ids.IDNumber
            GROUP BY ids.IDNumber
        )
        INSERT INTO #ExcelIdentity
            (IDNumber, ResidentID, MatchCount,
             ResidentActive, HasActiveDetails, InIdaraDuringPeriod)
        SELECT
            m.IDNumber,
            m.ResidentID,
            m.MatchCount,
            CONVERT(BIT, CASE WHEN ri.residentInfoActive = 1 THEN 1 ELSE 0 END),
            CONVERT(BIT, CASE WHEN EXISTS
            (
                SELECT 1 FROM Housing.ResidentDetails rd
                WHERE rd.residentInfoID_FK = m.ResidentID
                  AND rd.residentDetailsActive = 1
            ) THEN 1 ELSE 0 END),
            CONVERT(BIT, CASE WHEN EXISTS
            (
                SELECT 1 FROM Housing.ResidentDetails rd
                WHERE rd.residentInfoID_FK = m.ResidentID
                  AND rd.IdaraId_FK = @ImportIdaraID
                  AND rd.residentDetailsStartDate IS NOT NULL
                  AND CONVERT(DATE, rd.residentDetailsStartDate) <= @PeriodTo
                  AND (
                        rd.residentDetailsEndDate >= @PeriodFrom
                        OR (rd.residentDetailsEndDate IS NULL
                            AND rd.residentDetailsActive = 1)
                      )
            ) THEN 1 ELSE 0 END)
        FROM IdentityMatches m
        LEFT JOIN Housing.ResidentInfo ri ON ri.residentInfoID = m.ResidentID;

        /* سبب واحد حصري لكل صف، لتكون إحصاءات النجاح دقيقة. */
        CREATE TABLE #ExcelEligibility
        (
            RowNo INT NOT NULL PRIMARY KEY,
            ResidentID BIGINT NULL,
            ReasonCode NVARCHAR(40) NOT NULL
        );

        INSERT INTO #ExcelEligibility (RowNo, ResidentID, ReasonCode)
        SELECT
            c.RowNo,
            im.ResidentID,
            CASE
                WHEN c.IDNumber IS NULL THEN N'MISSING_IDENTITY'
                WHEN ISNULL(im.MatchCount, 0) = 0 THEN N'IDENTITY_NOT_FOUND'
                WHEN im.MatchCount > 1 THEN N'IDENTITY_DUPLICATE'
                WHEN im.ResidentActive = 0 THEN N'RESIDENT_INACTIVE'
                WHEN im.HasActiveDetails = 0 THEN N'NO_ACTIVE_DETAILS'
                WHEN im.InIdaraDuringPeriod = 0 THEN N'OUTSIDE_IDARA_PERIOD'
                ELSE N'ELIGIBLE'
            END
        FROM #Clean c
        LEFT JOIN #ExcelIdentity im ON im.IDNumber = c.IDNumber;



        MERGE INTO [DATACORE].[Housing].[BuildingPayment] AS target
        USING
(
    SELECT
        c.RowNo,
        c.generalNo_FK,
        c.IDNumber,
        c.unitID,
        c.amount,

                e.ResidentID AS residentInfoID,
        CASE WHEN e.ReasonCode = N'ELIGIBLE' THEN 1 ELSE 0 END AS IsEligible

    FROM #Clean AS c
    JOIN #ExcelEligibility e
        ON e.RowNo = c.RowNo

) AS source
        ON 1 = 0

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                buildingPaymentTypeID_FK,
                generalNo_FK,
                IDNumber,
                residentInfoID_FK,
                unitID,
                buildingDetailsID_FK,
                amount,
                deductListID_FK,
                buildingPayementActive,
                BillChargeTypeID_FK,
                IdaraId_FK,
                entryDate,
                entryData,
                hostname
            )
            VALUES
            (
                1,
                source.generalNo_FK,
                source.IDNumber,
                source.residentInfoID,
                source.unitID,
                NULL,
                source.amount,
                @DedcutID,
                source.IsEligible,
                @BillChargeTypeID,
                @IdaraId_FK,
                GETDATE(),
                @entryData,
                @hostName
            )

        OUTPUT
            source.RowNo,
            inserted.paymentID
        INTO #ImportedRows (RowNo, ExcelPaymentID);

        DECLARE @Inserted INT;

        SELECT @Inserted = COUNT(*)
        FROM #ImportedRows;

        IF @Inserted <> (SELECT COUNT(*) FROM #Clean)
            THROW 50001,
                N'تعذر إدخال صف واحد مقابل كل صف في ملف Excel. تم التراجع عن العملية.',
                1;

        -- إنشاء سجل تتبع مستقل لكل حركة Excel
        INSERT INTO Housing.BuildingPaymentExcelImportDetail
        (
            DeductListID_FK,
            ExcelRowNo,
            ExcelPaymentID_FK,
            ReplacedManualPaymentID_FK,
            MatchStatus,
            MatchNote,
            entryData
        )
        SELECT
            @DedcutID,
            ir.RowNo,
            ir.ExcelPaymentID,
            NULL,
        
                        CASE WHEN e.ReasonCode = N'ELIGIBLE'
                 THEN N'IMPORTED' ELSE N'PROTECTED' END,
            CASE e.ReasonCode
                WHEN N'MISSING_IDENTITY'
                    THEN N'تم تعطيل الحسم لعدم إدخال الهوية الوطنية في Excel؛ حُفظ الصف دون احتساب مالي.'
                WHEN N'IDENTITY_NOT_FOUND'
                    THEN N'تم تعطيل الحسم لعدم وجود ملف مستفيد مطابق للهوية الوطنية في النظام.'
                WHEN N'IDENTITY_DUPLICATE'
                    THEN N'تم تعطيل الحسم لتكرار الهوية الوطنية بين أكثر من ملف مستفيد؛ لم تُنسب الحركة إلى ملف تخميني.'
                WHEN N'RESIDENT_INACTIVE'
                    THEN N'تم تعطيل الحسم لأن ملف المستفيد الأساسي غير نشط في النظام.'
                WHEN N'NO_ACTIVE_DETAILS'
                    THEN N'تم تعطيل الحسم لعدم وجود سجل تفاصيل نشط للمستفيد في النظام.'
                WHEN N'OUTSIDE_IDARA_PERIOD'
                    THEN CONCAT(N'تم تعطيل الحسم لعدم ثبوت تبعية المستفيد للإدارة رقم ',
                                @ImportIdaraID, N' خلال شهر ', @IssueMonthInt,
                                N' لسنة ', @IssueYearInt, N'.')
                ELSE N'تم التحقق من هوية المستفيد ونشاط ملفه وتبعيته لإدارة المسير خلال شهر الحسم.'
            END,
            LEFT(@entryData, 200)
        FROM #ImportedRows ir
        JOIN #ExcelEligibility e ON e.RowNo = ir.RowNo;

        IF @@ROWCOUNT <> @Inserted
            THROW 50001,
                N'تعذر تسجيل تتبع جميع صفوف Excel. تم التراجع عن العملية.',
                1;


        EXEC Housing.usp_ClassifyAndLinkBuildingPayments
             @DeductListID = @DedcutID,
             @ApplyChanges = 1,
             @ShowDetails = 0,
             @ReturnResults = 0,
             @ChangedBy = @entryData;


                            /* ============================================================
           Excel vs Manual Salary Deductions
           كل صف Excel محفوظ مسبقاً.
           المطابقة 1:1؛ اليدوي يبقى نشطاً وExcel المطابق يُعطل.
           لا يتم نقل أي تسوية أو إعفاء أو استرداد.
           ============================================================ */

        -- صفوف Excel المؤهلة للمطابقة
        SELECT
            ir.ExcelPaymentID,
            ir.RowNo AS ExcelRowNo,
            xp.residentInfoID_FK AS ResidentID,
            xp.IdaraId_FK AS IdaraID,
            xp.BillChargeTypeID_FK AS ServiceID,
            xp.amount AS Amount,
            xp.buildingPaymentLinkStatusID_FK AS LinkStatusID,
            CASE
                WHEN xp.buildingPaymentLinkStatusID_FK = 1
                THEN TRY_CONVERT(
                    BIGINT,
                    NULLIF(LTRIM(RTRIM(xp.buildingDetailsID_FK)), N'')
                )
            END AS BuildingID
        INTO #MatchExcel
        FROM #ImportedRows ir
        JOIN Housing.BuildingPayment xp
            ON xp.paymentID = ir.ExcelPaymentID
        JOIN Housing.ResidentInfo ri
            ON ri.residentInfoID = xp.residentInfoID_FK
           AND NULLIF(LTRIM(RTRIM(ri.NationalID)), N'')
               = NULLIF(LTRIM(RTRIM(xp.IDNumber)), N'')
        WHERE xp.buildingPayementActive = 1
          AND xp.buildingPaymentTypeID_FK = 1
          AND xp.buildingPaymentLinkStatusID_FK IN (1, 2)
          AND xp.amount > 0
          AND
          (
              xp.buildingPaymentLinkStatusID_FK = 2
              OR TRY_CONVERT(
                  BIGINT,
                  NULLIF(LTRIM(RTRIM(xp.buildingDetailsID_FK)), N'')
              ) > 0
          );

        -- السدادات اليدوية المطابقة المؤهلة
        SELECT DISTINCT
            mp.paymentID AS ManualPaymentID,
            mp.residentInfoID_FK AS ResidentID,
            mp.IdaraId_FK AS IdaraID,
            mp.BillChargeTypeID_FK AS ServiceID,
            mp.amount AS Amount,
            mp.buildingPaymentLinkStatusID_FK AS LinkStatusID,
            CASE
                WHEN mp.buildingPaymentLinkStatusID_FK = 1
                THEN TRY_CONVERT(
                    BIGINT,
                    NULLIF(LTRIM(RTRIM(mp.buildingDetailsID_FK)), N'')
                )
            END AS BuildingID
        INTO #MatchManual
        FROM Housing.BuildingPayment mp WITH (UPDLOCK, HOLDLOCK)
        JOIN Housing.DeductList md
            ON md.deductListID = mp.deductListID_FK
        JOIN Housing.ResidentInfo ri
            ON ri.residentInfoID = mp.residentInfoID_FK
        JOIN #MatchExcel xe
            ON xe.ResidentID = mp.residentInfoID_FK
           AND xe.IdaraID = mp.IdaraId_FK
           AND xe.ServiceID = mp.BillChargeTypeID_FK
           AND xe.Amount = mp.amount
           AND xe.LinkStatusID = mp.buildingPaymentLinkStatusID_FK
           AND ISNULL(xe.BuildingID, -1) =
               ISNULL(
                   CASE
                       WHEN mp.buildingPaymentLinkStatusID_FK = 1
                       THEN TRY_CONVERT(
                           BIGINT,
                           NULLIF(
                               LTRIM(RTRIM(mp.buildingDetailsID_FK)),
                               N''
                           )
                       )
                   END, -1
               )
        WHERE mp.buildingPaymentTypeID_FK = 1
          AND mp.buildingPayementActive = 1
          AND mp.buildingPaymentLinkStatusID_FK IN (1, 2)
          AND md.paymentTypeID_FK = 1
          AND md.deductActive = 1
          AND md.issueMonth = TRY_CONVERT(INT, @IssueMonth)
          AND md.issueYear = TRY_CONVERT(INT, @IssueYear)
          AND md.IdaraId_FK = TRY_CONVERT(BIGINT, @IdaraId_FK)
          AND md.BillChargeTypeID_FK = @BillChargeTypeID
          AND
          (
              NULLIF(LTRIM(RTRIM(mp.IDNumber)), N'') IS NULL
              OR LTRIM(RTRIM(mp.IDNumber))
                 = LTRIM(RTRIM(ri.NationalID))
          )
          -- يجب إثبات أن السداد أُنشئ يدوياً
          AND EXISTS
          (
              SELECT 1
              FROM dbo.AuditLog a
              WHERE a.TableName = N'[Housing].[BuildingPayment]'
                AND a.RecordID = mp.paymentID
                AND a.ActionType IN
                (
                    N'PAYMENTANDREFUNDFORUSER',
                    N'PAYMENTANDREFUNDFOREXTENDANDEXIT'
                )
          )
          -- لا نستخدم سداداً يدوياً سبق أن غطى Excel آخر
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.BuildingPaymentExcelImportDetail t
              WHERE t.MatchedManualPaymentID_FK = mp.paymentID
                 OR t.ReplacedManualPaymentID_FK = mp.paymentID
          )
          -- عدم اعتبار استيراد سابق سداداً يدوياً
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.UploadExcelImportLog il
              WHERE il.DeductListID_FK = mp.deductListID_FK
          );

        -- ترتيب مستقل للحسومات المتطابقة من الطرفين
        CREATE TABLE #MatchedPairs
        (
            ExcelPaymentID BIGINT NOT NULL PRIMARY KEY,
            ManualPaymentID BIGINT NOT NULL UNIQUE,
            ExcelRowNo INT NOT NULL
        );

        ;WITH ExcelRanked AS
        (
            SELECT *,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        ResidentID, IdaraID, ServiceID,
                        Amount, LinkStatusID, BuildingID
                    ORDER BY ExcelRowNo, ExcelPaymentID
                ) AS MatchNumber
            FROM #MatchExcel
        ),
        ManualRanked AS
        (
            SELECT *,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        ResidentID, IdaraID, ServiceID,
                        Amount, LinkStatusID, BuildingID
                    ORDER BY ManualPaymentID
                ) AS MatchNumber
            FROM #MatchManual
        )
        INSERT INTO #MatchedPairs
        (
            ExcelPaymentID,
            ManualPaymentID,
            ExcelRowNo
        )
        SELECT
            e.ExcelPaymentID,
            m.ManualPaymentID,
            e.ExcelRowNo
        FROM ExcelRanked e
        JOIN ManualRanked m
            ON m.ResidentID = e.ResidentID
           AND m.IdaraID = e.IdaraID
           AND m.ServiceID = e.ServiceID
           AND m.Amount = e.Amount
           AND m.LinkStatusID = e.LinkStatusID
           AND ISNULL(m.BuildingID, -1) =
               ISNULL(e.BuildingID, -1)
           AND m.MatchNumber = e.MatchNumber;

        DECLARE @CoveredCount INT =
        (
            SELECT COUNT(*) FROM #MatchedPairs
        );

        -- تعطيل سداد Excel المطابق فقط
        UPDATE xp
        SET buildingPayementActive = 0
        FROM Housing.BuildingPayment xp
        JOIN #MatchedPairs m
            ON m.ExcelPaymentID = xp.paymentID
        WHERE xp.buildingPayementActive = 1;

        IF @@ROWCOUNT <> @CoveredCount
            THROW 50001,
                N'تعذر تعطيل جميع حسومات Excel المطابقة. تم التراجع.',
                1;

        -- تسجيل العلاقة الدائمة بين Excel واليدوي
        UPDATE t
        SET
            MatchedManualPaymentID_FK = m.ManualPaymentID,
            MatchStatus = N'COVERED_BY_MANUAL',
            MatchNote = CONCAT(
                N'حسم Excel مغطى بسداد يدوي نشط رقم ',
                m.ManualPaymentID,
                N'؛ تم تعطيل حسم Excel لمنع الاحتساب المزدوج.'
            )
        FROM Housing.BuildingPaymentExcelImportDetail t
        JOIN #MatchedPairs m
            ON m.ExcelPaymentID = t.ExcelPaymentID_FK
        WHERE t.DeductListID_FK = @DedcutID;

        IF @@ROWCOUNT <> @CoveredCount
            THROW 50001,
                N'تعذر حفظ ارتباطات مطابقة Excel بالسدادات اليدوية.',
                1;

        -- تسجيل التدقيق: السداد اليدوي لا يتغير
        INSERT INTO dbo.AuditLog
        (
            TableName,
            ActionType,
            RecordID,
            PerformedBy,
            Notes,
            PerformedAt
        )
        SELECT
            N'[Housing].[BuildingPayment]',
            N'EXCEL_COVERED_BY_MANUAL',
            m.ExcelPaymentID,
            @entryData,
            CONCAT(
                N'{"ExcelPaymentID":', m.ExcelPaymentID,
                N',"ManualPaymentID":', m.ManualPaymentID,
                N',"DeductListID":', @DedcutID,
                N',"ExcelRowNo":', m.ExcelRowNo,
                N'}'
            ),
            GETDATE()
        FROM #MatchedPairs m;

        IF @@ROWCOUNT <> @CoveredCount
            THROW 50001,
                N'تعذر تسجيل تدقيق مطابقات Excel.',
                1;

        INSERT INTO [Housing].[UploadExcelImportLog]
        (
            FileHash,
            OriginalFileName,
            InsertedRows,
            DeductListID_FK
        )
        VALUES
        (
            @FileHash,
            @OriginalFileName,
            @Inserted,
            @DedcutID
        );

        IF @DeductListReportID IS NOT NULL
        BEGIN
            INSERT Housing.DeductListReportImport
            (DeductListReportID_FK,DeductListID_FK,ImportedAmount,ImportedRows,entryData,hostName)
            SELECT @DeductListReportID,@DedcutID,ISNULL(SUM(amount),0),COUNT(*),@entryData,@hostName
            FROM Housing.BuildingPayment
            WHERE deductListID_FK=@DedcutID;
        END

                /* إحصاءات نهائية من السجلات المرفوعة، بعد التصنيف والمطابقة اليدوية. */
        DECLARE @NoActiveResidentRows INT = 0,
                @OutsideIdaraRows INT = 0,
                @ManualCoveredRows INT = @CoveredCount,
                @ActiveExcelRows INT = 0,
                @DisabledExcelRows INT = 0,
                @OtherDisabledRows INT = 0;

        SELECT
            @NoActiveResidentRows = COUNT(CASE WHEN e.ReasonCode IN
            (
                N'MISSING_IDENTITY', N'IDENTITY_NOT_FOUND',
                N'IDENTITY_DUPLICATE', N'RESIDENT_INACTIVE', N'NO_ACTIVE_DETAILS'
            ) THEN 1 END),
            @OutsideIdaraRows = COUNT(CASE
                WHEN e.ReasonCode = N'OUTSIDE_IDARA_PERIOD' THEN 1 END)
        FROM #ExcelEligibility e;

        SELECT @ActiveExcelRows = COUNT(*)
        FROM #ImportedRows ir
        JOIN Housing.BuildingPayment bp ON bp.paymentID = ir.ExcelPaymentID
        WHERE bp.buildingPayementActive = 1;

        SET @DisabledExcelRows = @Inserted - @ActiveExcelRows;
        SET @OtherDisabledRows = @DisabledExcelRows
                               - @NoActiveResidentRows
                               - @OutsideIdaraRows
                               - @ManualCoveredRows;

        IF @OtherDisabledRows < 0
            THROW 50001, N'تعارض في أعداد أسباب تعطيل حسومات Excel؛ تم التراجع.', 1;

        IF @StartedTran = 1 COMMIT;

        SELECT CAST(1 AS bit) AS IsSuccessful,
               CONCAT(
                   N'تم رفع ', @Inserted, N' صف بنجاح. ',
                   N'المعطّل لعدم وجود ملف مستفيد نشط مطابق للبيانات: ', @NoActiveResidentRows, N' صف. ',
                   N'المعطّل لعدم ثبوت تبعية المستفيد لإدارة المسير خلال شهر الحسم: ', @OutsideIdaraRows, N' صف. ',
                   N'المعطّل لوجود سداد يدوي مطابق: ', @ManualCoveredRows, N' صف. ',
                   N'إجمالي المعطّل: ', @DisabledExcelRows, N' صف. ',
                   N'المتبقي نشطًا: ', @ActiveExcelRows, N' صف.',
                   CASE WHEN @OtherDisabledRows > 0
                        THEN CONCAT(N' تعطيل لأسباب أخرى: ', @OtherDisabledRows, N' صف.')
                        ELSE N'' END
               ) AS Message_,
               @Inserted AS InsertedRows,
               @NoActiveResidentRows AS NoActiveResidentRows,
               @OutsideIdaraRows AS OutsideIdaraRows,
               @ManualCoveredRows AS CoveredByManualRows,
               @DisabledExcelRows AS DisabledRows,
               @ActiveExcelRows AS ActiveRows,
               @OtherDisabledRows AS OtherDisabledRows;
    END TRY
    BEGIN CATCH
        IF @StartedTran = 1 AND @@TRANCOUNT > 0 ROLLBACK;
        ;THROW;
    END CATCH
END