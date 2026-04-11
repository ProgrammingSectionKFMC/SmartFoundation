
/* =========================================================
   Description:
   إضافة/تعديل سجل في جدول VIC.TypesRoot (الأنواع)، مع التحقق من:
   - الاسم العربي إلزامي
   - صحة نطاق التواريخ (EndDate >= StartDate)
   - منع ربط العنصر بنفسه كأب
   ويقوم بتعبئة حقول التدقيق entryDate/entryData/hostName.
   Type: WRITE (UPSERT)
========================================================= */

CREATE   PROCEDURE [VIC].[TypesRoot_Upsert_SP]
(
      @typesID            INT = NULL
    , @typesName_A        NVARCHAR(200)
    , @typesName_E        NVARCHAR(200) = NULL
    , @typesDesc          NVARCHAR(600) = NULL
    , @typesActive        BIT = 1
    , @typesStartDate     DATETIME = NULL
    , @typesEndDate       DATETIME = NULL
    , @typesRoot_ParentID INT = NULL
    , @entryData          NVARCHAR(100)
    , @hostName           NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @NameA_Trim NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@typesName_A)), N'');
    DECLARE @NameE_Trim NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@typesName_E)), N'');
    DECLARE @Desc_Trim  NVARCHAR(600) = NULLIF(LTRIM(RTRIM(@typesDesc)), N'');

    DECLARE @SD DATETIME = ISNULL(@typesStartDate, GETDATE());
    DECLARE @ED DATETIME = @typesEndDate;

    DECLARE @IsInsert BIT = CASE WHEN @typesID IS NULL THEN 1 ELSE 0 END;

    -- AuditLog
    DECLARE @ActionType NVARCHAR(20);
    DECLARE @Note_Audit NVARCHAR(MAX);

    BEGIN TRY

        IF @tc = 0
            BEGIN TRAN;

        IF @NameA_Trim IS NULL
            THROW 50001, N'الاسم العربي مطلوب', 1;

        IF (@ED IS NOT NULL AND @ED < @SD)
            THROW 50001, N'لا يمكن أن يكون تاريخ النهاية أقل من تاريخ البداية', 1;

        IF (@typesID IS NOT NULL AND @typesRoot_ParentID IS NOT NULL AND @typesRoot_ParentID = @typesID)
            THROW 50001, N'لا يمكن ربط العنصر بنفسه كأب', 1;

        IF @IsInsert = 1
        BEGIN
            INSERT INTO VIC.TypesRoot
            (
                  typesName_A
                , typesName_E
                , typesDesc
                , typesActive
                , typesStartDate
                , typesEndDate
                , typesRoot_ParentID
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @NameA_Trim
                , @NameE_Trim
                , @Desc_Trim
                , @typesActive
                , @SD
                , @ED
                , @typesRoot_ParentID
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @typesID = CONVERT(INT, SCOPE_IDENTITY());
            IF @typesID IS NULL OR @typesID <= 0
                THROW 50002, N'فشل إضافة النوع', 1;

            -- AuditLog (INSERT)
            SET @ActionType = N'INSERT';

            SET @Note_Audit = N'{'
                + N'"typesID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @typesID), '') + N'"'
                + N',"typesName_A":"' + ISNULL(@NameA_Trim, '') + N'"'
                + N',"typesName_E":"' + ISNULL(@NameE_Trim, '') + N'"'
                + N',"typesDesc":"' + ISNULL(@Desc_Trim, '') + N'"'
                + N',"typesActive":"' + ISNULL(CONVERT(NVARCHAR(10), @typesActive), '') + N'"'
                + N',"typesStartDate":"' + ISNULL(CONVERT(NVARCHAR(30), @SD, 121), '') + N'"'
                + N',"typesEndDate":"' + ISNULL(CONVERT(NVARCHAR(30), @ED, 121), '') + N'"'
                + N',"typesRoot_ParentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @typesRoot_ParentID), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[TypesRoot]'
                , @ActionType
                , @typesID
                , @entryData
                , @Note_Audit
            );
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM VIC.TypesRoot WHERE typesID = @typesID)
                THROW 50001, N'السجل غير موجود للتعديل', 1;

            UPDATE VIC.TypesRoot
            SET
                  typesName_A        = @NameA_Trim
                , typesName_E        = @NameE_Trim
                , typesDesc          = @Desc_Trim
                , typesActive        = @typesActive
                , typesStartDate     = @SD
                , typesEndDate       = @ED
                , typesRoot_ParentID = @typesRoot_ParentID
                , entryDate          = GETDATE()
                , entryData          = @entryData
                , hostName           = @hostName
            WHERE typesID = @typesID;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1;

            -- AuditLog (UPDATE)
            SET @ActionType = N'UPDATE';

            SET @Note_Audit = N'{'
                + N'"typesID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @typesID), '') + N'"'
                + N',"typesName_A":"' + ISNULL(@NameA_Trim, '') + N'"'
                + N',"typesName_E":"' + ISNULL(@NameE_Trim, '') + N'"'
                + N',"typesDesc":"' + ISNULL(@Desc_Trim, '') + N'"'
                + N',"typesActive":"' + ISNULL(CONVERT(NVARCHAR(10), @typesActive), '') + N'"'
                + N',"typesStartDate":"' + ISNULL(CONVERT(NVARCHAR(30), @SD, 121), '') + N'"'
                + N',"typesEndDate":"' + ISNULL(CONVERT(NVARCHAR(30), @ED, 121), '') + N'"'
                + N',"typesRoot_ParentID":"' + ISNULL(CONVERT(NVARCHAR(MAX), @typesRoot_ParentID), '') + N'"'
                + N',"entryData":"' + ISNULL(@entryData, '') + N'"'
                + N',"hostName":"' + ISNULL(@hostName, '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[TypesRoot]'
                , @ActionType
                , @typesID
                , @entryData
                , @Note_Audit
            );
        END

        IF @tc = 0
            COMMIT;

        SELECT
              1 AS IsSuccessful
            , CASE WHEN @IsInsert = 1 THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END