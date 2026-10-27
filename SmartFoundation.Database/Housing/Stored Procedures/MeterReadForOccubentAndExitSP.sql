
CREATE PROCEDURE [Housing].[MeterReadForOccubentAndExitSP] 
(

      @Action                               NVARCHAR(200)
    , @ActionID                             BIGINT          = NULL
    , @residentInfoID                       NVARCHAR(100)   = NULL
    , @NationalID                           NVARCHAR(100)   = NULL
    , @GeneralNo                            NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo             NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate           NVARCHAR(1000)  = NULL
    , @WaitingClassID                       NVARCHAR(1000)  = NULL
    , @WaitingClassName                     NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID                   NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeName                 NVARCHAR(1000)  = NULL
    , @waitingClassSequence                 NVARCHAR(1000)  = NULL
    , @WaitingListOrder                     NVARCHAR(1000)  = NULL
    , @FullName_A                           NVARCHAR(1000)  = NULL
    , @buildingDetailsID                    NVARCHAR(1000)  = NULL
    , @buildingDetailsNo                    NVARCHAR(1000)  = NULL
    , @AssignPeriodID                       NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @meterID                              NVARCHAR(1000)  = NULL
    , @MeterServiceTypeID                   NVARCHAR(1000)  = NULL
    , @buildingActionRoot                   NVARCHAR(1000)  = NULL
    , @NewMeterReadValue                    NVARCHAR(1000)  = NULL
    , @meterReadID                          NVARCHAR(1000)  = NULL
    , @ExitDate                             NVARCHAR(1000)  = NULL
    , @BillsID                             NVARCHAR(1000)  = NULL
    , @idaraID_FK                           NVARCHAR(10)    = NULL
    , @entryData                            NVARCHAR(20)    = NULL
    , @hostName                             NVARCHAR(200)   = NULL
)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL
        , @Note1  NVARCHAR(MAX) = NULL
        , @Note2  NVARCHAR(MAX) = NULL
        , @Note3  NVARCHAR(MAX) = NULL
        , @Identity_Insert BIGINT = NULL
        , @Identity_Insert1 BIGINT = NULL
        , @Identity_Insert2 BIGINT = NULL
        , @meterReadTypeID_FK INT ;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    --DECLARE @buildingDetailsNo nvarchar(200) 
    --set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);

    Declare @MeterServiceCount int
    set @MeterServiceCount =(select count(*) 
    from  Housing.MeterForBuilding m 
    where m.buildingDetailsID_FK = @buildingDetailsID 
    and m.meterForBuildingActive = 1 
    and (m.meterForBuildingEndDate is null or cast(m.meterForBuildingEndDate as date) > cast(GETDATE() as date))
    )

   



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

   


         IF @Action IN
(
    N'MeterRead',
    N'METERREADFOROCCUBENTANDEXIT',
    N'UPDATEMETERREADFOROCCUBENTANDEXIT'
)
BEGIN

    -- التحقق من معرف العداد
    IF NULLIF(LTRIM(RTRIM(@meterID)), N'') IS NULL
    BEGIN
        ;THROW 50001, N'معرف العداد غير مرسل بشكل صحيح', 1;
    END;

    -- التحقق من أن القراءة رقم صحيح غير سالب
    IF NULLIF(LTRIM(RTRIM(@NewMeterReadValue)), N'') IS NULL
       OR TRY_CONVERT(BIGINT, @NewMeterReadValue) IS NULL
       OR TRY_CONVERT(BIGINT, @NewMeterReadValue) < 0
    BEGIN
        ;THROW 50001, N'يجب إدخال قراءة عداد صحيحة (رقم صحيح غير سالب)', 1;
    END;

    -- بداية التعديل الجديد: التحقق من الحد الأعلى للعداد

    DECLARE @ConfiguredMeterMaxRead BIGINT;

    SELECT
        @ConfiguredMeterMaxRead = mt.meterMaxRead
    FROM Housing.Meter m
    INNER JOIN Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
    WHERE m.meterID = TRY_CONVERT(BIGINT, @meterID);

    IF @ConfiguredMeterMaxRead IS NULL
       OR @ConfiguredMeterMaxRead <= 0
    BEGIN
        ;THROW 50001, N'الحد الأقصى للعداد غير معرف بشكل صحيح', 1;
    END;

    IF TRY_CONVERT(BIGINT, @NewMeterReadValue)
       > @ConfiguredMeterMaxRead
    BEGIN
        ;THROW 50001, N'القراءة المدخلة تتجاوز الحد الأقصى المسموح لهذا العداد', 1;
    END;

    -- نهاية التعديل الجديد

END;

        

     

        ----------------------------------------------------------------
        -- METERREADFOROCCUBENTANDEXIT
        ----------------------------------------------------------------
        IF @Action = N'METERREADFOROCCUBENTANDEXIT'



            BEGIN

        IF(@buildingActionRoot = 2)
        BEGIN
        IF EXISTS (
                 SELECT 1
                 FROM Housing.Bills b
                 WHERE b.meterID = @meterID
                   AND b.residentInfoID_FK = @residentInfoID
                   AND b.meterServiceTypeID = @MeterServiceTypeID
                   AND b.idaraID_FK = @IdaraId_FK
                   AND b.BillActive = 1
                   AND b.BillTypeID_FK = 3
                   AND b.buildingDetailsID = @buildingDetailsID

                      )

            BEGIN
                ;THROW 50001, N'تمت قراءة هذا العداد مسبقا', 1;
            END
            END


             IF(@buildingActionRoot = 1)
        BEGIN
        IF EXISTS (
                 SELECT 1
                 FROM Housing.Bills b
                 WHERE b.meterID = @meterID
                   AND b.residentInfoID_FK = @residentInfoID
                   AND b.meterServiceTypeID = @MeterServiceTypeID
                   AND b.idaraID_FK = @IdaraId_FK
                   AND b.BillActive = 1
                   AND b.BillTypeID_FK = 2
                   AND b.buildingDetailsID = @buildingDetailsID

                      )

            BEGIN
                ;THROW 50001, N'تمت قراءة هذا العداد مسبقا', 1;
            END

            END


                     IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
           ) NOT in (46,59)
            BEGIN
                ;THROW 50001, N'تم قراءة عدادات الخدمات واعتمادها مسبقا او تم الغاء تسكين المستفيد', 1;
            END

            

            Declare @buildingActionTypeID_ INT

            select TOP(1)
            @buildingActionTypeID_ =
            case 
            when w.LastActionTypeID = 46  then 47
            when w.LastActionTypeID = 59  then 60
            else 
            9999
            END
           
           
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID
            --AND W.LastActionTypeID IN (46,59)

            IF 
            (
               @buildingActionTypeID_ = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type Meter read', 1;
            END






            
                IF(@buildingActionRoot = 2)
                BEGIN
                set @meterReadTypeID_FK = 3
                END

                 IF(@buildingActionRoot = 1)
                BEGIN
                set @meterReadTypeID_FK = 1
                END



                
            --          INSERT INTO  Housing.BuildingAction
            --(
            --      buildingActionTypeID_FK
            --    , residentInfoID_FK
            --    , generalNo_FK
            --    , buildingActionDecisionNo
            --    , buildingActionDecisionDate
            --    , buildingDetailsID_FK
            --    , buildingDetailsNo
            --    , buildingActionActive
            --    , CustdyRecord
            --    , buildingActionParentID
            --    , AssignPeriodID_FK
            --    , buildingActionDate
            --    , IdaraId_FK
            --    , entryData
            --    , hostName
            --)
            
            -- VALUES
            --(
            --      @buildingActionTypeID_
            --    , @residentInfoID
            --    , @GeneralNo
            --    , @buildingActionDecisionNo
            --    , @buildingActionDecisionDate
            --    , @buildingDetailsID
            --    , @buildingDetailsNo
            --    , 1
            --    , @Notes
            --    , @LastActionID
            --    , @AssignPeriodID
            --    , @ExitDate
            --    , @IdaraID_INT
            --    , @entryData
            --    , @hostName
            --);


            
            --IF @@ROWCOUNT = 0
            --BEGIN
            --    ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد', 1; -- برمجي
            --END

            --SET @NewID = SCOPE_IDENTITY();
            --IF @NewID IS NULL OR @NewID <= 0
            --BEGIN
            --    ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد - Identity', 1; -- برمجي
            --END
            --SET @Note2 = N'{'
            --    + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
            --    + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_), '') + N'"'
            --    + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
            --    + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
            --    + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
            --    + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
            --    + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
            --    + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
            --    + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
            --    + N',"CustdyRecord": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
            --    + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
            --    + N',"AssignPeriodID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @AssignPeriodID), '') + N'"'
            --    + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            --    + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
            --    + N'}';

            --INSERT INTO  dbo.AuditLog
            --(
            --      TableName
            --    , ActionType
            --    , RecordID
            --    , PerformedBy
            --    , Notes
            --)
            --VALUES
            --(
            --      N'[Housing].[BuildingAction]'
            --    , N'METERREADFOROCCUBENTANDEXIT'
            --    , @ActionID
            --    , @entryData
            --    , @Note2
            --);

           



              INSERT INTO  Housing.[MeterRead]
            (

                   [meterReadTypeID_FK]
                  ,[meterID_FK]
                  ,[billPeriodID_FK]
                  ,[residentInfoID_FK]
                  ,[generalNo_FK]
                  ,[buildingDetailsID]
                  ,[buildingDetailsNo]
                  ,[dateOfRead]
                  ,[meterReadValue]
                  ,[buildingActionID_FK]
                  ,[meterReadActive]
                  ,[IdaraID_FK]
                  ,[entryData]
                  ,[hostName]
                  
                
            )
            
             VALUES
            (
                  @meterReadTypeID_FK
                , @meterID
                , 1
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , GETDATE()
                , @NewMeterReadValue
                , @LastActionID
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


             SET @Identity_Insert = SCOPE_IDENTITY();


            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
             BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد - MeterRead', 1; -- برمجي
            END


            SET @NewID = @Identity_Insert;



           SET @Note = N'{'
                            + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                            + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), 2), N'') + N'"'
                            + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), N'') + N'"'
                            + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), 1), N'') + N'"'
                            + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), N'') + N'"'
                            + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                            + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), N'') + N'"'
                            + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), N'') + N'"'
                            + N',"dateOfRead": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
                            + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewMeterReadValue), N'') + N'"'
                            + N',"buildingActionID_FK": ""'
                            + N',"meterReadActive": "1"'
                            + N',"IdaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                            + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                            + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), N'') + N'"'
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
                  N'[Housing].[MeterRead]'
                , @Action
                , @Identity_Insert
                , @entryData
                , @Note
            );




             IF(@buildingActionRoot = 2)
                BEGIN
               


            ----------------------
            DECLARE @InsertedBills TABLE
(
      BillID BIGINT
    , BillChargeTypeID_FK INT
    , BillTypeID_FK INT
    , PerviosPeriodID INT
    , CurrentPeriodID INT
    , PeriodMonth INT
    , PeriodYear INT
    , CurrentPeriodTax DECIMAL(18,2)
    , meterNo NVARCHAR(200)
    , meterID BIGINT
    , meterName_A NVARCHAR(200)
    , meterName_E NVARCHAR(200)
    , meterDescription NVARCHAR(MAX)
    , buildingDetailsNo NVARCHAR(200)
    , buildingUtilityTypeID INT
    , buildingDetailsID BIGINT
    , meterTypeID INT
    , meterServiceTypeID INT
    , meterReadID BIGINT
    , residentInfoID_FK BIGINT
    , generalNo_FK BIGINT
    , CurrentRead DECIMAL(18,2)
    , LastRead DECIMAL(18,2)
    , ReadDiff DECIMAL(18,2)
    , meterSlideMinValue1 DECIMAL(18,2)
    , meterSlideMaxValue1 DECIMAL(18,2)
    , SlidePriceFactor1 DECIMAL(18,2)
    , PriceForSlide1 DECIMAL(18,2)
    , meterSlideMinValue2 DECIMAL(18,2)
    , meterSlideMaxValue2 DECIMAL(18,2)
    , SlidePriceFactor2 DECIMAL(18,2)
    , PriceForSlide2 DECIMAL(18,2)
    , meterSlideMinValue3 DECIMAL(18,2)
    , meterSlideMaxValue3 DECIMAL(18,2)
    , SlidePriceFactor3 DECIMAL(18,2)
    , PriceForSlide3 DECIMAL(18,2)
    , meterSlideMinValue4 DECIMAL(18,2)
    , meterSlideMaxValue4 DECIMAL(18,2)
    , SlidePriceFactor4 DECIMAL(18,2)
    , PriceForSlide4 DECIMAL(18,2)
    , meterSlideMinValue5 DECIMAL(18,2)
    , meterSlideMaxValue5 DECIMAL(18,2)
    , SlidePriceFactor5 DECIMAL(18,2)
    , PriceForSlide5 DECIMAL(18,2)
    , meterSlideMinValue6 DECIMAL(18,2)
    , meterSlideMaxValue6 DECIMAL(18,2)
    , SlidePriceFactor6 DECIMAL(18,2)
    , PriceForSlide6 DECIMAL(18,2)
    , meterSlideMinValue7 DECIMAL(18,2)
    , meterSlideMaxValue7 DECIMAL(18,2)
    , SlidePriceFactor7 DECIMAL(18,2)
    , PriceForSlide7 DECIMAL(18,2)
    , meterSlideMinValue8 DECIMAL(18,2)
    , meterSlideMaxValue8 DECIMAL(18,2)
    , SlidePriceFactor8 DECIMAL(18,2)
    , PriceForSlide8 DECIMAL(18,2)
    , meterSlideMinValue9 DECIMAL(18,2)
    , meterSlideMaxValue9 DECIMAL(18,2)
    , SlidePriceFactor9 DECIMAL(18,2)
    , PriceForSlide9 DECIMAL(18,2)
    , meterSlideMinValue10 DECIMAL(18,2)
    , meterSlideMaxValue10 DECIMAL(18,2)
    , SlidePriceFactor10 DECIMAL(18,2)
    , PriceForSlide10 DECIMAL(18,2)
    , PRICE DECIMAL(18,2)
    , PRICETAX DECIMAL(18,2)
    , meterServicePrice DECIMAL(18,2)
    , meterServicePriceTAX DECIMAL(18,2)
    , TotalPrice DECIMAL(18,2)
    , BillActive BIT
    , idaraID_FK INT
    , entryDate DATETIME
    , entryData NVARCHAR(200)
    , hostName NVARCHAR(200)
);
            
            INSERT INTO [DATACORE].[Housing].[Bills]
