
CREATE PROCEDURE [Housing].[OtherWaitingListSP] 
(
      @Action                       NVARCHAR(200)
    , @ActionID                     BIGINT          = NULL
    , @residentInfoID_FK            NVARCHAR(100)   = NULL
    , @residentName                 NVARCHAR(100)   = NULL
    , @NationalID                   NVARCHAR(100)   = NULL
    , @GeneralNo                    NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo     NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate   NVARCHAR(1000)  = NULL
    , @WaitingClassID               NVARCHAR(1000)  = NULL
    , @WaitingClassName             NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID           NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeName         NVARCHAR(1000)  = NULL
    , @buildingDetailsID            NVARCHAR(1000)  = NULL
    , @Notes                        NVARCHAR(1000)  = NULL
    , @idaraID_FK                   NVARCHAR(10)    = NULL
    , @entryData                    NVARCHAR(20)    = NULL
    , @hostName                     NVARCHAR(200)   = NULL
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
    DECLARE @buildingDetailsNo nvarchar(500)
    set @buildingDetailsNo = (select top(1) b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID and b.BuildingIdaraID = @idaraID_FK order by b.buildingDetailsID desc)
    DECLARE @ActionTypeID int 
    set @ActionTypeID = (select w.ActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID)
    
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

            IF NULLIF(LTRIM(RTRIM(@ActionID)), N'') IS NULL
            BEGIN
                 ;THROW 50001, N'يوجد خطأ بجلب بيانات سجل الانتظار - Action ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - resident ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - GN', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - @NationalID', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم القرار مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ القرار مطلوب', 1;
            END
            if(@ActionTypeID Not in (7))
            Begin
         IF NULLIF(LTRIM(RTRIM(@WaitingClassID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'فئة سجل الانتظار مطلوبة', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@WaitingOrderTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'ترتيب سجل الانتظار مطلوبة', 1;
            END
            END

        ----------------------------------------------------------------
        -- MOVETOASSIGNLIST
        ----------------------------------------------------------------
        IF @Action = N'MOVETOOCCUPENTPROCEDURES'
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


             IF EXISTS
            (
                SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID and w.LastActionTypeID = 45 and w.ToIdaraID = @idaraID_FK
                  
            )
            BEGIN
                ;THROW 50001, N'تم اتخاذ اجراء للطلب مسبقا', 1;
            END

            IF EXISTS
            (
              select 1
              from Housing.V_WaitingList v 
              where v.residentInfoID = @residentInfoID_FK
              and (v.buildingActionRoot = 2 OR v.LastActionTypeID IN (38,40,45,46,47,57,58))
            )
            BEGIN
                ;THROW 50001, N'المستفيد ساكن او تحت اجراءات التسكين بسجل انتظار اخر او مسجل بمحضر تخصيص لفئة اخرى', 1;
            END

             
-- Validate the selected house before creating action 45.
-- Use the same occupancy lock as AssignSP.

DECLARE @OtherHouseID BIGINT =
    TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID, N''));

IF @OtherHouseID IS NULL OR @OtherHouseID <= 0
    THROW 50001, N'يجب اختيار منزل صالح.', 1;

DECLARE @OtherHouseLockResult INT;
DECLARE @OtherHouseLockResource NVARCHAR(255) =
    CONCAT(
        N'Housing.Occupancy:',
        @IdaraID_INT,
        N':',
        @OtherHouseID
    );

EXEC @OtherHouseLockResult = sys.sp_getapplock
    @Resource = @OtherHouseLockResource,
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 10000;

IF @OtherHouseLockResult < 0
    THROW 50001,
        N'تجري معالجة أخرى للمنزل؛ حدّث الصفحة وأعد المحاولة.',
        1;

IF NOT EXISTS
(
    SELECT 1
    FROM Housing.V_GetGeneralListForBuilding c
    WHERE c.buildingDetailsID = @OtherHouseID
      AND c.BuildingIdaraID = @IdaraID_INT
      AND c.buildingDetailsActive = 1
      AND c.LastActionTypeID = 5

      AND EXISTS
      (
          SELECT 1
          FROM Housing.BuildingSpace bs
          INNER JOIN Housing.BuildingSpaceType bst
              ON bst.BuildingSpaceTypeID =
                 bs.BuildingSpaceTypeID_FK
          WHERE bs.BuildingDetailsID_FK = c.buildingDetailsID
            AND bs.BuildingSpaceActive = 1
            AND bs.BuildingSpaceTypeID_FK = 1
            AND bst.BuildingSpaceTypeCode = N'BEDROOM'
            AND bst.BuildingSpaceTypeActive = 1

            AND (
                bs.BuildingSpaceStartDate IS NULL
                OR bs.BuildingSpaceStartDate <= CAST(GETDATE() AS DATE)
            )
            AND (
                bs.BuildingSpaceEndDate IS NULL
                OR bs.BuildingSpaceEndDate >= CAST(GETDATE() AS DATE)
            )
            AND (
                bst.BuildingSpaceTypeStartDate IS NULL
                OR bst.BuildingSpaceTypeStartDate <= CAST(GETDATE() AS DATE)
            )
            AND (
                bst.BuildingSpaceTypeEndDate IS NULL
                OR bst.BuildingSpaceTypeEndDate >= CAST(GETDATE() AS DATE)
            )
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.V_Occupant occupant
          WHERE occupant.buildingDetailsID = c.buildingDetailsID
            AND (
                occupant.LastActionTypeID IS NULL
                OR occupant.LastActionTypeID NOT IN (57, 58)
            )
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.V_WaitingList holding
          WHERE holding.buildingDetailsID = c.buildingDetailsID
            AND holding.LastActionTypeID IN (38, 40, 45, 46, 47)

            AND NOT EXISTS
            (
                SELECT 1
                FROM Housing.BuildingAction oldMigrationAction
                INNER JOIN Housing.AssignPeriod oldMigrationPeriod
                    ON oldMigrationPeriod.AssignPeriodID =
                       oldMigrationAction.AssignPeriodID_FK
                WHERE oldMigrationAction.buildingActionID =
                      holding.LastActionID
                  AND oldMigrationAction.buildingActionExtraText5 =
                      N'MIGRATION_GENERATED'
                  AND oldMigrationPeriod.AssignPeriodDescrption LIKE
                      N'Legacy allocation migration - WaitingClass %'
            )
      )
)
BEGIN
    THROW 50001,
        N'المنزل غير مؤهل للتسكين: يلزم أن يكون جاهزًا بالإجراء 5، وبه غرفة نوم نشطة، وغير مشغول أو مرتبط بتخصيص قائم.',
        1;
END;

if(@ActionTypeID Not in (7))
            Begin
              
                DECLARE @MyOrder int;
                DECLARE @ErrMsg_  nvarchar(4000);
                
                SELECT @MyOrder = x.rn
                FROM
                (
                    SELECT
                        w.ActionID,
                        ROW_NUMBER() OVER (ORDER BY w.ActionDecisionDate ASC,w.ActionDecisionNo ASC, w.GeneralNo ASC) AS rn
                   FROM Housing.V_WaitingList w
                   INNER JOIN Housing.V_GetFullResidentDetails rd 
                       ON w.residentInfoID = rd.residentInfoID
                   WHERE w.WaitingClassID = @WaitingClassID
                     AND w.IdaraId = @idaraID_FK
                     AND  (w.LastActionTypeID is null or w.LastActionTypeID in (34,35))
                     AND w.residentInfoID = @residentInfoID_FK
                ) x
                WHERE x.ActionID = @ActionID;
                
                IF @MyOrder IS NULL
                BEGIN
                    SET @ErrMsg_ = N'لم يتم العثور على الطلب داخل قائمة الانتظار';
                    ;THROW 50001, @ErrMsg_, 1;
                END
                
                END
                --IF cast(@MyOrder as int) <> 1
                --BEGIN
                --    SET @ErrMsg_ =
                --        N' المستفيد '+CAST(@residentName AS nvarchar(200))+N' ليس في رأس قائمة الانتظار في '
                --        + CAST(@WaitingClassName AS nvarchar(20));
                --    ;THROW 50001, @ErrMsg_, 1;
                --END

              

           

             INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionExtraType1
                , buildingActionExtraType2
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  45
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , case when @ActionTypeID = 7 then null
                  else @WaitingClassID END
                , @WaitingOrderTypeID
                , 1
                , @Notes
                , @ActionID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );
            
       

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في نقل المستفيد لاجراءات التسكين', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في المستفيد لاجراءات التسكين - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 45), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                , N'MOVETOOCCUPENTPROCEDURES'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم نقل المستفيد لاجراءات التسكين بنجاح' AS Message_;
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

