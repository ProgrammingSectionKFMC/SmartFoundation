
CREATE PROCEDURE [Housing].[MeterServiceTypeFixedAmountSP] 
(
      @Action                                 NVARCHAR(200)
    , @MeterServiceTypeFixedAmountID          BIGINT          = NULL
    , @MeterServiceTypeID_FK                  NVARCHAR(100)   = NULL
    , @FixedAmount                            NVARCHAR(100)   = NULL
    , @MeterServiceTypeFixedAmountStartDate   NVARCHAR(1000)  = NULL
    , @idaraID_FK                             NVARCHAR(10)    = NULL
    , @entryData                              NVARCHAR(20)    = NULL
    , @hostName                               NVARCHAR(200)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL
        , @NewID1 BIGINT = NULL
        , @Note1  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END
        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERTSERVICEFIXEDAMOUNT'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@FixedAmount)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'المبلغ مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@MeterServiceTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الخدمة مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@MeterServiceTypeFixedAmountStartDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ بداية الخدمة مطلوب', 1;
            END



            IF EXISTS
            (
                SELECT 1
                FROM  [Housing].[MeterServiceTypeFixedAmount] c
                WHERE c.MeterServiceTypeID_FK = @MeterServiceTypeID_FK
                  AND c.MeterServiceTypeFixedAmountActive = 1
                  AND c.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'سعر هذه الخدمة مضاف مسبقا', 1;
            END
            INSERT INTO  [Housing].[MeterServiceTypeFixedAmount]
            (
                  [MeterServiceTypeID_FK]
                 ,[FixedAmount]
                 ,[MeterServiceTypeFixedAmountStartDate]
                 ,[MeterServiceTypeFixedAmountActive]
                 ,[idaraID_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @MeterServiceTypeID_FK
                , @FixedAmount
                , @MeterServiceTypeFixedAmountStartDate
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سعر الخدمة', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سعر الخدمة - Identity', 1; -- برمجي
            END

            SET @Note = N'{'
                + N'"MeterServiceTypeFixedAmountID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"MeterServiceTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeID_FK), '') + N'"'
                + N',"FixedAmount": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @FixedAmount), '') + N'"'
                + N',"MeterServiceTypeFixedAmountStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeFixedAmountStartDate), '') + N'"'
                + N',"buildingClassActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';


                IF not exists 
                (
                SELECT 1
                FROM  [Housing].[MeterServiceTypeLinkedWithIdara] c
                WHERE c.MeterServiceTypeID_FK = @MeterServiceTypeID_FK
                  AND c.MeterServiceTypeLinkedWithIdaraActive = 1
                  AND c.Idara_FK = @IdaraID_INT
                )
                Begin

                INSERT INTO  [Housing].[MeterServiceTypeLinkedWithIdara]
            (
                  [MeterServiceTypeID_FK]
                 ,[Idara_FK]
                 ,[MeterServiceTypeLinkedWithIdaraStartDate]
                 ,[MeterServiceTypeLinkedWithIdaraActive]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @MeterServiceTypeID_FK
                , @IdaraID_INT
                , @MeterServiceTypeFixedAmountStartDate
                , 1
                , GETDATE()
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سعر الخدمة', 1; -- برمجي
            END
            SET @NewID1 = SCOPE_IDENTITY();
            IF @NewID1 IS NULL OR @NewID1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سعر الخدمة - Identity', 1; -- برمجي
            END

            SET @Note1 = N'{'
                + N'"MeterServiceTypeLinkedWithIdaraID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID1), '') + N'"'
                + N',"MeterServiceTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeID_FK), '') + N'"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"MeterServiceTypeFixedAmountStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeFixedAmountStartDate), '') + N'"'
                + N',"MeterServiceTypeLinkedWithIdaraActive": "1"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';



            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[MeterServiceTypeLinkedWithIdara]'
                , N'INSERTSERVICEFIXEDAMOUNT'
                , ISNULL(@NewID1, 0)
                , @entryData
                , @Note1
            );

            END



            SELECT 1 AS IsSuccessful, N'تم اضافة سعر الخدمة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'EDITSERVICEFIXEDAMOUNT'
        BEGIN
            IF @MeterServiceTypeFixedAmountID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@FixedAmount)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'المبلغ مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@MeterServiceTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الخدمة مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@MeterServiceTypeFixedAmountStartDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ بداية الخدمة مطلوب', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  [Housing].[MeterServiceTypeFixedAmount] c
                WHERE c.MeterServiceTypeID_FK = @MeterServiceTypeID_FK
                  AND c.MeterServiceTypeFixedAmountActive = 1
                  AND c.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  [Housing].[MeterServiceTypeFixedAmount]
            SET
                MeterServiceTypeFixedAmountActive = 0,MeterServiceTypeFixedAmountEndDate = GETDATE()
            WHERE MeterServiceTypeFixedAmountID = @MeterServiceTypeFixedAmountID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سعر الخدمة', 1; -- برمجي/غير متوقع
            END

            INSERT INTO  [Housing].[MeterServiceTypeFixedAmount]
            (
                  [MeterServiceTypeID_FK]
                 ,[FixedAmount]
                 ,[MeterServiceTypeFixedAmountStartDate]
                 ,[MeterServiceTypeFixedAmountActive]
                 ,[idaraID_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @MeterServiceTypeID_FK
                , @FixedAmount
                , @MeterServiceTypeFixedAmountStartDate
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تحديث سعر الخدمة', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تحديث سعر الخدمة - Identity', 1; -- برمجي
            END

             SET @Note = N'{'
                + N'"MeterServiceTypeFixedAmountID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"MeterServiceTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeID_FK), '') + N'"'
                + N',"FixedAmount": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @FixedAmount), '') + N'"'
                + N',"MeterServiceTypeFixedAmountStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeFixedAmountStartDate), '') + N'"'
                + N',"buildingClassActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[MeterServiceTypeFixedAmount]'
                , N'EDITSERVICEFIXEDAMOUNT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث سعر الخدمة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETESERVICEFIXEDAMOUNT'
         BEGIN
            IF @MeterServiceTypeFixedAmountID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  [Housing].[MeterServiceTypeFixedAmount] c
                WHERE c.MeterServiceTypeID_FK = @MeterServiceTypeID_FK
                  AND c.MeterServiceTypeFixedAmountActive = 1
                  AND c.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END

            UPDATE  [Housing].[MeterServiceTypeFixedAmount]
            SET
                MeterServiceTypeFixedAmountActive = 0,MeterServiceTypeFixedAmountEndDate = GETDATE()
            WHERE MeterServiceTypeFixedAmountID = @MeterServiceTypeFixedAmountID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم حذف أي سعر الخدمة', 1; -- برمجي/غير متوقع
            END


             SET @Note = N'{'
                + N'"MeterServiceTypeFixedAmountID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeFixedAmountID), '') + N'"'
                + N',"MeterServiceTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeID_FK), '') + N'"'
                + N',"FixedAmount": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @FixedAmount), '') + N'"'
                + N',"MeterServiceTypeFixedAmountStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterServiceTypeFixedAmountStartDate), '') + N'"'
                + N',"MeterServiceTypeFixedAmountEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"buildingClassActive": "0"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[MeterServiceTypeFixedAmount]'
                , N'DELETESERVICEFIXEDAMOUNT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف سعر الخدمة بنجاح' AS Message_;
            RETURN;
        END


        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END

GO

