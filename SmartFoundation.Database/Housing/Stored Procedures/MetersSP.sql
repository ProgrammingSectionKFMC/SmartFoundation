

CREATE PROCEDURE [Housing].[MetersSP] 
(
      @Action                                     NVARCHAR(100) = NULL
     ,@meterID                                    NVARCHAR(100)   = NULL
     ,@meterTypeID_FK                             NVARCHAR(100)   = NULL
     ,@meterNo                                    NVARCHAR(1000)   = NULL
     ,@meterName_A                                NVARCHAR(1000)   = NULL
     ,@meterName_E                                NVARCHAR(1000)   = NULL
     ,@meterDescription                           NVARCHAR(1000)   = NULL
     ,@meterStartDate                             NVARCHAR(100)   = NULL
     ,@meterEndDate                               NVARCHAR(100)   = NULL
     ,@meterServiceTypeID                         NVARCHAR(100)   = NULL
     ,@meterTypeName_A                            NVARCHAR(1000)   = NULL
     ,@meterTypeName_E                            NVARCHAR(1000)   = NULL
     ,@meterTypeDescription                       NVARCHAR(1000)   = NULL
     ,@meterTypeConversionFactor                  NVARCHAR(100)   = NULL
     ,@meterMaxRead                               NVARCHAR(100)   = NULL
     ,@meterTypeStartDate                         NVARCHAR(100)   = NULL
     ,@meterTypeEndDate                           NVARCHAR(100)   = NULL
     ,@meterServicePrice                          NVARCHAR(100)   = NULL
     ,@MeterNote                                  NVARCHAR(100)   = NULL
     ,@meterReadValue 					          NVARCHAR(100)   = NULL
     ,@Notes                                      NVARCHAR(100)   = NULL
     ,@buildingDetailsID_FK                       NVARCHAR(100)   = NULL
     ,@meterForBuildingID                         NVARCHAR(100)   = NULL
     ,@buildingDetailsNo1                         NVARCHAR(100)   = NULL
     ,@MeterCalculateTypeID                       NVARCHAR(100)   = NULL
     ,@MeterTypeFixedAmount                       NVARCHAR(100)   = NULL
     ,@AbnormalReadConfirmed                      NVARCHAR(10)    = NULL
     ,@IdaraId_FK                                 NVARCHAR(100)   = NULL
     ,@entryData                                  NVARCHAR(100)   = NULL
     ,@hostName                                   NVARCHAR(100)   = NULL
     
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID           BIGINT = NULL
        , @Note            NVARCHAR(MAX) = NULL
        , @Identity_Insert BIGINT = NULL
        , @Identity_Insert1 BIGINT = NULL
        , @Identity_Insert2 BIGINT = NULL
        , @Identity_Update BIGINT = NULL
        , @Identity_Update1 BIGINT = NULL
        , @Identity_Update2 BIGINT = NULL
        , @LinkedServiceTypeID INT = NULL
        , @LinkedServiceStartDate DATETIME = NULL
        , @UnlinkBillPeriodID INT = NULL
        , @UnlinkBillFromDate DATE = NULL
        , @UnlinkBillToDate DATE = NULL
        , @UnlinkBillYear INT = NULL
        , @UnlinkBillMonth INT = NULL
        , @LastBilledPeriodEndDate DATE = NULL
        , @MinimumUnlinkDate DATE = NULL
        , @UnlinkValidationMessage NVARCHAR(2048) = NULL
        , @LinkEffectiveDate DATE = NULL
        , @ActiveServicePeriodID INT = NULL
        , @ActiveServicePeriodStartDate DATE = NULL
        , @LastClosedServicePeriodEndDate DATE = NULL
        , @LinkValidationMessage NVARCHAR(2048) = NULL;

    -- تحويلات رقمية آمنة
   DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

   DECLARE @buildingDetailsNo nvarchar(500) = (select top(1) bd.buildingDetailsNo from Housing.BuildingDetails bd where bd.buildingDetailsID = @buildingDetailsID_FK and bd.IdaraId_FK = @IdaraId_FK and bd.buildingDetailsActive = 1 order by bd.buildingDetailsID desc);

   DECLARE @residentInfoID_FK BIGINT;

   DECLARE @generalNo_FK nvarchar(500);


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
       

   


         IF(@Action IN('DELETE'))
       BEGIN

       if(select count(*) from Housing.V_WaitingList w where w.residentInfoID = 4) > 0
       begin
       ;THROW 50001, N'لايمكن حذف المستفيد لوجود اجراءات متعلقة به في النظام', 1;

       end

       END
        ----------------------------------------------------------------
        -- INSERTNEWMETERTYPE
        ----------------------------------------------------------------
        IF @Action = N'INSERTNEWMETERTYPE'
        BEGIN


            IF EXISTS (
                SELECT 1
                FROM  Housing.MeterType c
                WHERE c.meterTypeName_A = @meterTypeName_A and c.meterTypeActive = 1
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'بيانات نوع العداد مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.MeterType
            (
                  [meterServiceTypeID_FK]
                 ,[meterTypeName_A]
                 ,[meterTypeName_E]
                 ,[meterTypeDescription]
                 ,[meterTypeConversionFactor]
                 ,[meterMaxRead]
                 ,[meterTypeStartDate]
                 ,[meterTypeEndDate]
                 ,[MeterCalculateTypeID_FK]
                 ,[meterTypeActive]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @meterServiceTypeID
                , @meterTypeName_A
                , @meterTypeName_E
                , @meterTypeDescription
                , @meterTypeConversionFactor
                , @meterMaxRead
                , @meterTypeStartDate
                , @meterTypeEndDate
                , @MeterCalculateTypeID
                , 1
                , @IdaraID_INT
                , convert(nvarchar(10),Getdate(),23)
                , @entryData
                , @hostName
            );

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة نوع العداد - MeterType', 1; -- برمجي
            END

            if(@MeterCalculateTypeID = 1)

            begin

                INSERT INTO  Housing.MeterServicePrice
                (
                      [meterTypeID_FK]
                     ,[meterServicePriceStartDate]
                     ,[meterServicePriceEndDate]
                     ,[meterServicePrice]
                     ,[meterServicePriceActive]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      @Identity_Insert
                    , @meterTypeStartDate
                    , @meterTypeEndDate
                    , @meterServicePrice
                    , 1
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END

            END


            if(@MeterCalculateTypeID = 2)

            begin

                IF TRY_CONVERT(DECIMAL(18,2), @MeterTypeFixedAmount) IS NULL
                   OR TRY_CONVERT(DECIMAL(18,2), @MeterTypeFixedAmount) <= 0
                BEGIN
                    ;THROW 50001, N'يجب إدخال سعر ثابت أكبر من صفر لنوع العداد الثابت', 1;
                END;

                INSERT INTO  [Housing].[MeterTypeFixedAmount]
                (
                      [MeterTypeID_FK]
                     ,[FixedAmount]
                     ,[MeterTypeFixedAmountStartDate]
                     ,[MeterTypeFixedAmountEndDate]
                     ,[MeterTypeFixedAmountActive]
                     ,[idaraID_FK]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      @Identity_Insert
                    , @MeterTypeFixedAmount
                    , @meterTypeStartDate
                    , @meterTypeEndDate
                    , 1
                    , @IdaraId_FK
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END

            END

            SET @NewID = @Identity_Insert;

            SET @Note = N'{'
                + N'"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"meterServiceTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterServiceTypeID), '') + N'"'
                + N',"meterTypeName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeName_A), '') + N'"'
                + N',"meterTypeName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeName_E), '') + N'"'
                + N',"meterTypeDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeDescription), '') + N'"'
                + N',"meterTypeConversionFactor": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeConversionFactor), '') + N'"'
                + N',"meterMaxRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterMaxRead), '') + N'"'
                + N',"meterTypeStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeStartDate), '') + N'"'
                + N',"meterTypeEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeEndDate), '') + N'"'
                + N',"MeterCalculateTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterCalculateTypeID), '') + N'"'
                + N',"meterTypeActive": 1"' + N'"'
                + N',"meterServicePriceStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeStartDate), '') + N'"'
                + N',"meterServicePriceEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeEndDate), '') + N'"'
                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterServicePrice), '') + N'"'

                + N',"MeterTypeFixedAmountStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeStartDate), '') + N'"'
                + N',"MeterTypeFixedAmountEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeEndDate), '') + N'"'
                + N',"FixedAmount": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterTypeFixedAmount), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[MeterType],[Housing].[MeterServicePrice]'
                , N'INSERTNEWMETERTYPE'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة نوع العداد بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATENEWMETERTYPE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATENEWMETERTYPE'
           BEGIN


            IF not EXISTS (
                SELECT 1
                FROM  Housing.MeterType c
                WHERE c.meterTypeID = @meterTypeID_FK
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'بيانات نوع العداد غير موجوده', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@meterTypeID_FK)), N'') IS NULL
                BEGIN
                    ;THROW 50001, N'رمز نوع العداد مطلوب', 1;
                END

                --update Housing.MeterType
                --set meterTypeActive = 0
                --where meterTypeID = @meterTypeID_FK


                UPDATE Housing.MeterType
                SET
                      meterServiceTypeID_FK      = COALESCE(@meterServiceTypeID, meterServiceTypeID_FK)
                    , meterTypeName_A            = COALESCE(NULLIF(@meterTypeName_A, ''), meterTypeName_A)
                    , meterTypeName_E            = COALESCE(NULLIF(@meterTypeName_E, ''), meterTypeName_E)
                    , meterTypeDescription       = COALESCE(NULLIF(@meterTypeDescription, ''), meterTypeDescription)
                    , meterTypeConversionFactor  = COALESCE(@meterTypeConversionFactor, meterTypeConversionFactor)
                    , meterMaxRead               = COALESCE(@meterMaxRead, meterMaxRead)
                    , meterTypeStartDate         = COALESCE(@meterTypeStartDate, meterTypeStartDate)
                    , meterTypeEndDate           = COALESCE(@meterTypeEndDate, meterTypeEndDate)
                    , meterTypeActive            = COALESCE(1, meterTypeActive)
                    , MeterCalculateTypeID_FK    = COALESCE(@MeterCalculateTypeID, MeterCalculateTypeID_FK)
                    , IdaraId_FK                 = COALESCE(@IdaraID_INT, IdaraId_FK)
                    , UpdatedDate                = isnull(UpdatedDate,'')+N','+convert(nvarchar(10),Getdate(),23)
                    , UpdatedBy                  = isnull(UpdatedBy,'')+N','+@entryData
                    
                WHERE meterTypeID = @meterTypeID_FK;


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في تعديل نوع العداد - MeterType', 1; -- برمجي
                END
                if(@MeterCalculateTypeID = 1)

            begin
                 update Housing.MeterServicePrice
                set meterServicePriceActive = 0
                where meterTypeID_FK = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END

                 INSERT INTO  Housing.MeterServicePrice
                (
                      [meterTypeID_FK]
                     ,[meterServicePriceStartDate]
                     ,[meterServicePriceEndDate]
                     ,[meterServicePrice]
                     ,[meterServicePriceActive]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      @meterTypeID_FK
                    , @meterTypeStartDate
                    , @meterTypeEndDate
                    , @meterServicePrice
                    , 1
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END


                END

                 if(@MeterCalculateTypeID = 2)

            begin
                IF TRY_CONVERT(DECIMAL(18,2), @MeterTypeFixedAmount) IS NULL
                   OR TRY_CONVERT(DECIMAL(18,2), @MeterTypeFixedAmount) <= 0
                BEGIN
                    ;THROW 50001, N'يجب إدخال سعر ثابت أكبر من صفر لنوع العداد الثابت', 1;
                END;

                 update Housing.MeterTypeFixedAmount
                set MeterTypeFixedAmountActive = 0,
                    MeterTypeFixedAmountEndDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))
                where meterTypeID_FK = @meterTypeID_FK
                  AND idaraID_FK = @IdaraID_INT
                  AND MeterTypeFixedAmountActive = 1


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END


                 INSERT INTO  [Housing].[MeterTypeFixedAmount]
                (
                      [MeterTypeID_FK]
                     ,[FixedAmount]
                     ,[MeterTypeFixedAmountStartDate]
                     ,[MeterTypeFixedAmountEndDate]
                     ,[MeterTypeFixedAmountActive]
                     ,[idaraID_FK]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      @meterTypeID_FK
                    , @MeterTypeFixedAmount
                    , CAST(GETDATE() AS date)
                    , NULL
                    , 1
                    , @IdaraId_FK
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
                END

                END

            


            SET @NewID = @meterTypeID_FK;

            SET @Note = N'{'
                + N'"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"meterServiceTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterServiceTypeID), '') + N'"'
                + N',"meterTypeName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeName_A), '') + N'"'
                + N',"meterTypeName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeName_E), '') + N'"'
                + N',"meterTypeDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeDescription), '') + N'"'
                + N',"meterTypeConversionFactor": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeConversionFactor), '') + N'"'
                + N',"meterMaxRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterMaxRead), '') + N'"'
                + N',"meterTypeStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeStartDate), '') + N'"'
                + N',"meterTypeEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeEndDate), '') + N'"'
                + N',"meterTypeActive": 1"' + N'"'
                + N',"meterServicePriceStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeStartDate), '') + N'"'
                + N',"meterServicePriceEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeEndDate), '') + N'"'
                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterServicePrice), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[MeterType],[Housing].[MeterServicePrice]'
                , N'UPDATENEWMETERTYPE'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );


            SELECT 1 AS IsSuccessful, N'تم تعديل نوع العداد بنجاح' AS Message_;
            RETURN;
        END

         ----------------------------------------------------------------
        -- DELETENEWMETERTYPE
        ----------------------------------------------------------------
         ELSE IF @Action = N'DELETENEWMETERTYPE'
           BEGIN


             IF NULLIF(LTRIM(RTRIM(@meterTypeID_FK)), N'') IS NULL
                BEGIN
                    ;THROW 50001, N'رمز نوع العداد مطلوب', 1;
                END

            IF not EXISTS (
                SELECT 1
                FROM  Housing.MeterType c
                 WHERE c.meterTypeID = @meterTypeID_FK
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterTypeActive = 1
            )
            BEGIN
                ;THROW 50001, N'بيانات نوع العداد غير موجوده', 1;
            END


             IF  EXISTS (
                SELECT 1
                FROM  Housing.MeterType c
                inner join Housing.Meter m on c.meterTypeID = m .meterTypeID_FK
                WHERE c.meterTypeID = @meterTypeID_FK
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterTypeActive = 1 and m.meterActive = 1
            )
            BEGIN
                ;THROW 50001, N'نوع العداد مرتبط بعدادات نشطة لايمكن حذفه', 1;
            END

           

                update Housing.MeterType
                set meterTypeActive = 0,meterTypeEndDate = GETDATE(),CanceledBy = @entryData,CanceledDate = GETDATE(),CanceledNote = @Notes
                where meterTypeID = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في حذف نوع العداد - MeterType', 1; -- برمجي
                END

                if(@MeterCalculateTypeID = 1)
                begin

                 update Housing.MeterServicePrice
                set meterServicePriceActive = 0,meterServicePriceEndDate = GETDATE()
                where meterTypeID_FK = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في حذف نوع العداد - MeterServicePrice', 1; -- برمجي
                END

                END


                 if(@MeterCalculateTypeID = 2)
                begin
                 update Housing.MeterTypeFixedAmount
                set MeterTypeFixedAmountActive = 0,MeterTypeFixedAmountEndDate = CAST(GETDATE() AS date)
                where meterTypeID_FK = @meterTypeID_FK
                  AND idaraID_FK = @IdaraID_INT
                  AND MeterTypeFixedAmountActive = 1

             IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في حذف نوع العداد - MeterTypeFixedAmount', 1; -- برمجي
                END
                END

            SET @NewID = @meterTypeID_FK;

            SET @Note = N'{'
                + N'"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"meterTypeEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"meterServicePriceEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[MeterType],[Housing].[MeterServicePrice]'
                , N'DELETENEWMETERTYPE'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف نوع العداد بنجاح' AS Message_;
            RETURN;
        END





        ----------------------------------------------------------------
        -- INSERTNEWMETER
        ----------------------------------------------------------------
        ELSE IF @Action = N'INSERTNEWMETER'
        BEGIN
        

            IF EXISTS (
                SELECT 1
                FROM  Housing.Meter c
                WHERE c.meterNo = @meterNo and c.meterActive = 1
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterActive = 1
            )
            BEGIN
                ;THROW 50001, N'بيانات العداد مدخلة مسبقا', 1;
            END

             IF EXISTS (
                SELECT 1
                FROM  Housing.Meter c
                WHERE c.meterName_A = @meterName_A and c.meterActive = 1
                    AND c.IdaraId_FK = @IdaraID_INT
                  AND c.meterActive = 1
            )
            BEGIN
                ;THROW 50001, N'اسم العداد بالعربي مدخل مسبقا', 1;
            END



            INSERT INTO  Housing.Meter
            (
                  [meterTypeID_FK]
                 ,[meterNo]
                 ,[meterName_A]
                 ,[meterName_E]
                 ,[meterDescription]
                 ,[meterStartDate]
                 ,[meterEndDate]
                 ,[meterActive]
                 ,[IdaraId_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @meterTypeID_FK
                , @meterNo
                , @meterName_A
                , @meterName_E
                , @meterDescription
                , @meterStartDate
                , null
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );



            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة  العداد - Meter', 1; -- برمجي
            END

             SET @Note = N'{'
                + N'"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), '') + N'"'
                + N',"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeID_FK), '') + N'"'
                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterNo), '') + N'"'
                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_A), '') + N'"'
                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_E), '') + N'"'
                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterDescription), '') + N'"'
                + N',"meterStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterStartDate), '') + N'"'
                + N',"meterEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterEndDate), '') + N'"'
                + N',"meterActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

                + N'}';

                INSERT INTO  Housing.MeterRead
                (
                      [meterReadTypeID_FK]
                     ,[meterID_FK]
                     ,[billPeriodID_FK]
                     ,[dateOfRead]
                     ,[meterReadValue]
                     ,[meterReadActive]
                     ,[IdaraID_FK]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      4
                    , @Identity_Insert
                    , 1
                    , GETDATE()
                    , @meterReadValue
                    , 1
                    , @IdaraId_FK
                    , GETDATE()
                    , @entryData
                    , @hostName
                );


                SET @Identity_Insert1 = SCOPE_IDENTITY();

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة  العداد - MeterRead', 1; -- برمجي
                END

             declare @Note1 nvarchar(max)
             SET @Note1 = N'{'
                + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert1), '') + N'"'
                + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '4'), '') + N'"'
                + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"dateOfRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterReadValue), '') + N'"'
                + N',"meterReadActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[Meter],[Housing].[MeterRead]'
                , N'INSERTNEWMETER'
                , ISNULL(@Identity_Insert, 0)
                , @entryData
                , @Note+' - '+@Note1
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة العداد بنجاح' AS Message_;
            RETURN;
        END


           ----------------------------------------------------------------
        -- EDITNEWMETER
        ----------------------------------------------------------------
        ELSE IF @Action = N'EDITNEWMETER'
        BEGIN
        

          IF @meterID IS NULL OR @meterID <= 0
            BEGIN
        ;THROW 50001, N'رقم العداد مطلوب للتعديل', 1;
        END

    -- تأكد موجود
    IF NOT EXISTS (
        SELECT 1
        FROM  Housing.Meter m
        WHERE m.meterID = @meterID
          AND m.IdaraId_FK = @IdaraID_INT
          AND m.meterActive = 1
    )
    BEGIN
        ;THROW 50001, N'العداد غير موجود', 1;
    END

    -- منع تكرار رقم العداد (مع استثناء نفس السجل)
    IF EXISTS (
        SELECT 1
        FROM  Housing.Meter c
        WHERE c.meterNo = @meterNo
          AND c.IdaraId_FK = @IdaraID_INT
          AND c.meterActive = 1
          AND c.meterID <> @meterID
    )
    BEGIN
        ;THROW 50001, N'بيانات العداد مدخلة مسبقا', 1;
    END

    -- منع تكرار الاسم العربي (مع استثناء نفس السجل)
    IF EXISTS (
        SELECT 1
        FROM  Housing.Meter c
        WHERE c.meterName_A = @meterName_A
          AND c.IdaraId_FK = @IdaraID_INT
          AND c.meterActive = 1
          AND c.meterID <> @meterID
    )
    BEGIN
        ;THROW 50001, N'اسم العداد بالعربي مدخل مسبقا', 1;
    END



          UPDATE m
    SET
        m.meterTypeID_FK   = COALESCE(@meterTypeID_FK, m.meterTypeID_FK),
        m.meterNo          = COALESCE(NULLIF(LTRIM(RTRIM(@meterNo)), N''), m.meterNo),
        m.meterName_A      = COALESCE(NULLIF(LTRIM(RTRIM(@meterName_A)), N''), m.meterName_A),
        m.meterName_E      = COALESCE(NULLIF(LTRIM(RTRIM(@meterName_E)), N''), m.meterName_E),
        m.meterDescription = COALESCE(NULLIF(LTRIM(RTRIM(@meterDescription)), N''), m.meterDescription),
        m.meterStartDate   = COALESCE(@meterStartDate, m.meterStartDate),
        m.meterEndDate     = COALESCE(@meterEndDate, m.meterEndDate),
        m.entryDate        = GETDATE(),
        m.entryData        = @entryData,
        m.hostName         = @hostName
    FROM  Housing.Meter m
    WHERE m.meterID = @meterID
      AND m.IdaraId_FK = @IdaraID_INT
      AND m.meterActive = 1;



         IF @@ROWCOUNT <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تحديث  العداد - Meter', 1; -- برمجي
            END

             SET @Note = N'{'
                + N'"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), '') + N'"'
                + N',"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeID_FK), '') + N'"'
                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterNo), '') + N'"'
                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_A), '') + N'"'
                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_E), '') + N'"'
                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterDescription), '') + N'"'
                + N',"meterStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterStartDate), '') + N'"'
                + N',"meterEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterEndDate), '') + N'"'
                + N',"meterActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

                + N'}';

              IF NULLIF(LTRIM(RTRIM(ISNULL(@meterReadValue, N''))), N'') IS NOT NULL
                 BEGIN
                     ;WITH x AS
                     (
                         SELECT TOP (1) mr.meterReadID
                         FROM  Housing.MeterRead mr
                         WHERE mr.meterID_FK = @meterID
                           AND (mr.meterReadTypeID_FK = 4)
                           AND mr.meterReadActive = 1
                         ORDER BY mr.dateOfRead DESC, mr.meterReadID DESC
                     )
                     UPDATE mr
                     SET mr.meterReadValue = @meterReadValue,
                         mr.entryDate      = GETDATE(),
                         mr.entryData      = @entryData,
                         mr.hostName       = @hostName
                     FROM  Housing.MeterRead mr
                     INNER JOIN x ON x.meterReadID = mr.meterReadID;
                 END

                 if(@MeterCalculateTypeID = 1)
                 Begin
                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في تحديث  العداد - MeterRead', 1; -- برمجي
                END
                END
                 

             declare @Note12 nvarchar(max)
             SET @Note12 = N'{'
                + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), ''), '') + N'"'
                + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '4'), '') + N'"'
                + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"dateOfRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterReadValue), '') + N'"'
                + N',"meterReadActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[Meter],[Housing].[MeterRead]'
                , N'INSERTNEWMETER'
                , ISNULL(@meterID, 0)
                , @entryData
                , @Note+' - '+@Note12
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث العداد بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETENEWMETER
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETENEWMETER'
        BEGIN
        

          IF @meterID IS NULL OR @meterID <= 0
            BEGIN
        ;THROW 50001, N'رقم العداد مطلوب للحذف', 1;
        END

    -- تأكد موجود
    IF NOT EXISTS (
        SELECT 1
        FROM  Housing.Meter m
        WHERE m.meterID = @meterID
          AND m.IdaraId_FK = @IdaraID_INT
          AND m.meterActive = 1
    )
    BEGIN
        ;THROW 50001, N'العداد غير موجود', 1;
    END

      -- تأكد موجود
    IF EXISTS (
        SELECT 1
        FROM  Housing.Meter m
        INNER JOIN Housing.MeterForBuilding mbb ON mbb.meterID_FK = m.meterID
        WHERE m.meterID = @meterID
          AND m.IdaraId_FK = @IdaraID_INT
          AND m.meterActive = 1
          AND mbb.meterForBuildingActive = 1
    )
    BEGIN
        ;THROW 50001, N'العداد مرتبط بمنى حاليا ولايمكن حذفه', 1;
    END



          UPDATE m
    SET
        m.meterActive   = 0,
        M.meterEndDate  = GETDATE(),
        m.CanceledBy    = @entryData,
        m.canceledDate  = GETDATE(),
        m.CanceledNote  = @Notes,
        m.entryData        = @entryData,
        m.hostName         = @hostName
    FROM  Housing.Meter m
    WHERE m.meterID = @meterID
      AND m.IdaraId_FK = @IdaraID_INT
      AND m.meterActive = 1;



         IF @@ROWCOUNT <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف  العداد - Meter', 1; -- برمجي
            END

             SET @Note = N'{'
                + N'"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), '') + N'"'
                + N',"meterTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterTypeID_FK), '') + N'"'
                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterNo), '') + N'"'
                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_A), '') + N'"'
                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterName_E), '') + N'"'
                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterDescription), '') + N'"'
                + N',"meterStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterStartDate), '') + N'"'
                + N',"meterEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterEndDate), '') + N'"'
                + N',"meterActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[Meter]'
                , N'DELETENEWMETER'
                , ISNULL(@meterID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف العداد بنجاح' AS Message_;
            RETURN;
        END

           ----------------------------------------------------------------
        -- LINKMETERTOBUILDINGS
        ----------------------------------------------------------------
        ELSE IF @Action = N'LINKMETERTOBUILDINGS'
        BEGIN
        

          IF @meterID IS NULL OR @meterID <= 0
            BEGIN
        ;THROW 50001, N'رقم العداد مطلوب للربط', 1;
        END

         IF @buildingDetailsID_FK IS NULL
            BEGIN
        ;THROW 50001, N'رقم المبنى مطلوب للربط', 1;
        END



    -- تأكد موجود
    IF NOT EXISTS (
        SELECT 1
        FROM  Housing.Meter m
        WHERE m.meterID = @meterID
          AND m.IdaraId_FK = @IdaraID_INT
          AND m.meterActive = 1
    )
    BEGIN
        ;THROW 50001, N'العداد غير موجود', 1;
    END

    SELECT @LinkedServiceTypeID = meterType.meterServiceTypeID_FK
    FROM Housing.Meter meter
    INNER JOIN Housing.MeterType meterType
        ON meterType.meterTypeID = meter.meterTypeID_FK
    WHERE meter.meterID = @meterID;

    IF @LinkedServiceTypeID IS NULL
        THROW 50001, N'تعذر تحديد نوع خدمة العداد', 1;

    SET @LinkEffectiveDate = TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(@meterStartDate)), N''));

    IF @LinkEffectiveDate IS NULL
        THROW 50001, N'تاريخ بداية ربط العداد مطلوب أو غير صحيح', 1;

    IF @LinkEffectiveDate > CONVERT(date, GETDATE())
        THROW 50001, N'لا يمكن أن يكون تاريخ بداية الربط في المستقبل', 1;

    /* أحدث فترة نشطة لنفس الإدارة ولنفس نوع خدمة العداد. */
    SELECT TOP (1)
          @ActiveServicePeriodID = period.billPeriodID
        , @ActiveServicePeriodStartDate = CONVERT(date, period.billPeriodStartDate)
    FROM Housing.BillPeriod period
    INNER JOIN Housing.BillPeriodType periodType
        ON periodType.billPeriodTypeID = period.billPeriodTypeID_FK
    WHERE period.IdaraId_FK = @IdaraID_INT
      AND period.billPeriodActive = 1
      AND periodType.meterServiceTypeID_FK = @LinkedServiceTypeID
    ORDER BY period.billPeriodStartDate DESC, period.billPeriodID DESC;

    IF @ActiveServicePeriodID IS NOT NULL
       AND @LinkEffectiveDate < @ActiveServicePeriodStartDate
    BEGIN
        SET @LinkValidationMessage = N'لا يمكن أن يكون تاريخ بداية الربط قبل بداية آخر فترة نشطة لنفس الخدمة '
            + CONVERT(nvarchar(10), @ActiveServicePeriodStartDate, 105);
        THROW 50001, @LinkValidationMessage, 1;
    END;

    /* عند عدم وجود فترة نشطة يجب أن يبدأ الربط بعد نهاية آخر فترة مغلقة لنفس الخدمة. */
    IF @ActiveServicePeriodID IS NULL
    BEGIN
        SELECT TOP (1)
            @LastClosedServicePeriodEndDate = CONVERT(date, period.billPeriodEndDate)
        FROM Housing.BillPeriod period
        INNER JOIN Housing.BillPeriodType periodType
            ON periodType.billPeriodTypeID = period.billPeriodTypeID_FK
        WHERE period.IdaraId_FK = @IdaraID_INT
          AND period.billPeriodActive = 0
          AND periodType.meterServiceTypeID_FK = @LinkedServiceTypeID
          AND period.billPeriodEndDate IS NOT NULL
        ORDER BY period.billPeriodEndDate DESC, period.billPeriodID DESC;

        IF @LastClosedServicePeriodEndDate IS NOT NULL
           AND @LinkEffectiveDate <= @LastClosedServicePeriodEndDate
        BEGIN
            SET @LinkValidationMessage = N'لا يمكن أن يكون تاريخ بداية الربط قبل '
                + CONVERT(nvarchar(10), DATEADD(DAY, 1, @LastClosedServicePeriodEndDate), 105)
                + N'؛ لأن آخر فترة مغلقة لنفس الخدمة تنتهي في '
                + CONVERT(nvarchar(10), @LastClosedServicePeriodEndDate, 105);
            THROW 50001, @LinkValidationMessage, 1;
        END;
    END;

      -- تأكد موجود
   
     INSERT INTO  Housing.MeterForBuilding
            (
                  [meterID_FK]
                 ,[buildingDetailsID_FK]
                 ,[meterForBuildingStartDate]
                 ,[meterForBuildingDescription]
                 ,[meterForBuildingActive]
                 ,[IdaraID_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @meterID
                , @buildingDetailsID_FK
                , @LinkEffectiveDate
                , @Notes
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );



            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة  العداد - MeterForBuilding', 1; -- برمجي
            END

            /* ربط العداد يعني أن الخدمة متوفرة في المبنى، وتستمر بعد فك الربط. */
            IF @LinkedServiceTypeID IS NOT NULL
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM Housing.BuildingDetailsMeterServices buildingService
                   WHERE buildingService.BuildingDetailsID_FK = @buildingDetailsID_FK
                     AND buildingService.MeterServicesTypeID_FK = @LinkedServiceTypeID
                     AND buildingService.IdaraId_FK = @IdaraID_INT
                     AND buildingService.BuildingDetailsMeterServicesActive = 1
               )
            BEGIN
                INSERT Housing.BuildingDetailsMeterServices
                (
                      BuildingDetailsID_FK, MeterServicesTypeID_FK
                    , BuildingDetailsMeterServicesStartDate, BuildingDetailsMeterServicesActive
                    , IdaraId_FK, entryDate, entryData, hostName
                )
                VALUES
                (
                      @buildingDetailsID_FK, @LinkedServiceTypeID
                    , @LinkEffectiveDate, 1
                    , @IdaraID_INT, GETDATE(), @entryData, @hostName
                );
            END;


             INSERT INTO  Housing.MeterRead
                (
                      [meterReadTypeID_FK]
                     ,[meterID_FK]
                     ,[billPeriodID_FK]
                     ,[buildingDetailsID]
                     ,[buildingDetailsNo]
                     ,[dateOfRead]
                     ,[meterReadValue]
                     ,[meterReadActive]
                     ,[IdaraID_FK]
                     ,[entryDate]
                     ,[entryData]
                     ,[hostName]
                     
                )
                VALUES
                (
                      5
                    , @meterID
                    , COALESCE(@ActiveServicePeriodID, 1)
                    , @buildingDetailsID_FK
                    , @buildingDetailsNo 
                    , @LinkEffectiveDate
                    , @meterReadValue
                    , 1
                    , @IdaraId_FK
                    , GETDATE()
                    , @entryData
                    , @hostName
                );

                 SET @Identity_Insert1 = SCOPE_IDENTITY();
            IF @Identity_Insert1 IS NULL OR @Identity_Insert1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة  العداد - MeterForBuilding', 1; -- برمجي
            END



             SET @Note = N'{'
                + N'"meterForBuildingID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), '') + N'"'
                + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), '') + N'"'
                + N',"buildingDetailsID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID_FK), '') + N'"'
                + N',"meterForBuildingStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @LinkEffectiveDate), '') + N'"'
                + N',"meterForBuildingDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"meterForBuildingActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert1), '') + N'"'
                + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '5'), '') + N'"'
                + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), COALESCE(@ActiveServicePeriodID, 1)), '') + N'"'
                + N',"dateOfRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), @LinkEffectiveDate), '') + N'"'
                + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterReadValue), '') + N'"'
                + N',"meterReadActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'

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
                  N'[Housing].[MeterForBuilding],[Housing].[MeterRead]'
                , N'LINKMETERTOBUILDINGS'
                , ISNULL(@Identity_Insert, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم ربط العداد بالمبنى بنجاح' AS Message_;
            RETURN;
        END

----------------------------------------------------------------
-- UNLINKMETERTOBUILDINGS
----------------------------------------------------------------
ELSE IF @Action = N'UNLINKMETERTOBUILDINGS'
BEGIN

    ------------------------------------------------------------
    -- Validations
    ------------------------------------------------------------
    IF @meterForBuildingID IS NULL OR @meterForBuildingID <= 0
    BEGIN
        ;THROW 50001, N'رقم المرجعي لربط العداد مطلوب للالغاء', 1;
        END

    IF NOT EXISTS
    (
        SELECT 1
        FROM  Housing.MeterForBuilding m
        WHERE m.meterForBuildingID = @meterForBuildingID
          AND m.meterForBuildingActive = 1
    )
    BEGIN
        ;THROW 50001, N'ربط العداد غير موجود أو غير نشط', 1;
        END
    ------------------------------------------------------------
    -- Load link info (Building + Meter)
    ------------------------------------------------------------
    SELECT TOP (1)
        @meterID              = m.meterID_FK,
        @buildingDetailsID_FK  = m.buildingDetailsID_FK,
        @buildingDetailsNo1    = B.buildingDetailsNo,
        @IdaraId_FK            = COALESCE(m.IdaraId_FK, @IdaraId_FK),
        @LinkedServiceStartDate = m.meterForBuildingStartDate,
        @LinkedServiceTypeID    = meterType.meterServiceTypeID_FK
    FROM Housing.MeterForBuilding m
    INNER JOIN Housing.Meter meter ON meter.meterID = m.meterID_FK
    INNER JOIN Housing.MeterType meterType ON meterType.meterTypeID = meter.meterTypeID_FK
    INNER JOIN Housing.V_GetGeneralListForBuilding B ON B.buildingDetailsID = m.buildingDetailsID_FK
    WHERE m.meterForBuildingID = @meterForBuildingID;

    IF @meterID IS NULL OR @meterID <= 0
    BEGIN
        ;THROW 50001, N'لم يتم العثور على رقم العداد من ربط العداد', 1;
        END

    IF @buildingDetailsID_FK IS NULL OR @buildingDetailsID_FK <= 0
    BEGIN
        ;THROW 50001, N'لم يتم العثور على رقم المبنى من ربط العداد', 1;
        END

    SET @UnlinkBillToDate = TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(@meterEndDate)), N''));

    IF @UnlinkBillToDate IS NULL
        THROW 50001, N'تاريخ إلغاء الربط مطلوب أو غير صحيح', 1;

    IF @UnlinkBillToDate > CONVERT(date, GETDATE())
        THROW 50001, N'لا يمكن أن يكون تاريخ إلغاء الربط في المستقبل', 1;

    IF @LinkedServiceStartDate IS NOT NULL
       AND @UnlinkBillToDate < CONVERT(date, @LinkedServiceStartDate)
    BEGIN
        SET @UnlinkValidationMessage = N'لا يمكن أن يكون تاريخ إلغاء الربط قبل تاريخ بداية الربط '
            + CONVERT(nvarchar(10), CONVERT(date, @LinkedServiceStartDate), 105);
        THROW 50001, @UnlinkValidationMessage, 1;
    END;

    /*
       نعتمد نهاية الفترة المحاسبية لآخر فاتورة نشطة، وليس BillsToDate فقط؛
       فقد تكون الفاتورة جزئية بينما الفترة المحاسبية تغطي الشهر كاملاً.
    */
    SELECT TOP (1)
        @LastBilledPeriodEndDate = COALESCE
        (
            CONVERT(date, period.billPeriodEndDate),
            CONVERT(date, bill.BillsToDate)
        )
    FROM Housing.Bills bill
    INNER JOIN Housing.BillPeriod period
        ON period.billPeriodID = bill.CurrentPeriodID
    INNER JOIN Housing.BillPeriodType periodType
        ON periodType.billPeriodTypeID = period.billPeriodTypeID_FK
    WHERE bill.meterID = @meterID
      AND bill.BillActive = 1
      AND bill.meterServiceTypeID = @LinkedServiceTypeID
      AND periodType.meterServiceTypeID_FK = @LinkedServiceTypeID
      AND period.billPeriodEndDate IS NOT NULL
    ORDER BY
        CONVERT(date, period.billPeriodEndDate) DESC,
        bill.BillsID DESC;

    IF @LastBilledPeriodEndDate IS NOT NULL
    BEGIN
        SET @MinimumUnlinkDate = DATEADD(DAY, 1, @LastBilledPeriodEndDate);

        IF @UnlinkBillToDate < @MinimumUnlinkDate
        BEGIN
            SET @UnlinkValidationMessage = N'لا يمكن أن يكون تاريخ إلغاء الربط قبل '
                + CONVERT(nvarchar(10), @MinimumUnlinkDate, 105)
                + N'؛ لأن آخر فترة فاتورة مرصودة تنتهي في '
                + CONVERT(nvarchar(10), @LastBilledPeriodEndDate, 105);
            THROW 50001, @UnlinkValidationMessage, 1;
        END;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.MeterRead meterRead
        WHERE meterRead.meterID_FK = @meterID
          AND meterRead.meterReadActive = 1
          AND CONVERT(date, ISNULL(meterRead.dateOfRead, meterRead.entryDate)) > @UnlinkBillToDate
    )
        THROW 50001, N'لا يمكن إلغاء الربط بهذا التاريخ لوجود قراءة عداد نشطة بتاريخ لاحق', 1;

    ------------------------------------------------------------
    -- Load occupant info (resident + general)
    ------------------------------------------------------------
    SELECT TOP (1)
        @residentInfoID_FK = o.residentInfoID,
        @generalNo_FK      = o.generalNo
    FROM Housing.V_Occupant o
    WHERE o.buildingDetailsID = @buildingDetailsID_FK;

    ------------------------------------------------------------
    -- Insert MeterRead BEFORE unlink
    ------------------------------------------------------------
    IF @meterReadValue IS NULL
    BEGIN
        ;THROW 50001, N'قراءة العداد مطلوبة', 1;
        END

    /* دعم الروابط القديمة التي لم تكن تسجل خدمة المبنى عند ربط العداد. */
    IF @LinkedServiceTypeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM Housing.BuildingDetailsMeterServices buildingService
           WHERE buildingService.BuildingDetailsID_FK = @buildingDetailsID_FK
             AND buildingService.MeterServicesTypeID_FK = @LinkedServiceTypeID
             AND buildingService.IdaraId_FK = TRY_CONVERT(INT, @IdaraId_FK)
             AND buildingService.BuildingDetailsMeterServicesActive = 1
       )
    BEGIN
        INSERT Housing.BuildingDetailsMeterServices
        (
              BuildingDetailsID_FK, MeterServicesTypeID_FK
            , BuildingDetailsMeterServicesStartDate, BuildingDetailsMeterServicesActive
            , IdaraId_FK, entryDate, entryData, hostName
        )
        VALUES
        (
              @buildingDetailsID_FK, @LinkedServiceTypeID
            , COALESCE(@LinkedServiceStartDate, GETDATE()), 1
            , TRY_CONVERT(INT, @IdaraId_FK), GETDATE(), @entryData, @hostName
        );
    END;

    SET @UnlinkBillYear = YEAR(@UnlinkBillToDate);
    SET @UnlinkBillMonth = MONTH(@UnlinkBillToDate);

    EXEC Housing.GetOrCreateMonthlyBillPeriod
          @IdaraID = @IdaraId_FK
        , @MeterServiceTypeID = @LinkedServiceTypeID
        , @Year = @UnlinkBillYear
        , @Month = @UnlinkBillMonth
        , @EntryData = @entryData
        , @HostName = @hostName
        , @BillPeriodID = @UnlinkBillPeriodID OUTPUT;

    SELECT @UnlinkBillFromDate = DATEADD(DAY, 1, MAX(CONVERT(date, bill.BillsToDate)))
    FROM Housing.Bills bill
    WHERE bill.meterID = @meterID
      AND bill.BillActive = 1
      AND bill.BillsToDate IS NOT NULL
      AND CONVERT(date, bill.BillsToDate) < @UnlinkBillToDate;

    SET @UnlinkBillFromDate = COALESCE
    (
        @UnlinkBillFromDate,
        CONVERT(date, @LinkedServiceStartDate),
        @UnlinkBillToDate
    );

    IF @UnlinkBillFromDate > @UnlinkBillToDate
        THROW 50001, N'لا توجد مدة جديدة مستحقة لإصدار الفاتورة الختامية', 1;

    DECLARE @NewReadValue DECIMAL(18,2) = TRY_CONVERT(DECIMAL(18,2), NULLIF(LTRIM(RTRIM(@meterReadValue)), N''));
    DECLARE @LastReadValue DECIMAL(18,2) = NULL;
    DECLARE @AbnormalReadConfirmedBit BIT = CASE
        WHEN LOWER(LTRIM(RTRIM(ISNULL(@AbnormalReadConfirmed, N'')))) IN (N'1', N'true', N'on', N'yes') THEN 1
        ELSE 0 END;

    IF @NewReadValue IS NULL OR @NewReadValue < 0
    BEGIN
        ;THROW 50001, N'قراءة العداد غير صحيحة', 1;
    END

    SELECT TOP (1) @LastReadValue = TRY_CONVERT(DECIMAL(18,2), mr.meterReadValue)
    FROM Housing.MeterRead mr
    WHERE mr.meterID_FK = @meterID
      AND mr.meterReadActive = 1
      AND CONVERT(date, ISNULL(mr.dateOfRead, mr.entryDate)) <= @UnlinkBillToDate
    ORDER BY ISNULL(mr.dateOfRead, mr.entryDate) DESC, mr.meterReadID DESC;

    IF @LastReadValue IS NOT NULL
       AND @NewReadValue <= @LastReadValue
       AND @AbnormalReadConfirmedBit = 0
    BEGIN
        ;THROW 50001, N'القراءة الجديدة أقل من أو مساوية للقراءة السابقة. يجب التحقق من الفاتورة المتوقعة وتأكيد صحة القراءة قبل إلغاء الربط.', 1;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.CalculteElectrictyBills_ByNewReadValue(@meterID, @meterReadValue) preview
        WHERE preview.TotalPrice IS NOT NULL
    )
    BEGIN
        ;THROW 50001, N'تعذر حساب الفاتورة الختامية للعداد. يرجى التحقق من القراءة.', 1;
    END

    INSERT INTO  Housing.MeterRead
    (
        meterReadTypeID_FK,
        meterID_FK,
        billPeriodID_FK,     
        buildingDetailsID,
        buildingDetailsNo,
        residentInfoID_FK,
        generalNo_FK,
        dateOfRead,
        meterReadValue,
        meterReadActive,
        IdaraID_FK,
        entryDate,
        entryData,
        hostName
    )
    VALUES
    (
        6,
        @meterID,
        @UnlinkBillPeriodID,
        @buildingDetailsID_FK,
        @buildingDetailsNo1,
        @residentInfoID_FK,
        @generalNo_FK,
        @UnlinkBillToDate,
        @meterReadValue,
        1,
        @IdaraId_FK,
        GETDATE(),
        @entryData,
        @hostName
    );

    SET @Identity_Insert1 = SCOPE_IDENTITY();
    IF @Identity_Insert1 IS NULL OR @Identity_Insert1 <= 0
    BEGIN
        ;THROW 50002, N'حصل خطأ في إضافة قراءة العداد - MeterRead', 1;
        END
    ------------------------------------------------------------
    -- Issue bill BEFORE unlink (prevent duplicates)
    ------------------------------------------------------------
    INSERT INTO Housing.Bills
    (
        BillChargeTypeID_FK, BillTypeID_FK,
        PerviosPeriodID, CurrentPeriodID, PeriodMonth, PeriodYear, CurrentPeriodTax,
        meterNo, meterID, meterName_A, meterName_E, meterDescription,
        buildingDetailsNo, buildingUtilityTypeID, buildingDetailsID,
        meterTypeID, meterServiceTypeID, meterReadID, generalNo_FK,residentInfoID_FK,
        CurrentRead, LastRead, ReadDiff,
        meterSlideMinValue1, meterSlideMaxValue1, SlidePriceFactor1, PriceForSlide1,
        meterSlideMinValue2, meterSlideMaxValue2, SlidePriceFactor2, PriceForSlide2,
        meterSlideMinValue3, meterSlideMaxValue3, SlidePriceFactor3, PriceForSlide3,
        meterSlideMinValue4, meterSlideMaxValue4, SlidePriceFactor4, PriceForSlide4,
        meterSlideMinValue5, meterSlideMaxValue5, SlidePriceFactor5, PriceForSlide5,
        meterSlideMinValue6, meterSlideMaxValue6, SlidePriceFactor6, PriceForSlide6,
        meterSlideMinValue7, meterSlideMaxValue7, SlidePriceFactor7, PriceForSlide7,
        meterSlideMinValue8, meterSlideMaxValue8, SlidePriceFactor8, PriceForSlide8,
        meterSlideMinValue9, meterSlideMaxValue9, SlidePriceFactor9, PriceForSlide9,
        meterSlideMinValue10, meterSlideMaxValue10, SlidePriceFactor10, PriceForSlide10,
        PRICE, PRICETAX, meterServicePrice, meterServicePriceTAX, TotalPrice,
        BillsFromDate, BillsToDate,
        BillActive, entryData, hostName, idaraID_FK
    )
    SELECT
        f.BillChargeTypeID_FK,
        4,
        f.PerviosPeriodID, @UnlinkBillPeriodID, MONTH(@UnlinkBillToDate), YEAR(@UnlinkBillToDate), f.CurrentPeriodTax,
        f.meterNo, f.meterID, f.meterName_A, f.meterName_E, f.meterDescription,
        f.buildingDetailsNo, f.buildingUtilityTypeID, f.buildingDetailsID,
        f.meterTypeID, f.meterServiceTypeID, f.meterReadID, f.generalNo_FK,f.residentInfoID_FK,
        f.CurrentRead, f.LastRead, f.ReadDiff,
        f.meterSlideMinValue1, f.meterSlideMaxValue1, f.SlidePriceFactor1, f.PriceForSlide1,
        f.meterSlideMinValue2, f.meterSlideMaxValue2, f.SlidePriceFactor2, f.PriceForSlide2,
        f.meterSlideMinValue3, f.meterSlideMaxValue3, f.SlidePriceFactor3, f.PriceForSlide3,
        f.meterSlideMinValue4, f.meterSlideMaxValue4, f.SlidePriceFactor4, f.PriceForSlide4,
        f.meterSlideMinValue5, f.meterSlideMaxValue5, f.SlidePriceFactor5, f.PriceForSlide5,
        f.meterSlideMinValue6, f.meterSlideMaxValue6, f.SlidePriceFactor6, f.PriceForSlide6,
        f.meterSlideMinValue7, f.meterSlideMaxValue7, f.SlidePriceFactor7, f.PriceForSlide7,
        f.meterSlideMinValue8, f.meterSlideMaxValue8, f.SlidePriceFactor8, f.PriceForSlide8,
        f.meterSlideMinValue9, f.meterSlideMaxValue9, f.SlidePriceFactor9, f.PriceForSlide9,
        f.meterSlideMinValue10, f.meterSlideMaxValue10, f.SlidePriceFactor10, f.PriceForSlide10,
        f.PRICE, f.PRICETAX, f.meterServicePrice, f.meterServicePriceTAX, f.TotalPrice,
        @UnlinkBillFromDate, @UnlinkBillToDate,
        1,
        @entryData,
        @hostName,
        f.IdaraID_FK
    FROM Housing.CalculteElectrictyBills_ByLastActiveRead_PeriodSource(@meterID) f
    WHERE f.PRICE IS NOT NULL
      -- منع تكرار إصدار فاتورة لنفس القراءة
      AND f.meterReadID = @Identity_Insert1
      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.Bills b
          WHERE b.meterID = f.meterID
            AND b.meterReadID = f.meterReadID
            AND b.BillTypeID_FK = 4
            AND b.BillActive = 1
      );

    IF @@ROWCOUNT <= 0
    BEGIN
        ;THROW 50002, N'حصل خطأ في إصدار الفاتورة الختامية - Bills', 1;
    END

    ------------------------------------------------------------
    -- Unlink AFTER read & bill
    ------------------------------------------------------------
    UPDATE Housing.MeterForBuilding
    SET
        meterForBuildingEndDate = @UnlinkBillToDate,
        meterForBuildingActive  = 0,
        CanceledBy              = @entryData,
        CanceledDate            = GETDATE(),
        CanceledNote            = @Notes
    WHERE meterForBuildingID = @meterForBuildingID;

    IF @@ROWCOUNT <= 0
    BEGIN
        ;THROW 50002, N'حصل خطأ في الغاء ربط العداد - MeterForBuilding', 1;
        END
    ------------------------------------------------------------
    -- Audit Note
    ------------------------------------------------------------
    SET @Note = N'{'
        + N'"meterForBuildingID":"'        + ISNULL(CONVERT(NVARCHAR(MAX), @meterForBuildingID), '') + N'"'
        + N',"meterForBuildingEndDate":"'  + ISNULL(CONVERT(NVARCHAR(MAX), @UnlinkBillToDate), '') + N'"'
        + N',"CanceledBy":"'               + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
        + N',"CanceledDate":"'             + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
        + N',"CanceledNote":"'             + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
        + N',"meterForBuildingActive":0'
        + N',"meterReadID":"'              + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert1), '') + N'"'
        + N',"meterReadTypeID_FK":"6"'
        + N',"billPeriodID_FK":"'          + ISNULL(CONVERT(NVARCHAR(MAX), @UnlinkBillPeriodID), '') + N'"'
        + N',"dateOfRead":"'               + ISNULL(CONVERT(NVARCHAR(MAX), @UnlinkBillToDate), '') + N'"'
        + N',"meterReadValue":"'           + ISNULL(CONVERT(NVARCHAR(MAX), @meterReadValue), '') + N'"'
        + N',"IdaraId_FK":"'               + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraId_FK), '') + N'"'
        + N',"entryData":"'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
        + N',"entryDate":"'                + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
        + N',"hostName":"'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
        + N'}';

    INSERT INTO  dbo.AuditLog
    (
        TableName,
        ActionType,
        RecordID,
        PerformedBy,
        Notes
    )
    VALUES
    (
        N'[Housing].[MeterForBuilding],[Housing].[MeterRead],[Housing].[Bills]',
        N'UNLINKMETERTOBUILDINGS',
        ISNULL(@meterForBuildingID, 0),
        @entryData,
        @Note
    );

    SELECT 1 AS IsSuccessful, N'تم إضافة قراءة وإصدار فاتورة ثم الغاء ربط العداد بالمبنى بنجاح' AS Message_;
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