(
      [BillChargeTypeID_FK]
    , [BillTypeID_FK]
    , [PerviosPeriodID]
    , [CurrentPeriodID]
    , [PeriodMonth]
    , [PeriodYear]
    , [CurrentPeriodTax]
    , [meterNo]
    , [meterID]
    , [meterName_A]
    , [meterName_E]
    , [meterDescription]
    , [buildingDetailsNo]
    , [buildingUtilityTypeID]
    , [buildingDetailsID]
    , [meterTypeID]
    , [meterServiceTypeID]
    , [meterReadID]
    , [residentInfoID_FK]
    , [generalNo_FK]
    , [CurrentRead]
    , [LastRead]
    , [ReadDiff]
    , [meterSlideMinValue1]
    , [meterSlideMaxValue1]
    , [SlidePriceFactor1]
    , [PriceForSlide1]
    , [meterSlideMinValue2]
    , [meterSlideMaxValue2]
    , [SlidePriceFactor2]
    , [PriceForSlide2]
    , [meterSlideMinValue3]
    , [meterSlideMaxValue3]
    , [SlidePriceFactor3]
    , [PriceForSlide3]
    , [meterSlideMinValue4]
    , [meterSlideMaxValue4]
    , [SlidePriceFactor4]
    , [PriceForSlide4]
    , [meterSlideMinValue5]
    , [meterSlideMaxValue5]
    , [SlidePriceFactor5]
    , [PriceForSlide5]
    , [meterSlideMinValue6]
    , [meterSlideMaxValue6]
    , [SlidePriceFactor6]
    , [PriceForSlide6]
    , [meterSlideMinValue7]
    , [meterSlideMaxValue7]
    , [SlidePriceFactor7]
    , [PriceForSlide7]
    , [meterSlideMinValue8]
    , [meterSlideMaxValue8]
    , [SlidePriceFactor8]
    , [PriceForSlide8]
    , [meterSlideMinValue9]
    , [meterSlideMaxValue9]
    , [SlidePriceFactor9]
    , [PriceForSlide9]
    , [meterSlideMinValue10]
    , [meterSlideMaxValue10]
    , [SlidePriceFactor10]
    , [PriceForSlide10]
    , [PRICE]
    , [PRICETAX]
    , [meterServicePrice]
    , [meterServicePriceTAX]
    , [TotalPrice]
    , [BillActive]
    , [idaraID_FK]
    , [entryDate]
    , [entryData]
    , [hostName]
)
OUTPUT
      INSERTED.BillsID
    , INSERTED.BillChargeTypeID_FK
    , INSERTED.BillTypeID_FK
    , INSERTED.PerviosPeriodID
    , 1
    , INSERTED.PeriodMonth
    , INSERTED.PeriodYear
    , INSERTED.CurrentPeriodTax
    , INSERTED.meterNo
    , INSERTED.meterID
    , INSERTED.meterName_A
    , INSERTED.meterName_E
    , INSERTED.meterDescription
    , INSERTED.buildingDetailsNo
    , INSERTED.buildingUtilityTypeID
    , @buildingDetailsID
    , INSERTED.meterTypeID
    , INSERTED.meterServiceTypeID
    , @Identity_Insert
    , @residentInfoID
    , @GeneralNo
    , INSERTED.CurrentRead
    , INSERTED.LastRead
    , INSERTED.ReadDiff
    , INSERTED.meterSlideMinValue1
    , INSERTED.meterSlideMaxValue1
    , INSERTED.SlidePriceFactor1
    , INSERTED.PriceForSlide1
    , INSERTED.meterSlideMinValue2
    , INSERTED.meterSlideMaxValue2
    , INSERTED.SlidePriceFactor2
    , INSERTED.PriceForSlide2
    , INSERTED.meterSlideMinValue3
    , INSERTED.meterSlideMaxValue3
    , INSERTED.SlidePriceFactor3
    , INSERTED.PriceForSlide3
    , INSERTED.meterSlideMinValue4
    , INSERTED.meterSlideMaxValue4
    , INSERTED.SlidePriceFactor4
    , INSERTED.PriceForSlide4
    , INSERTED.meterSlideMinValue5
    , INSERTED.meterSlideMaxValue5
    , INSERTED.SlidePriceFactor5
    , INSERTED.PriceForSlide5
    , INSERTED.meterSlideMinValue6
    , INSERTED.meterSlideMaxValue6
    , INSERTED.SlidePriceFactor6
    , INSERTED.PriceForSlide6
    , INSERTED.meterSlideMinValue7
    , INSERTED.meterSlideMaxValue7
    , INSERTED.SlidePriceFactor7
    , INSERTED.PriceForSlide7
    , INSERTED.meterSlideMinValue8
    , INSERTED.meterSlideMaxValue8
    , INSERTED.SlidePriceFactor8
    , INSERTED.PriceForSlide8
    , INSERTED.meterSlideMinValue9
    , INSERTED.meterSlideMaxValue9
    , INSERTED.SlidePriceFactor9
    , INSERTED.PriceForSlide9
    , INSERTED.meterSlideMinValue10
    , INSERTED.meterSlideMaxValue10
    , INSERTED.SlidePriceFactor10
    , INSERTED.PriceForSlide10
    , INSERTED.PRICE
    , INSERTED.PRICETAX
    , INSERTED.meterServicePrice
    , INSERTED.meterServicePriceTAX
    , INSERTED.TotalPrice
    , INSERTED.BillActive
    , INSERTED.idaraID_FK
    , INSERTED.entryDate
    , INSERTED.entryData
    , INSERTED.hostName
INTO @InsertedBills
SELECT
      (SELECT TOP (1) bb.BillChargeTypeID
       FROM Housing.BillChargeType bb
       WHERE bb.MeterServiceTypeID_FK = @MeterServiceTypeID)
    , @meterReadTypeID_FK
    , s.PerviosPeriodID
    , 1
    , s.PeriodMonth
    , s.PeriodYear
    , s.CurrentPeriodTax
    , s.meterNo
    , s.meterID
    , s.meterName_A
    , s.meterName_E
    , s.meterDescription
    , s.buildingDetailsNo
    , s.buildingUtilityTypeID
    , @buildingDetailsID
    , s.meterTypeID
    , s.meterServiceTypeID
    , @Identity_Insert
    , @residentInfoID
    , @GeneralNo
    , s.CurrentRead
    , s.LastRead
    , s.ReadDiff
    , s.meterSlideMinValue1
    , s.meterSlideMaxValue1
    , s.SlidePriceFactor1
    , s.PriceForSlide1
    , s.meterSlideMinValue2
    , s.meterSlideMaxValue2
    , s.SlidePriceFactor2
    , s.PriceForSlide2
    , s.meterSlideMinValue3
    , s.meterSlideMaxValue3
    , s.SlidePriceFactor3
    , s.PriceForSlide3
    , s.meterSlideMinValue4
    , s.meterSlideMaxValue4
    , s.SlidePriceFactor4
    , s.PriceForSlide4
    , s.meterSlideMinValue5
    , s.meterSlideMaxValue5
    , s.SlidePriceFactor5
    , s.PriceForSlide5
    , s.meterSlideMinValue6
    , s.meterSlideMaxValue6
    , s.SlidePriceFactor6
    , s.PriceForSlide6
    , s.meterSlideMinValue7
    , s.meterSlideMaxValue7
    , s.SlidePriceFactor7
    , s.PriceForSlide7
    , s.meterSlideMinValue8
    , s.meterSlideMaxValue8
    , s.SlidePriceFactor8
    , s.PriceForSlide8
    , s.meterSlideMinValue9
    , s.meterSlideMaxValue9
    , s.SlidePriceFactor9
    , s.PriceForSlide9
    , s.meterSlideMinValue10
    , s.meterSlideMaxValue10
    , s.SlidePriceFactor10
    , s.PriceForSlide10
    , s.PRICE
    , s.PRICETAX
    , s.meterServicePrice
    , s.meterServicePriceTAX
    , s.TotalPrice
    , 1
    , @IdaraID_INT
    , GETDATE()
    , @entryData
    , @hostName
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @NewMeterReadValue,@Identity_Insert) s;



             


            IF NOT EXISTS (SELECT 1 FROM @InsertedBills)
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل الفاتورة - Bills', 1;
            END;

            SELECT TOP (1) @Identity_Insert1 = BillID
            FROM @InsertedBills;

           SELECT TOP (1)
                            @Note1 = N'{'
                                + N'"BillID": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillID), N'') + N'"'
                                + N',"BillChargeTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillChargeTypeID_FK), N'') + N'"'
                                + N',"BillTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillTypeID_FK), N'') + N'"'
                                + N',"PerviosPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), PerviosPeriodID), N'') + N'"'
                                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodID), N'') + N'"'
                                + N',"PeriodMonth": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodMonth), N'') + N'"'
                                + N',"PeriodYear": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodYear), N'') + N'"'
                                + N',"CurrentPeriodTax": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodTax), N'') + N'"'
                                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterNo), N'') + N'"'
                                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterID), N'') + N'"'
                                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_A), N'') + N'"'
                                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_E), N'') + N'"'
                                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterDescription), N'') + N'"'
                                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsNo), N'') + N'"'
                                + N',"buildingUtilityTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingUtilityTypeID), N'') + N'"'
                                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsID), N'') + N'"'
                                + N',"meterTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterTypeID), N'') + N'"'
                                + N',"meterServiceTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServiceTypeID), N'') + N'"'
                                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), residentInfoID_FK), N'') + N'"'
                                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), generalNo_FK), N'') + N'"'
                                + N',"CurrentRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentRead), N'') + N'"'
                                + N',"LastRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), LastRead), N'') + N'"'
                                + N',"ReadDiff": "' + ISNULL(CONVERT(NVARCHAR(MAX), ReadDiff), N'') + N'"'
                        
                                + N',"meterSlideMinValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue1), N'') + N'"'
                                + N',"meterSlideMaxValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue1), N'') + N'"'
                                + N',"SlidePriceFactor1": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor1), N'') + N'"'
                                + N',"PriceForSlide1": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide1), N'') + N'"'
                        
                                + N',"meterSlideMinValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue2), N'') + N'"'
                                + N',"meterSlideMaxValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue2), N'') + N'"'
                                + N',"SlidePriceFactor2": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor2), N'') + N'"'
                                + N',"PriceForSlide2": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide2), N'') + N'"'
                        
                                + N',"meterSlideMinValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue3), N'') + N'"'
                                + N',"meterSlideMaxValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue3), N'') + N'"'
                                + N',"SlidePriceFactor3": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor3), N'') + N'"'
                                + N',"PriceForSlide3": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide3), N'') + N'"'
                        
                                + N',"meterSlideMinValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue4), N'') + N'"'
                                + N',"meterSlideMaxValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue4), N'') + N'"'
                                + N',"SlidePriceFactor4": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor4), N'') + N'"'
                                + N',"PriceForSlide4": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide4), N'') + N'"'
                        
                                + N',"meterSlideMinValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue5), N'') + N'"'
                                + N',"meterSlideMaxValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue5), N'') + N'"'
                                + N',"SlidePriceFactor5": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor5), N'') + N'"'
                                + N',"PriceForSlide5": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide5), N'') + N'"'
                        
                                + N',"meterSlideMinValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue6), N'') + N'"'
                                + N',"meterSlideMaxValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue6), N'') + N'"'
                                + N',"SlidePriceFactor6": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor6), N'') + N'"'
                                + N',"PriceForSlide6": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide6), N'') + N'"'
                        
                                + N',"meterSlideMinValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue7), N'') + N'"'
                                + N',"meterSlideMaxValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue7), N'') + N'"'
                                + N',"SlidePriceFactor7": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor7), N'') + N'"'
                                + N',"PriceForSlide7": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide7), N'') + N'"'
                        
                                + N',"meterSlideMinValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue8), N'') + N'"'
                                + N',"meterSlideMaxValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue8), N'') + N'"'
                                + N',"SlidePriceFactor8": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor8), N'') + N'"'
                                + N',"PriceForSlide8": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide8), N'') + N'"'
                        
                                + N',"meterSlideMinValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue9), N'') + N'"'
                                + N',"meterSlideMaxValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue9), N'') + N'"'
                                + N',"SlidePriceFactor9": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor9), N'') + N'"'
                                + N',"PriceForSlide9": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide9), N'') + N'"'
                        
                                + N',"meterSlideMinValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue10), N'') + N'"'
                                + N',"meterSlideMaxValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue10), N'') + N'"'
                                + N',"SlidePriceFactor10": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor10), N'') + N'"'
                                + N',"PriceForSlide10": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide10), N'') + N'"'
                        
                                + N',"PRICE": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICE), N'') + N'"'
                                + N',"PRICETAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICETAX), N'') + N'"'
                                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePrice), N'') + N'"'
                                + N',"meterServicePriceTAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePriceTAX), N'') + N'"'
                                + N',"TotalPrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), TotalPrice), N'') + N'"'
                                + N',"BillActive": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillActive), N'') + N'"'
                                + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), idaraID_FK), N'') + N'"'
                                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(19), entryDate, 120), N'') + N'"'
                                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), entryData), N'') + N'"'
                                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), hostName), N'') + N'"'
                                + N'}'
                        FROM @InsertedBills;

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
                  N'[Housing].[Bills]'
                , @Action
                , @Identity_Insert1
                , @entryData
                , @Note1
            );



           END




           

             IF(@buildingActionRoot = 1)
                BEGIN
               


            ----------------------
            DECLARE @InsertedBillsocc TABLE
