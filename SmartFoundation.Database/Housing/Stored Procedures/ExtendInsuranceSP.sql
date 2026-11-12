
CREATE PROCEDURE [Housing].[ExtendInsuranceSP]
(
      @Action                            NVARCHAR(200)
    , @ExtendInsuranceID                 BIGINT          = NULL
    , @residentInfoID_FK                 NVARCHAR(10)    = NULL
    , @generalNo_FK                      NVARCHAR(100)   = NULL
    , @NationalID                        NVARCHAR(100)   = NULL
    , @unitID                            NVARCHAR(100)   = NULL
    , @FullName                          NVARCHAR(100)   = NULL
    , @buildingDetailsID                 NVARCHAR(100)   = NULL
    , @InsuranceAmountWithRemaining      NVARCHAR(100)   = NULL
    , @ExtendInsuranceIncomeNo           NVARCHAR(1000)  = NULL
    , @ExtendInsuranceIncomeDate         NVARCHAR(1000)  = NULL
    , @ExtendInsuranceApprovedNote       NVARCHAR(1000)  = NULL
    , @idaraID_FK                        NVARCHAR(10)    = NULL
    , @entryData                         NVARCHAR(20)    = NULL
    , @hostName                          NVARCHAR(200)   = NULL
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
        , @Note1  NVARCHAR(MAX) = NULL
        , @NewID2 BIGINT = NULL
        , @Note2  NVARCHAR(MAX) = NULL

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

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

        IF @ExtendInsuranceID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الرقم المرجعي مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@generalNo_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الرقم العام مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@InsuranceAmountWithRemaining)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'مبلغ التأمين مطلوب', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@ExtendInsuranceApprovedNote)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'ملاحظات اعتماد التأمين مطلوبة', 1;
        END




        ----------------------------------------------------------------
        -- APPROVEEXTENDINSURANCE
        ----------------------------------------------------------------
         IF @Action = N'APPROVEEXTENDINSURANCE'
        BEGIN


         Declare @InsertedAmount decimal(18,2)
         set @InsertedAmount = TRY_CAST(@InsuranceAmountWithRemaining as decimal(18,2))
         
         
            

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.ExtendInsurance
                WHERE ExtendInsuranceID = @ExtendInsuranceID
                  AND ExtendInsuranceActive = 1
                  and residentInfoID_FK = @residentInfoID_FK
            )
            BEGIN
                ;THROW 50001, N'الرقم المرجعي للتامين غير موجود', 1;
            END

            IF  EXISTS
            (
                SELECT 1
                FROM  Housing.ExtendInsurance
                WHERE ExtendInsuranceID = @ExtendInsuranceID
                  AND ExtendInsuranceActive = 1
                  and residentInfoID_FK = @residentInfoID_FK
                  and ExtendInsuranceApproved = 1
                  and ExtendInsuranceApprovedby is not null
                  and ExtendInsuranceApprovedDate is not null
            )
            BEGIN
                ;THROW 50001, N'تم اعتماد التأمين الاحترازي مسبقا', 1;
            END



            UPDATE  Housing.ExtendInsurance
            SET
                  ExtendInsuranceApproved        = 1
                , ExtendInsuranceIncomeNo      = ISNULL(@ExtendInsuranceIncomeNo, ExtendInsuranceIncomeNo)
                , ExtendInsuranceIncomeDate      = ISNULL(@ExtendInsuranceIncomeDate, ExtendInsuranceIncomeDate)
                , ExtendInsuranceApprovedby = ISNULL(@entryData, ExtendInsuranceApprovedby)
                , ExtendInsuranceApprovedNote = ISNULL(@ExtendInsuranceApprovedNote, ExtendInsuranceApprovedNote)
                , ExtendInsuranceApprovedDate = GETDATE()
            WHERE ExtendInsuranceID = @ExtendInsuranceID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث حالة التأمين', 1; -- برمجي/غير متوقع
            END



            SET @Note = N'{'
                + N'"ExtendInsuranceID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceID), '') + N'"'
                + N',"ExtendInsuranceApproved": 1 "'+ N'"'
                + N',"ExtendInsuranceIncomeNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceIncomeNo), '') + N'"'
                + N',"ExtendInsuranceIncomeDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceIncomeDate), '') + N'"'
                + N',"ExtendInsuranceApprovedNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceApprovedNote), '') + N'"'
                + N',"IdaraId_FK": "'              + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"ExtendInsuranceApprovedby": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"ExtendInsuranceApprovedDate": "'                + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
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
                  N'[Housing].[ExtendInsurance]'
                , N'APPROVEEXTENDINSURANCE'
                , @ExtendInsuranceID
                , @entryData
                , @Note
            );



             INSERT INTO Housing.DeductList
            (
                  [deductTypeID_FK]
                 ,[DeductListStatusID_FK]
                 ,[deductName]
                 ,[amountTypeID_FK]
                 ,[paymentTypeID_FK]
                 ,[issueMonth]
                 ,[issueYear]
                 ,[paymentNo]
                 ,[paymentDate]
                 ,[description]
                 ,[deductActive]
                 ,[BillChargeTypeID_FK]
                 ,[ExtendInsuranceID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                 5,
                 2,
                 N'اعتماد التأمين الاحترازي',
                 1,
                 5,
                 MONTH(GETDATE()),
                 YEAR(GETDATE()),
                 @ExtendInsuranceIncomeNo,
                 @ExtendInsuranceIncomeDate,
                 @ExtendInsuranceApprovedNote,
                 1,
                 6,
                 @ExtendInsuranceID,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في اعتماد التأمين الاحترازي',  1; -- برمجي/غير متوقع
            END

            set @NewID1 = SCOPE_IDENTITY();

             SET @Note1 = N'{'
                + N'"deductListID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID1), '') + N'"'
                + N',"deductTypeID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), 5), '') + N'"'
                + N',"deductTypeID_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), 2), '') + N'"'
                + N',"deductName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), N'اعتماد التأمين الاحترازي'), '') + N'"'
                + N',"amountTypeID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"paymentTypeID_FK": "'    + ISNULL(CONVERT(NVARCHAR(MAX), 5), '') + N'"'
                + N',"issueMonth": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  MONTH(GETDATE())), '') + N'"'
                + N',"issueYear": "'           + ISNULL(CONVERT(NVARCHAR(MAX), YEAR(GETDATE())), '') + N'"'
                + N',"paymentNo": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceIncomeNo), '') + N'"'
                + N',"paymentDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceIncomeDate), '') + N'"'
                + N',"description": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceApprovedNote), '') + N'"'
                + N',"deductActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 6), '') + N'"'
                + N',"ExtendInsuranceID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceID), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[DeductList]'
                , @Action
                , @NewID1
                , @entryData
                , @Note1
            );



            
               INSERT INTO [Housing].[BuildingPayment]
            (
                  [buildingPaymentTypeID_FK]
                 ,[generalNo_FK]
                 ,[IDNumber]
                 ,[residentInfoID_FK]
                 ,[unitID]
                 ,[userName]
                 ,[buildingDetailsID_FK]
                 ,[amount]
                 ,[deductListID_FK]
                 ,[buildingPayementActive]
                 ,[BillChargeTypeID_FK]
                 ,[ExtendInsuranceID_FK]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                 5,
                 @generalNo_FK,
                 @NationalID,
                 @residentInfoID_FK,
                 @unitID,
                 @FullName,
                 @buildingDetailsID,
                 @InsertedAmount,
                 @NewID1,
                 1,
                 6,
                 @ExtendInsuranceID,
                 @IdaraID_INT,
                 GETDATE(),
                 @entryData,
                 @hostName

            )


            IF @@ROWCOUNT = 0
            BEGIN
                 ;THROW 50002, N'حصل خطأ في عملية الدفع او الاعادة - BuildingPayment',  1; -- برمجي/غير متوقع
            END

            set @NewID2 = SCOPE_IDENTITY();

             SET @Note2 = N'{'
                + N'"paymentID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID2), '') + N'"'
                + N',"buildingPaymentTypeID_FK": "'            + ISNULL(CONVERT(NVARCHAR(MAX), 5), '') + N'"'
                + N',"generalNo_FK": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @generalNo_FK), '') + N'"'
                + N',"IDNumber": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @NationalID), '') + N'"'
                + N',"residentInfoID_FK": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"unitID": "'    + ISNULL(CONVERT(NVARCHAR(MAX), @unitID), '') + N'"'
                + N',"userName": "'      + ISNULL(CONVERT(NVARCHAR(MAX),  @FullName), '') + N'"'
                + N',"buildingDetailsID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"amount": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @InsertedAmount), '') + N'"'
                + N',"deductListID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID1), '') + N'"'
                + N',"buildingPayementActive": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"BillChargeTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), 6), '') + N'"'
                + N',"ExtendInsuranceID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @ExtendInsuranceID), '') + N'"'
                + N',"IdaraId_FK": "'                      + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                       + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'                        + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingPayment]'
                , @Action
                , @NewID2
                , @entryData
                , @Note2
            );



            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETEBUILDINGTYPE'
        BEGIN

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
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

