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
        
        /* APH_STAGE03B_BEGIN: serialized write paths */
        IF @Action IN (N'CLOSEASSIGNPERIOD',N'ASSIGNHOUSE',N'UPDATEASSIGNHOUSE',N'CANCLEASSIGNHOUSE')
        BEGIN
            DECLARE @APHLockResult INT;
            EXEC @APHLockResult=sys.sp_getapplock
                @Resource=N'Housing.AssignPeriodHistory',
                @LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
            IF @APHLockResult<0
                THROW 51405,N'تعذر قفل سجل محاضر التخصيص مؤقتًا.',1;
            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.AssignPeriod p
                WHERE p.AssignPeriodID=TRY_CONVERT(BIGINT,@AssignPeriodID)
                  AND p.IdaraId_FK=@IdaraID_INT
                  AND p.WaitingClassID_FK=TRY_CONVERT(INT,@WaitingClassID)
                  AND p.AssignPeriodActive=1
                  AND p.AssignPeriodClose=1
                  AND p.AssignPeriodEnddate IS NULL
            )
                THROW 51406,N'محضر التخصيص لا يتبع للإدارة والفئة المحددتين أو ليس مفتوحًا.',1;
        END;
        /* APH_STAGE03B_END */
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END


        
-- حماية التخصيص من ازدواج السكن عبر جميع الإدارات
IF @Action IN
(
    N'ASSIGNHOUSE',
    N'UPDATEASSIGNHOUSE'
)
BEGIN
    DECLARE @GuardResidentID BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(@residentInfoID, N''));

    IF @GuardResidentID IS NULL OR @GuardResidentID <= 0
        THROW 50001, N'معرف المستفيد غير صحيح.', 1;

    IF @ActionID IS NULL
        THROW 50001, N'رقم سجل الانتظار مطلوب.', 1;

    -- قفل موحد على المستفيد، دون ربطه بإدارة
    DECLARE @GuardLockResult INT;
    DECLARE @GuardLockName NVARCHAR(255) =
        CONCAT(N'Housing.ResidentHousing:', @GuardResidentID);

    EXEC @GuardLockResult = sys.sp_getapplock
          @Resource = @GuardLockName,
          @LockMode = N'Exclusive',
          @LockOwner = N'Transaction',
          @LockTimeout = 10000;

    IF @GuardLockResult < 0
        THROW 50001,
            N'تجري عملية إسكان أخرى للمستفيد؛ يرجى إعادة المحاولة.',
            1;

    DECLARE
        @GuardConflictID BIGINT = NULL,
        @GuardStage INT,
        @GuardHouse NVARCHAR(200),
        @GuardIdara NVARCHAR(300),
        @GuardStageName NVARCHAR(300),
        @GuardMessage NVARCHAR(2048);

    SELECT TOP (1)
        @GuardConflictID = w.ActionID,
        @GuardStage = w.LastActionTypeID,
        @GuardHouse = COALESCE(
            NULLIF(w.buildingDetailsNo, N''),
            CONVERT(NVARCHAR(30), w.buildingDetailsID),
            N'غير محدد'
        ),
        @GuardIdara = COALESCE(
            i.idaraLongName_A,
            N'غير محددة'
        ),
        @GuardStageName = COALESCE(
            w.LastActionTypeName,
            N'غير محددة'
        )
    FROM Housing.V_WaitingList w
    LEFT JOIN Housing.BuildingDetails b
        ON b.buildingDetailsID = w.buildingDetailsID
    LEFT JOIN dbo.Idara i
        ON i.idaraID = COALESCE(b.IdaraId_FK, w.IdaraId)
    WHERE w.residentInfoID = @GuardResidentID
      AND w.ActionID <> @ActionID
      AND
      (
          w.buildingActionRoot = 2
          OR w.LastActionTypeID IN
          (38,40,45,46,47,57,58)
      )
    ORDER BY
        CASE
            WHEN w.LastActionTypeID IN (57,58) THEN 0
            WHEN w.buildingActionRoot = 2 THEN 1
            ELSE 2
        END,
        w.LastActionID DESC;

    IF @GuardConflictID IS NOT NULL
    BEGIN
        SET @GuardMessage = CONCAT(
            N'لا يمكن تخصيص المنزل للمستفيد.',
            N' يوجد ارتباط سكني آخر.',
            N' الإدارة: ', @GuardIdara,
            N'، المنزل: ', @GuardHouse,
            N'، آخر إجراء: ', @GuardStageName,
            N' (', @GuardStage, N'). ',
            CASE
                WHEN @GuardStage IN (57,58)
                    THEN N'إخلاء المستفيد لازال تحت الإجراء ولم يعتمد الاخلاء نهائياً .'
                WHEN @GuardStage IN (38,40,45,46,47)
                    THEN N'المستفيد مرتبط بطلب تخصيص أو تسكين آخر لم تكتمل إجراءاته. يجب مراجعة الطلب السابق واستكماله أو إلغاؤه نظامياً قبل إجراء تخصيص جديد.'
                ELSE
                    N'يجب اكتمال الإخلاء النهائي  قبل تخصيص منزل جديد.'
            END
        );

        THROW 50001, @GuardMessage, 1;
    END;