(
      BillID BIGINT
    , BillChargeTypeID_FK INT
    , BillTypeID_FK INT
    , PerviosPeriodID INT
    , CurrentPeriodID INT
    , PeriodMonth INT
    , PeriodYear INT
    , CurrentPeriodTax DECIMAL(18,2)
    , meterNo NVARCHAR(200)
    , meterID BIGINT
    , meterName_A NVARCHAR(200)
    , meterName_E NVARCHAR(200)
    , meterDescription NVARCHAR(MAX)
    , buildingDetailsNo NVARCHAR(200)
    , buildingUtilityTypeID INT
    , buildingDetailsID BIGINT
    , meterTypeID INT
    , meterServiceTypeID INT
    , meterReadID BIGINT
    , residentInfoID_FK BIGINT
    , generalNo_FK BIGINT
    , CurrentRead DECIMAL(18,2)
    , LastRead DECIMAL(18,2)
    , ReadDiff DECIMAL(18,2)
    , meterSlideMinValue1 DECIMAL(18,2)
    , meterSlideMaxValue1 DECIMAL(18,2)
    , SlidePriceFactor1 DECIMAL(18,2)
    , PriceForSlide1 DECIMAL(18,2)
    , meterSlideMinValue2 DECIMAL(18,2)
    , meterSlideMaxValue2 DECIMAL(18,2)
    , SlidePriceFactor2 DECIMAL(18,2)
    , PriceForSlide2 DECIMAL(18,2)
    , meterSlideMinValue3 DECIMAL(18,2)
    , meterSlideMaxValue3 DECIMAL(18,2)
    , SlidePriceFactor3 DECIMAL(18,2)
    , PriceForSlide3 DECIMAL(18,2)
    , meterSlideMinValue4 DECIMAL(18,2)
    , meterSlideMaxValue4 DECIMAL(18,2)
    , SlidePriceFactor4 DECIMAL(18,2)
    , PriceForSlide4 DECIMAL(18,2)
    , meterSlideMinValue5 DECIMAL(18,2)
    , meterSlideMaxValue5 DECIMAL(18,2)
    , SlidePriceFactor5 DECIMAL(18,2)
    , PriceForSlide5 DECIMAL(18,2)
    , meterSlideMinValue6 DECIMAL(18,2)
    , meterSlideMaxValue6 DECIMAL(18,2)
    , SlidePriceFactor6 DECIMAL(18,2)
    , PriceForSlide6 DECIMAL(18,2)
    , meterSlideMinValue7 DECIMAL(18,2)
    , meterSlideMaxValue7 DECIMAL(18,2)
    , SlidePriceFactor7 DECIMAL(18,2)
    , PriceForSlide7 DECIMAL(18,2)
    , meterSlideMinValue8 DECIMAL(18,2)
    , meterSlideMaxValue8 DECIMAL(18,2)
    , SlidePriceFactor8 DECIMAL(18,2)
    , PriceForSlide8 DECIMAL(18,2)
    , meterSlideMinValue9 DECIMAL(18,2)
    , meterSlideMaxValue9 DECIMAL(18,2)
    , SlidePriceFactor9 DECIMAL(18,2)
    , PriceForSlide9 DECIMAL(18,2)
    , meterSlideMinValue10 DECIMAL(18,2)
    , meterSlideMaxValue10 DECIMAL(18,2)
    , SlidePriceFactor10 DECIMAL(18,2)
    , PriceForSlide10 DECIMAL(18,2)
    , PRICE DECIMAL(18,2)
    , PRICETAX DECIMAL(18,2)
    , meterServicePrice DECIMAL(18,2)
    , meterServicePriceTAX DECIMAL(18,2)
    , TotalPrice DECIMAL(18,2)
    , BillActive BIT
    , idaraID_FK INT
    , entryDate DATETIME
    , entryData NVARCHAR(200)
    , hostName NVARCHAR(200)
);
            
            INSERT INTO [DATACORE].[Housing].[Bills]
(
      [BillChargeTypeID_FK]
    , [BillTypeID_FK]
    , [PerviosPeriodID]
    , [CurrentPeriodID]
    , [PeriodMonth]
    , [PeriodYear]
    , [CurrentPeriodTax]
    , [meterNo]
    , [meterID]
    , [meterName_A]
    , [meterName_E]
    , [meterDescription]
    , [buildingDetailsNo]
    , [buildingUtilityTypeID]
    , [buildingDetailsID]
    , [meterTypeID]
    , [meterServiceTypeID]
    , [meterReadID]
    , [residentInfoID_FK]
    , [generalNo_FK]
    , [CurrentRead]
    , [LastRead]
    , [ReadDiff]
    , [meterSlideMinValue1]
    , [meterSlideMaxValue1]
    , [SlidePriceFactor1]
    , [PriceForSlide1]
    , [meterSlideMinValue2]
    , [meterSlideMaxValue2]
    , [SlidePriceFactor2]
    , [PriceForSlide2]
    , [meterSlideMinValue3]
    , [meterSlideMaxValue3]
    , [SlidePriceFactor3]
    , [PriceForSlide3]
    , [meterSlideMinValue4]
    , [meterSlideMaxValue4]
    , [SlidePriceFactor4]
    , [PriceForSlide4]
    , [meterSlideMinValue5]
    , [meterSlideMaxValue5]
    , [SlidePriceFactor5]
    , [PriceForSlide5]
    , [meterSlideMinValue6]
    , [meterSlideMaxValue6]
    , [SlidePriceFactor6]
    , [PriceForSlide6]
    , [meterSlideMinValue7]
    , [meterSlideMaxValue7]
    , [SlidePriceFactor7]
    , [PriceForSlide7]
    , [meterSlideMinValue8]
    , [meterSlideMaxValue8]
    , [SlidePriceFactor8]
    , [PriceForSlide8]
    , [meterSlideMinValue9]
    , [meterSlideMaxValue9]
    , [SlidePriceFactor9]
    , [PriceForSlide9]
    , [meterSlideMinValue10]
    , [meterSlideMaxValue10]
    , [SlidePriceFactor10]
    , [PriceForSlide10]
    , [PRICE]
    , [PRICETAX]
    , [meterServicePrice]
    , [meterServicePriceTAX]
    , [TotalPrice]
    , [BillActive]
    , [idaraID_FK]
    , [entryDate]
    , [entryData]
    , [hostName]
)
OUTPUT
      INSERTED.BillsID
    , INSERTED.BillChargeTypeID_FK
    , INSERTED.BillTypeID_FK
    , INSERTED.PerviosPeriodID
    , 1
    , INSERTED.PeriodMonth
    , INSERTED.PeriodYear
    , INSERTED.CurrentPeriodTax
    , INSERTED.meterNo
    , INSERTED.meterID
    , INSERTED.meterName_A
    , INSERTED.meterName_E
    , INSERTED.meterDescription
    , INSERTED.buildingDetailsNo
    , INSERTED.buildingUtilityTypeID
    , @buildingDetailsID
    , INSERTED.meterTypeID
    , INSERTED.meterServiceTypeID
    , @Identity_Insert
    , NULL
    , NULL
    , INSERTED.CurrentRead
    , INSERTED.LastRead
    , INSERTED.ReadDiff
    , INSERTED.meterSlideMinValue1
    , INSERTED.meterSlideMaxValue1
    , INSERTED.SlidePriceFactor1
    , INSERTED.PriceForSlide1
    , INSERTED.meterSlideMinValue2
    , INSERTED.meterSlideMaxValue2
    , INSERTED.SlidePriceFactor2
    , INSERTED.PriceForSlide2
    , INSERTED.meterSlideMinValue3
    , INSERTED.meterSlideMaxValue3
    , INSERTED.SlidePriceFactor3
    , INSERTED.PriceForSlide3
    , INSERTED.meterSlideMinValue4
    , INSERTED.meterSlideMaxValue4
    , INSERTED.SlidePriceFactor4
    , INSERTED.PriceForSlide4
    , INSERTED.meterSlideMinValue5
    , INSERTED.meterSlideMaxValue5
    , INSERTED.SlidePriceFactor5
    , INSERTED.PriceForSlide5
    , INSERTED.meterSlideMinValue6
    , INSERTED.meterSlideMaxValue6
    , INSERTED.SlidePriceFactor6
    , INSERTED.PriceForSlide6
    , INSERTED.meterSlideMinValue7
    , INSERTED.meterSlideMaxValue7
    , INSERTED.SlidePriceFactor7
    , INSERTED.PriceForSlide7
    , INSERTED.meterSlideMinValue8
    , INSERTED.meterSlideMaxValue8
    , INSERTED.SlidePriceFactor8
    , INSERTED.PriceForSlide8
    , INSERTED.meterSlideMinValue9
    , INSERTED.meterSlideMaxValue9
    , INSERTED.SlidePriceFactor9
    , INSERTED.PriceForSlide9
    , INSERTED.meterSlideMinValue10
    , INSERTED.meterSlideMaxValue10
    , INSERTED.SlidePriceFactor10
    , INSERTED.PriceForSlide10
    , INSERTED.PRICE
    , INSERTED.PRICETAX
    , INSERTED.meterServicePrice
    , INSERTED.meterServicePriceTAX
    , INSERTED.TotalPrice
    , INSERTED.BillActive
    , INSERTED.idaraID_FK
    , INSERTED.entryDate
    , INSERTED.entryData
    , INSERTED.hostName
