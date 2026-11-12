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
    , @entryData          NVARCHAR(40)
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
    DECLARE @IsInsert BIT = CASE WHEN @typesID IS NULL THEN 1 ELSE 0 END;
    DECLARE @ActionType NVARCHAR(20);

    BEGIN TRY
        IF @NameA_Trim IS NULL
            THROW 50001, N'الاسم العربي مطلوب', 1;

        IF @typesEndDate IS NOT NULL AND @typesEndDate < @SD
            THROW 50001, N'تاريخ النهاية لا يمكن أن يكون قبل البداية', 1;

        IF @typesID IS NOT NULL
           AND @typesRoot_ParentID IS NOT NULL
           AND @typesRoot_ParentID = @typesID
            THROW 50001, N'لا يمكن أن يكون أب لنفسه', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @IsInsert = 1
        BEGIN
            INSERT INTO VIC.TypesRoot
            (
                typesName_A, typesName_E, typesDesc, typesActive,
                typesStartDate, typesEndDate, typesRoot_ParentID,
                entryDate, entryData, hostName
            )
            VALUES
            (
                @NameA_Trim, @NameE_Trim, @Desc_Trim, @typesActive,
                @SD, @typesEndDate, @typesRoot_ParentID,
                GETDATE(), @entryData, @hostName
            );

            SET @typesID = SCOPE_IDENTITY();
            IF @typesID IS NULL
                THROW 50002, N'فشل الإدخال', 1;

            SET @ActionType = 'INSERT';
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM VIC.TypesRoot WHERE typesID = @typesID)
                THROW 50001, N'السجل غير موجود', 1;

            UPDATE VIC.TypesRoot
            SET typesName_A = @NameA_Trim,
                typesName_E = @NameE_Trim,
                typesDesc = @Desc_Trim,
                typesActive = @typesActive,
                typesStartDate = @SD,
                typesEndDate = @typesEndDate,
                typesRoot_ParentID = @typesRoot_ParentID,
                entryDate = GETDATE(),
                entryData = @entryData,
                hostName = @hostName
            WHERE typesID = @typesID;

            IF @@ROWCOUNT = 0
                THROW 50002, N'لم يتم التحديث', 1;

            SET @ActionType = 'UPDATE';
        END

        IF @tc = 0 COMMIT;

        SELECT CAST(1 AS BIT) AS IsSuccessful,
               CASE WHEN @IsInsert = 1
                    THEN N'تم الإنشاء بنجاح'
                    ELSE N'تم التحديث بنجاح'
               END AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END

GO

