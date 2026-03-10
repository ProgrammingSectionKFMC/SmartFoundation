
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
    , @AssignPeriodID                       NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @meterID                              NVARCHAR(1000)  = NULL
    , @NewMeterReadValue                    NVARCHAR(1000)  = NULL
    , @meterReadID                          NVARCHAR(1000)  = NULL
    , @ExitDate                          NVARCHAR(1000)  = NULL
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
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    DECLARE @buildingDetailsNo nvarchar(200) 
    set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);

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

   


         IF @Action IN(N'MeterRead')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@meterID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'معرف العداد غير مرسل بشكل صحيح', 1;
            END

          IF NULLIF(LTRIM(RTRIM(@NewMeterReadValue)), N'') IS NULL
               OR TRY_CONVERT(BIGINT, @NewMeterReadValue) IS NULL
               OR TRY_CONVERT(BIGINT, @NewMeterReadValue) < 0
            BEGIN
                ;THROW 50001, N'يجب إدخال قراءة عداد صحيحة (رقم صحيح موجب)', 1;
            END


        END

        

     

        ----------------------------------------------------------------
        -- METERREADFOROCCUBENTANDEXIT
        ----------------------------------------------------------------
        IF @Action = N'METERREADFOROCCUBENTANDEXIT'
        BEGIN
       


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
                ;THROW 50001, N'تم قراءة عدادات الخدمات مسبقا', 1;
            END



            Declare @buildingActionTypeID_FK INT , @meterReadTypeID_FK int, @billPeriodID_FK int

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 46  then 47
             when w.LastActionTypeID = 59  then 60
            else 
            9999
            END,
            @meterReadTypeID_FK =
            case 
            when w.LastActionTypeID = 46  then 1
            when w.LastActionTypeID = 59  then 3
            else 
            9999
            END,
            @billPeriodID_FK =
            case 
            when w.LastActionTypeID = 46  then 1
            when w.LastActionTypeID = 59  then 1
            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type Meter read', 1;
            END


             IF 
            (
               @meterReadTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما meter Read Type Meter read', 1;
            END

           IF 
            (
               @billPeriodID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما bill Period Meter read', 1;
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
                  @meterReadTypeID_FK
                , @meterID
                , @billPeriodID_FK
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


             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد', 1; -- برمجي
            END

             SET @NewID = SCOPE_IDENTITY();


              Declare @MeterServiceReaded int
    set @MeterServiceReaded =(
            Select Count(*)
            FROM Housing.V_WaitingList w 
                INNER JOIN Housing.V_GetFullResidentDetails rd ON w.residentInfoID = rd.residentInfoID
                Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
                left Join Housing.V_GetListMetersLinkedWithBuildings mbb on w.buildingDetailsID = mbb.buildingDetailsID_FK
                left join Housing.V_GetListAllMetersLastRead mr on mbb.meterID = mr.meterID_FK
                left join Housing.MeterRead m on mr.meterReadID = m.meterReadID
                left join Housing.MeterReadType mrt on m.meterReadTypeID_FK = mrt.meterReadTypeID
                left join Housing.MeterServiceType mst on mbb.meterServiceTypeID_FK = mst.meterServiceTypeID
                left join Housing.MeterType mty on mbb.meterTypeID_FK = mty.meterTypeID
        
        WHERE w.IdaraId = @idaraID_FK
          AND  w.LastActionTypeID in (46,59)
          AND w.buildingDetailsID = @buildingDetailsID
          and m.BuildingActionID_FK is not null

    )

            if(@MeterServiceCount = @MeterServiceReaded)
            begin

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
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @buildingActionTypeID_FK
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
                , @ExitDate
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد', 1; -- برمجي
            END

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل قراءة العداد - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
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
                , @Note
            );

            END

            
            SELECT 1 AS IsSuccessful, N'تم  قراءة العداد بنجاح' AS Message_;
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
                ;THROW 50001, N'لايمكن تعديل قراءة عدادات الخدمات ', 1;
            END



            Declare @buildingActionTypeID_FK1 INT , @meterReadTypeID_FK1 int, @billPeriodID_FK1 int

            select 
            @buildingActionTypeID_FK1 =
            case 
            when w.LastActionTypeID = 46  then 47
            when w.LastActionTypeID = 59  then 60
            else 
            9999
            END,
            @meterReadTypeID_FK1 =
            case 
            when w.LastActionTypeID = 46  then 1
            when w.LastActionTypeID = 59  then 3
            else 
            9999
            END,
            @billPeriodID_FK1 =
            case 
            when w.LastActionTypeID = 46  then 1
            when w.LastActionTypeID = 59  then 1

            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID

            IF 
            (
               @buildingActionTypeID_FK1 = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type Meter read', 1;
            END


             IF 
            (
               @meterReadTypeID_FK1 = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما meter Read Type Meter read', 1;
            END

           IF 
            (
               @billPeriodID_FK1 = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما bill Period Meter read', 1;
            END


            UPDATE  Housing.[MeterRead]
            set meterReadActive = 0 , CanceledBy = @entryData
            where meterReadID = @meterReadID

               IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل قراءة العداد', 1; -- برمجي
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
                  ,[BuildingActionID_FK]
                  ,[meterReadActive]
                  ,[IdaraID_FK]
                  ,[entryData]
                  ,[hostName]
                
            )
            
             VALUES
            (
                  @meterReadTypeID_FK1
                , @meterID
                , @billPeriodID_FK1
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


             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل قراءة العداد', 1; -- برمجي
            END


            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل قراءة العداد - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
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
                , N'UPDATEMETERREADFOROCCUBENTANDEXIT'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تعديل قراءة العداد بنجاح' AS Message_;
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
