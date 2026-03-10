
CREATE PROCEDURE [Housing].[AssignStatusSP] 
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
    , @BuildingActionTypeCases              NVARCHAR(1000)  = NULL
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
        ELSE IF @Action = N'ENDASSIGNPERIOD'
        BEGIN


          IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.AssignPeriod a
                WHERE a.AssignPeriodID = @AssignPeriodID
                and a.AssignPeriodActive = 1 and a.AssignPeriodClose = 0 and a.AssignPeriodEnddate is not null and a.AssignPeriodFinalEND = 1 and a.AssignPeriodFinalEnddate is null
                  AND a.IdaraId_FK = @IdaraID_INT
            )
            BEGIN
                ;THROW 50001, N'تم انهاء هذا المحضر مسبقا', 1;
            END

            IF EXISTS
            (
                SELECT 1
                 FROM Housing.V_WaitingList w 
                     WHERE w.AssignPeriodID = @AssignPeriodID
                       AND w.IdaraId = @IdaraID_INT
                       AND  w.LastActionTypeID in (38,40)
            )
            BEGIN
                ;THROW 50001, N'لايمكن انهاء محضر التخصيص لوجود مستفيدين لم يتم معالجتهم لحد الان', 1;
            END

            SET @NewID = (SELECT TOP(1) a.AssignPeriodID 
            FROM Housing.AssignPeriod a 
            where a.IdaraId_FK = @idaraID_FK and a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.AssignPeriodEnddate is null
            order by a.AssignPeriodID desc);

            UPDATE Housing.AssignPeriod 
            set AssignPeriodFinalEnddate = GETDATE(), AssignPeriodFinalENDNote = @Notes, AssignPeriodFinalENDBy =@entryData,AssignPeriodFinalEND = 0
            where AssignPeriodID = @AssignPeriodID 
            and IdaraId_FK = @idaraID_FK and AssignPeriodActive = 1 and AssignPeriodClose = 0 and AssignPeriodEnddate is not null and AssignPeriodFinalEND = 1 and AssignPeriodFinalEnddate is null
            
          

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انهاء محضر التخصيص', 1; -- برمجي
            END


            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في انهاء محضر التخصيص - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"AssignPeriodID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"AssignPeriodFinalENDNote": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"AssignPeriodFinalEND": "0"'
                + N',"AssignPeriodFinalENDBy": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
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
        -- ASSIGNSTATUS
        ----------------------------------------------------------------
        ELSE IF @Action = N'ASSIGNSTATUS'
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
            ) in (39,41,42,45)
            BEGIN
                ;THROW 50001, N'تم معالجة هذا الطلب مسبقا', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 38 and @BuildingActionTypeCases = 1 then 45
            when w.LastActionTypeID = 40 and @BuildingActionTypeCases = 1 then 45 
            when w.LastActionTypeID = 38 and @BuildingActionTypeCases = 0 then 39
            when w.LastActionTypeID = 40 and @BuildingActionTypeCases = 0 then 42 
            else 0
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID

            IF 
            (
               @buildingActionTypeID_FK = 0 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما building Action Type', 1;
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
                ;THROW 50002, N'حصل خطأ في معالجة تخصيص المستفيد', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في معالجة تخصيص المستفيد - Identity', 1; -- برمجي
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
            

            SELECT 1 AS IsSuccessful, N'تم معالجة تخصيص المستفيد بنجاح' AS Message_;
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