INTO @InsertedBillsocc
SELECT
      (SELECT TOP (1) bb.BillChargeTypeID
       FROM Housing.BillChargeType bb
       WHERE bb.MeterServiceTypeID_FK = @MeterServiceTypeID)
    , @meterReadTypeID_FK
    , s.PerviosPeriodID
    , 1
    , s.PeriodMonth
    , s.PeriodYear
    , s.CurrentPeriodTax
    , s.meterNo
    , s.meterID
    , s.meterName_A
    , s.meterName_E
    , s.meterDescription
    , s.buildingDetailsNo
    , s.buildingUtilityTypeID
    , @buildingDetailsID
    , s.meterTypeID
    , s.meterServiceTypeID
    , @Identity_Insert
    , NULL
    , NULL
    , s.CurrentRead
    , s.LastRead
    , s.ReadDiff
    , s.meterSlideMinValue1
    , s.meterSlideMaxValue1
    , s.SlidePriceFactor1
    , s.PriceForSlide1
    , s.meterSlideMinValue2
    , s.meterSlideMaxValue2
    , s.SlidePriceFactor2
    , s.PriceForSlide2
    , s.meterSlideMinValue3
    , s.meterSlideMaxValue3
    , s.SlidePriceFactor3
    , s.PriceForSlide3
    , s.meterSlideMinValue4
    , s.meterSlideMaxValue4
    , s.SlidePriceFactor4
    , s.PriceForSlide4
    , s.meterSlideMinValue5
    , s.meterSlideMaxValue5
    , s.SlidePriceFactor5
    , s.PriceForSlide5
    , s.meterSlideMinValue6
    , s.meterSlideMaxValue6
    , s.SlidePriceFactor6
    , s.PriceForSlide6
    , s.meterSlideMinValue7
    , s.meterSlideMaxValue7
    , s.SlidePriceFactor7
    , s.PriceForSlide7
    , s.meterSlideMinValue8
    , s.meterSlideMaxValue8
    , s.SlidePriceFactor8
    , s.PriceForSlide8
    , s.meterSlideMinValue9
    , s.meterSlideMaxValue9
    , s.SlidePriceFactor9
    , s.PriceForSlide9
    , s.meterSlideMinValue10
    , s.meterSlideMaxValue10
    , s.SlidePriceFactor10
    , s.PriceForSlide10
    , s.PRICE
    , s.PRICETAX
    , s.meterServicePrice
    , s.meterServicePriceTAX
    , s.TotalPrice
    , 1
    , @IdaraID_INT
    , GETDATE()
    , @entryData
    , @hostName
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @NewMeterReadValue,@Identity_Insert) s;



             


            IF NOT EXISTS (SELECT 1 FROM @InsertedBillsocc)
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل الفاتورة - Bills', 1;
            END;

            SELECT TOP (1) @Identity_Insert2 = BillID
            FROM @InsertedBillsocc;

           SELECT TOP (1)
                            @Note3 = N'{'
                                + N'"BillID": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillID), N'') + N'"'
                                + N',"BillChargeTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillChargeTypeID_FK), N'') + N'"'
                                + N',"BillTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillTypeID_FK), N'') + N'"'
                                + N',"PerviosPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), PerviosPeriodID), N'') + N'"'
                                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodID), N'') + N'"'
                                + N',"PeriodMonth": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodMonth), N'') + N'"'
                                + N',"PeriodYear": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodYear), N'') + N'"'
                                + N',"CurrentPeriodTax": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodTax), N'') + N'"'
                                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterNo), N'') + N'"'
                                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterID), N'') + N'"'
                                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_A), N'') + N'"'
                                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_E), N'') + N'"'
                                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterDescription), N'') + N'"'
                                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsNo), N'') + N'"'
                                + N',"buildingUtilityTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingUtilityTypeID), N'') + N'"'
                                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsID), N'') + N'"'
                                + N',"meterTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterTypeID), N'') + N'"'
                                + N',"meterServiceTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServiceTypeID), N'') + N'"'
                                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), residentInfoID_FK), N'') + N'"'
                                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), generalNo_FK), N'') + N'"'
                                + N',"CurrentRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentRead), N'') + N'"'
                                + N',"LastRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), LastRead), N'') + N'"'
                                + N',"ReadDiff": "' + ISNULL(CONVERT(NVARCHAR(MAX), ReadDiff), N'') + N'"'
                        
                                + N',"meterSlideMinValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue1), N'') + N'"'
                                + N',"meterSlideMaxValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue1), N'') + N'"'
                                + N',"SlidePriceFactor1": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor1), N'') + N'"'
                                + N',"PriceForSlide1": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide1), N'') + N'"'
                        
                                + N',"meterSlideMinValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue2), N'') + N'"'
                                + N',"meterSlideMaxValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue2), N'') + N'"'
                                + N',"SlidePriceFactor2": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor2), N'') + N'"'
                                + N',"PriceForSlide2": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide2), N'') + N'"'
                        
                                + N',"meterSlideMinValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue3), N'') + N'"'
                                + N',"meterSlideMaxValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue3), N'') + N'"'
                                + N',"SlidePriceFactor3": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor3), N'') + N'"'
                                + N',"PriceForSlide3": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide3), N'') + N'"'
                        
                                + N',"meterSlideMinValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue4), N'') + N'"'
                                + N',"meterSlideMaxValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue4), N'') + N'"'
                                + N',"SlidePriceFactor4": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor4), N'') + N'"'
                                + N',"PriceForSlide4": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide4), N'') + N'"'
                        
                                + N',"meterSlideMinValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue5), N'') + N'"'
                                + N',"meterSlideMaxValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue5), N'') + N'"'
                                + N',"SlidePriceFactor5": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor5), N'') + N'"'
                                + N',"PriceForSlide5": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide5), N'') + N'"'
                        
                                + N',"meterSlideMinValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue6), N'') + N'"'
                                + N',"meterSlideMaxValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue6), N'') + N'"'
                                + N',"SlidePriceFactor6": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor6), N'') + N'"'
                                + N',"PriceForSlide6": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide6), N'') + N'"'
                        
                                + N',"meterSlideMinValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue7), N'') + N'"'
                                + N',"meterSlideMaxValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue7), N'') + N'"'
                                + N',"SlidePriceFactor7": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor7), N'') + N'"'
                                + N',"PriceForSlide7": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide7), N'') + N'"'
                        
                                + N',"meterSlideMinValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue8), N'') + N'"'
                                + N',"meterSlideMaxValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue8), N'') + N'"'
                                + N',"SlidePriceFactor8": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor8), N'') + N'"'
                                + N',"PriceForSlide8": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide8), N'') + N'"'
                        
                                + N',"meterSlideMinValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue9), N'') + N'"'
                                + N',"meterSlideMaxValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue9), N'') + N'"'
                                + N',"SlidePriceFactor9": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor9), N'') + N'"'
                                + N',"PriceForSlide9": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide9), N'') + N'"'
                        
                                + N',"meterSlideMinValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue10), N'') + N'"'
                                + N',"meterSlideMaxValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue10), N'') + N'"'
                                + N',"SlidePriceFactor10": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor10), N'') + N'"'
                                + N',"PriceForSlide10": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide10), N'') + N'"'
                        
                                + N',"PRICE": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICE), N'') + N'"'
                                + N',"PRICETAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICETAX), N'') + N'"'
                                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePrice), N'') + N'"'
                                + N',"meterServicePriceTAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePriceTAX), N'') + N'"'
                                + N',"TotalPrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), TotalPrice), N'') + N'"'
                                + N',"BillActive": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillActive), N'') + N'"'
                                + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), idaraID_FK), N'') + N'"'
                                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(19), entryDate, 120), N'') + N'"'
                                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), entryData), N'') + N'"'
                                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), hostName), N'') + N'"'
                                + N'}'
                        FROM @InsertedBillsocc;

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
                  N'[Housing].[Bills]'
                , @Action
                , @Identity_Insert2
                , @entryData
                , @Note3
            );



           END
            


            IF @tc = 0
    COMMIT TRANSACTION;

SELECT 1 AS IsSuccessful,
       N'تم تسجيل القراءة واصدار الفاتورة بنجاح' AS Message_;
RETURN;

         END

       ----------------------------------------------------------------
        -- UPDATEMETERREADFOROCCUBENTANDEXIT
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEMETERREADFOROCCUBENTANDEXIT'
        BEGIN
       


                     IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

              IF @meterReadID IS NULL
            BEGIN
                ;THROW 50001, N'رقم القراءة مطلوب للتحديث', 1;
            END

              IF @BillsID IS NULL
            BEGIN
                ;THROW 50001, N'رقم الفاتورة مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.Bills w
                WHERE w.BillsID = @BillsID
            )
            BEGIN
                ;THROW 50001, N'رقم الفاتورة غير موجود', 1;
            END

             IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.MeterRead w
                WHERE w.meterReadID = @meterReadID
            )
            BEGIN
                ;THROW 50001, N'رقم القراءة غير موجود', 1;
            END





              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) NOT in (46,59)
            BEGIN
                ;THROW 50001, N'تم قراءة عدادات الخدمات واعتمادها مسبقا او تم الغاء تسكين المستفيد', 1;
            END

            

            Declare @buildingActionTypeID_1 INT

            select TOP(1)
            @buildingActionTypeID_1 =
            case 
            when w.LastActionTypeID = 46  then 47
            when w.LastActionTypeID = 59  then 60
            else 
            9999
            END
           
           
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID
            --AND W.LastActionTypeID IN (46,59)

            IF 
            (
               @buildingActionTypeID_1 = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type Meter read', 1;
            END






            
                IF(@buildingActionRoot = 2)
                BEGIN
                set @meterReadTypeID_FK = 3
                END

                 IF(@buildingActionRoot = 1)
                BEGIN
                set @meterReadTypeID_FK = 1
                END



                
            --          INSERT INTO  Housing.BuildingAction
            --(
            --      buildingActionTypeID_FK
            --    , residentInfoID_FK
            --    , generalNo_FK
            --    , buildingActionDecisionNo
            --    , buildingActionDecisionDate
            --    , buildingDetailsID_FK
            --    , buildingDetailsNo
            --    , buildingActionActive
            --    , CustdyRecord
            --    , buildingActionParentID
            --    , AssignPeriodID_FK
            --    , buildingActionDate
            --    , IdaraId_FK
            --    , entryData
            --    , hostName
            --)
            
            -- VALUES
            --(
            --      @buildingActionTypeID_
            --    , @residentInfoID
            --    , @GeneralNo
            --    , @buildingActionDecisionNo
            --    , @buildingActionDecisionDate
            --    , @buildingDetailsID
            --    , @buildingDetailsNo
            --    , 1
            --    , @Notes
            --    , @LastActionID
            --    , @AssignPeriodID
            --    , @ExitDate
            --    , @IdaraID_INT
            --    , @entryData
            --    , @hostName
            --);


            
            --IF @@ROWCOUNT = 0
            --BEGIN
            --    ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد', 1; -- برمجي
            --END

            --SET @NewID = SCOPE_IDENTITY();
            --IF @NewID IS NULL OR @NewID <= 0
            --BEGIN
            --    ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد - Identity', 1; -- برمجي
            --END
            --SET @Note2 = N'{'
            --    + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
            --    + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_), '') + N'"'
            --    + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
            --    + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
            --    + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
            --    + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
            --    + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
            --    + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
            --    + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
            --    + N',"CustdyRecord": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
            --    + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
            --    + N',"AssignPeriodID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @AssignPeriodID), '') + N'"'
            --    + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
            --    + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
            --    + N'}';

            --INSERT INTO  dbo.AuditLog
            --(
            --      TableName
            --    , ActionType
            --    , RecordID
            --    , PerformedBy
            --    , Notes
            --)
            --VALUES
            --(
            --      N'[Housing].[BuildingAction]'
            --    , N'METERREADFOROCCUBENTANDEXIT'
            --    , @ActionID
            --    , @entryData
            --    , @Note2
            --);

           
           update Housing.MeterRead
           set meterReadActive = 0,CanceledBy = @entryData+','+convert(nvarchar(10),getdate(),23)+' '+convert(nvarchar(10),getdate(),8)
           where meterReadID = @meterReadID

           if @@ROWCOUNT <= 0
           begin
           ;THROW 50001, N'حصل خطأ ما disactive Meter read', 1;
           end


           update Housing.bills
           set BillActive = 0,CanceledBy = @entryData+','+convert(nvarchar(10),getdate(),23)+' '+convert(nvarchar(10),getdate(),8)
           where BillsID = @BillsID


            if @@ROWCOUNT <= 0
           begin
           ;THROW 50001, N'حصل خطأ ما disactive bill', 1;
           end


              INSERT INTO  Housing.[MeterRead]
            (

                   [meterReadTypeID_FK]
                  ,[meterID_FK]
                  ,[billPeriodID_FK]
                  ,[residentInfoID_FK]
                  ,[generalNo_FK]
                  ,[buildingDetailsID]
                  ,[buildingDetailsNo]
                  ,[dateOfRead]
                  ,[meterReadValue]
                  ,[buildingActionID_FK]
                  ,[meterReadActive]
                  ,[IdaraID_FK]
                  ,[entryData]
                  ,[hostName]
                  
                
            )
            
             VALUES
            (
                  @meterReadTypeID_FK
                , @meterID
                , 1
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , GETDATE()
                , @NewMeterReadValue
                , @LastActionID
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


             SET @Identity_Insert = SCOPE_IDENTITY();


            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
             BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد - MeterRead', 1; -- برمجي
            END


            SET @NewID = @Identity_Insert;



           SET @Note = N'{'
                            + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                            + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), 2), N'') + N'"'
                            + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), N'') + N'"'
                            + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), 1), N'') + N'"'
                            + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), N'') + N'"'
                            + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                            + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), N'') + N'"'
                            + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), N'') + N'"'
                            + N',"dateOfRead": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
                            + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewMeterReadValue), N'') + N'"'
                            + N',"buildingActionID_FK": ""'
                            + N',"meterReadActive": "1"'
                            + N',"IdaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                            + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                            + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), N'') + N'"'
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
                  N'[Housing].[MeterRead]'
                , @Action
                , @Identity_Insert
                , @entryData
                , @Note
            );




             IF(@buildingActionRoot = 2)
                BEGIN
               


            ----------------------
            DECLARE @InsertedBills1 TABLE
