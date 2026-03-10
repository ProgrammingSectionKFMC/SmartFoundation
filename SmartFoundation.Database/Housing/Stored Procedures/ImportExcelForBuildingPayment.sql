
CREATE PROCEDURE [Housing].[ImportExcelForBuildingPayment]
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



        DECLARE @DeductListName NVARCHAR(255) =
    CONCAT(
        N'مسير استقطاع ايجار المساكن برقم ',
        @DeductListNo,
        N' وتاريخ ',
        CONVERT(NVARCHAR(10), @DeductListDate, 111),
        N' لشهر ',
        RIGHT(N'0' + CAST(@IssueMonth AS NVARCHAR(2)), 2),
        N' لعام ',
        @IssueYear,
        N' للإدارة ',
        ISNULL(
            (SELECT TOP (1) a.IdaraName
             FROM dbo.V_GetListIdara a
             WHERE IdaraID = @IdaraId_FK),
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

        INSERT INTO [DATACORE].[Housing].[BuildingPayment]
        (
            [buildingPaymentTypeID_FK],
            [generalNo_FK],
            [IDNumber],
            [residentInfoID_FK],
            [unitID],
            [buildingDetailsID_FK],
            [amount],
            [deductListID_FK],
            [buildingPayementActive],
            [BillChargeTypeID_FK],
            [IdaraId_FK],
            [entryDate],
            [entryData],
            [hostname]
        )
        SELECT
            1,
            c.generalNo_FK,
            c.IDNumber,
            r.residentInfoID,
            c.unitID,
            CASE
                WHEN oc.cnt > 1 THEN NULL
                ELSE o.buildingDetailsID
            END,
            c.amount,
            @DedcutID,
            1,
            @BillChargeTypeID,
            @IdaraId_FK,
            GETDATE(),
            @entryData,
            @hostName
        FROM #Clean AS c
        LEFT JOIN Housing.V_GetFullResidentDetails r
            ON c.generalNo_FK = r.generalNo_FK
        LEFT JOIN Housing.V_Occupant o
            ON o.residentInfoID = r.residentInfoID
            LEFT JOIN (
                        SELECT
                            residentInfoID,
                            COUNT(*) AS cnt
                        FROM Housing.V_Occupant
                        GROUP BY residentInfoID
                    ) oc
                        ON oc.residentInfoID = r.residentInfoID;

        DECLARE @Inserted int = @@ROWCOUNT;

        INSERT INTO [Housing].[UploadExcelImportLog] (FileHash, OriginalFileName, InsertedRows)
        VALUES (@FileHash, @OriginalFileName, @Inserted);

        IF @StartedTran = 1 COMMIT;

        SELECT CAST(1 AS bit) AS IsSuccessful,
               CONCAT(N'تم إدخال ', @Inserted, N' صف بنجاح.') AS Message_,
               @Inserted AS InsertedRows;
    END TRY
    BEGIN CATCH
        IF @StartedTran = 1 AND @@TRANCOUNT > 0 ROLLBACK;
        ;THROW;
    END CATCH
END
