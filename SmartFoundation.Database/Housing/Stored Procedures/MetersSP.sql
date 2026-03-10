

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
        , @Identity_Update2 BIGINT = NULL;

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
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة نوع العداد - MeterType', 1; -- برمجي
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

                update Housing.MeterType
                set meterTypeActive = 0
                where meterTypeID = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في تعديل نوع العداد - MeterType', 1; -- برمجي
                END

                 update Housing.MeterServicePrice
                set meterServicePriceActive = 0
                where meterTypeID_FK = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة نوع العداد - MeterServicePrice', 1; -- برمجي
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
                , 1
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل نوع العداد - MeterType', 1; -- برمجي
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
                    ;THROW 50003, N'حصل خطأ في تعديل نوع العداد - ResidentDetails', 1; -- برمجي
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
                , N'INSERTNEWMETERTYPE'
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

                 update Housing.MeterServicePrice
                set meterServicePriceActive = 0,meterServicePriceEndDate = GETDATE()
                where meterTypeID_FK = @meterTypeID_FK


                 IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في حذف نوع العداد - MeterServicePrice', 1; -- برمجي
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


                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في تحديث  العداد - MeterRead', 1; -- برمجي
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
                , GETDATE()
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
                    , 1
                    , @buildingDetailsID_FK
                    , @buildingDetailsNo 
                    , GETDATE()
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
                + N',"meterForBuildingStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"meterForBuildingDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"meterForBuildingActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert1), '') + N'"'
                + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '5'), '') + N'"'
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
        @IdaraId_FK            = COALESCE(m.IdaraId_FK, @IdaraId_FK)
    FROM Housing.MeterForBuilding m
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
    INSERT INTO  Housing.MeterRead
    (
        meterReadTypeID_FK,
        meterID_FK,
        billPeriodID_FK,     -- ⚠️ يفضّل لاحقاً تحسب CurrentPeriodID الحقيقي بدل (1)
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
        1,
        @buildingDetailsID_FK,
        @buildingDetailsNo1,
        @residentInfoID_FK,
        @generalNo_FK,
        GETDATE(),
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
        BillActive, entryData, hostName, idaraID_FK
    )
    SELECT
        f.BillChargeTypeID_FK,
        4,
        f.PerviosPeriodID, f.CurrentPeriodID, f.PeriodMonth, f.PeriodYear, f.CurrentPeriodTax,
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

    ------------------------------------------------------------
    -- Unlink AFTER read & bill
    ------------------------------------------------------------
    UPDATE Housing.MeterForBuilding
    SET
        meterForBuildingEndDate = GETDATE(),
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
        + N',"meterForBuildingEndDate":"'  + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
        + N',"CanceledBy":"'               + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
        + N',"CanceledDate":"'             + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
        + N',"CanceledNote":"'             + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
        + N',"meterForBuildingActive":0'
        + N',"meterReadID":"'              + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert1), '') + N'"'
        + N',"meterReadTypeID_FK":"6"'
        + N',"billPeriodID_FK":"1"'
        + N',"dateOfRead":"'               + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
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