(
      BillID BIGINT
    , BillChargeTypeID_FK INT
    , BillTypeID_FK INT
    , PerviosPeriodID INT
    , CurrentPeriodID INT
    , PeriodMonth INT
    , PeriodYear INT
    , CurrentPeriodTax DECIMAL(18,2)
    , meterNo NVARCHAR(200)
    , meterID BIGINT
    , meterName_A NVARCHAR(200)
    , meterName_E NVARCHAR(200)
    , meterDescription NVARCHAR(MAX)
    , buildingDetailsNo NVARCHAR(200)
    , buildingUtilityTypeID INT
    , buildingDetailsID BIGINT
    , meterTypeID INT
    , meterServiceTypeID INT
    , meterReadID BIGINT
    , residentInfoID_FK BIGINT
    , generalNo_FK BIGINT
    , CurrentRead DECIMAL(18,2)
    , LastRead DECIMAL(18,2)
    , ReadDiff DECIMAL(18,2)
    , meterSlideMinValue1 DECIMAL(18,2)
    , meterSlideMaxValue1 DECIMAL(18,2)
    , SlidePriceFactor1 DECIMAL(18,2)
    , PriceForSlide1 DECIMAL(18,2)
    , meterSlideMinValue2 DECIMAL(18,2)
    , meterSlideMaxValue2 DECIMAL(18,2)
    , SlidePriceFactor2 DECIMAL(18,2)
    , PriceForSlide2 DECIMAL(18,2)
    , meterSlideMinValue3 DECIMAL(18,2)
    , meterSlideMaxValue3 DECIMAL(18,2)
    , SlidePriceFactor3 DECIMAL(18,2)
    , PriceForSlide3 DECIMAL(18,2)
    , meterSlideMinValue4 DECIMAL(18,2)
    , meterSlideMaxValue4 DECIMAL(18,2)
    , SlidePriceFactor4 DECIMAL(18,2)
    , PriceForSlide4 DECIMAL(18,2)
    , meterSlideMinValue5 DECIMAL(18,2)
    , meterSlideMaxValue5 DECIMAL(18,2)
    , SlidePriceFactor5 DECIMAL(18,2)
    , PriceForSlide5 DECIMAL(18,2)
    , meterSlideMinValue6 DECIMAL(18,2)
    , meterSlideMaxValue6 DECIMAL(18,2)
    , SlidePriceFactor6 DECIMAL(18,2)
    , PriceForSlide6 DECIMAL(18,2)
    , meterSlideMinValue7 DECIMAL(18,2)
    , meterSlideMaxValue7 DECIMAL(18,2)
    , SlidePriceFactor7 DECIMAL(18,2)
    , PriceForSlide7 DECIMAL(18,2)
    , meterSlideMinValue8 DECIMAL(18,2)
    , meterSlideMaxValue8 DECIMAL(18,2)
    , SlidePriceFactor8 DECIMAL(18,2)
    , PriceForSlide8 DECIMAL(18,2)
    , meterSlideMinValue9 DECIMAL(18,2)
    , meterSlideMaxValue9 DECIMAL(18,2)
    , SlidePriceFactor9 DECIMAL(18,2)
    , PriceForSlide9 DECIMAL(18,2)
    , meterSlideMinValue10 DECIMAL(18,2)
    , meterSlideMaxValue10 DECIMAL(18,2)
    , SlidePriceFactor10 DECIMAL(18,2)
    , PriceForSlide10 DECIMAL(18,2)
    , PRICE DECIMAL(18,2)
    , PRICETAX DECIMAL(18,2)
    , meterServicePrice DECIMAL(18,2)
    , meterServicePriceTAX DECIMAL(18,2)
    , TotalPrice DECIMAL(18,2)
    , BillActive BIT
    , idaraID_FK INT
    , entryDate DATETIME
    , entryData NVARCHAR(200)
    , hostName NVARCHAR(200)
);
            
            INSERT INTO [DATACORE].[Housing].[Bills]
(
      [BillChargeTypeID_FK]
    , [BillTypeID_FK]
    , [PerviosPeriodID]
    , [CurrentPeriodID]
    , [PeriodMonth]
    , [PeriodYear]
    , [CurrentPeriodTax]
    , [meterNo]
    , [meterID]
    , [meterName_A]
    , [meterName_E]
    , [meterDescription]
    , [buildingDetailsNo]
    , [buildingUtilityTypeID]
    , [buildingDetailsID]
    , [meterTypeID]
    , [meterServiceTypeID]
    , [meterReadID]
    , [residentInfoID_FK]
    , [generalNo_FK]
    , [CurrentRead]
    , [LastRead]
    , [ReadDiff]
    , [meterSlideMinValue1]
    , [meterSlideMaxValue1]
    , [SlidePriceFactor1]
    , [PriceForSlide1]
    , [meterSlideMinValue2]
    , [meterSlideMaxValue2]
    , [SlidePriceFactor2]
    , [PriceForSlide2]
    , [meterSlideMinValue3]
    , [meterSlideMaxValue3]
    , [SlidePriceFactor3]
    , [PriceForSlide3]
    , [meterSlideMinValue4]
    , [meterSlideMaxValue4]
    , [SlidePriceFactor4]
    , [PriceForSlide4]
    , [meterSlideMinValue5]
    , [meterSlideMaxValue5]
    , [SlidePriceFactor5]
    , [PriceForSlide5]
    , [meterSlideMinValue6]
    , [meterSlideMaxValue6]
    , [SlidePriceFactor6]
    , [PriceForSlide6]
    , [meterSlideMinValue7]
    , [meterSlideMaxValue7]
    , [SlidePriceFactor7]
    , [PriceForSlide7]
    , [meterSlideMinValue8]
    , [meterSlideMaxValue8]
    , [SlidePriceFactor8]
    , [PriceForSlide8]
    , [meterSlideMinValue9]
    , [meterSlideMaxValue9]
    , [SlidePriceFactor9]
    , [PriceForSlide9]
    , [meterSlideMinValue10]
    , [meterSlideMaxValue10]
    , [SlidePriceFactor10]
    , [PriceForSlide10]
    , [PRICE]
    , [PRICETAX]
    , [meterServicePrice]
    , [meterServicePriceTAX]
    , [TotalPrice]
    , [BillActive]
    , [idaraID_FK]
    , [entryDate]
    , [entryData]
    , [hostName]
)
OUTPUT
      INSERTED.BillsID
    , INSERTED.BillChargeTypeID_FK
    , INSERTED.BillTypeID_FK
    , INSERTED.PerviosPeriodID
    , 1
    , INSERTED.PeriodMonth
    , INSERTED.PeriodYear
    , INSERTED.CurrentPeriodTax
    , INSERTED.meterNo
    , INSERTED.meterID
    , INSERTED.meterName_A
    , INSERTED.meterName_E
    , INSERTED.meterDescription
    , INSERTED.buildingDetailsNo
    , INSERTED.buildingUtilityTypeID
    , @buildingDetailsID
    , INSERTED.meterTypeID
    , INSERTED.meterServiceTypeID
    , @Identity_Insert
    , @residentInfoID
    , @GeneralNo
    , INSERTED.CurrentRead
    , INSERTED.LastRead
    , INSERTED.ReadDiff
    , INSERTED.meterSlideMinValue1
    , INSERTED.meterSlideMaxValue1
    , INSERTED.SlidePriceFactor1
    , INSERTED.PriceForSlide1
    , INSERTED.meterSlideMinValue2
    , INSERTED.meterSlideMaxValue2
    , INSERTED.SlidePriceFactor2
    , INSERTED.PriceForSlide2
    , INSERTED.meterSlideMinValue3
    , INSERTED.meterSlideMaxValue3
    , INSERTED.SlidePriceFactor3
    , INSERTED.PriceForSlide3
    , INSERTED.meterSlideMinValue4
    , INSERTED.meterSlideMaxValue4
    , INSERTED.SlidePriceFactor4
    , INSERTED.PriceForSlide4
    , INSERTED.meterSlideMinValue5
    , INSERTED.meterSlideMaxValue5
    , INSERTED.SlidePriceFactor5
    , INSERTED.PriceForSlide5
    , INSERTED.meterSlideMinValue6
    , INSERTED.meterSlideMaxValue6
    , INSERTED.SlidePriceFactor6
    , INSERTED.PriceForSlide6
    , INSERTED.meterSlideMinValue7
    , INSERTED.meterSlideMaxValue7
    , INSERTED.SlidePriceFactor7
    , INSERTED.PriceForSlide7
    , INSERTED.meterSlideMinValue8
    , INSERTED.meterSlideMaxValue8
    , INSERTED.SlidePriceFactor8
    , INSERTED.PriceForSlide8
    , INSERTED.meterSlideMinValue9
    , INSERTED.meterSlideMaxValue9
    , INSERTED.SlidePriceFactor9
    , INSERTED.PriceForSlide9
    , INSERTED.meterSlideMinValue10
    , INSERTED.meterSlideMaxValue10
    , INSERTED.SlidePriceFactor10
    , INSERTED.PriceForSlide10
    , INSERTED.PRICE
    , INSERTED.PRICETAX
    , INSERTED.meterServicePrice
    , INSERTED.meterServicePriceTAX
    , INSERTED.TotalPrice
    , INSERTED.BillActive
    , INSERTED.idaraID_FK
    , INSERTED.entryDate
    , INSERTED.entryData
    , INSERTED.hostName
