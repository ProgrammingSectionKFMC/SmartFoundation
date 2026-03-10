

CREATE PROCEDURE [Housing].[AllMeterReadSP] 
(
      @Action                                     NVARCHAR(100) = NULL
     ,@MeterServiceTypeID                        NVARCHAR(100)   = NULL
     ,@meterID                                    NVARCHAR(100)   = NULL
     ,@meterTypeID_FK                             NVARCHAR(100)   = NULL
     ,@meterNo                                    NVARCHAR(1000)   = NULL
     ,@meterName_A                                NVARCHAR(1000)   = NULL
     ,@meterName_E                                NVARCHAR(1000)   = NULL
     ,@meterDescription                           NVARCHAR(1000)   = NULL
     ,@meterStartDate                             NVARCHAR(100)   = NULL
     ,@meterEndDate                               NVARCHAR(100)   = NULL
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
     ,@billPeriodID                               NVARCHAR(100)   = NULL
     ,@billsID                                    NVARCHAR(100)   = NULL
     ,@MeterReadID                                NVARCHAR(100)   = NULL
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
        , @Note1            NVARCHAR(MAX) = NULL
        , @Note2            NVARCHAR(MAX) = NULL
        , @Note3            NVARCHAR(MAX) = NULL
        , @Note4            NVARCHAR(MAX) = NULL
        , @Note5            NVARCHAR(MAX) = NULL
        , @Note6            NVARCHAR(MAX) = NULL
        , @Identity_Insert BIGINT = NULL
        , @Identity_Insert1 BIGINT = NULL
        , @Identity_Insert2 BIGINT = NULL
        , @Identity_Update BIGINT = NULL
        , @Identity_Update1 BIGINT = NULL
        , @Identity_Update2 BIGINT = NULL;

    -- تحويلات رقمية آمنة
   DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

   DECLARE @billPeriodTypeID_FK int = 
   (
     SELECT bpt.billPeriodTypeID
     FROM Housing.BillPeriodType bpt 
     WHERE  bpt.billPeriodTypeActive = 1 AND bpt.meterServiceTypeID_FK = @meterServiceTypeID
   );

   DECLARE @billPeriodIDs bigint 
        ,@billPeriodName_A nvarchar(100) 
        ,@billPeriodName_E nvarchar(100) 
        ,@billPeriodStartDate datetime 
        ,@billPeriodEndDate datetime
        ,@billPeriodCount BIGINT
        ,@AllmeterReaded   INT = 0
        ,@AllMetersCount   INT = 0
        ,@AllMetersNotReaded   INT = 0
        ,@CurrentPeriodID  INT = NULL
        ,@residentInfoID BigInt = NULL
        ,@GeneralNo NvarChar(100) = NULL
        ,@buildingDetailsID Int = NULL
        ,@buildingDetailsNo NvarChar(100) = NULL ;


        IF EXISTS (
                    SELECT 1
                    FROM  Housing.MeterForBuilding mfb
                    WHERE mfb.meterForBuildingActive = 1
                      AND mfb.meterID_FK = @meterID)
                      BEGIN
                        SELECT TOP(1) @buildingDetailsID = mfb.buildingDetailsID_FK, @buildingDetailsNo = bd.buildingDetailsNo
                        FROM  Housing.MeterForBuilding mfb
                        inner join  Housing.BuildingDetails bd on mfb.buildingDetailsID_FK = bd.buildingDetailsID
                        WHERE mfb.meterForBuildingActive = 1
                          AND mfb.meterID_FK = @meterID
                      END

         IF EXISTS (
                    SELECT 1
                    FROM  Housing.V_Occupant mfb
                    WHERE mfb.buildingDetailsID = @buildingDetailsID)

                      BEGIN
                        SELECT TOP(1) @residentInfoID = mfb.residentInfoID,@GeneralNo = mfb.GeneralNo FROM  Housing.V_Occupant mfb
                        WHERE mfb.buildingDetailsID = @buildingDetailsID
                      END
           



        set @billPeriodCount = (SELECT COUNT(*)
                FROM  Housing.BillPeriod bp
                inner join  Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE  bpt.billPeriodTypeActive = 1
                    AND bp.IdaraId_FK = @IdaraId_FK and bpt.meterServiceTypeID_FK = @MeterServiceTypeID and bp.billPeriodActive = 1
        )

        
        set @billPeriodIDs = (SELECT top(1) COALESCE(MAX(bp.billPeriodID), -1)
                FROM  Housing.BillPeriod bp
                inner join  Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE  bpt.billPeriodTypeActive = 1
                    AND bp.IdaraId_FK = @IdaraId_FK and bpt.meterServiceTypeID_FK = @MeterServiceTypeID  and bp.billPeriodActive = 1
                   
        )

        if(@billPeriodCount) < 1
        Begin
		select Top(1) @billPeriodStartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0), @billPeriodEndDate= EOMONTH(dateadd(MONTH,0,GETDATE())),
		@billPeriodName_A = case 
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 01 then N'يناير'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 02 then N'فبراير'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 03 then N'مارس'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 04 then N'ابريل'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 05 then N'مايو'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 06 then N'يونيو'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 07 then N'يوليو'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 08 then N'اغسطس'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 09 then N'سبتمبر'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 10 then N'اكتوبر'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 11 then N'نوفمبر'
		when DATEPART(MONTH,dateadd(MONTH,0,GETDATE())) = 12 then N'ديسمبر'
		End 

		,@billPeriodName_E= DATENAME(MONTH,dateadd(MONTH,0,GETDATE()))
		
		END
		else
        BEGIN

        select Top(1) @billPeriodStartDate = dateadd(MONTH,1,bp.billPeriodStartDate),@billPeriodEndDate=EOMONTH(dateadd(MONTH,0,bp.billPeriodEndDate)),
		@billPeriodName_A = case 
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 01 then N'يناير'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 02 then N'فبراير'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 03 then N'مارس'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 04 then N'ابريل'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 05 then N'مايو'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 06 then N'يونيو'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 07 then N'يوليو'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 08 then N'اغسطس'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 09 then N'سبتمبر'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 10 then N'اكتوبر'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 11 then N'نوفمبر'
		when DATEPART(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate)) = 12 then N'ديسمبر'
		End 

		,@billPeriodName_E= dATEnaME(MONTH,dateadd(MONTH,0,bp.billPeriodStartDate))
		
		
		from  Housing.BillPeriod bp 
        inner join  Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
		WHERE  bpt.billPeriodTypeActive = 1 AND bp.IdaraId_FK = @IdaraId_FK and bpt.meterServiceTypeID_FK = @MeterServiceTypeID  and bp.billPeriodActive = 1
		order by bp.billPeriodID desc

        END


         DECLARE
        @MonthStart DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1),
        @MonthEnd   DATE = EOMONTH(GETDATE());


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


        IF OBJECT_ID('tempdb..#EligibleMeters') IS NOT NULL
        DROP TABLE #EligibleMeters;

        SELECT
            em.meterID,
            em.meterNo,
            em.meterServiceTypeID_FK
        INTO #EligibleMeters
        FROM Housing.FN_EligibleMeters(@IdaraId_FK, @MonthStart, @MonthEnd) em
        WHERE em.meterServiceTypeID_FK = @MeterServiceTypeID; -- مهم لتخفيف النتائج

        -- فهرس: نحتاج meterID للـ joins/exists + meterNo للـ order + meterServiceTypeID_FK للفلترة
        CREATE UNIQUE CLUSTERED INDEX IX_EligibleMeters ON #EligibleMeters(meterID);
        CREATE NONCLUSTERED INDEX IX_EligibleMeters_No ON #EligibleMeters(meterNo) INCLUDE (meterServiceTypeID_FK);
       

       SELECT @AllMetersCount = COUNT(*) FROM #EligibleMeters;

       SELECT @AllmeterReaded = COUNT(*)
       FROM #EligibleMeters em
       WHERE EXISTS
       (
           SELECT 1
           FROM  Housing.Bills b
           WHERE b.meterID = em.meterID
             AND b.meterServiceTypeID = @MeterServiceTypeID
             AND b.idaraID_FK = @IdaraId_FK
             AND b.BillActive = 1
             AND b.BillTypeID_FK = 2
             AND b.CurrentPeriodID = @billPeriodIDs
       );

       set @AllMetersNotReaded = @AllMetersCount - @AllmeterReaded;

        ----------------------------------------------------------------
        -- INSERTNEWMETERTYPE
        ----------------------------------------------------------------
        IF @Action = N'OPENMETERREADPERIOD'
        BEGIN

        

           IF NOT EXISTS (
                SELECT 1
                FROM Housing.MeterServiceType mst
                inner join Housing.MeterServiceTypeLinkedWithIdara msl on mst.meterServiceTypeID = msl.meterServiceTypeID_FK
                WHERE mst.meterServiceTypeActive = 1 and msl.MeterServiceTypeLinkedWithIdaraActive = 1
                    AND msl.Idara_FK = @IdaraId_FK and msl.MeterServiceTypeID_FK = @MeterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'هذه الخدمة غير متوفرة في ادارتك حاليا', 1;
            END


            IF EXISTS (
                SELECT 1
                FROM Housing.BillPeriod bp
                inner join Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE bp.billPeriodActive = 1 and bpt.billPeriodTypeActive = 1
                    AND bp.IdaraId_FK = @IdaraID_INT and bpt.meterServiceTypeID_FK = @meterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'يوجد فترة نشطة لهذه الخدمة يجب انهائها اولا', 1;
            END

            INSERT INTO  Housing.BillPeriod
            (
                 [billPeriodTypeID_FK]
                ,[billPeriodName_A]
                ,[billPeriodName_E]
                ,[billPeriodStartDate]
                ,[billPeriodEndDate]
                ,[billPeriodActive]
                ,[ClosedBy]
                ,[IdaraId_FK]
                ,[entryDate]
                ,[entryData]
                ,[hostName]
            )
            VALUES
            (
            @billPeriodTypeID_FK   
           ,@billPeriodName_A   
           ,@billPeriodName_E   
           ,@billPeriodStartDate   
           ,@billPeriodEndDate   
		   ,1
           ,null
           ,@IdaraId_FK
           ,GETDATE()
           ,@entryData   
           ,@hostName   

           );


        

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة نوع العداد - MeterType', 1; -- برمجي
            END

              

            SET @NewID = @Identity_Insert;

            SET @Note = N'{'
                + N'"billPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"billPeriodTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodTypeID_FK), '') + N'"'
                + N',"billPeriodName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodName_A), '') + N'"'
                + N',"billPeriodName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodName_E), '') + N'"'
                + N',"billPeriodStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodStartDate), '') + N'"'
                + N',"billPeriodEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodEndDate), '') + N'"'
                + N',"billPeriodActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraId_FK), '') + N'"'
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
                  N'[Housing].[BillPeriod]'
                , N'OPENMETERREADPERIOD'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم فتح فترة قراءة عدادات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATENEWMETERTYPE
        ----------------------------------------------------------------
        ELSE IF @Action = N'CLOSEMETERREADPERIOD'
        BEGIN

           IF NOT EXISTS (
                SELECT 1
                FROM Housing.MeterServiceType mst
                inner join Housing.MeterServiceTypeLinkedWithIdara msl on mst.meterServiceTypeID = msl.meterServiceTypeID_FK
                WHERE mst.meterServiceTypeActive = 1 and msl.MeterServiceTypeLinkedWithIdaraActive = 1
                    AND msl.Idara_FK = @IdaraId_FK  and msl.MeterServiceTypeID_FK = @MeterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'هذه الخدمة غير متوفرة في ادارتك حاليا', 1;
            END


           
            IF NOT EXISTS (
                SELECT 1
                FROM Housing.BillPeriod bp
                inner join Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE bp.billPeriodActive = 1 and bpt.billPeriodTypeActive = 1
                    AND bp.IdaraId_FK = @IdaraID_INT and bpt.meterServiceTypeID_FK = @meterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'لايوجد فترة نشطة لهذه الخدمة لانهائها', 1;
            END

            
            IF (@AllMetersNotReaded > 0)

            BEGIN
            Declare @msg NVARCHAR(500) = N'لايمكن اغلاق الفترة لوجود عدد ' + ISNULL(CONVERT(NVARCHAR(10), @AllMetersNotReaded), '0') + N' عدادات لم يتم قراءتها بعد'
                ;THROW 50001, @msg, 1;
            END


          Update Housing.BillPeriod           
          set billPeriodActive = 0, ClosedBy = cast(isnull(@entryData,N'') as nvarchar(20))+N' - '+ isnull(@hostName,N'') +N' - ' + CONVERT(NVARCHAR(20), GETDATE(), 120)
          where billPeriodID = @billPeriodID and IdaraId_FK = @IdaraID_INT

             

            SET @Identity_Update = @@ROWCOUNT;
            IF @Identity_Update IS NULL OR @Identity_Update <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اغلاق الفترة - CLOSEMETERREADPERIOD', 1; -- برمجي
            END

              

            SET @NewID = @Identity_Update;

            SET @Note = N'{'
                + N'"billPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodID), '') + N'"'
                + N',"ClosedBy": "' + ISNULL(CONVERT(NVARCHAR(MAX), cast(isnull(@entryData,N'') as nvarchar(20))+N' - '+ isnull(@hostName,N'') +N' - ' + CONVERT(NVARCHAR(20), GETDATE(), 120)), '') + N'"'
                + N',"billPeriodActive": 1"' + N'"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraId_FK), '') + N'"'
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
                  N'[Housing].[BillPeriod]'
                , N'CLOSEMETERREADPERIOD'
                , ISNULL(@billPeriodID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اغلاق فترة قراءة عدادات بنجاح' AS Message_;
            RETURN;
        END

         ----------------------------------------------------------------
        -- READ
        ----------------------------------------------------------------
         ELSE IF @Action in(N'READELECTRICITYMETER',N'READWATERMETER',N'READGASMETER')
         BEGIN

          IF NOT EXISTS (
                SELECT 1
                FROM Housing.MeterServiceType mst
                inner join Housing.MeterServiceTypeLinkedWithIdara msl on mst.meterServiceTypeID = msl.meterServiceTypeID_FK
                WHERE mst.meterServiceTypeActive = 1 and msl.MeterServiceTypeLinkedWithIdaraActive = 1
                    AND msl.Idara_FK = @IdaraId_FK and msl.MeterServiceTypeID_FK = @MeterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'هذه الخدمة غير متوفرة في ادارتك حاليا', 1;
            END


        IF EXISTS (
                 SELECT 1
    FROM Housing.Bills b
    WHERE b.meterID = @meterID
      AND b.CurrentPeriodID = @billPeriodID
      AND b.meterServiceTypeID = @MeterServiceTypeID
      AND b.idaraID_FK = @IdaraId_FK
      AND b.BillActive = 1
      AND b.BillTypeID_FK = 2
                      )

            BEGIN
                ;THROW 50001, N'تمت قراءة هذا العداد مسبقا', 1;
            END


           
            IF NOT EXISTS (
                SELECT 1
                FROM Housing.BillPeriod bp
                inner join Housing.BillPeriodType bpt on bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE bp.billPeriodActive = 1 and bpt.billPeriodTypeActive = 1
                    AND bp.IdaraId_FK = @IdaraID_INT and bpt.meterServiceTypeID_FK = @meterServiceTypeID   
                      )

            BEGIN
                ;THROW 50001, N'لايوجد فترة نشطة لقراءة هذا العداد', 1;
            END

            
           


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
                  2
                , @meterID
                , @billPeriodID
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , GETDATE()
                , @MeterReadValue
                , null
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
                            + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodID), N'') + N'"'
                            + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), N'') + N'"'
                            + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                            + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), N'') + N'"'
                            + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), N'') + N'"'
                            + N',"dateOfRead": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
                            + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
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
    , @billPeriodID
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
    , 2
    , s.PerviosPeriodID
    , @billPeriodID
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
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @meterReadValue,@Identity_Insert) s;



             


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
            



            SELECT 1 AS IsSuccessful, N'تم تسجيل القراءة واصدار الفاتورة بنجاح' AS Message_;
            RETURN;

         END


        ----------------------------------------------------------------
        -- EDIT
        ----------------------------------------------------------------
         ELSE IF @Action in(N'EDITELECTRICITYMETER',N'EDITWATERMETER',N'EDITGASMETER')
         BEGIN

            IF @BillsID IS NULL 
            BEGIN
                ;THROW 50001, N'رقم الفاتورة مطلوب', 1;
            END

            IF @MeterReadID IS NULL 
            BEGIN
                ;THROW 50001, N'رقم القراءة مطلوب', 1;
            END

            IF @MeterReadValue IS NULL 
            BEGIN
                ;THROW 50001, N'قيمة القراءة الجديدة مطلوبة', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.MeterServiceType mst
                INNER JOIN Housing.MeterServiceTypeLinkedWithIdara msl
                    ON mst.meterServiceTypeID = msl.meterServiceTypeID_FK
                WHERE mst.meterServiceTypeActive = 1
                  AND msl.MeterServiceTypeLinkedWithIdaraActive = 1
                  AND msl.Idara_FK = @IdaraId_FK
                  AND msl.MeterServiceTypeID_FK = @MeterServiceTypeID
            )
            BEGIN
                ;THROW 50001, N'هذه الخدمة غير متوفرة في ادارتك حاليا', 1;
            END

            ----------------------------------------------------------------
            -- Load old bill
            ----------------------------------------------------------------

          
         
          
            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BillPeriod bp
                INNER JOIN Housing.BillPeriodType bpt
                    ON bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE bp.billPeriodActive = 1
                  AND bpt.billPeriodTypeActive = 1
                  AND bp.IdaraId_FK = @IdaraID_INT
                  AND bpt.meterServiceTypeID_FK = @MeterServiceTypeID
                  AND bp.billPeriodID = @billPeriodID
            )
            BEGIN
                ;THROW 50001, N'الفترة المرتبطة بهذه القراءة ليست نشطة حاليا', 1;
            END

         
            ----------------------------------------------------------------
            -- Disable old bill
            ----------------------------------------------------------------
            UPDATE Housing.Bills
               SET BillActive = 0
             WHERE BillsID = @billsID
               AND BillActive = 1;

            SET @Identity_Update1 = @@ROWCOUNT;

            IF @Identity_Update1 IS NULL 
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعطيل الفاتورة القديمة', 1;
            END

            SET @Note = N'{'
                + N'"BillsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BillsID), N'') + N'"'
                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadID), N'') + N'"'
                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterID), N'') + N'"'
                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX),@billPeriodID ), N'') + N'"'
                + N',"NewReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
                + N',"BillActive": "0"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N',"entryDate": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
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
                  N'[Housing].[Bills]'
                , @Action
                , @BillsID
                , @entryData
                , @Note
            );

            ----------------------------------------------------------------
            -- Disable old meter read
            ----------------------------------------------------------------
            UPDATE Housing.MeterRead
               SET meterReadActive = 0
             WHERE meterReadID = @MeterReadID
               AND meterReadActive = 1;

            SET @Identity_Update2 = @@ROWCOUNT;

            IF @Identity_Update2 IS NULL 
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعطيل القراءة القديمة', 1;
            END

            SET @Note1 = N'{'
                + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadID), N'') + N'"'
                + N',"BillsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BillsID), N'') + N'"'
                + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterID), N'') + N'"'
                + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodID), N'') + N'"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ResidentInfoID), N'') + N'"'
                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingDetailsID), N'') + N'"'
                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingDetailsNo), N'') + N'"'
                + N',"NewReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
                + N',"meterReadActive": "0"'
                + N',"IdaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N',"entryDate": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
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
                , @MeterReadID
                , @entryData
                , @Note1
            );

        


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
                  2
                , @meterID
                , @billPeriodID
                , @residentInfoID
                , @GeneralNo
                , @buildingDetailsID
                , @buildingDetailsNo
                , GETDATE()
                , @MeterReadValue
                , null
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


             SET @Identity_Insert = SCOPE_IDENTITY();


            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
             BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد بعد التعديل - MeterRead', 1; -- برمجي
            END


            SET @NewID = @Identity_Insert;



           SET @Note3 = N'{'
                            + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Identity_Insert), N'') + N'"'
                            + N',"meterReadTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), 2), N'') + N'"'
                            + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @meterID), N'') + N'"'
                            + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodID), N'') + N'"'
                            + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), N'') + N'"'
                            + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                            + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), N'') + N'"'
                            + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), N'') + N'"'
                            + N',"dateOfRead": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
                            + N',"meterReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
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
                , @Note3
            );

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
    , @billPeriodID
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
    , 2
    , s.PerviosPeriodID
    , @billPeriodID
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
FROM Housing.CalculteElectrictyBills_ByNewReadValue_ForInsert(@meterID, @meterReadValue,@Identity_Insert) s;



             


            IF NOT EXISTS (SELECT 1 FROM @InsertedBills1)
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل الفاتورة بعد التعديل - Bills', 1;
            END;

            SELECT TOP (1) @Identity_Insert2 = BillID
            FROM @InsertedBills1;

           SELECT TOP (1)
                            @Note4 = N'{'
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
                , @Identity_Insert2
                , @entryData
                , @Note1
            );
            

            SELECT 1 AS IsSuccessful, N'تم تعديل القراءة بنجاح وتعطيل الفاتورة السابقة وإصدار فاتورة جديدة' AS Message_;
            RETURN;

         END


         ----------------------------------------------------------------
        -- EDIT
        ----------------------------------------------------------------
         ELSE IF @Action in(N'DELETEELECTRICITYMETER',N'DELETEWATERMETER',N'DELETEGASMETER')
         BEGIN

            IF @BillsID IS NULL 
            BEGIN
                ;THROW 50001, N'رقم الفاتورة مطلوب', 1;
            END

            IF @MeterReadID IS NULL 
            BEGIN
                ;THROW 50001, N'رقم القراءة مطلوب', 1;
            END

            IF @MeterReadValue IS NULL 
            BEGIN
                ;THROW 50001, N'قيمة القراءة الجديدة مطلوبة', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.MeterServiceType mst
                INNER JOIN Housing.MeterServiceTypeLinkedWithIdara msl
                    ON mst.meterServiceTypeID = msl.meterServiceTypeID_FK
                WHERE mst.meterServiceTypeActive = 1
                  AND msl.MeterServiceTypeLinkedWithIdaraActive = 1
                  AND msl.Idara_FK = @IdaraId_FK
                  AND msl.MeterServiceTypeID_FK = @MeterServiceTypeID
            )
            BEGIN
                ;THROW 50001, N'هذه الخدمة غير متوفرة في ادارتك حاليا', 1;
            END

            ----------------------------------------------------------------
            -- Load old bill
            ----------------------------------------------------------------

          
         
          
            IF NOT EXISTS
            (
                SELECT 1
                FROM Housing.BillPeriod bp
                INNER JOIN Housing.BillPeriodType bpt
                    ON bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
                WHERE bp.billPeriodActive = 1
                  AND bpt.billPeriodTypeActive = 1
                  AND bp.IdaraId_FK = @IdaraID_INT
                  AND bpt.meterServiceTypeID_FK = @MeterServiceTypeID
                  AND bp.billPeriodID = @billPeriodID
            )
            BEGIN
                ;THROW 50001, N'الفترة المرتبطة بهذه القراءة ليست نشطة حاليا', 1;
            END

         
            ----------------------------------------------------------------
            -- Disable old bill
            ----------------------------------------------------------------
            UPDATE Housing.Bills
               SET BillActive = 0
             WHERE BillsID = @billsID
               AND BillActive = 1;

            SET @Identity_Update1 = @@ROWCOUNT;

            IF @Identity_Update1 IS NULL 
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف الفاتورة ', 1;
            END

            SET @Note = N'{'
                + N'"BillsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BillsID), N'') + N'"'
                + N',"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadID), N'') + N'"'
                + N',"meterID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterID), N'') + N'"'
                + N',"CurrentPeriodID": "' + ISNULL(CONVERT(NVARCHAR(MAX),@billPeriodID ), N'') + N'"'
                + N',"NewReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
                + N',"BillActive": "0"'
                + N',"IdaraId_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N',"entryDate": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
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
                  N'[Housing].[Bills]'
                , @Action
                , @BillsID
                , @entryData
                , @Note
            );

            ----------------------------------------------------------------
            -- Disable old meter read
            ----------------------------------------------------------------
            UPDATE Housing.MeterRead
               SET meterReadActive = 0
             WHERE meterReadID = @MeterReadID
               AND meterReadActive = 1;

            SET @Identity_Update2 = @@ROWCOUNT;

            IF @Identity_Update2 IS NULL 
            BEGIN
                ;THROW 50002, N'حصل خطأ في حذف الفاتورة ', 1;
            END

            SET @Note1 = N'{'
                + N'"meterReadID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadID), N'') + N'"'
                + N',"BillsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BillsID), N'') + N'"'
                + N',"meterID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterID), N'') + N'"'
                + N',"billPeriodID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @billPeriodID), N'') + N'"'
                + N',"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ResidentInfoID), N'') + N'"'
                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), N'') + N'"'
                + N',"buildingDetailsID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingDetailsID), N'') + N'"'
                + N',"buildingDetailsNo": "' + ISNULL(CONVERT(NVARCHAR(MAX), @BuildingDetailsNo), N'') + N'"'
                + N',"NewReadValue": "' + ISNULL(CONVERT(NVARCHAR(MAX), @MeterReadValue), N'') + N'"'
                + N',"meterReadActive": "0"'
                + N',"IdaraID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_INT), N'') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                + N',"entryDate": "' + CONVERT(NVARCHAR(19), GETDATE(), 120) + N'"'
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
                , @MeterReadID
                , @entryData
                , @Note1
            );


            SELECT 1 AS IsSuccessful, N'تم حذف القراءة بنجاح وتعطيل الفاتورة السابقة بنجاح' AS Message_;
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
