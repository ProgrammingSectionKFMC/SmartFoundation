
CREATE PROCEDURE [Housing].[AssignSP] 
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

   


         IF @Action IN(N'OPENASSIGNPERIOD')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة وصف لمحضر التخصيص', 1;
            END

           
        END

        ----------------------------------------------------------------
        -- OPENASSIGNPERIOD
        ----------------------------------------------------------------
        IF @Action = N'OPENASSIGNPERIOD'
        BEGIN


          IF EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'يوجد محضر تخصيص نشط', 1;
            END


            INSERT INTO  Housing.AssignPeriod
            (
                 [AssignPeriodDescrption]
                ,[AssignPeriodStartdate]
                ,[AssignPeriodActive]
                ,[AssignPeriodClose]
                ,[AssignPeriodFinalEND]
                ,[IdaraId_FK]
                ,[entryData]
                ,[hostName]
            )
            VALUES
            (
                  @Notes
                , GETDATE()
                , 1
                , 1
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء محضر التخصيص', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انشاء محضر التخصيص - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"AssignPeriodID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"AssignPeriodDescrption": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"AssignPeriodStartdate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"AssignPeriodActive": "1"'
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
                  N'[Housing].[AssignPeriod]'
                , N'OPENASSIGNPERIOD'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم انشاء محضر التخصيص بنجاح' AS Message_;
            RETURN;
        END



         ----------------------------------------------------------------
        -- OPENASSIGNPERIOD
        ----------------------------------------------------------------
        ELSE IF @Action = N'CLOSEASSIGNPERIOD'
        BEGIN


          IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'لا يوجد محضر تخصيص نشط', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList a
                WHERE a.AssignPeriodID = @AssignPeriodID
                  AND a.IdaraId = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'لايمكن اغلاق المحضر التخصيص لعدم وجود اي مستفيد مخصص له منزل', 1;
            END

            SET @NewID = (SELECT TOP(1) a.AssignPeriodID 
            FROM Housing.AssignPeriod a 
            where a.IdaraId_FK = @idaraID_FK and a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
            order by a.AssignPeriodID desc);

            UPDATE Housing.AssignPeriod 
            set AssignPeriodEnddate = GETDATE(), AssignPeriodCloseNote = @Notes, AssignPeriodCloseBy =@entryData,AssignPeriodClose = 0
            where IdaraId_FK = @idaraID_FK and AssignPeriodActive = 1 and AssignPeriodClose = 1 and AssignPeriodEnddate is null 
            
          

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اغلاق محضر التخصيص', 1; -- برمجي
            END


            
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
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
            Select 
            w.LastActionTypeID
            ,w.residentInfoID
            ,w.GeneralNo
            ,w.ActionDecisionNo
            ,w.ActionDecisionDate
            ,w.buildingDetailsID
            ,w.buildingDetailsNo
            ,1
            ,w.LastActionNote
            ,w.LastActionbuildingActionParentID
            ,@AssignPeriodID
            ,@idaraID_FK
            ,@entryData
            ,@hostName

            From Housing.V_WaitingList w
            where 
                 w.IdaraId = 1
                 AND  w.LastActionTypeID in (27,39,41)


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تخصيص المنزل للمستفيد', 1; -- برمجي
            END



            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اغلاق محضر التخصيص - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"AssignPeriodID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"AssignPeriodDescrption": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"AssignPeriodStartdate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"AssignPeriodActive": "1"'
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
                  N'[Housing].[AssignPeriod]'
                , N'CLOSEASSIGNPERIOD'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اغلاق محضر التخصيص بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- ASSIGNHOUSE
        ----------------------------------------------------------------
        ELSE IF @Action = N'ASSIGNHOUSE'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

              IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'لا يوجد محضر تخصيص نشط', 1;
            END
            
             IF @buildingDetailsID IS NULL
            BEGIN
                ;THROW 50001, N'يجب اختيار المبنى', 1;
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
                FROM [DATACORE].[Housing].[V_GetGeneralListForBuilding] c
                where c.BuildingIdaraID = @IdaraID_INT and c.buildingDetailsActive = 1
            )
            BEGIN
                ;THROW 50001, N'عذرا المنزل غير نشط حاليا', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (38,40)
            BEGIN
                ;THROW 50001, N'تم التخصيص لهذا المستفيد مسبقا', 1;
            END

            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 27 then 38
            when w.LastActionTypeID = 39 then 40
            else 0
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID




            IF 
            (
               @buildingActionTypeID_FK = 0 
            )
            BEGIN
                ;THROW 50001, N'لايمكن التخصيص لهذا المستفيد لتجاوزه الحد الاعلى من التخصيص', 1;
            END

          

             IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (42)
            BEGIN
            Declare @msg1 nvarchar(1000)
            set @msg1 = N'تم الغاء أحقية السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' مسبقا لتجاوزه عدد مرات التخصيص المسموحة نظام'
                ;THROW 50001, @msg1, 1;
            END


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
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
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
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تخصيص المنزل للمستفيد', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تخصيص المنزل للمستفيد - Identity', 1; -- برمجي
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
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
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
                , N'ASSIGNHOUSE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تخصيص المنزل للمستفيد بنجاح' AS Message_;
            RETURN;
        END


        ----------------------------------------------------------------
        -- CANCLEASSIGNHOUSE
        ----------------------------------------------------------------
        ELSE IF @Action = N'CANCLEASSIGNHOUSE'
        BEGIN
       
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END
            
             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'لا يوجد محضر تخصيص نشط', 1;
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
               @LastActionTypeID NOT IN (38,40)
            )
            BEGIN
                ;THROW 50001, N'لايوجد تخصيص منزل للمستفيد لاستبعاده !! ', 1;
            END

          
           Declare @buildingActionTypeID_FK1 INT

            select 
            @buildingActionTypeID_FK1 =
            case 
            when @LastActionTypeID = 38 then 27
            when @LastActionTypeID = 40 then 39
            else null
            END
           

           

            Declare @LastBuildingNo Nvarchar(200),@LastBuildingID bigint

            Select @LastBuildingNo = ba.buildingDetailsNo,@LastBuildingID = ba.buildingDetailsID_FK
            from BuildingAction ba where ba.buildingActionID = @LastActionID


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
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  44
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @LastBuildingID
                , @LastBuildingNo
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            Declare @TakeOffResidentFromAssignPeriodIdentity Bigint
            set @TakeOffResidentFromAssignPeriodIdentity = SCOPE_IDENTITY()
            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في استبعاد المستفيد من محضر التخصيص', 1; -- برمجي
            END



              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                --, buildingDetailsID_FK
                --, buildingDetailsNo
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (

                  @buildingActionTypeID_FK1
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                --, @buildingDetailsID
                --, @buildingDetailsNo
                , 1
                , NULL
                , @TakeOffResidentFromAssignPeriodIdentity
                , NULL
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في استبعاد المستفيد من محضر التخصيص', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في استبعاد المستفيد من محضر التخصيص - Identity', 1; -- برمجي
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
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
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
                , N'ASSIGNHOUSE'
                , @ActionID
                , @entryData
                , @Note
            );

             Declare @msg6 nvarchar(1000)
             --if (@buildingActionTypeID_FK2 = 39)
             --BEGIN
             --set @msg5 = N'تم تبديل المنزل للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' بنجاح'
             --END
             --ELSE if (@buildingActionTypeID_FK = 41)
             --BEGIN
             --set @msg5 = N'تم الغاء تخصيص السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' للمرة الثانية'
             --END
             -- ELSE if (@buildingActionTypeID_FK = 42)
             --BEGIN
             --set @msg5 = N'تم الغاء أحقية السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' لتجاوزه عدد مرات التخصيص المسموحة نظام'
             --END

             set @msg6 = N'تم استبعاد المستفيد'+cast(@FullName_A as nvarchar(1000))+N' من محضر التخصيص بنجاح'
            SELECT 1 AS IsSuccessful, @msg6 AS Message_;
            RETURN;
        END

            
        

            
        
        
        ----------------------------------------------------------------
        -- UPDATEASSIGNHOUSE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEASSIGNHOUSE'
        BEGIN
       
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END
            
              IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'لا يوجد محضر تخصيص نشط', 1;
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
               @LastActionTypeID NOT IN (38,40)
            )
            BEGIN
                ;THROW 50001, N'لايوجد منزل مخصص مسبقا لاستبداله ', 1;
            END

          

             IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (42)
            BEGIN
            Declare @msg4 nvarchar(1000)
            set @msg4 = N'تم الغاء أحقية السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' مسبقا '
                ;THROW 50001, @msg1, 1;
            END


            Declare @LastBuildingNo1 Nvarchar(200),@LastBuildingID1 bigint

            Select @LastBuildingNo1 = ba.buildingDetailsNo,@LastBuildingID1 = ba.buildingDetailsID_FK
            from BuildingAction ba where ba.buildingActionID = @LastActionID


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
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  43
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @LastBuildingID1
                , @LastBuildingNo1
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            Declare @changeHouseIdentity Bigint
            set @changeHouseIdentity = SCOPE_IDENTITY()
            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تبديل المنزل للمستفيد', 1; -- برمجي
            END



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
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (

                  @lastActionTypeID
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @changeHouseIdentity
                , @AssignPeriodID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تبديل المنزل للمستفيد', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تبديل المنزل للمستفيد - Identity', 1; -- برمجي
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
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
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
                , N'ASSIGNHOUSE'
                , @ActionID
                , @entryData
                , @Note
            );

             Declare @msg5 nvarchar(1000)
             --if (@buildingActionTypeID_FK2 = 39)
             --BEGIN
             --set @msg5 = N'تم تبديل المنزل للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' بنجاح'
             --END
             --ELSE if (@buildingActionTypeID_FK = 41)
             --BEGIN
             --set @msg5 = N'تم الغاء تخصيص السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' للمرة الثانية'
             --END
             -- ELSE if (@buildingActionTypeID_FK = 42)
             --BEGIN
             --set @msg5 = N'تم الغاء أحقية السكن للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' لتجاوزه عدد مرات التخصيص المسموحة نظام'
             --END

             set @msg5 = N'تم تبديل المنزل للمستفيد'+cast(@FullName_A as nvarchar(1000))+N' بنجاح'
            SELECT 1 AS IsSuccessful, @msg5 AS Message_;
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