END;

   


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
                WHERE a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 and a.WaitingClassID_FK = @WaitingClassID
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
                ,[WaitingClassID_FK]
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
                , @WaitingClassID
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
                + N',"WaitingClassID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @WaitingClassID), '') + N'"'
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
            and WaitingClassID_FK = @WaitingClassID
            
          

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
                , InAssignPeriod
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
            , 1
            ,@idaraID_FK
            ,@entryData
            ,@hostName

            From Housing.V_WaitingList w
            where 
                 w.IdaraId = @idaraID_FK
                 AND  (w.LastActionTypeID in (27,39,41)
                 OR ((w.LastActionTypeID in (38,40)) and (w.InAssignPeriod IS NULL or w.InAssignPeriod <> 1)))
                 and w.WaitingClassID = @WaitingClassID

            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اغلاق محضر التخصيص', 1; -- برمجي
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

            EXEC Housing.SyncAssignPeriodHistory @AssignPeriodID=@AssignPeriodID, @ApplyChanges=1;
            SELECT 1 AS IsSuccessful, N'تم اغلاق محضر التخصيص بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- ASSIGNHOUSE
        ----------------------------------------------------------------
        ELSE IF @Action = N'ASSIGNHOUSE'
        BEGIN
        /* APH_EXCLUSIVITY_20261028_BEGIN */
        -- Server-side identity: NEVER trust residentInfoID / LastActionID submitted by browser.
        DECLARE @APH_ResidentID BIGINT;
        SELECT @APH_ResidentID=ba.residentInfoID_FK
        FROM Housing.BuildingAction ba
        WHERE ba.buildingActionID=@ActionID
          AND ba.buildingActionTypeID_FK IN (1,7,25)
          AND ba.buildingActionActive=1
          AND ba.IdaraId_FK=@IdaraID_INT;
        IF @APH_ResidentID IS NULL
          THROW 50001,N'سجل الانتظار غير صالح أو لا يتبع لإدارتك.',1;
        IF TRY_CONVERT(BIGINT,@residentInfoID) IS NULL OR
           TRY_CONVERT(BIGINT,@residentInfoID)<>@APH_ResidentID
          THROW 50001,N'بيانات المستفيد لا تطابق سجل الانتظار المعتمد.',1;

        -- Restrict allocation to the EXACT active/open minute in this department/class.
        -- The previous code only checked that SOME minute was open in the department.
        IF NOT EXISTS
        (
          SELECT 1 FROM Housing.AssignPeriod ap WITH (UPDLOCK, HOLDLOCK)
          WHERE ap.AssignPeriodID=TRY_CONVERT(BIGINT,@AssignPeriodID)
            AND ap.WaitingClassID_FK=TRY_CONVERT(INT,@WaitingClassID)
            AND ap.IdaraId_FK=@IdaraID_INT
            AND ap.AssignPeriodActive=1 AND ap.AssignPeriodClose=1
            AND ap.AssignPeriodEnddate IS NULL
        )
          THROW 50001,N'المحضر المختار غير مفتوح أو لا يتبع لفئة الانتظار أو الإدارة الحالية.',1;

        -- Serialize operations for the same resident, across waiting classes and departments.
        DECLARE @APH_ResidentLockResult INT;
        DECLARE @APH_ResidentLockResource NVARCHAR(255) =
            CONCAT(N'Housing.ResidentHousing:',@APH_ResidentID);
        EXEC @APH_ResidentLockResult=sys.sp_getapplock
           @Resource=@APH_ResidentLockResource,
           @LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
        IF @APH_ResidentLockResult<0
          THROW 50001,N'تجري معالجة سكنية أخرى للمستفيد؛ يرجى إعادة المحاولة.',1;

        -- Fresh and authorized waiting root; client-provided parent cannot be stale or forged.
        IF NOT EXISTS
        (
          SELECT 1 FROM Housing.V_WaitingList w
          WHERE w.ActionID=@ActionID AND w.residentInfoID=@APH_ResidentID
            AND w.IdaraId=@IdaraID_INT
            AND w.WaitingClassID=TRY_CONVERT(INT,@WaitingClassID)
            AND w.LastActionID=TRY_CONVERT(BIGINT,@LastActionID)
            AND w.LastActionTypeID IN (27,39)
        )
          THROW 50001,N'بيانات طلب الانتظار تغيرت أو لم تعد مؤهلة للتخصيص؛ حدّث الصفحة.',1;

        -- Current OPERATIONAL allocations in ANY minute, class, root, or department.
        -- Legacy reconstructed minutes intentionally excluded: they can have historical
        -- missing outcomes and do not establish a current housing commitment alone.
        IF EXISTS
        (
          SELECT 1
          FROM Housing.AssignPeriodMember m
          JOIN Housing.AssignPeriodAllocation a
            ON a.AssignPeriodMemberID_FK=m.AssignPeriodMemberID
          WHERE m.ResidentInfoID_FK=@APH_ResidentID
            AND m.DataOrigin=N'OPERATIONAL'
            AND a.OutcomeActionID_FK IS NULL
        )
          THROW 50001,N'للمستفيد تخصيص تشغيلي سابق لم تتم معالجته، ولو في محضر أو إدارة أخرى.',1;

        -- No approved housing/ongoing occupancy / pending exit until FINAL action 3.
        -- 54=physical receipt, 57=available for operational house workflow; neither
        -- releases the resident to be allocated another house until 3.
        IF EXISTS
        (
          SELECT 1 FROM Housing.V_WaitingList w
          WHERE w.residentInfoID=@APH_ResidentID
            AND
            (
              w.LastActionTypeID IN (45,46,47)
              OR (w.LastActionTypeID<>3
                  AND (w.buildingActionRoot=2
                       OR w.LastActionTypeID IN (2,24,48,49,50,51,52,54,55,56,57,58,59,60,61)))
              OR
              (
                w.LastActionTypeID IN (38,40)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM Housing.BuildingAction legacyAction
                    JOIN Housing.AssignPeriod legacyPeriod
                      ON legacyPeriod.AssignPeriodID=legacyAction.AssignPeriodID_FK
                    WHERE legacyAction.buildingActionID=w.LastActionID
                      AND legacyAction.buildingActionExtraText5=N'MIGRATION_GENERATED'
                      AND legacyPeriod.AssignPeriodDescrption LIKE
                          N'Legacy allocation migration - WaitingClass %'
                )
              )
            )
        )
          THROW 50001,N'المستفيد لديه تخصيص أو موافقة أو إشغال لم يكتمل إخلاؤه نهائياً بالإجراء 3، ولو في إدارة أخرى.',1;
        /* APH_EXCLUSIVITY_20261028_END */

       


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
            and w.ActionID = @ActionID




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


             IF NOT EXISTS
            (
                 SELECT 1
                FROM [DATACORE].[Housing].[V_GetGeneralListForBuilding] c
                where c.buildingDetailsID = TRY_CONVERT(BIGINT, @buildingDetailsID)
                  and c.BuildingIdaraID = @IdaraID_INT
                  and c.buildingDetailsActive = 1
                  and c.LastActionTypeID in (5,39,41,42,43,44)
            )
            BEGIN
                ;THROW 50001, N'لا يمكن التخصيص؛ المنزل غير متاح أو تم تخصيصه لمستفيد اخر قم بتحديث الصفحه', 1;
            END

            


              
            /* APH_HOUSE_ELIGIBILITY_20261028_A_BEGIN */
            DECLARE @APH_HouseID_A BIGINT = TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID,N''));
            IF @APH_HouseID_A IS NULL OR @APH_HouseID_A <= 0
                THROW 50001, N'يجب اختيار منزل صالح.', 1;

            DECLARE @APH_HouseLockResult_A INT;
            DECLARE @APH_HouseLockResource_A NVARCHAR(255) =
                CONCAT(N'Housing.Occupancy:',@IdaraID_INT,N':',@APH_HouseID_A);
            EXEC @APH_HouseLockResult_A = sys.sp_getapplock
                  @Resource = @APH_HouseLockResource_A,
                  @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
            IF @APH_HouseLockResult_A < 0
                THROW 50001,N'تجري معالجة أخرى للمنزل؛ حدّث الصفحة وأعد المحاولة.',1;

            IF NOT EXISTS
            (
               SELECT 1
               FROM Housing.V_GetGeneralListForBuilding c
               WHERE c.buildingDetailsID = @APH_HouseID_A
                 AND c.BuildingIdaraID = @IdaraID_INT
                 AND c.buildingDetailsActive = 1
                 AND c.LastActionTypeID = 5
                 AND EXISTS
                 (
                     SELECT 1
                     FROM Housing.BuildingSpace bs
                     INNER JOIN Housing.BuildingSpaceType bst
                       ON bst.BuildingSpaceTypeID = bs.BuildingSpaceTypeID_FK
                     WHERE bs.BuildingDetailsID_FK = c.buildingDetailsID
                       AND bs.BuildingSpaceActive = 1
                       AND bs.BuildingSpaceTypeID_FK = 1
                       AND bst.BuildingSpaceTypeCode = N'BEDROOM'
                       AND bst.BuildingSpaceTypeActive = 1
                       AND (bs.BuildingSpaceStartDate IS NULL OR bs.BuildingSpaceStartDate <= CAST(GETDATE() AS date))
                       AND (bs.BuildingSpaceEndDate IS NULL OR bs.BuildingSpaceEndDate >= CAST(GETDATE() AS date))
                       AND (bst.BuildingSpaceTypeStartDate IS NULL OR bst.BuildingSpaceTypeStartDate <= CAST(GETDATE() AS date))
                       AND (bst.BuildingSpaceTypeEndDate IS NULL OR bst.BuildingSpaceTypeEndDate >= CAST(GETDATE() AS date))
                 )
                 AND NOT EXISTS
                 (
                     SELECT 1 FROM Housing.V_Occupant occupant
                     WHERE occupant.buildingDetailsID = c.buildingDetailsID
                       AND (occupant.LastActionTypeID IS NULL
                            OR occupant.LastActionTypeID NOT IN (57,58))
                 )
                              AND NOT EXISTS
               (
                   SELECT 1 FROM Housing.V_WaitingList holding
                   WHERE holding.buildingDetailsID = c.buildingDetailsID
                     AND holding.LastActionTypeID IN (38,40,45,46,47)
                     AND NOT EXISTS
                     (
                         SELECT 1
                         FROM Housing.BuildingAction oldMigrationAction
                         JOIN Housing.AssignPeriod oldMigrationPeriod
                           ON oldMigrationPeriod.AssignPeriodID = oldMigrationAction.AssignPeriodID_FK
                         WHERE oldMigrationAction.buildingActionID = holding.LastActionID
                           AND oldMigrationAction.buildingActionExtraText5 = N'MIGRATION_GENERATED'
                           AND oldMigrationPeriod.AssignPeriodDescrption LIKE
                                 N'Legacy allocation migration - WaitingClass %'
                     )
               )
            )
                THROW 50001,N'المنزل غير مؤهل: يلزم إجراء 5 وغرفة نوم نشطة، ونشاط المنزل والإدارة، وألا يكون مشغولاً.',1;
            
            /* APH_HOUSE_ELIGIBILITY_20261028_A_END */
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
                --, InAssignPeriod
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
                --, 1
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
            

            EXEC Housing.SyncAssignPeriodHistory @AssignPeriodID=@AssignPeriodID, @ApplyChanges=1;
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
                --, InAssignPeriod
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
                --, NULL
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
            EXEC Housing.SyncAssignPeriodHistory @AssignPeriodID=@AssignPeriodID, @ApplyChanges=1;
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
                ;THROW 50001, @msg4, 1;
            END


            Declare @LastBuildingNo1 Nvarchar(200),@LastBuildingID1 bigint

            Select @LastBuildingNo1 = ba.buildingDetailsNo,@LastBuildingID1 = ba.buildingDetailsID_FK
            from BuildingAction ba where ba.buildingActionID = @LastActionID


            
            /* APH_HOUSE_ELIGIBILITY_20261028_U_BEGIN */
            DECLARE @APH_HouseID_U BIGINT = TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID,N''));
            IF @APH_HouseID_U IS NULL OR @APH_HouseID_U <= 0
                THROW 50001, N'يجب اختيار منزل صالح.', 1;

            DECLARE @APH_HouseLockResult_U INT;
            DECLARE @APH_HouseLockResource_U NVARCHAR(255) =
                CONCAT(N'Housing.Occupancy:',@IdaraID_INT,N':',@APH_HouseID_U);
            EXEC @APH_HouseLockResult_U = sys.sp_getapplock
                  @Resource = @APH_HouseLockResource_U,
                  @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
            IF @APH_HouseLockResult_U < 0
                THROW 50001,N'تجري معالجة أخرى للمنزل؛ حدّث الصفحة وأعد المحاولة.',1;

            IF NOT EXISTS
            (
               SELECT 1
               FROM Housing.V_GetGeneralListForBuilding c
               WHERE c.buildingDetailsID = @APH_HouseID_U
                 AND c.BuildingIdaraID = @IdaraID_INT
                 AND c.buildingDetailsActive = 1
                 AND c.LastActionTypeID = 5
                 AND EXISTS
                 (
                     SELECT 1
                     FROM Housing.BuildingSpace bs
                     INNER JOIN Housing.BuildingSpaceType bst
                       ON bst.BuildingSpaceTypeID = bs.BuildingSpaceTypeID_FK
                     WHERE bs.BuildingDetailsID_FK = c.buildingDetailsID
                       AND bs.BuildingSpaceActive = 1
                       AND bs.BuildingSpaceTypeID_FK = 1
                       AND bst.BuildingSpaceTypeCode = N'BEDROOM'
                       AND bst.BuildingSpaceTypeActive = 1
                       AND (bs.BuildingSpaceStartDate IS NULL OR bs.BuildingSpaceStartDate <= CAST(GETDATE() AS date))
                       AND (bs.BuildingSpaceEndDate IS NULL OR bs.BuildingSpaceEndDate >= CAST(GETDATE() AS date))
                       AND (bst.BuildingSpaceTypeStartDate IS NULL OR bst.BuildingSpaceTypeStartDate <= CAST(GETDATE() AS date))
                       AND (bst.BuildingSpaceTypeEndDate IS NULL OR bst.BuildingSpaceTypeEndDate >= CAST(GETDATE() AS date))
                 )
                 AND NOT EXISTS
                 (
                     SELECT 1 FROM Housing.V_Occupant occupant
                     WHERE occupant.buildingDetailsID = c.buildingDetailsID
                       AND (occupant.LastActionTypeID IS NULL
                            OR occupant.LastActionTypeID NOT IN (57,58))
                 )
                              AND NOT EXISTS
               (
                   SELECT 1 FROM Housing.V_WaitingList holding
                   WHERE holding.buildingDetailsID = c.buildingDetailsID
                     AND holding.LastActionTypeID IN (38,40,45,46,47)
                     AND NOT EXISTS
                     (
                         SELECT 1
                         FROM Housing.BuildingAction oldMigrationAction
                         JOIN Housing.AssignPeriod oldMigrationPeriod
                           ON oldMigrationPeriod.AssignPeriodID = oldMigrationAction.AssignPeriodID_FK
                         WHERE oldMigrationAction.buildingActionID = holding.LastActionID
                           AND oldMigrationAction.buildingActionExtraText5 = N'MIGRATION_GENERATED'
                           AND oldMigrationPeriod.AssignPeriodDescrption LIKE
                                 N'Legacy allocation migration - WaitingClass %'
                     )
               )
            )
                THROW 50001,N'المنزل غير مؤهل: يلزم إجراء 5 وغرفة نوم نشطة، ونشاط المنزل والإدارة، وألا يكون مشغولاً.',1;
            
            IF @APH_HouseID_U =
               (SELECT buildingDetailsID_FK FROM Housing.BuildingAction
                WHERE buildingActionID = TRY_CONVERT(BIGINT,@LastActionID))
                THROW 50001,N'يجب اختيار منزل مختلف عند تعديل التخصيص.',1;

            /* APH_HOUSE_ELIGIBILITY_20261028_U_END */
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
                --, InAssignPeriod
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
                --, 1
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
            EXEC Housing.SyncAssignPeriodHistory @AssignPeriodID=@AssignPeriodID, @ApplyChanges=1;
            SELECT 1 AS IsSuccessful, @msg5 AS Message_;
            RETURN;
        END

            
         ----------------------------------------------------------------
        -- AssignNote
        ----------------------------------------------------------------
        IF @Action = N'AssignNote'
        BEGIN


             IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (38,40)
            BEGIN
                ;THROW 50001, N'تم التخصيص لهذا المستفيد مسبقا', 1;
            END


             IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (42)
            BEGIN
                ;THROW 50001, N'تم الغاء احقية السكن لهذا المستفيد لتجاوزه الحد الاعلي من فرص التخصيص', 1;
            END

            if exists (select 1
            from Housing.AssignNote n
            where n.residentInfoID_FK = @residentInfoID 
            and n.buildingActionID_FK = @LastActionID 
            and n.AssignPeriodID_FK = @AssignPeriodID 
            and n.AssignNoteActive = 1
            )
            Begin

            update Housing.AssignNote set AssignNoteActive = 0
            where residentInfoID_FK = @residentInfoID 
            and buildingActionID_FK = @LastActionID 
            and AssignPeriodID_FK = @AssignPeriodID 
            and AssignNoteActive = 1


            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سبب عدم التخصيص', 1;
            END
             
            END




            INSERT INTO  Housing.AssignNote
            (
                  [AssignPeriodID_FK]
                 ,[residentInfoID_FK]
                 ,[buildingActionID_FK]
                 ,[AssignNote]
                 ,[AssignNoteActive]
                 ,[IdaraID_FK]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @AssignPeriodID
                , @residentInfoID
                , @LastActionID
                , @Notes
                , 1
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة سبب عدم التخصيص - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"AssignNoteID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"AssignPeriodID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"residentInfoID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"buildingActionID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"AssignNote": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"AssignNoteActive": "1"'
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
                  N'[Housing].[AssignNote]'
                , N'AssignNote'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة سبب عدم التخصيص بنجاح' AS Message_;
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