INTO @InsertedBills1
SELECT
      (SELECT TOP (1) bb.BillChargeTypeID
       FROM Housing.BillChargeType bb
       WHERE bb.MeterServiceTypeID_FK = @MeterServiceTypeID)
    , @meterReadTypeID_FK
    , s.PerviosPeriodID
    , 1
    , s.PeriodMonth
    , s.PeriodYear
    , s.CurrentPeriodTax
    , s.meterNo
    , s.meterID
    , s.meterName_A
    , s.meterName_E
    , s.meterDescription
    , s.buildingDetailsNo
    , s.buildingUtilityTypeID
    , @buildingDetailsID
    , s.meterTypeID
    , s.meterServiceTypeID
    , @Identity_Insert
    , @residentInfoID
    , @GeneralNo
    , s.CurrentRead
    , s.LastRead
    , s.ReadDiff
    , s.meterSlideMinValue1
    , s.meterSlideMaxValue1
    , s.SlidePriceFactor1
    , s.PriceForSlide1
    , s.meterSlideMinValue2
    , s.meterSlideMaxValue2
    , s.SlidePriceFactor2
    , s.PriceForSlide2
    , s.meterSlideMinValue3
    , s.meterSlideMaxValue3
    , s.SlidePriceFactor3
    , s.PriceForSlide3
    , s.meterSlideMinValue4
    , s.meterSlideMaxValue4
    , s.SlidePriceFactor4
    , s.PriceForSlide4
    , s.meterSlideMinValue5
    , s.meterSlideMaxValue5
    , s.SlidePriceFactor5
    , s.PriceForSlide5
    , s.meterSlideMinValue6
    , s.meterSlideMaxValue6
    , s.SlidePriceFactor6
    , s.PriceForSlide6
    , s.meterSlideMinValue7
    , s.meterSlideMaxValue7
    , s.SlidePriceFactor7
    , s.PriceForSlide7
    , s.meterSlideMinValue8
    , s.meterSlideMaxValue8
    , s.SlidePriceFactor8
    , s.PriceForSlide8
    , s.meterSlideMinValue9
    , s.meterSlideMaxValue9
    , s.SlidePriceFactor9
    , s.PriceForSlide9
    , s.meterSlideMinValue10
    , s.meterSlideMaxValue10
    , s.SlidePriceFactor10
    , s.PriceForSlide10
    , s.PRICE
    , s.PRICETAX
    , s.meterServicePrice
    , s.meterServicePriceTAX
    , s.TotalPrice
    , 1
    , @IdaraID_INT
    , GETDATE()
    , @entryData
    , @hostName
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @NewMeterReadValue,@Identity_Insert) s;



             


            IF NOT EXISTS (SELECT 1 FROM @InsertedBills1)
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل الفاتورة - Bills', 1;
            END;

            SELECT TOP (1) @Identity_Insert1 = BillID
            FROM @InsertedBills1;

           SELECT TOP (1)
                            @Note1 = N'{'
                                + N'"BillID": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillID), N'') + N'"'
                                + N',"BillChargeTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillChargeTypeID_FK), N'') + N'"'
                                + N',"BillTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillTypeID_FK), N'') + N'"'
                                + N',"PerviosPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), PerviosPeriodID), N'') + N'"'
                                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodID), N'') + N'"'
                                + N',"PeriodMonth": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodMonth), N'') + N'"'
                                + N',"PeriodYear": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodYear), N'') + N'"'
                                + N',"CurrentPeriodTax": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodTax), N'') + N'"'
                                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterNo), N'') + N'"'
                                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterID), N'') + N'"'
                                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_A), N'') + N'"'
                                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_E), N'') + N'"'
                                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterDescription), N'') + N'"'
                                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsNo), N'') + N'"'
                                + N',"buildingUtilityTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingUtilityTypeID), N'') + N'"'
                                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsID), N'') + N'"'
                                + N',"meterTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterTypeID), N'') + N'"'
                                + N',"meterServiceTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServiceTypeID), N'') + N'"'
                                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), residentInfoID_FK), N'') + N'"'
                                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), generalNo_FK), N'') + N'"'
                                + N',"CurrentRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentRead), N'') + N'"'
                                + N',"LastRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), LastRead), N'') + N'"'
                                + N',"ReadDiff": "' + ISNULL(CONVERT(NVARCHAR(MAX), ReadDiff), N'') + N'"'
                        
                                + N',"meterSlideMinValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue1), N'') + N'"'
                                + N',"meterSlideMaxValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue1), N'') + N'"'
                                + N',"SlidePriceFactor1": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor1), N'') + N'"'
                                + N',"PriceForSlide1": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide1), N'') + N'"'
                        
                                + N',"meterSlideMinValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue2), N'') + N'"'
                                + N',"meterSlideMaxValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue2), N'') + N'"'
                                + N',"SlidePriceFactor2": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor2), N'') + N'"'
                                + N',"PriceForSlide2": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide2), N'') + N'"'
                        
                                + N',"meterSlideMinValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue3), N'') + N'"'
                                + N',"meterSlideMaxValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue3), N'') + N'"'
                                + N',"SlidePriceFactor3": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor3), N'') + N'"'
                                + N',"PriceForSlide3": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide3), N'') + N'"'
                        
                                + N',"meterSlideMinValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue4), N'') + N'"'
                                + N',"meterSlideMaxValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue4), N'') + N'"'
                                + N',"SlidePriceFactor4": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor4), N'') + N'"'
                                + N',"PriceForSlide4": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide4), N'') + N'"'
                        
                                + N',"meterSlideMinValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue5), N'') + N'"'
                                + N',"meterSlideMaxValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue5), N'') + N'"'
                                + N',"SlidePriceFactor5": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor5), N'') + N'"'
                                + N',"PriceForSlide5": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide5), N'') + N'"'
                        
                                + N',"meterSlideMinValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue6), N'') + N'"'
                                + N',"meterSlideMaxValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue6), N'') + N'"'
                                + N',"SlidePriceFactor6": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor6), N'') + N'"'
                                + N',"PriceForSlide6": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide6), N'') + N'"'
                        
                                + N',"meterSlideMinValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue7), N'') + N'"'
                                + N',"meterSlideMaxValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue7), N'') + N'"'
                                + N',"SlidePriceFactor7": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor7), N'') + N'"'
                                + N',"PriceForSlide7": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide7), N'') + N'"'
                        
                                + N',"meterSlideMinValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue8), N'') + N'"'
                                + N',"meterSlideMaxValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue8), N'') + N'"'
                                + N',"SlidePriceFactor8": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor8), N'') + N'"'
                                + N',"PriceForSlide8": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide8), N'') + N'"'
                        
                                + N',"meterSlideMinValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue9), N'') + N'"'
                                + N',"meterSlideMaxValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue9), N'') + N'"'
                                + N',"SlidePriceFactor9": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor9), N'') + N'"'
                                + N',"PriceForSlide9": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide9), N'') + N'"'
                        
                                + N',"meterSlideMinValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue10), N'') + N'"'
                                + N',"meterSlideMaxValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue10), N'') + N'"'
                                + N',"SlidePriceFactor10": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor10), N'') + N'"'
                                + N',"PriceForSlide10": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide10), N'') + N'"'
                        
                                + N',"PRICE": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICE), N'') + N'"'
                                + N',"PRICETAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICETAX), N'') + N'"'
                                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePrice), N'') + N'"'
                                + N',"meterServicePriceTAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePriceTAX), N'') + N'"'
                                + N',"TotalPrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), TotalPrice), N'') + N'"'
                                + N',"BillActive": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillActive), N'') + N'"'
                                + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), idaraID_FK), N'') + N'"'
                                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(19), entryDate, 120), N'') + N'"'
                                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), entryData), N'') + N'"'
                                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), hostName), N'') + N'"'
                                + N'}'
                        FROM @InsertedBills1;

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
                  N'[Housing].[Bills]'
                , @Action
                , @Identity_Insert1
                , @entryData
                , @Note1
            );



           END




           

             IF(@buildingActionRoot = 1)
                BEGIN
               


            ----------------------
            DECLARE @InsertedBillsocc1 TABLE
(
      BillID BIGINT
    , BillChargeTypeID_FK INT
    , BillTypeID_FK INT
    , PerviosPeriodID INT
    , CurrentPeriodID INT
    , PeriodMonth INT
    , PeriodYear INT
    , CurrentPeriodTax DECIMAL(18,2)
    , meterNo NVARCHAR(200)
    , meterID BIGINT
    , meterName_A NVARCHAR(200)
    , meterName_E NVARCHAR(200)
    , meterDescription NVARCHAR(MAX)
    , buildingDetailsNo NVARCHAR(200)
    , buildingUtilityTypeID INT
    , buildingDetailsID BIGINT
    , meterTypeID INT
    , meterServiceTypeID INT
    , meterReadID BIGINT
    , residentInfoID_FK BIGINT
    , generalNo_FK BIGINT
    , CurrentRead DECIMAL(18,2)
    , LastRead DECIMAL(18,2)
    , ReadDiff DECIMAL(18,2)
    , meterSlideMinValue1 DECIMAL(18,2)
    , meterSlideMaxValue1 DECIMAL(18,2)
    , SlidePriceFactor1 DECIMAL(18,2)
    , PriceForSlide1 DECIMAL(18,2)
    , meterSlideMinValue2 DECIMAL(18,2)
    , meterSlideMaxValue2 DECIMAL(18,2)
    , SlidePriceFactor2 DECIMAL(18,2)
    , PriceForSlide2 DECIMAL(18,2)
    , meterSlideMinValue3 DECIMAL(18,2)
    , meterSlideMaxValue3 DECIMAL(18,2)
    , SlidePriceFactor3 DECIMAL(18,2)
    , PriceForSlide3 DECIMAL(18,2)
    , meterSlideMinValue4 DECIMAL(18,2)
    , meterSlideMaxValue4 DECIMAL(18,2)
    , SlidePriceFactor4 DECIMAL(18,2)
    , PriceForSlide4 DECIMAL(18,2)
    , meterSlideMinValue5 DECIMAL(18,2)
    , meterSlideMaxValue5 DECIMAL(18,2)
    , SlidePriceFactor5 DECIMAL(18,2)
    , PriceForSlide5 DECIMAL(18,2)
    , meterSlideMinValue6 DECIMAL(18,2)
    , meterSlideMaxValue6 DECIMAL(18,2)
    , SlidePriceFactor6 DECIMAL(18,2)
    , PriceForSlide6 DECIMAL(18,2)
    , meterSlideMinValue7 DECIMAL(18,2)
    , meterSlideMaxValue7 DECIMAL(18,2)
    , SlidePriceFactor7 DECIMAL(18,2)
    , PriceForSlide7 DECIMAL(18,2)
    , meterSlideMinValue8 DECIMAL(18,2)
    , meterSlideMaxValue8 DECIMAL(18,2)
    , SlidePriceFactor8 DECIMAL(18,2)
    , PriceForSlide8 DECIMAL(18,2)
    , meterSlideMinValue9 DECIMAL(18,2)
    , meterSlideMaxValue9 DECIMAL(18,2)
    , SlidePriceFactor9 DECIMAL(18,2)
    , PriceForSlide9 DECIMAL(18,2)
    , meterSlideMinValue10 DECIMAL(18,2)
    , meterSlideMaxValue10 DECIMAL(18,2)
    , SlidePriceFactor10 DECIMAL(18,2)
    , PriceForSlide10 DECIMAL(18,2)
    , PRICE DECIMAL(18,2)
    , PRICETAX DECIMAL(18,2)
    , meterServicePrice DECIMAL(18,2)
    , meterServicePriceTAX DECIMAL(18,2)
    , TotalPrice DECIMAL(18,2)
    , BillActive BIT
    , idaraID_FK INT
    , entryDate DATETIME
    , entryData NVARCHAR(200)
    , hostName NVARCHAR(200)
);
            
            INSERT INTO [DATACORE].[Housing].[Bills]
(
      [BillChargeTypeID_FK]
    , [BillTypeID_FK]
    , [PerviosPeriodID]
    , [CurrentPeriodID]
    , [PeriodMonth]
    , [PeriodYear]
    , [CurrentPeriodTax]
    , [meterNo]
    , [meterID]
    , [meterName_A]
    , [meterName_E]
    , [meterDescription]
    , [buildingDetailsNo]
    , [buildingUtilityTypeID]
    , [buildingDetailsID]
    , [meterTypeID]
    , [meterServiceTypeID]
    , [meterReadID]
    , [residentInfoID_FK]
    , [generalNo_FK]
    , [CurrentRead]
    , [LastRead]
    , [ReadDiff]
    , [meterSlideMinValue1]
    , [meterSlideMaxValue1]
    , [SlidePriceFactor1]
    , [PriceForSlide1]
    , [meterSlideMinValue2]
    , [meterSlideMaxValue2]
    , [SlidePriceFactor2]
    , [PriceForSlide2]
    , [meterSlideMinValue3]
    , [meterSlideMaxValue3]
    , [SlidePriceFactor3]
    , [PriceForSlide3]
    , [meterSlideMinValue4]
    , [meterSlideMaxValue4]
    , [SlidePriceFactor4]
    , [PriceForSlide4]
    , [meterSlideMinValue5]
    , [meterSlideMaxValue5]
    , [SlidePriceFactor5]
    , [PriceForSlide5]
    , [meterSlideMinValue6]
    , [meterSlideMaxValue6]
    , [SlidePriceFactor6]
    , [PriceForSlide6]
    , [meterSlideMinValue7]
    , [meterSlideMaxValue7]
    , [SlidePriceFactor7]
    , [PriceForSlide7]
    , [meterSlideMinValue8]
    , [meterSlideMaxValue8]
    , [SlidePriceFactor8]
    , [PriceForSlide8]
    , [meterSlideMinValue9]
    , [meterSlideMaxValue9]
    , [SlidePriceFactor9]
    , [PriceForSlide9]
    , [meterSlideMinValue10]
    , [meterSlideMaxValue10]
    , [SlidePriceFactor10]
    , [PriceForSlide10]
    , [PRICE]
    , [PRICETAX]
    , [meterServicePrice]
    , [meterServicePriceTAX]
    , [TotalPrice]
    , [BillActive]
    , [idaraID_FK]
    , [entryDate]
    , [entryData]
    , [hostName]
)
OUTPUT
      INSERTED.BillsID
    , INSERTED.BillChargeTypeID_FK
    , INSERTED.BillTypeID_FK
    , INSERTED.PerviosPeriodID
    , 1
    , INSERTED.PeriodMonth
    , INSERTED.PeriodYear
    , INSERTED.CurrentPeriodTax
    , INSERTED.meterNo
    , INSERTED.meterID
    , INSERTED.meterName_A
    , INSERTED.meterName_E
    , INSERTED.meterDescription
    , INSERTED.buildingDetailsNo
    , INSERTED.buildingUtilityTypeID
    , @buildingDetailsID
    , INSERTED.meterTypeID
    , INSERTED.meterServiceTypeID
    , @Identity_Insert
    , NULL
    , NULL
    , INSERTED.CurrentRead
    , INSERTED.LastRead
    , INSERTED.ReadDiff
    , INSERTED.meterSlideMinValue1
    , INSERTED.meterSlideMaxValue1
    , INSERTED.SlidePriceFactor1
    , INSERTED.PriceForSlide1
    , INSERTED.meterSlideMinValue2
    , INSERTED.meterSlideMaxValue2
    , INSERTED.SlidePriceFactor2
    , INSERTED.PriceForSlide2
    , INSERTED.meterSlideMinValue3
    , INSERTED.meterSlideMaxValue3
    , INSERTED.SlidePriceFactor3
    , INSERTED.PriceForSlide3
    , INSERTED.meterSlideMinValue4
    , INSERTED.meterSlideMaxValue4
    , INSERTED.SlidePriceFactor4
    , INSERTED.PriceForSlide4
    , INSERTED.meterSlideMinValue5
    , INSERTED.meterSlideMaxValue5
    , INSERTED.SlidePriceFactor5
    , INSERTED.PriceForSlide5
    , INSERTED.meterSlideMinValue6
    , INSERTED.meterSlideMaxValue6
    , INSERTED.SlidePriceFactor6
    , INSERTED.PriceForSlide6
    , INSERTED.meterSlideMinValue7
    , INSERTED.meterSlideMaxValue7
    , INSERTED.SlidePriceFactor7
    , INSERTED.PriceForSlide7
    , INSERTED.meterSlideMinValue8
    , INSERTED.meterSlideMaxValue8
    , INSERTED.SlidePriceFactor8
    , INSERTED.PriceForSlide8
    , INSERTED.meterSlideMinValue9
    , INSERTED.meterSlideMaxValue9
    , INSERTED.SlidePriceFactor9
    , INSERTED.PriceForSlide9
    , INSERTED.meterSlideMinValue10
    , INSERTED.meterSlideMaxValue10
    , INSERTED.SlidePriceFactor10
    , INSERTED.PriceForSlide10
    , INSERTED.PRICE
    , INSERTED.PRICETAX
    , INSERTED.meterServicePrice
    , INSERTED.meterServicePriceTAX
    , INSERTED.TotalPrice
    , INSERTED.BillActive
    , INSERTED.idaraID_FK
    , INSERTED.entryDate
    , INSERTED.entryData
    , INSERTED.hostName
INTO @InsertedBillsocc1
SELECT
      (SELECT TOP (1) bb.BillChargeTypeID
       FROM Housing.BillChargeType bb
       WHERE bb.MeterServiceTypeID_FK = @MeterServiceTypeID)
    , @meterReadTypeID_FK
    , s.PerviosPeriodID
    , 1
    , s.PeriodMonth
    , s.PeriodYear
    , s.CurrentPeriodTax
    , s.meterNo
    , s.meterID
    , s.meterName_A
    , s.meterName_E
    , s.meterDescription
    , s.buildingDetailsNo
    , s.buildingUtilityTypeID
    , @buildingDetailsID
    , s.meterTypeID
    , s.meterServiceTypeID
    , @Identity_Insert
    , NULL
    , NULL
    , s.CurrentRead
    , s.LastRead
    , s.ReadDiff
    , s.meterSlideMinValue1
    , s.meterSlideMaxValue1
    , s.SlidePriceFactor1
    , s.PriceForSlide1
    , s.meterSlideMinValue2
    , s.meterSlideMaxValue2
    , s.SlidePriceFactor2
    , s.PriceForSlide2
    , s.meterSlideMinValue3
    , s.meterSlideMaxValue3
    , s.SlidePriceFactor3
    , s.PriceForSlide3
    , s.meterSlideMinValue4
    , s.meterSlideMaxValue4
    , s.SlidePriceFactor4
    , s.PriceForSlide4
    , s.meterSlideMinValue5
    , s.meterSlideMaxValue5
    , s.SlidePriceFactor5
    , s.PriceForSlide5
    , s.meterSlideMinValue6
    , s.meterSlideMaxValue6
    , s.SlidePriceFactor6
    , s.PriceForSlide6
    , s.meterSlideMinValue7
    , s.meterSlideMaxValue7
    , s.SlidePriceFactor7
    , s.PriceForSlide7
    , s.meterSlideMinValue8
    , s.meterSlideMaxValue8
    , s.SlidePriceFactor8
    , s.PriceForSlide8
    , s.meterSlideMinValue9
    , s.meterSlideMaxValue9
    , s.SlidePriceFactor9
    , s.PriceForSlide9
    , s.meterSlideMinValue10
    , s.meterSlideMaxValue10
    , s.SlidePriceFactor10
    , s.PriceForSlide10
    , s.PRICE
    , s.PRICETAX
    , s.meterServicePrice
    , s.meterServicePriceTAX
    , s.TotalPrice
    , 1
    , @IdaraID_INT
    , GETDATE()
    , @entryData
    , @hostName
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @NewMeterReadValue,@Identity_Insert) s;



             


            IF NOT EXISTS (SELECT 1 FROM @InsertedBillsocc1)
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل الفاتورة - Bills', 1;
            END;

            SELECT TOP (1) @Identity_Insert2 = BillID
            FROM @InsertedBillsocc1;

           SELECT TOP (1)
                            @Note3 = N'{'
                                + N'"BillID": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillID), N'') + N'"'
                                + N',"BillChargeTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillChargeTypeID_FK), N'') + N'"'
                                + N',"BillTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillTypeID_FK), N'') + N'"'
                                + N',"PerviosPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), PerviosPeriodID), N'') + N'"'
                                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodID), N'') + N'"'
                                + N',"PeriodMonth": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodMonth), N'') + N'"'
                                + N',"PeriodYear": "' + ISNULL(CONVERT(NVARCHAR(MAX), PeriodYear), N'') + N'"'
                                + N',"CurrentPeriodTax": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentPeriodTax), N'') + N'"'
                                + N',"meterNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterNo), N'') + N'"'
                                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterID), N'') + N'"'
                                + N',"meterName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_A), N'') + N'"'
                                + N',"meterName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterName_E), N'') + N'"'
                                + N',"meterDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterDescription), N'') + N'"'
                                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsNo), N'') + N'"'
                                + N',"buildingUtilityTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingUtilityTypeID), N'') + N'"'
                                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), buildingDetailsID), N'') + N'"'
                                + N',"meterTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterTypeID), N'') + N'"'
                                + N',"meterServiceTypeID": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServiceTypeID), N'') + N'"'
                                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), residentInfoID_FK), N'') + N'"'
                                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), generalNo_FK), N'') + N'"'
                                + N',"CurrentRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), CurrentRead), N'') + N'"'
                                + N',"LastRead": "' + ISNULL(CONVERT(NVARCHAR(MAX), LastRead), N'') + N'"'
                                + N',"ReadDiff": "' + ISNULL(CONVERT(NVARCHAR(MAX), ReadDiff), N'') + N'"'
                        
                                + N',"meterSlideMinValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue1), N'') + N'"'
                                + N',"meterSlideMaxValue1": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue1), N'') + N'"'
                                + N',"SlidePriceFactor1": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor1), N'') + N'"'
                                + N',"PriceForSlide1": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide1), N'') + N'"'
                        
                                + N',"meterSlideMinValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue2), N'') + N'"'
                                + N',"meterSlideMaxValue2": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue2), N'') + N'"'
                                + N',"SlidePriceFactor2": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor2), N'') + N'"'
                                + N',"PriceForSlide2": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide2), N'') + N'"'
                        
                                + N',"meterSlideMinValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue3), N'') + N'"'
                                + N',"meterSlideMaxValue3": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue3), N'') + N'"'
                                + N',"SlidePriceFactor3": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor3), N'') + N'"'
                                + N',"PriceForSlide3": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide3), N'') + N'"'
                        
                                + N',"meterSlideMinValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue4), N'') + N'"'
                                + N',"meterSlideMaxValue4": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue4), N'') + N'"'
                                + N',"SlidePriceFactor4": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor4), N'') + N'"'
                                + N',"PriceForSlide4": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide4), N'') + N'"'
                        
                                + N',"meterSlideMinValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue5), N'') + N'"'
                                + N',"meterSlideMaxValue5": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue5), N'') + N'"'
                                + N',"SlidePriceFactor5": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor5), N'') + N'"'
                                + N',"PriceForSlide5": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide5), N'') + N'"'
                        
                                + N',"meterSlideMinValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue6), N'') + N'"'
                                + N',"meterSlideMaxValue6": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue6), N'') + N'"'
                                + N',"SlidePriceFactor6": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor6), N'') + N'"'
                                + N',"PriceForSlide6": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide6), N'') + N'"'
                        
                                + N',"meterSlideMinValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue7), N'') + N'"'
                                + N',"meterSlideMaxValue7": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue7), N'') + N'"'
                                + N',"SlidePriceFactor7": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor7), N'') + N'"'
                                + N',"PriceForSlide7": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide7), N'') + N'"'
                        
                                + N',"meterSlideMinValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue8), N'') + N'"'
                                + N',"meterSlideMaxValue8": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue8), N'') + N'"'
                                + N',"SlidePriceFactor8": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor8), N'') + N'"'
                                + N',"PriceForSlide8": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide8), N'') + N'"'
                        
                                + N',"meterSlideMinValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue9), N'') + N'"'
                                + N',"meterSlideMaxValue9": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue9), N'') + N'"'
                                + N',"SlidePriceFactor9": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor9), N'') + N'"'
                                + N',"PriceForSlide9": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide9), N'') + N'"'
                        
                                + N',"meterSlideMinValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMinValue10), N'') + N'"'
                                + N',"meterSlideMaxValue10": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterSlideMaxValue10), N'') + N'"'
                                + N',"SlidePriceFactor10": "' + ISNULL(CONVERT(NVARCHAR(MAX), SlidePriceFactor10), N'') + N'"'
                                + N',"PriceForSlide10": "' + ISNULL(CONVERT(NVARCHAR(MAX), PriceForSlide10), N'') + N'"'
                        
                                + N',"PRICE": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICE), N'') + N'"'
                                + N',"PRICETAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), PRICETAX), N'') + N'"'
                                + N',"meterServicePrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePrice), N'') + N'"'
                                + N',"meterServicePriceTAX": "' + ISNULL(CONVERT(NVARCHAR(MAX), meterServicePriceTAX), N'') + N'"'
                                + N',"TotalPrice": "' + ISNULL(CONVERT(NVARCHAR(MAX), TotalPrice), N'') + N'"'
                                + N',"BillActive": "' + ISNULL(CONVERT(NVARCHAR(MAX), BillActive), N'') + N'"'
                                + N',"idaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), idaraID_FK), N'') + N'"'
                                + N',"entryDate": "' + ISNULL(CONVERT(NVARCHAR(19), entryDate, 120), N'') + N'"'
                                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), entryData), N'') + N'"'
                                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), hostName), N'') + N'"'
                                + N'}'
                        FROM @InsertedBillsocc1;

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
                  N'[Housing].[Bills]'
                , @Action
                , @Identity_Insert2
                , @entryData
                , @Note3
            );



           END
            
            IF @tc = 0
    COMMIT TRANSACTION;
            SELECT 1 AS IsSuccessful, N'تم تعديل قراءة العداد بنجاح' AS Message_;
            RETURN;
        END


      
            
          ----------------------------------------------------------------
        -- UPDATEMETERREADFOROCCUBENTANDEXIT
        ----------------------------------------------------------------
        ELSE IF @Action = N'APPROVEMETERREADFOROCCUBENTANDEXIT'
        BEGIN
       


                     IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

              IF @meterReadID IS NULL
            BEGIN
                ;THROW 50001, N'رقم القراءة مطلوب للتحديث', 1;
            END

              IF @BillsID IS NULL
            BEGIN
                ;THROW 50001, N'رقم الفاتورة مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END



              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) NOT in (46,59)
            BEGIN
                ;THROW 50001, N'تم قراءة عدادات الخدمات واعتمادها مسبقا او تم الغاء تسكين المستفيد', 1;
            END

            

            Declare @buildingActionTypeID_11 INT,@occupantDate nvarchar(10),@ExitDate_ nvarchar(10)

            select TOP(1)
            @buildingActionTypeID_11 =
            case 
            when w.LastActionTypeID = 46  then 47
            when w.LastActionTypeID = 59  then 60
            else 
            9999
            END

            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID
            AND W.LastActionTypeID IN (46,59)

            IF 
            (
               @buildingActionTypeID_11 = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type', 1;
            END

            if(
            select TOP(1)
            w.LastActionTypeID
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.buildingDetailsID = @buildingDetailsID
            AND W.LastActionTypeID IN (46,59)) = 46
            BEGIN

            set @occupantDate = (select TOP(1)
            CONVERT(NVARCHAR(10), w.OccupentDate, 23)
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.buildingDetailsID = @buildingDetailsID
            AND W.LastActionTypeID IN (46))

            set @ExitDate_ = null
            
            END

            else if(
            select TOP(1)
            w.LastActionTypeID
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.buildingDetailsID = @buildingDetailsID
            AND W.LastActionTypeID IN (46,59)) = 59
            BEGIN

            set @occupantDate = (select TOP(1)
            CONVERT(NVARCHAR(10), w.OccupentDate, 23)
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.buildingDetailsID = @buildingDetailsID
            AND W.LastActionTypeID IN (59))

            set @ExitDate_ = (select TOP(1)
            CONVERT(NVARCHAR(10), w.ExitDate, 23)
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.buildingDetailsID = @buildingDetailsID
            AND W.LastActionTypeID IN (59))
            
            END


            /* ==========================================================
   SERVER-SIDE METER READINGS COMPLETENESS GUARD

   Applies to:
       46 -> 47 : Occupancy
       59 -> 60 : Exit

   Must run before INSERT INTO Housing.BuildingAction.

   No changes to meter pricing or bill calculations.
   ========================================================== */

DECLARE
      @QA_StageType INT
    , @QA_StageActionID BIGINT
    , @QA_ResidentID BIGINT
    , @QA_GeneralNo BIGINT
    , @QA_BuildingID BIGINT
    , @QA_IdaraID INT
    , @QA_EffectiveDate DATE
    , @QA_ExpectedReadType INT
    , @QA_ExpectedBillType INT
    , @QA_LockResult INT
    , @QA_LockResource NVARCHAR(255);


-- 1. حجز العملية لمنع اعتمادين متزامنين.

IF @ActionID IS NULL OR @IdaraID_INT IS NULL
BEGIN
    THROW 50001,
        N'بيانات نطاق اعتماد قراءات العدادات غير صحيحة.',
        1;
END;

SET @QA_LockResource =
    CONCAT(
        N'ApproveMeterRead:',
        @IdaraID_INT,
        N':',
        @ActionID
    );

EXEC @QA_LockResult = sys.sp_getapplock
      @Resource    = @QA_LockResource
    , @LockMode    = N'Exclusive'
    , @LockOwner   = N'Transaction'
    , @LockTimeout = 15000;

IF @QA_LockResult < 0
BEGIN
    THROW 50001,
        N'تعذر حجز عملية اعتماد قراءات العدادات.',
        1;
END;


-- 2. قراءة بيانات الدورة الحالية من الخادم.

SELECT
      @QA_StageType = w.LastActionTypeID
    , @QA_StageActionID =
        TRY_CONVERT(BIGINT, w.LastActionID)
    , @QA_ResidentID =
        TRY_CONVERT(BIGINT, w.residentInfoID)
    , @QA_GeneralNo =
        TRY_CONVERT(BIGINT, w.GeneralNo)
    , @QA_BuildingID =
        TRY_CONVERT(BIGINT, w.buildingDetailsID)
    , @QA_IdaraID =
        TRY_CONVERT(INT, w.IdaraId)
    ,@QA_EffectiveDate =
    CASE
        WHEN w.LastActionTypeID = 59
            THEN TRY_CONVERT(DATE, w.ExitDate)

        WHEN w.LastActionTypeID = 46
            THEN COALESCE(
                TRY_CONVERT(DATE, w.LastActionDate),
                (
                    SELECT CAST(
                        COALESCE(a.buildingActionDate, a.entryDate)
                        AS DATE
                    )
                    FROM Housing.BuildingAction a
                    WHERE a.buildingActionID =
                          TRY_CONVERT(BIGINT, w.LastActionID)
                      AND a.buildingActionTypeID_FK = 46
                      AND a.buildingActionActive = 1
                      AND a.residentInfoID_FK =
                          TRY_CONVERT(BIGINT, w.residentInfoID)
                      AND a.generalNo_FK =
                          TRY_CONVERT(BIGINT, w.GeneralNo)
                      AND a.buildingDetailsID_FK =
                          TRY_CONVERT(BIGINT, w.buildingDetailsID)
                      AND a.IdaraId_FK =
                          TRY_CONVERT(INT, w.IdaraId)
                )
            )

        ELSE TRY_CONVERT(DATE, w.LastActionDate)
    END
FROM Housing.V_WaitingList w
WHERE w.ActionID = @ActionID;


-- 3. التحقق من المرحلة والمستفيد والمسكن والإدارة.

IF
       @QA_StageType IS NULL
    OR @QA_StageType NOT IN (46, 59)
    OR @QA_StageActionID IS NULL
    OR @QA_ResidentID IS NULL
    OR @QA_GeneralNo IS NULL
    OR @QA_BuildingID IS NULL
    OR @QA_IdaraID IS NULL
    OR @QA_EffectiveDate IS NULL

    OR TRY_CONVERT(BIGINT, @residentInfoID) IS NULL
    OR TRY_CONVERT(BIGINT, @GeneralNo) IS NULL
    OR TRY_CONVERT(BIGINT, @buildingDetailsID) IS NULL
    OR TRY_CONVERT(BIGINT, @LastActionID) IS NULL

    OR @QA_ResidentID <> TRY_CONVERT(BIGINT, @residentInfoID)
    OR @QA_GeneralNo <> TRY_CONVERT(BIGINT, @GeneralNo)
    OR @QA_BuildingID <> TRY_CONVERT(BIGINT, @buildingDetailsID)
    OR @QA_IdaraID <> @IdaraID_INT
    OR @QA_StageActionID <> TRY_CONVERT(BIGINT, @LastActionID)

    OR TRY_CONVERT(INT, @buildingActionRoot) IS NULL
    OR (
        @QA_StageType = 59
        AND TRY_CONVERT(INT, @buildingActionRoot) <> 2
    )
    OR (
        @QA_StageType = 46
        AND TRY_CONVERT(INT, @buildingActionRoot) <> 1
    )
BEGIN
    THROW 50001,
        N'بيانات طلب اعتماد القراءات لا تطابق المرحلة الحالية.',
        1;
END;


-- 4. تحديد نوع القراءة والفاتورة حسب العملية.

SET @QA_ExpectedReadType =
    CASE
        WHEN @QA_StageType = 59 THEN 3
        ELSE 1
    END;

SET @QA_ExpectedBillType =
    CASE
        WHEN @QA_StageType = 59 THEN 3
        WHEN @QA_StageType = 46 THEN 1
    END;


-- 5. حصر العدادات المفوترة المؤهلة في تاريخ العملية.

DECLARE @QA_EligibleMeters TABLE
(
      MeterID BIGINT NOT NULL PRIMARY KEY
    , ServiceTypeID INT NOT NULL
);

INSERT INTO @QA_EligibleMeters
(
    MeterID,
    ServiceTypeID
)
SELECT DISTINCT
      m.meterID
    , mt.meterServiceTypeID_FK
FROM Housing.MeterForBuilding l WITH (UPDLOCK, HOLDLOCK)

INNER JOIN Housing.Meter m
    ON m.meterID = l.meterID_FK

INNER JOIN Housing.MeterType mt
    ON mt.meterTypeID = m.meterTypeID_FK

WHERE l.buildingDetailsID_FK = @QA_BuildingID
  AND l.IdaraID_FK = @QA_IdaraID
  AND l.meterForBuildingActive = 1

  AND (
        l.meterForBuildingStartDate IS NULL
        OR CAST(l.meterForBuildingStartDate AS DATE)
           <= @QA_EffectiveDate
      )
  AND (
        l.meterForBuildingEndDate IS NULL
        OR CAST(l.meterForBuildingEndDate AS DATE)
           >= @QA_EffectiveDate
      )

  AND m.meterActive = 1
  AND (
        m.meterStartDate IS NULL
        OR CAST(m.meterStartDate AS DATE)
           <= @QA_EffectiveDate
      )
  AND (
        m.meterEndDate IS NULL
        OR CAST(m.meterEndDate AS DATE)
           >= @QA_EffectiveDate
      )

  AND mt.meterTypeActive = 1
  AND mt.IdaraId_FK = @QA_IdaraID

  -- العدادات التي تعتمد على قراءة استهلاك.
  AND mt.MeterCalculateTypeID_FK = 1

  AND (
        mt.meterTypeStartDate IS NULL
        OR CAST(mt.meterTypeStartDate AS DATE)
           <= @QA_EffectiveDate
      )
  AND (
        mt.meterTypeEndDate IS NULL
        OR CAST(mt.meterTypeEndDate AS DATE)
           >= @QA_EffectiveDate
      );


-- 6. يجب وجود عدادات مؤهلة لهذه المرحلة.

IF NOT EXISTS
(
    SELECT 1
    FROM @QA_EligibleMeters
)
BEGIN
    THROW 50001,
        N'لا توجد عدادات مفوترة مؤهلة للاعتماد في هذه الدورة.',
        1;
END;


-- 7. منع الاعتماد إذا كانت قراءة أو فاتورة أي عداد ناقصة.

IF EXISTS
(
    SELECT 1
    FROM @QA_EligibleMeters e

    OUTER APPLY
    (
        SELECT
              COUNT(DISTINCT r.meterReadID) AS ReadCount
            , COUNT(DISTINCT b.BillsID) AS BillCount

        FROM Housing.MeterRead r

        LEFT JOIN Housing.Bills b
            ON b.meterReadID = r.meterReadID
           AND b.meterID = e.MeterID
           AND b.BillActive = 1
           AND b.BillTypeID_FK = @QA_ExpectedBillType
           AND b.meterServiceTypeID = e.ServiceTypeID
           AND
(
    (
        @QA_StageType = 59
        AND b.residentInfoID_FK = @QA_ResidentID
        AND b.generalNo_FK = @QA_GeneralNo
    )
    OR
    (
        @QA_StageType = 46
        AND b.residentInfoID_FK IS NULL
        AND b.generalNo_FK IS NULL
    )
)
           AND b.buildingDetailsID = @QA_BuildingID
           AND b.idaraID_FK = @QA_IdaraID
           AND b.BillChargeTypeID_FK IN (2, 3, 4)

        WHERE r.meterID_FK = e.MeterID
          AND r.meterReadActive = 1
          AND r.meterReadTypeID_FK = @QA_ExpectedReadType

          -- القراءة يجب أن تخص المرحلة الحالية.
          AND r.buildingActionID_FK = @QA_StageActionID

          AND r.residentInfoID_FK = @QA_ResidentID
          AND r.generalNo_FK = @QA_GeneralNo
          AND r.buildingDetailsID = @QA_BuildingID
          AND r.IdaraID_FK = @QA_IdaraID

    ) coverage

    WHERE coverage.ReadCount <> 1
       OR coverage.BillCount <> 1
)
BEGIN
    THROW 50001,
        N'لا يمكن اعتماد القراءات؛ توجد عدادات مفوترة دون قراءة وفاتورة صحيحتين لهذه الدورة.',
        1;
END;


-- 8. التأكد من أن القراءة والفاتورة المرسلتين للاعتماد
--    تخصان الدورة الحالية وليستا من دورة قديمة.

IF NOT EXISTS
(
    SELECT 1
    FROM @QA_EligibleMeters e

    INNER JOIN Housing.MeterRead r
        ON r.meterID_FK = e.MeterID
       AND r.meterReadID = TRY_CONVERT(BIGINT, @meterReadID)
       AND r.meterReadActive = 1
       AND r.meterReadTypeID_FK = @QA_ExpectedReadType
       AND r.buildingActionID_FK = @QA_StageActionID
       AND r.residentInfoID_FK = @QA_ResidentID
       AND r.generalNo_FK = @QA_GeneralNo
       AND r.buildingDetailsID = @QA_BuildingID
       AND r.IdaraID_FK = @QA_IdaraID

    INNER JOIN Housing.Bills b
        ON b.meterReadID = r.meterReadID
       AND b.BillsID = TRY_CONVERT(BIGINT, @BillsID)
       AND b.meterID = e.MeterID
       AND b.BillActive = 1
       AND b.BillTypeID_FK = @QA_ExpectedBillType
       AND b.meterServiceTypeID = e.ServiceTypeID
       AND
(
    (
        @QA_StageType = 59
        AND b.residentInfoID_FK = @QA_ResidentID
        AND b.generalNo_FK = @QA_GeneralNo
    )
    OR
    (
        @QA_StageType = 46
        AND b.residentInfoID_FK IS NULL
        AND b.generalNo_FK IS NULL
    )
)
AND b.buildingDetailsID = @QA_BuildingID
       AND b.idaraID_FK = @QA_IdaraID
)
BEGIN
    THROW 50001,
        N'قراءة أو فاتورة التأكيد غير مرتبطة بدورة الاعتماد الحالية.',
        1;
END;

/* END SERVER-SIDE COMPLETENESS GUARD */

                
                      INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , CustdyRecord
                , buildingActionParentID
                , AssignPeriodID_FK
                , buildingActionDate
                , OccupentDate
                , ExitDate
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @buildingActionTypeID_11
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , GETDATE()
                , @occupantDate
                , @ExitDate_
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


          
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اعتماد القراءات  - Identity', 1; -- برمجي
            END
            SET @Note2 = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"CustdyRecord": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"AssignPeriodID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @AssignPeriodID), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                  N'[Housing].[BuildingAction]'
                , N'METERREADFOROCCUBENTANDEXIT'
                , @ActionID
                , @entryData
                , @Note2
            );

           
          
            
            IF @tc = 0
    COMMIT TRANSACTION;
            SELECT 1 AS IsSuccessful, N'تم اعتماد القراءات بنجاح' AS Message_;
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