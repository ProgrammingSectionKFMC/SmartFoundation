/* Historical page SP, cloned from the exact live HousingResidentSP pasted on 2026-11-10.
   Transaction is handled only by dbo.Masters_CRUD.
   Action types: HISTORICALRESIDENTSTART, HISTORICALRESIDENTCUSTODY,
   HISTORICALRESIDENTFINALIZE, HISTORICALRESIDENTCANCEL.
   Prerequisite: 00_Prerequisites.sql. No changes to the regular procedure here. */
CREATE   PROCEDURE [Housing].[HousingHistoricalResidentSP] 
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
    , @Notes                                NVARCHAR(4000)  = NULL
    , @BuildingActionTypeCases              NVARCHAR(1000)  = NULL
    , @OccupentLetterNo                     NVARCHAR(1000)  = NULL
    , @OccupentLetterDate                   NVARCHAR(1000)  = NULL
    , @OccupentDate                         NVARCHAR(1000)  = NULL
    , @idaraID_FK                           NVARCHAR(10)    = NULL
    , @entryData                            NVARCHAR(20)    = NULL
    , @hostName                             NVARCHAR(200)   = NULL
)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Transaction is exclusively owned by dbo.Masters_CRUD; no local BEGIN/COMMIT.

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    DECLARE @buildingDetailsNo nvarchar(200) 
    set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);


    DECLARE @ActionTypeID int 
    set @ActionTypeID = (select w.ActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID)
    

    Declare @HasMeterService int
    set @HasMeterService =(select count(*) 
    from  Housing.MeterForBuilding m 
    where m.buildingDetailsID_FK = @buildingDetailsID 
    and m.meterForBuildingActive = 1 
    and (m.meterForBuildingEndDate is null or cast(m.meterForBuildingEndDate as date) > cast(GETDATE() as date)))

    BEGIN TRY
        IF @@TRANCOUNT = 0
            THROW 50001, N'يجب تنفيذ العملية من خلال Masters_CRUD.', 1;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

   


         IF @Action IN(N'HISTORICALRESIDENTCUSTODY')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة العهد والملاحظات على المنزل', 1;
            END

           
        END

        

     


        --------------------------------------------------------------------
        -- This page can only continue historical sequences it created.
        -- Re-read authoritative state; form pXX fields are untrusted.
        --------------------------------------------------------------------
        IF @Action <> N'HISTORICALRESIDENTCUSTODY' AND LEN(COALESCE(@Notes,N'')) > 1000
            THROW 50001, N'الملاحظات أو سبب الاستثناء يجب ألا يتجاوز 1000 حرف.', 1;

        IF @Action IN (N'HISTORICALRESIDENTCUSTODY',N'HISTORICALRESIDENTFINALIZE',N'HISTORICALRESIDENTCANCEL')
        BEGIN
            DECLARE @HistGuard45 BIGINT = NULL;
            DECLARE @HistGuardResident BIGINT = TRY_CONVERT(BIGINT,NULLIF(@residentInfoID,N''));
            DECLARE @HistGuardBuilding BIGINT = TRY_CONVERT(BIGINT,NULLIF(@buildingDetailsID,N''));
            DECLARE @HistGuardLast BIGINT = TRY_CONVERT(BIGINT,NULLIF(@LastActionID,N''));

            IF @ActionID IS NULL OR @HistGuardResident IS NULL OR @HistGuardBuilding IS NULL OR @HistGuardLast IS NULL
                THROW 50001, N'بيانات طلب التسكين الاستثنائي غير مكتملة.', 1;

            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
                  AND w.residentInfoID = @HistGuardResident
                  AND w.buildingDetailsID = @HistGuardBuilding
                  AND w.IdaraId = @IdaraID_INT
                  AND w.LastActionID = @HistGuardLast
                  AND w.LastActionTypeID IN (45,46,47)
            )
                THROW 50001, N'حالة التسكين الاستثنائي تغيرت، يرجى تحديث الصفحة.', 1;

            SELECT TOP(1) @HistGuard45 = a45.buildingActionID
            FROM Housing.BuildingAction a45
            LEFT JOIN Housing.BuildingAction a38
                ON a38.buildingActionID = a45.buildingActionParentID
               AND a38.buildingActionTypeID_FK = 38
            LEFT JOIN Housing.BuildingAction a27
                ON a27.buildingActionID = a38.buildingActionParentID
               AND a27.buildingActionTypeID_FK = 27
            WHERE a45.buildingActionTypeID_FK = 45
              AND a45.HistoricalOccupentDate IS NOT NULL
              AND a45.buildingActionActive = 1
              AND a45.residentInfoID_FK = @HistGuardResident
              AND a45.buildingDetailsID_FK = @HistGuardBuilding
              AND a45.IdaraId_FK = @IdaraID_INT
              AND (a45.buildingActionParentID = @ActionID
                   OR a27.buildingActionParentID = @ActionID)
              -- Last 45 / 46 / 47 must belong to this exact 45, not a previous attempt.
              AND
              (
                  a45.buildingActionID = @HistGuardLast
                  OR EXISTS
                  (
                      SELECT 1 FROM Housing.BuildingAction directStep
                      WHERE directStep.buildingActionID = @HistGuardLast
                        AND directStep.buildingActionParentID = a45.buildingActionID
                        AND directStep.buildingActionTypeID_FK IN (46,47)
                  )
                  OR EXISTS
                  (
                      SELECT 1 FROM Housing.BuildingAction last47
                      INNER JOIN Housing.BuildingAction intermediate46
                          ON intermediate46.buildingActionID = last47.buildingActionParentID
                      WHERE last47.buildingActionID = @HistGuardLast
                        AND last47.buildingActionTypeID_FK = 47
                        AND intermediate46.buildingActionTypeID_FK = 46
                        AND intermediate46.buildingActionParentID = a45.buildingActionID
                  )
              )
            ORDER BY a45.buildingActionID DESC;

            IF @HistGuard45 IS NULL
                THROW 50001, N'لم يتم العثور على بداية تسكين استثنائي معتمدة لهذا الطلب.', 1;

            -- Always use the period attached to action 45, even if a meter-read action 47 did not copy it.
            SELECT @AssignPeriodID = CONVERT(NVARCHAR(100),a45.AssignPeriodID_FK)
            FROM Housing.BuildingAction a45
            WHERE a45.buildingActionID = @HistGuard45;

            SELECT
                  @GeneralNo = CONVERT(NVARCHAR(100),w.GeneralNo)
                , @buildingActionDecisionNo = w.ActionDecisionNo
                , @buildingActionDecisionDate = w.ActionDecisionDate
                , @WaitingClassID = CONVERT(NVARCHAR(100),w.WaitingClassID)
                , @WaitingOrderTypeID = CONVERT(NVARCHAR(100),w.WaitingOrderTypeID)
                , @buildingDetailsID = CONVERT(NVARCHAR(100),w.buildingDetailsID)
                , @LastActionID = CONVERT(NVARCHAR(100),w.LastActionID)
            FROM Housing.V_WaitingList w
            WHERE w.ActionID = @ActionID AND w.LastActionID = @HistGuardLast;

            SELECT @buildingDetailsNo = b.buildingDetailsNo
            FROM Housing.V_GetGeneralListForBuilding b
            WHERE b.buildingDetailsID = @HistGuardBuilding;

            SELECT @HasMeterService = COUNT(*)
            FROM Housing.MeterForBuilding m
            WHERE m.buildingDetailsID_FK = @HistGuardBuilding
              AND m.meterForBuildingActive = 1
              AND (m.meterForBuildingEndDate IS NULL OR CAST(m.meterForBuildingEndDate AS date) > CAST(GETDATE() AS date));
        END;

        --------------------------------------------------------------------
        -- Begin historical occupancy: root -> (27 -> 38) -> 45.
        -- Ordinary waiting-list order is NOT a condition on this page.
        --------------------------------------------------------------------
        IF @Action = N'HISTORICALRESIDENTSTART'
        BEGIN
            DECLARE @HistResidentID BIGINT = TRY_CONVERT(BIGINT,NULLIF(@residentInfoID,N''));
            DECLARE @HistBuildingID BIGINT = TRY_CONVERT(BIGINT,NULLIF(@buildingDetailsID,N''));
            DECLARE @HistDate DATE = TRY_CONVERT(DATE,NULLIF(@OccupentDate,N''),23);
            DECLARE @HistSide BIT = NULL;
            DECLARE @HistClassID INT = NULL;
            DECLARE @HistGeneralNo BIGINT = NULL;
            DECLARE @HistOrderTypeID INT = NULL;
            DECLARE @HistDecisionNo NVARCHAR(200) = NULL;
            DECLARE @HistDecisionDate DATE = NULL;
            DECLARE @HistHouseNo NVARCHAR(200) = NULL;
            DECLARE @HistLastType INT = NULL;
            DECLARE @HistLastActionID BIGINT = NULL;
            DECLARE @HistPeriodID BIGINT = NULL;
            DECLARE @HistParentID BIGINT = NULL;
            DECLARE @HistAction27 BIGINT = NULL;
            DECLARE @HistAction38 BIGINT = NULL;
            DECLARE @HistAction45 BIGINT = NULL;
            DECLARE @HistLastExit DATE = NULL;
            DECLARE @HistLockResult INT;
            DECLARE @HistHouseLockName NVARCHAR(255) = CONCAT(N'Housing.Occupancy:',@IdaraID_INT,N':',@HistBuildingID);
            DECLARE @HistResidentLockName NVARCHAR(255) = CONCAT(N'Housing.ResidentOccupancy:',@HistResidentID);
            DECLARE @HistPeriodLockName NVARCHAR(255);

            IF @ActionID IS NULL OR @ActionID <= 0 OR @HistResidentID IS NULL OR @HistResidentID <= 0
                THROW 50001, N'سجل الانتظار أو المستفيد غير صحيح.', 1;
            IF @HistBuildingID IS NULL OR @HistBuildingID <= 0
                THROW 50001, N'يجب اختيار منزل صحيح.', 1;
            IF @HistDate IS NULL OR @HistDate > CAST(GETDATE() AS DATE)
                THROW 50001, N'تاريخ التسكين بأثر رجعي غير صحيح أو مستقبلي.', 1;
            IF NULLIF(LTRIM(RTRIM(@Notes)),N'') IS NULL
                THROW 50001, N'يجب كتابة سبب التسكين الاستثنائي.', 1;
            IF @IdaraID_INT IS NULL OR @IdaraID_INT <= 0
                THROW 50001, N'الإدارة غير صحيحة.', 1;

            -- Use the same locking order as ordinary occupancy: house then resident.
            EXEC @HistLockResult = sys.sp_getapplock
                @Resource = @HistHouseLockName,
                @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
            IF @HistLockResult < 0 THROW 50001, N'المنزل قيد المعالجة؛ يرجى إعادة المحاولة.', 1;

            EXEC @HistLockResult = sys.sp_getapplock
                @Resource = @HistResidentLockName,
                @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
            IF @HistLockResult < 0 THROW 50001, N'المستفيد قيد المعالجة؛ يرجى إعادة المحاولة.', 1;

            -- Lock the selected root as well; never trust the form's displayed attributes.
            IF NOT EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction root WITH (UPDLOCK, HOLDLOCK)
                WHERE root.buildingActionID = @ActionID
                  AND root.residentInfoID_FK = @HistResidentID
                  AND root.buildingActionActive = 1
            )
                THROW 50001, N'سجل الانتظار غير موجود أو تغيرت حالته.', 1;

            SELECT
                  @HistSide = CASE WHEN c.idara_FK IS NULL THEN 0 ELSE 1 END
                , @HistClassID = w.WaitingClassID
                , @HistGeneralNo = TRY_CONVERT(BIGINT,w.GeneralNo)
                , @HistOrderTypeID = TRY_CONVERT(INT,w.WaitingOrderTypeID)
                , @HistDecisionNo = w.ActionDecisionNo
                , @HistDecisionDate = TRY_CONVERT(DATE,w.ActionDecisionDate)
                , @HistLastType = w.LastActionTypeID
                , @HistLastActionID = w.LastActionID
            FROM Housing.V_WaitingList w
            INNER JOIN Housing.WaitingClass c
                ON c.waitingClassID = w.WaitingClassID AND c.waitingClassActive = 1
            WHERE w.ActionID = @ActionID
              AND w.residentInfoID = @HistResidentID
              AND w.IdaraId = @IdaraID_INT
              AND (c.idara_FK IS NULL OR c.idara_FK = @IdaraID_INT)
              AND (
                    w.LastActionTypeID IS NULL
                    OR w.LastActionTypeID IN (34,35)
                    OR w.LastActionTypeID = w.ActionTypeID
                  );

            IF @HistSide IS NULL OR @HistClassID IS NULL OR @HistGeneralNo IS NULL
                THROW 50001, N'المستفيد ليس في قائمة انتظار مؤهلة ضمن الإدارة.', 1;
            IF @WaitingClassID IS NOT NULL
               AND TRY_CONVERT(INT,@WaitingClassID) <> @HistClassID
                THROW 50001, N'فئة الانتظار تغيرت؛ يرجى تحديث الصفحة.', 1;
            -- Historical allocation is always FIRST allocation; never overwrite an earlier one.
            IF EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction priorAction
                WHERE priorAction.residentInfoID_FK = @HistResidentID
                  AND priorAction.buildingActionActive = 1
                  AND priorAction.buildingActionTypeID_FK IN (38,40,45,46,47)
                  AND EXISTS
                  (
                      SELECT 1 FROM Housing.V_WaitingList currentW
                      WHERE currentW.residentInfoID = @HistResidentID
                        AND currentW.LastActionID = priorAction.buildingActionID
                        AND currentW.ActionID <> @ActionID
                  )
            )
                THROW 50001, N'للمستفيد تخصيص أو إجراءات تسكين أخرى؛ لا يمكن إنشاء تخصيص أول استثنائي.', 1;

            IF EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList otherW
                WHERE otherW.residentInfoID = @HistResidentID
                  AND otherW.ActionID <> @ActionID
                  AND otherW.LastActionTypeID IN (38,40,45,46,47,2,24,57,58)
            ) OR EXISTS
            (
                SELECT 1 FROM Housing.V_Occupant occupied
                WHERE occupied.residentInfoID = @HistResidentID
            )
                THROW 50001, N'للمستفيد إشغال أو تخصيص آخر جارٍ يمنع التسكين الاستثنائي.', 1;

            -- Do not trust the options previously loaded into the form.
            -- Enforce the same house readiness/bedroom rules used in the current OtherWaitingListDL.
            SELECT @HistHouseNo = b.buildingDetailsNo
            FROM Housing.V_GetGeneralListForBuilding b
            WHERE b.buildingDetailsID = @HistBuildingID
              AND b.BuildingIdaraID = @IdaraID_INT
              AND b.buildingDetailsActive = 1
              AND b.LastActionTypeID = 5
              AND EXISTS
              (
                  SELECT 1
                  FROM Housing.BuildingSpace bs
                  INNER JOIN Housing.BuildingSpaceType bst
                      ON bst.BuildingSpaceTypeID = bs.BuildingSpaceTypeID_FK
                  WHERE bs.BuildingDetailsID_FK = b.buildingDetailsID
                    AND bs.BuildingSpaceActive = 1
                    AND bs.BuildingSpaceTypeID_FK = 1
                    AND bst.BuildingSpaceTypeCode = N'BEDROOM'
                    AND bst.BuildingSpaceTypeActive = 1
                    AND (bs.BuildingSpaceStartDate IS NULL OR bs.BuildingSpaceStartDate <= CAST(GETDATE() AS DATE))
                    AND (bs.BuildingSpaceEndDate IS NULL OR bs.BuildingSpaceEndDate >= CAST(GETDATE() AS DATE))
                    AND (bst.BuildingSpaceTypeStartDate IS NULL OR bst.BuildingSpaceTypeStartDate <= CAST(GETDATE() AS DATE))
                    AND (bst.BuildingSpaceTypeEndDate IS NULL OR bst.BuildingSpaceTypeEndDate >= CAST(GETDATE() AS DATE))
              );
            IF @HistHouseNo IS NULL
                THROW 50001, N'المنزل غير جاهز للتخصيص أو لا يتبع الإدارة أو لا يحتوي غرفة نوم نشطة.', 1;

            IF EXISTS
            (
                SELECT 1 FROM Housing.V_WaitingList otherW
                WHERE otherW.buildingDetailsID = @HistBuildingID
                  AND otherW.IdaraId = @IdaraID_INT
                  AND otherW.residentInfoID <> @HistResidentID
                  AND otherW.LastActionTypeID IN (2,24,38,40,45,46,47,57,58)
            ) OR EXISTS
            (
                SELECT 1 FROM Housing.V_Occupant occupied
                WHERE occupied.buildingDetailsID = @HistBuildingID
            )
                THROW 50001, N'المنزل مشغول أو مرتبط بتخصيص أو إجراءات تسكين أخرى.', 1;

            -- Historical period must be vacant; a currently vacant house is not enough.
            IF EXISTS
            (
                SELECT 1
                FROM Housing.fn_BuildingOccupancyPeriods(@HistBuildingID,@IdaraID_INT) occ
                WHERE occ.OccupentDate <= CAST(GETDATE() AS DATE)
                  AND (occ.ExitDate IS NULL OR occ.ExitDate >= @HistDate)
                  AND occ.residentInfoID_FK <> @HistResidentID
            )
                THROW 50001, N'يوجد إشغال سابق يتداخل مع تاريخ التسكين المطلوب.', 1;

            SELECT @HistLastExit = MAX(CONVERT(DATE,
                        COALESCE(exitAction.ExitDate,exitAction.buildingActionDate,exitAction.entryDate)))
            FROM Housing.BuildingAction exitAction
            WHERE exitAction.residentInfoID_FK = @HistResidentID
              AND exitAction.buildingActionTypeID_FK = 3
              AND exitAction.buildingActionActive = 1;
            IF @HistLastExit IS NOT NULL AND @HistDate <= @HistLastExit
                THROW 50001, N'يجب أن يكون التاريخ بعد آخر إخلاء فعلي للمستفيد.', 1;

            -- Historical assignment period: one permanently closed period / department / MAIN class.
            IF @HistSide = 0
            BEGIN
                SET @HistPeriodLockName = CONCAT(N'Housing.HistoricalAssignPeriod:',@IdaraID_INT,N':',@HistClassID);
                EXEC @HistLockResult = sys.sp_getapplock
                    @Resource = @HistPeriodLockName,
                    @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
                IF @HistLockResult < 0 THROW 50001, N'محضر التخصيص الاستثنائي قيد الإنشاء.', 1;

                SELECT @HistPeriodID = a.AssignPeriodID
                FROM Housing.AssignPeriod a WITH (UPDLOCK,HOLDLOCK)
                WHERE a.IdaraId_FK = @IdaraID_INT
                  AND a.WaitingClassID_FK = @HistClassID
                  AND a.IsHistoricalOccupancy = 1;

                IF @HistPeriodID IS NULL
                BEGIN
                    INSERT INTO Housing.AssignPeriod
                    (
                          AssignPeriodDescrption, AssignPeriodStartdate, AssignPeriodEnddate
                        , AssignPeriodActive, AssignPeriodClose, AssignPeriodCloseNote
                        , AssignPeriodFinalEND, AssignPeriodFinalENDNote, AssignPeriodFinalEnddate
                        , WaitingClassID_FK, IdaraId_FK, entryData, hostName, IsHistoricalOccupancy
                    )
                    VALUES
                    (
                          N'تسكين بأثر رجعي', GETDATE(), GETDATE()
                        , 1, 0, N'محضر استثنائي مغلق تلقائياً'
                        , 0, N'محضر استثنائي منتهٍ تلقائياً', GETDATE()
                        , @HistClassID, @IdaraID_INT, @entryData, @hostName, 1
                    );
                    SET @HistPeriodID = SCOPE_IDENTITY();
                    INSERT INTO dbo.AuditLog (TableName,ActionType,RecordID,PerformedBy,Notes)
                    VALUES (N'[Housing].[AssignPeriod]',N'CREATEHISTORICALASSIGNPERIOD',
                            @HistPeriodID,@entryData,
                            CONCAT(N'Idara=',@IdaraID_INT,N'; Class=',@HistClassID));
                END;
                IF NOT EXISTS
                (
                    SELECT 1 FROM Housing.AssignPeriod a
                    WHERE a.AssignPeriodID = @HistPeriodID
                      AND a.IdaraId_FK = @IdaraID_INT
                      AND a.WaitingClassID_FK = @HistClassID
                      AND a.IsHistoricalOccupancy = 1
                      AND a.AssignPeriodActive = 1
                      AND a.AssignPeriodClose = 0
                      AND a.AssignPeriodFinalEND = 0
                )
                    THROW 50001, N'المحضر التاريخي ليس مغلقاً بالحالة المعتمدة.', 1;

                INSERT INTO Housing.BuildingAction
                (
                      buildingActionTypeID_FK, residentInfoID_FK, generalNo_FK
                    , buildingActionDecisionNo, buildingActionDecisionDate
                    , buildingActionExtraType1, buildingActionExtraType2
                    , buildingActionActive, buildingActionNote, buildingActionParentID
                    , IdaraId_FK, entryData, hostName
                )
                VALUES
                (
                      27, @HistResidentID, @HistGeneralNo
                    , @HistDecisionNo, @HistDecisionDate
                    , @HistClassID, @HistOrderTypeID
                    , 1, @Notes, @ActionID
                    , @IdaraID_INT, @entryData, @hostName
                );
                SET @HistAction27 = SCOPE_IDENTITY();
                IF @HistAction27 IS NULL THROW 50002, N'تعذر تسجيل الإجراء 27.', 1;

                INSERT INTO Housing.BuildingAction
                (
                      buildingActionTypeID_FK, residentInfoID_FK, generalNo_FK
                    , buildingActionDecisionNo, buildingActionDecisionDate
                    , buildingDetailsID_FK, buildingDetailsNo, buildingActionActive
                    , buildingActionNote, buildingActionParentID
                    , AssignPeriodID_FK, InAssignPeriod, IdaraId_FK, entryData, hostName
                )
                VALUES
                (
                      38, @HistResidentID, @HistGeneralNo
                    , @HistDecisionNo, @HistDecisionDate
                    , @HistBuildingID, @HistHouseNo, 1
                    , @Notes, @HistAction27
                    , @HistPeriodID, 0, @IdaraID_INT, @entryData, @hostName
                );
                SET @HistAction38 = SCOPE_IDENTITY();
                IF @HistAction38 IS NULL THROW 50002, N'تعذر تسجيل الإجراء 38.', 1;
                SET @HistParentID = @HistAction38;
            END
            ELSE
            BEGIN
                SET @HistParentID = @ActionID;
            END;

            INSERT INTO Housing.BuildingAction
            (
                  buildingActionTypeID_FK, residentInfoID_FK, generalNo_FK
                , buildingActionDecisionNo, buildingActionDecisionDate
                , buildingDetailsID_FK, buildingDetailsNo
                , buildingActionExtraType1, buildingActionExtraType2
                , buildingActionActive, buildingActionNote, buildingActionParentID
                , AssignPeriodID_FK, InAssignPeriod, HistoricalOccupentDate
                , IdaraId_FK, entryData, hostName
            )
            VALUES
            (
                  45, @HistResidentID, @HistGeneralNo
                , @HistDecisionNo, @HistDecisionDate
                , @HistBuildingID, @HistHouseNo
                , @HistClassID, @HistOrderTypeID
                , 1, @Notes, @HistParentID
                , @HistPeriodID, 0, @HistDate
                , @IdaraID_INT, @entryData, @hostName
            );
            SET @HistAction45 = SCOPE_IDENTITY();
            IF @HistAction45 IS NULL THROW 50002, N'تعذر تسجيل الإجراء 45.', 1;

            INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,PerformedBy,Notes)
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'HISTORICALRESIDENTSTART'
                , @HistAction45
                , @entryData
                , CONCAT(N'Root=',@ActionID, N'; Idara=',@IdaraID_INT,
                         N'; WaitingClass=',@HistClassID, N'; Building=',@HistBuildingID,
                         N'; HistoricalDate=',CONVERT(NVARCHAR(10),@HistDate,23),
                         N'; Period=',COALESCE(CONVERT(NVARCHAR(30),@HistPeriodID),N'NULL'),
                         N'; 27=',COALESCE(CONVERT(NVARCHAR(30),@HistAction27),N'NULL'),
                         N'; 38=',COALESCE(CONVERT(NVARCHAR(30),@HistAction38),N'NULL'),
                         N'; Reason=',@Notes)
            );

            SELECT 1 AS IsSuccessful,
                   N'تم بدء التسكين الاستثنائي ونقل المستفيد إلى إجراءات التسكين بنجاح' AS Message_;
            RETURN;
        END
        --------------------------------------------------------------------

        ----------------------------------------------------------------
        -- CustdyRecord
        ----------------------------------------------------------------
        ELSE IF @Action = N'HISTORICALRESIDENTCUSTODY'
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
            ) in (46)
            BEGIN
                ;THROW 50001, N'بانتظار قراءة عدادات الخدمات', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 45 and @HasMeterService > 0 then 46
            when w.LastActionTypeID = 45 and @HasMeterService < 1 then 47 
            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما Has Meter Service', 1;
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
                , CustdyRecord
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
                ;THROW 50002, N'حصل خطأ في تسجيل العهد والملاحظات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل العهد والملاحظات - Identity', 1; -- برمجي
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
                , N'HISTORICALRESIDENTCUSTODY'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تسجيل العهد والملاحظات بنجاح' AS Message_;
            RETURN;
        END


      
        ----------------------------------------------------------------
        -- FinalOccupent
        ----------------------------------------------------------------
        ELSE IF @Action = N'HISTORICALRESIDENTFINALIZE'
        BEGIN
            -- Serialize occupancy changes with exit creation/edit/cancellation.
            -- Masters_CRUD owns the outer transaction and releases this lock.

           

            DECLARE @OccupancyLockResult INT;
            DECLARE @OccupancyLockResource NVARCHAR(255) = CONCAT(
                N'Housing.Occupancy:', @IdaraID_INT, N':', TRY_CONVERT(BIGINT, @buildingDetailsID));
            EXEC @OccupancyLockResult = sys.sp_getapplock
                  @Resource = @OccupancyLockResource
                , @LockMode = 'Exclusive'
                , @LockOwner = 'Transaction'
                , @LockTimeout = 10000;
            IF @OccupancyLockResult < 0
                THROW 50001, N'تجري معالجة أخرى للمنزل؛ يرجى إعادة المحاولة.', 1;

                ------------------------------------------------------------
-- منع تنفيذ تسكينين متزامنين للمستفيد نفسه
-- عبر جميع الإدارات والمنازل
------------------------------------------------------------
DECLARE @ResidentOccupancyID BIGINT =
    TRY_CONVERT(BIGINT, NULLIF(@residentInfoID, N''));

IF @ResidentOccupancyID IS NULL OR @ResidentOccupancyID <= 0
BEGIN
    THROW 50001, N'رقم المستفيد غير صحيح', 1;
END;

DECLARE @ResidentLockResult INT;

DECLARE @ResidentLockResource NVARCHAR(255) =
    CONCAT(
        N'Housing.ResidentOccupancy:',
        @ResidentOccupancyID
    );

EXEC @ResidentLockResult = sys.sp_getapplock
      @Resource = @ResidentLockResource
    , @LockMode = N'Exclusive'
    , @LockOwner = N'Transaction'
    , @LockTimeout = 10000;

IF @ResidentLockResult < 0
BEGIN
    THROW 50001,
          N'تجري معالجة تسكين أخرى للمستفيد؛ يرجى إعادة المحاولة.',
          1;
END;

                 IF EXISTS
(
    SELECT 1
    FROM Housing.V_WaitingList w
    WHERE w.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND w.LastActionTypeID IN (57,58)
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد التسكين؛ لا تزال إجراءات الإخلاء المالي للمستفيد غير مكتملة.',
        1;
END;
       
            IF (SELECT COUNT(*) FROM Housing.V_Occupant e WHERE e.residentInfoID = @residentInfoID) > 0
            
            BEGIN
            declare @msg nvarchar(1000) = N'المستفيد ساكن حاليا او لازال تحت اجراءات الاخلاء بالمنزل رقم : '+(select top(1) e.buildingDetailsNo FROM Housing.V_Occupant e WHERE e.residentInfoID = @residentInfoID)+N' في '+(select top(1) i.idaraLongName_A FROM Housing.V_Occupant e inner join dbo.Idara i on e.LastActionIdaraID =i.idaraID WHERE e.residentInfoID = @residentInfoID)+N' يجب انهاء اجراءات الاخلاء وتحصيل جميع المستحقات قبل اعتماد تسكينه بالمنزل الجديد '
                ;THROW 50001, @msg, 1;
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
            ) in (46)
            BEGIN
                ;THROW 50001, N'بانتظار قراءة عدادات الخدمات', 1;
            END

            DECLARE
                  @OccupentDateValue DATE
                , @LastResidentExitDate DATE
                , @PreviousOccupantID BIGINT
                , @PreviousOccupantName NVARCHAR(300)
                , @PreviousOccupantNationalID NVARCHAR(50)
                , @PreviousOccupantExitDate DATE
                , @AvailableFromDate DATE
                , @PreviousOccupancyMessage NVARCHAR(1000)
                , @CurrentAssignActionID BIGINT
                , @CurrentAssignActionTypeID INT
                , @BuildingStateBeforeAssign INT;

------------------------------------------------------------
-- Historical occupancy date: immutable date set when action 45 was started.
------------------------------------------------------------
DECLARE @HistChosenOccupentDate DATE = NULL;
SELECT @HistChosenOccupentDate = a45.HistoricalOccupentDate
FROM Housing.BuildingAction a45
WHERE a45.buildingActionID = @HistGuard45
  AND a45.buildingActionTypeID_FK = 45
  AND a45.buildingActionActive = 1
  AND a45.residentInfoID_FK = TRY_CONVERT(BIGINT,@residentInfoID)
  AND a45.buildingDetailsID_FK = TRY_CONVERT(BIGINT,@buildingDetailsID);

IF @HistChosenOccupentDate IS NULL OR @HistChosenOccupentDate > CAST(GETDATE() AS DATE)
    THROW 50001, N'تاريخ التسكين الاستثنائي المحفوظ غير صالح.', 1;

SET @OccupentDateValue = @HistChosenOccupentDate;
SET @OccupentDate = CONVERT(NVARCHAR(10),@HistChosenOccupentDate,23);
-- No occupancy letter fields on the historical page.
SET @OccupentLetterNo = NULL;
SET @OccupentLetterDate = NULL;
SET @buildingActionTypeID_FK = 2;

------------------------------------------------------------
-- الشرط الأول:
-- تاريخ التسكين يجب أن يكون بعد آخر إخلاء للمستفيد نفسه
-- الحركة 3 = إخلاء نهائي
------------------------------------------------------------
SELECT
    @LastResidentExitDate =
        MAX(
            CONVERT(
                DATE,
                COALESCE(
                      ba.ExitDate
                    , ba.buildingActionDate
                    , ba.entryDate
                )
            )
        )
FROM Housing.BuildingAction ba
WHERE ba.residentInfoID_FK =
      TRY_CONVERT(BIGINT, @residentInfoID)
  AND ba.buildingActionTypeID_FK = 3
  AND ba.buildingActionActive = 1;

IF @LastResidentExitDate IS NOT NULL
   AND @OccupentDateValue <= @LastResidentExitDate
BEGIN
    DECLARE @ResidentExitDateMessage NVARCHAR(1000);

    SET @ResidentExitDateMessage =
        CONCAT(
              N'لا يمكن اعتماد التسكين؛ يجب أن يكون تاريخ التسكين بعد آخر إخلاء للمستفيد بتاريخ '
            , CONVERT(NVARCHAR(10), @LastResidentExitDate, 23)
        );

    ;THROW 50001, @ResidentExitDateMessage, 1;
END;

------------------------------------------------------------
-- الشرط الثاني:
-- يجب أن يكون المنزل شاغراً طوال الفترة من تاريخ التسكين
-- المطلوب وحتى تاريخ الاعتماد. لا يكفي التحقق من حالة المنزل
-- الحالية، لأن التسكين بأثر رجعي قد يتداخل مع ساكن سابق.
------------------------------------------------------------
;WITH PreviousOccupancies AS
(
    SELECT
          occupancy.OccupancyActionID AS buildingActionID
        , occupancy.residentInfoID_FK
        , occupancy.OccupentDate
        , occupancy.ExitDate
    FROM Housing.fn_BuildingOccupancyPeriods(TRY_CONVERT(BIGINT, @buildingDetailsID), @IdaraID_INT) occupancy
    WHERE occupancy.residentInfoID_FK <> TRY_CONVERT(BIGINT, @residentInfoID)
      AND occupancy.OccupentDate <= CASE WHEN @OccupentDateValue > CAST(GETDATE() AS DATE)
                                         THEN @OccupentDateValue ELSE CAST(GETDATE() AS DATE) END
      AND (
            occupancy.ExitDate IS NULL
            OR occupancy.ExitDate >= @OccupentDateValue
          )
)
SELECT TOP (1)
      @PreviousOccupantID = previousOccupancy.residentInfoID_FK
    , @PreviousOccupantName = LTRIM(RTRIM(CONCAT_WS(N' ',
            residentDetails.firstName_A,
            residentDetails.secondName_A,
            residentDetails.thirdName_A,
            residentDetails.lastName_A)))
    , @PreviousOccupantNationalID = residentInfo.NationalID
    , @PreviousOccupantExitDate = previousOccupancy.ExitDate
FROM PreviousOccupancies previousOccupancy
LEFT JOIN Housing.ResidentInfo residentInfo
    ON residentInfo.residentInfoID = previousOccupancy.residentInfoID_FK
OUTER APPLY
(
    SELECT TOP (1)
          rd.firstName_A
        , rd.secondName_A
        , rd.thirdName_A
        , rd.lastName_A
    FROM Housing.ResidentDetails rd
    WHERE rd.residentInfoID_FK = previousOccupancy.residentInfoID_FK
      AND rd.residentDetailsActive = 1
    ORDER BY rd.residentDetailsID DESC
) residentDetails
ORDER BY
      CASE WHEN previousOccupancy.ExitDate IS NULL THEN 0 ELSE 1 END
    , previousOccupancy.ExitDate DESC
    , previousOccupancy.OccupentDate DESC
    , previousOccupancy.buildingActionID DESC
OPTION (MAXRECURSION 32767);

IF @PreviousOccupantID IS NOT NULL
BEGIN
    SET @PreviousOccupantName = COALESCE(
        NULLIF(@PreviousOccupantName, N''),
        CONCAT(N'رقم ', @PreviousOccupantID));

    IF NULLIF(LTRIM(RTRIM(@PreviousOccupantNationalID)), N'') IS NOT NULL
    BEGIN
        SET @PreviousOccupantName = CONCAT(
            @PreviousOccupantName,
            N' (هوية: ',
            @PreviousOccupantNationalID,
            N')');
    END;

    IF @PreviousOccupantExitDate IS NULL
    BEGIN
        SET @PreviousOccupancyMessage = CONCAT(
              N'لا يمكن اعتماد التسكين؛ المنزل مسكون بالمستفيد '
            , @PreviousOccupantName
            , N' ولم يتم تسجيل إخلاء سارٍ له.');

        ;THROW 50001, @PreviousOccupancyMessage, 1;
    END;

    SET @AvailableFromDate = DATEADD(DAY, 1, @PreviousOccupantExitDate);

    SET @PreviousOccupancyMessage = CONCAT(
          N'لا يمكن اعتماد التسكين؛ المنزل مسكون بالمستفيد '
        , @PreviousOccupantName
        , N' حتى تاريخ '
        , CONVERT(NVARCHAR(10), @PreviousOccupantExitDate, 23)
        , N'، ومتاح للتسكين ابتداءً من '
        , CONVERT(NVARCHAR(10), @AvailableFromDate, 23)
        , N'.');

    ;THROW 50001, @PreviousOccupancyMessage, 1;
END;




------------------------------------------------------------
-- تحديد مسار التسكين من سجل الانتظار الفعلي
-- القوائم الرئيسية: 38/40
-- القوائم الجانبية: انتقال مباشر إلى 45
------------------------------------------------------------
DECLARE @IsSideWaitingList BIT = NULL;

SELECT @IsSideWaitingList =
    CASE
        WHEN wc.idara_FK IS NOT NULL THEN 1
        ELSE 0
    END
FROM Housing.V_WaitingList w
INNER JOIN Housing.WaitingClass wc ON wc.waitingClassID = w.WaitingClassID
WHERE w.ActionID = @ActionID
  AND w.residentInfoID =
      TRY_CONVERT(BIGINT, @residentInfoID)
  AND w.buildingDetailsID =
      TRY_CONVERT(BIGINT, @buildingDetailsID)
  AND w.IdaraId = @IdaraID_INT
  AND w.LastActionID =
      TRY_CONVERT(BIGINT, @LastActionID)
  AND w.LastActionTypeID = 47;

IF @IsSideWaitingList IS NULL
BEGIN
    THROW 50001,
        N'بيانات طلب التسكين غير متطابقة أو تغيرت حالته',
        1;
END;

------------------------------------------------------------
-- تتبع سلسلة الإجراءات الحالية
------------------------------------------------------------
;WITH CurrentActionChain AS
(
    SELECT
        ba.buildingActionID,
        ba.buildingActionTypeID_FK,
        ba.buildingActionParentID,
        ba.buildingDetailsID_FK,
        ba.residentInfoID_FK,
        0 AS ChainLevel
    FROM Housing.BuildingAction ba
    WHERE ba.buildingActionID =
          TRY_CONVERT(BIGINT, @LastActionID)
      AND ba.residentInfoID_FK =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND ba.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND ba.IdaraId_FK = @IdaraID_INT
      AND ba.buildingActionActive = 1

    UNION ALL

    SELECT
        parentBa.buildingActionID,
        parentBa.buildingActionTypeID_FK,
        parentBa.buildingActionParentID,
        parentBa.buildingDetailsID_FK,
        parentBa.residentInfoID_FK,
        child.ChainLevel + 1
    FROM Housing.BuildingAction parentBa
    INNER JOIN CurrentActionChain child
        ON parentBa.buildingActionID =
           child.buildingActionParentID
    WHERE child.ChainLevel < 10
      AND parentBa.residentInfoID_FK =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND parentBa.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND parentBa.IdaraId_FK = @IdaraID_INT
      AND parentBa.buildingActionActive = 1
)
SELECT TOP (1)
    @CurrentAssignActionID = buildingActionID,
    @CurrentAssignActionTypeID = buildingActionTypeID_FK
FROM CurrentActionChain
WHERE
    (
        @IsSideWaitingList = 0
        AND buildingActionTypeID_FK IN (38, 40)
    )
    OR
    (
        @IsSideWaitingList = 1
        AND buildingActionTypeID_FK = 45
        AND buildingActionParentID = @ActionID
    )
ORDER BY ChainLevel ASC
OPTION (MAXRECURSION 10);

IF @CurrentAssignActionID IS NULL
BEGIN
    THROW 50001,
        N'تعذر تحديد حركة التخصيص أو النقل لإجراءات التسكين المرتبطة بالطلب',
        1;
END;


------------------------------------------------------------
-- منع وجود مسار تسكين جارٍ آخر للمستفيد
-- مع احترام أولوية القوائم الرئيسية على الجانبية
------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM Housing.V_WaitingList otherW
    WHERE otherW.residentInfoID = @ResidentOccupancyID
      AND otherW.ActionID <> @ActionID
      AND
      (
          -- موافقة أو إجراءات تسكين جارية على سجل آخر
          otherW.LastActionTypeID IN (45, 46, 47)

          OR

          -- القوائم الرئيسية لها الأولوية على الجانبية
          (
              @IsSideWaitingList = 1
              AND EXISTS (SELECT 1 FROM Housing.WaitingClass c
                          WHERE c.waitingClassID = otherW.WaitingClassID
                            AND c.idara_FK IS NULL)
              AND otherW.LastActionTypeID IN (38, 40)
          )
      )
)
BEGIN
    THROW 50001,
          N'لا يمكن اعتماد التسكين؛ للمستفيد إجراءات تسكين جارية على سجل آخر أو تخصيص رئيسي قائم يمنع التسكين الجانبي.',
          1;
END;
------------------------------------------------------------
-- القوائم الجانبية:
-- تم فحص أهلية المنزل عند إنشاء الحركة 45
-- بواسطة OtherWaitingListSP.
-- لا تشترط وجود تخصيص 38/40.
--
-- تستمر فحوص الإشغال والتعارض والحالة 47 الموجودة
-- بعد هذا المقطع دون تعديل.
------------------------------------------------------------

------------------------------------------------------------
-- التأكد من عدم تخصيص أو تسكين المنزل لمستفيد آخر
-- بعد بداية التخصيص الحالي
------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM Housing.BuildingAction conflictingAction
    WHERE conflictingAction.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND conflictingAction.buildingActionActive = 1
      AND conflictingAction.buildingActionID >
          @CurrentAssignActionID
      AND conflictingAction.residentInfoID_FK <>
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND conflictingAction.buildingActionTypeID_FK IN
          (
              2,   -- تسكين نهائي
              38,  -- تخصيص أول
              40,  -- تخصيص ثانٍ
              45,  -- موافقة على المنزل
              46,  -- انتظار قراءة التسكين
              47   -- اكتمال قراءة التسكين
          )
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد التسكين؛ تم تخصيص المنزل أو تسكينه لمستفيد آخر',
        1;
END;

------------------------------------------------------------
-- التأكد من أن الحالة الحالية للطلب هي 47
------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM Housing.V_WaitingList w
    WHERE w.ActionID = @ActionID
      AND w.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND w.buildingDetailsID =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND w.IdaraId = @IdaraID_INT
      AND w.LastActionID =
          TRY_CONVERT(BIGINT, @LastActionID)
      AND w.LastActionTypeID = 47
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد التسكين؛ لم تكتمل قراءة العدادات أو تغيرت حالة الطلب',
        1;
END;


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionExtraText2
                , buildingActionExtraText3
                , buildingActionDate
                , OccupentDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , buildingActionExtraType1
                , buildingActionExtraType2
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  2
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , @OccupentLetterDate
                , @OccupentLetterNo
                , @OccupentDate
                , @OccupentDate
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , @WaitingClassID
                , @WaitingOrderTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            SET @NewID = SCOPE_IDENTITY();
            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي', 1; -- برمجي
            END

            
            DECLARE @BillsResidentInfoID BIGINT =
    TRY_CONVERT(BIGINT, @residentInfoID);

DECLARE @BillsGeneralNo BIGINT =
    TRY_CONVERT(BIGINT, @GeneralNo);

DECLARE @BillsBuildingDetailsID BIGINT =
    TRY_CONVERT(BIGINT, @buildingDetailsID);

DECLARE @BillsOccupentDate DATE =
    TRY_CONVERT(DATE, @OccupentDate);

EXEC [Housing].[BackfillResidentServiceBills]
      @ResidentInfoID    = @BillsResidentInfoID
    , @GeneralNo         = @BillsGeneralNo
    , @BuildingDetailsID = @BillsBuildingDetailsID
    , @OccupentDate      = @BillsOccupentDate
    , @IdaraID           = @IdaraID_INT
    , @EntryData         = @entryData
    , @HostName          = @hostName;

            DECLARE @ToDate date = EOMONTH(DATEADD(MONTH, -1, GETDATE()));

            if(@OccupentDate <  @ToDate)
            begin

            /*
               فاتورة الإيجار لا تستحق على المنزل وهو خالٍ. إذا وجدت فاتورة
               قديمة غير مرتبطة بمستفيد وتتداخل مع السكن بأثر رجعي، نلغيها
               قبل إنشاء الفاتورة الصحيحة للمستفيد.
            */
            UPDATE vacantRentBill
               SET vacantRentBill.BillActive = 0,
                   vacantRentBill.CanceledBy = CONCAT(N'RETROACTIVE_OCCUPANCY:', @BillsResidentInfoID),
                   vacantRentBill.entryData = @entryData,
                   vacantRentBill.hostName = @hostName
            FROM Housing.Bills vacantRentBill
            LEFT JOIN Housing.BillPeriod vacantRentPeriod
              ON vacantRentPeriod.billPeriodID = vacantRentBill.CurrentPeriodID
             AND vacantRentPeriod.IdaraId_FK = vacantRentBill.idaraID_FK
            CROSS APPLY
            (
                SELECT
                      COALESCE
                      (
                          CAST(vacantRentBill.BillsFromDate AS date),
                          CAST(vacantRentPeriod.billPeriodStartDate AS date),
                          CASE
                              WHEN vacantRentBill.PeriodYear BETWEEN 1753 AND 9999
                               AND vacantRentBill.PeriodMonth BETWEEN 1 AND 12
                              THEN DATEFROMPARTS(vacantRentBill.PeriodYear, vacantRentBill.PeriodMonth, 1)
                          END
                      ) AS BillFromDate
                    , COALESCE
                      (
                          CAST(vacantRentBill.BillsToDate AS date),
                          CAST(vacantRentPeriod.billPeriodEndDate AS date),
                          CASE
                              WHEN vacantRentBill.PeriodYear BETWEEN 1753 AND 9999
                               AND vacantRentBill.PeriodMonth BETWEEN 1 AND 12
                              THEN EOMONTH(DATEFROMPARTS(vacantRentBill.PeriodYear, vacantRentBill.PeriodMonth, 1))
                          END
                      ) AS BillToDate
            ) vacantRentDate
            WHERE vacantRentBill.buildingDetailsID = @BillsBuildingDetailsID
              AND vacantRentBill.idaraID_FK = @IdaraID_INT
              AND vacantRentBill.BillChargeTypeID_FK = 1
              AND vacantRentBill.BillActive = 1
              AND vacantRentBill.residentInfoID_FK IS NULL
              AND vacantRentDate.BillFromDate <= @ToDate
              AND vacantRentDate.BillToDate >= @BillsOccupentDate;

            -- INSERT INTO [DATACORE].[Housing].[RentBills]
            --(
            --      [residentInfoID_FK]
            --     ,[buildingDetailsID_FK]
            --     ,[buildingRentTypeID_FK]
            --     ,[rentBillsAmount]
            --     ,[rentBillsFromDate]
            --     ,[rentBillsToDate]
            --     ,[rentBillsActive]
            --     ,[idaraID_FK]
            --     ,[entryData]
            --     ,[hostName]
            --)

            
             INSERT INTO [DATACORE].[Housing].[Bills]
            (
                  [residentInfoID_FK]
                 ,[generalNo_FK]
                 ,[buildingDetailsID]
                 ,[BillChargeTypeID_FK]
                 ,[buildingRentTypeID_FK]
                 ,[PeriodMonth]
                 ,[PeriodYear]
                 ,[PRICE]
                 ,[PRICETAX]
                 ,[TotalPrice]
                 ,[BillsFromDate]
                 ,[BillsToDate]
                 ,[BillActive]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[hostName]
            )
            SELECT 
            @residentInfoID,
            @GeneralNo,
            @buildingDetailsID,
            1,
            1,
            DATEPART(MONTH,r.CalcFromDate),
            DATEPART(YEAR,r.CalcFromDate),
            r.RentForMonth,
            0.00,
            r.RentForMonth,
            r.CalcFromDate,
            r.CalcToDate,
            1,
            @idaraID_FK,
            @entryData,
            @hostName
            FROM Housing.fn_CalcMonthlyBuildingRent_ByBuildingDetailsID(@buildingDetailsID,@OccupentDate, @ToDate) r
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.Bills existingRentBill WITH (UPDLOCK, HOLDLOCK)
                WHERE existingRentBill.residentInfoID_FK = @BillsResidentInfoID
                  AND existingRentBill.buildingDetailsID = @BillsBuildingDetailsID
                  AND existingRentBill.idaraID_FK = @IdaraID_INT
                  AND existingRentBill.BillChargeTypeID_FK = 1
                  AND existingRentBill.BillActive = 1
                  AND CAST(existingRentBill.BillsFromDate AS date) <= r.CalcToDate
                  AND CAST(existingRentBill.BillsToDate AS date) >= r.CalcFromDate
            )

             IF EXISTS
             (
                 SELECT 1
                 FROM Housing.fn_CalcMonthlyBuildingRent_ByBuildingDetailsID
                      (@buildingDetailsID, @OccupentDate, @ToDate) expectedRent
                 WHERE NOT EXISTS
                 (
                     SELECT 1
                     FROM Housing.Bills savedRentBill
                     WHERE savedRentBill.residentInfoID_FK = @BillsResidentInfoID
                       AND savedRentBill.buildingDetailsID = @BillsBuildingDetailsID
                       AND savedRentBill.idaraID_FK = @IdaraID_INT
                       AND savedRentBill.BillChargeTypeID_FK = 1
                       AND savedRentBill.BillActive = 1
                       AND CAST(savedRentBill.BillsFromDate AS date) <= expectedRent.CalcToDate
                       AND CAST(savedRentBill.BillsToDate AS date) >= expectedRent.CalcFromDate
                 )
             )
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي - RentBills', 1; -- برمجي
            END

            end

            EXEC Housing.GenerateMissingResidentFixedServiceBills
                  @ResidentInfoID = @BillsResidentInfoID
                , @GeneralNo = @BillsGeneralNo
                , @BuildingDetailsID = @BillsBuildingDetailsID
                , @OccupentDate = @BillsOccupentDate
                , @IdaraID = @IdaraID_INT
                , @EntryData = @entryData
                , @HostName = @hostName;

            --SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي - Identity', 1; -- برمجي
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
                , N'HISTORICALRESIDENTFINALIZE'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تسكين المستفيد بشكل نهائي بنجاح' AS Message_;
            RETURN;
        END
        ----------------------------------------------------------------
        -- Cancel Housing Resident Before Final Occupancy
        ----------------------------------------------------------------
      ----------------------------------------------------------------
-- HISTORICALRESIDENTCANCEL
-- إلغاء إجراءات التسكين قبل التسكين النهائي رقم 2
----------------------------------------------------------------
ELSE IF @Action = N'HISTORICALRESIDENTCANCEL'
BEGIN
    DECLARE
          @CancelActionTypeID  INT
        , @CurrentActionTypeID INT
        , @AssignActionTypeID  INT
        , @MeterReadActionID   BIGINT
        , @CancelReason        NVARCHAR(1000);

    SET @CancelReason =
        CONCAT(
              N'HISTORICALRESIDENTCANCEL; User=', @entryData
            , N'; Date=', CONVERT(NVARCHAR(19), GETDATE(), 120)
            , N'; Reason=', @Notes
        );

    ------------------------------------------------------------
    -- التحققات الأساسية
    ------------------------------------------------------------
    IF @ActionID IS NULL
    BEGIN
        ;THROW 50001, N'رقم السجل مطلوب', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@residentInfoID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم المستفيد غير صحيح', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@LastActionID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم آخر حركة غير صحيح', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم المنزل غير صحيح', 1;
    END;

    IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
    BEGIN
        ;THROW 50001, N'يجب كتابة سبب إلغاء التسكين', 1;
    END;

    ------------------------------------------------------------
    -- التأكد من وجود سجل الانتظار وتطابق بياناته
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_WaitingList w
        WHERE w.ActionID = @ActionID
          AND w.residentInfoID =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND w.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND w.IdaraId = @IdaraID_INT
    )
    BEGIN
        ;THROW 50001, N'السجل غير موجود', 1;
    END;

    ------------------------------------------------------------
    -- قراءة آخر حالة الفعلية من قاعدة البيانات
    ------------------------------------------------------------
    SELECT
        @CurrentActionTypeID = w.LastActionTypeID
    FROM Housing.V_WaitingList w
    WHERE w.ActionID = @ActionID
      AND w.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND w.buildingDetailsID =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND w.IdaraId = @IdaraID_INT
      AND w.LastActionID =
          TRY_CONVERT(BIGINT, @LastActionID);

    IF @CurrentActionTypeID IS NULL
    BEGIN
        ;THROW 50001,
            N'تغيرت حالة المستفيد، يرجى تحديث الصفحة والمحاولة مرة أخرى',
            1;
    END;

    ------------------------------------------------------------
    -- يسمح بالإلغاء فقط قبل التسكين النهائي:
    -- 45 = موافقة المستفيد على المنزل
    -- 46 = بانتظار قراءة عدادات التسكين
    -- 47 = تم اعتماد قراءات التسكين
    ------------------------------------------------------------
    IF @CurrentActionTypeID NOT IN (45, 46, 47)
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ تم تسكين المستفيد نهائياً أو تغيرت حالته',
            1;
    END;


    ------------------------------------------------------------
-- إلغاء التسكين الجانبي وإعادة المستفيد لقائمة الانتظار
------------------------------------------------------------
DECLARE @IsSideCancellation BIT = 0;
DECLARE @SideOriginalWaitingClassID INT = NULL;

SELECT @SideOriginalWaitingClassID = w.WaitingClassID,
       @IsSideCancellation =
    CASE
        WHEN wc.idara_FK IS NOT NULL THEN 1 ELSE 0
    END
FROM Housing.V_WaitingList w
INNER JOIN Housing.WaitingClass wc ON wc.waitingClassID = w.WaitingClassID
WHERE w.ActionID = @ActionID
  AND w.residentInfoID = TRY_CONVERT(BIGINT, @residentInfoID)
  AND w.buildingDetailsID = TRY_CONVERT(BIGINT, @buildingDetailsID)
  AND w.IdaraId = @IdaraID_INT
  AND w.LastActionID = TRY_CONVERT(BIGINT, @LastActionID)
  AND w.LastActionTypeID = @CurrentActionTypeID;

IF @IsSideCancellation = 1
BEGIN
    DECLARE @SideHouseLockResult INT;
    DECLARE @SideResidentLockResult INT;
    Declare @OccupancyText Nvarchar(2000);
    set @OccupancyText = CONCAT(
            N'Housing.Occupancy:', @IdaraID_INT,
            N':', TRY_CONVERT(BIGINT, @buildingDetailsID))
    EXEC @SideHouseLockResult = sys.sp_getapplock
        @Resource = @OccupancyText
        ,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @SideHouseLockResult < 0
        THROW 50001,
            N'تجري معالجة أخرى للمنزل؛ يرجى إعادة المحاولة.', 1;
            Declare @ResourceText nvarchar(2000)
            set @ResourceText = CONCAT(
            N'Housing.ResidentOccupancy:',
            TRY_CONVERT(BIGINT, @residentInfoID)
        )
    EXEC @SideResidentLockResult = sys.sp_getapplock
        @Resource = @ResourceText,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @SideResidentLockResult < 0
        THROW 50001,
            N'تجري معالجة أخرى للمستفيد؛ يرجى إعادة المحاولة.', 1;

    -- إعادة التحقق بعد الحصول على الأقفال
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_WaitingList w
        WHERE w.ActionID = @ActionID
          AND w.residentInfoID = TRY_CONVERT(BIGINT, @residentInfoID)
          AND w.buildingDetailsID = TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND w.IdaraId = @IdaraID_INT
          AND w.LastActionID = TRY_CONVERT(BIGINT, @LastActionID)
          AND w.LastActionTypeID = @CurrentActionTypeID
    )
        THROW 50001,
            N'تغيرت حالة طلب التسكين؛ حدّث الصفحة.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.V_Occupant o
        WHERE o.residentInfoID = TRY_CONVERT(BIGINT, @residentInfoID)
    )
        THROW 50001,
            N'لا يمكن الإلغاء بعد التسكين النهائي.', 1;

    DECLARE @Side45 BIGINT = NULL;
    DECLARE @Side46 BIGINT = NULL;
    DECLARE @Side47 BIGINT = NULL;

    ;WITH SideChain AS
    (
        SELECT
            b.buildingActionID,
            b.buildingActionParentID,
            b.buildingActionTypeID_FK,
            0 AS ChainLevel
        FROM Housing.BuildingAction b
        WHERE b.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND b.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND b.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND b.IdaraId_FK = @IdaraID_INT
          AND b.buildingActionActive = 1

        UNION ALL

        SELECT
            p.buildingActionID,
            p.buildingActionParentID,
            p.buildingActionTypeID_FK,
            child.ChainLevel + 1
        FROM Housing.BuildingAction p
        INNER JOIN SideChain child
            ON child.buildingActionParentID = p.buildingActionID
        WHERE child.ChainLevel < 3
          AND p.buildingActionTypeID_FK IN (45, 46, 47)
          AND p.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND p.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND p.IdaraId_FK = @IdaraID_INT
          AND p.buildingActionActive = 1
    )
    SELECT
        @Side45 = MAX(
            CASE WHEN buildingActionTypeID_FK = 45
                       AND buildingActionParentID = @ActionID
                 THEN buildingActionID END
        ),
        @Side46 = MAX(
            CASE WHEN buildingActionTypeID_FK = 46
                 THEN buildingActionID END
        ),
        @Side47 = MAX(
            CASE WHEN buildingActionTypeID_FK = 47
                 THEN buildingActionID END
        )
    FROM SideChain
    OPTION (MAXRECURSION 4);

    IF @Side45 IS NULL
       OR (@CurrentActionTypeID = 46 AND @Side46 IS NULL)
       OR (@CurrentActionTypeID = 47 AND @Side47 IS NULL)
        THROW 50001,
            N'تعذر التحقق من سلسلة التسكين الجانبية.', 1;

    --------------------------------------------------------
    -- حماية فواتير وقراءات التسكين
    --------------------------------------------------------
    IF @Side46 IS NOT NULL
    BEGIN
        UPDATE b
        SET b.BillActive = 0,
            b.CanceledBy = @CancelReason
        FROM Housing.Bills b
        INNER JOIN Housing.MeterRead mr
            ON mr.meterReadID = b.meterReadID
        WHERE mr.buildingActionID_FK = @Side46
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND b.BillTypeID_FK = 1
          AND b.BillActive = 1;

        UPDATE mr
        SET mr.meterReadActive = 0,
            mr.CanceledBy = @CancelReason
        FROM Housing.MeterRead mr
        WHERE mr.buildingActionID_FK = @Side46
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND mr.meterReadActive = 1;
    END;

    --------------------------------------------------------
    -- إلغاء السلسلة منطقيًا، مع حفظ سجلاتها
    --------------------------------------------------------
    UPDATE ba
    SET ba.buildingActionActive = 0
    FROM Housing.BuildingAction ba
    WHERE ba.buildingActionID IN (@Side45, @Side46, @Side47)
      AND ba.residentInfoID_FK =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND ba.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND ba.IdaraId_FK = @IdaraID_INT
      AND ba.buildingActionActive = 1;

    IF @@ROWCOUNT <>
       (1
        + CASE WHEN @Side46 IS NULL THEN 0 ELSE 1 END
        + CASE WHEN @Side47 IS NULL THEN 0 ELSE 1 END)
        THROW 50001,
            N'تعذر إلغاء سلسلة التسكين كاملة.', 1;

    -- Verify that the original waiting-list registration is visible again.
    -- 34/35 belong to inter-department transfer requests, not WAITING.
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_WaitingList w
        WHERE w.ActionID = @ActionID
          AND w.residentInfoID = TRY_CONVERT(BIGINT, @residentInfoID)
          AND w.IdaraId = @IdaraID_INT
          AND (
               w.WaitingClassID = @SideOriginalWaitingClassID
               OR (w.WaitingClassID IS NULL AND @SideOriginalWaitingClassID IS NULL)
          )
          AND (
               w.LastActionTypeID IS NULL
               OR w.LastActionTypeID = w.ActionTypeID
          )
          AND (
               w.LastActionID IS NULL
               OR w.LastActionID = w.ActionID
          )
    )
        THROW 50001,
            N'تعذر تأكيد العودة إلى سجل الانتظار الجانبي الأصلي؛ تمت إعادة العملية دون تغيير.',
            1;

    INSERT INTO dbo.AuditLog
    (
        TableName, ActionType, RecordID, PerformedBy, Notes
    )
    VALUES
    (
        N'[Housing].[BuildingAction]',
        N'HISTORICALRESIDENTCANCEL',
        @Side45,
        @entryData,
        CONCAT(
            N'SIDE_WAITING_RETURN; Root=', @ActionID,
            N'; Action45=', @Side45,
            N'; Action46=', COALESCE(CONVERT(NVARCHAR(30), @Side46), N'NULL'),
            N'; Action47=', COALESCE(CONVERT(NVARCHAR(30), @Side47), N'NULL'),
            N'; Reason=', @Notes
        )
    );

    SELECT 1 AS IsSuccessful,
           N'تم إلغاء إجراءات التسكين وإعادة المستفيد إلى قائمة الانتظار الجانبية'
           AS Message_;
    RETURN;
END;


    ------------------------------------------------------------
    -- قفل آخر حركة وإعادة التحقق وقت التنفيذ
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction ba WITH (UPDLOCK, HOLDLOCK)
        WHERE ba.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND ba.buildingActionTypeID_FK IN (45, 46, 47)
          AND ba.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND ba.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND ba.IdaraId_FK = @IdaraID_INT
          AND ba.buildingActionActive = 1
    )
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ حالة المستفيد تغيرت',
            1;
    END;

    ------------------------------------------------------------
    -- لا يسمح بالإلغاء إذا أصبح المستفيد ساكناً فعلياً
    ------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM Housing.V_Occupant o
        WHERE o.residentInfoID =
              TRY_CONVERT(BIGINT, @residentInfoID)
    )
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ تم تسكين المستفيد بشكل نهائي',
            1;
    END;

    ------------------------------------------------------------
    -- تتبع سلسلة الحركات:
    --
    -- التخصيص الأول:
    -- 38 -> 45 -> 46 -> 47
    --
    -- التخصيص الثاني:
    -- 40 -> 45 -> 46 -> 47
    ------------------------------------------------------------
    ;WITH ActionChain AS
    (
        SELECT
              ba.buildingActionID
            , ba.buildingActionTypeID_FK
            , ba.buildingActionParentID
            , 0 AS ChainLevel
        FROM Housing.BuildingAction ba
        WHERE ba.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND ba.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND ba.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND ba.IdaraId_FK = @IdaraID_INT
          AND ba.buildingActionActive = 1

        UNION ALL

        SELECT
              parentBa.buildingActionID
            , parentBa.buildingActionTypeID_FK
            , parentBa.buildingActionParentID
            , child.ChainLevel + 1
        FROM Housing.BuildingAction parentBa
        INNER JOIN ActionChain child
            ON parentBa.buildingActionID =
               child.buildingActionParentID
        WHERE child.ChainLevel < 10
          AND parentBa.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND parentBa.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND parentBa.IdaraId_FK = @IdaraID_INT
          AND parentBa.buildingActionActive = 1
    )
    SELECT
          @AssignActionTypeID =
              MAX(
                  CASE
                      WHEN buildingActionTypeID_FK IN (38, 40)
                      THEN buildingActionTypeID_FK
                  END
              )
        , @MeterReadActionID =
              MAX(
                  CASE
                      WHEN buildingActionTypeID_FK = 46
                      THEN buildingActionID
                  END
              )
    FROM ActionChain
    OPTION (MAXRECURSION 10);

    ------------------------------------------------------------
    -- تحديد نتيجة الإلغاء
    --
    -- 38 = التخصيص الأول  -> 39 رفض التخصيص الأول
    -- 40 = التخصيص الثاني -> 42 إلغاء أهلية السكن
    ------------------------------------------------------------
    SET @CancelActionTypeID =
        CASE @AssignActionTypeID
            WHEN 38 THEN 39
            WHEN 40 THEN 42
            ELSE 0
        END;

    IF ISNULL(@CancelActionTypeID, 0) = 0
    BEGIN
        ;THROW 50001,
            N'تعذر تحديد ما إذا كان التخصيص الأول أو الثاني',
            1;
    END;

    ------------------------------------------------------------
    -- إذا كانت الحالة 46 أو 47:
    -- إلغاء قراءات وفواتير التسكين المرتبطة بالعملية
    ------------------------------------------------------------
    ------------------------------------------------------------
-- الحالة 46 يجب أن تكون مرتبطة بحركة طلب قراءة
------------------------------------------------------------
IF @CurrentActionTypeID = 46
   AND @MeterReadActionID IS NULL
BEGIN
    THROW 50001,
        N'تعذر تحديد حركة طلب قراءة عدادات التسكين',
        1;
END;

------------------------------------------------------------
-- السماح بالحالة 45 -> 47 مباشرة عند عدم وجود عدادات
-- مع التحقق من الأب الفعلي للحركة 47
------------------------------------------------------------
IF @CurrentActionTypeID = 47
   AND @MeterReadActionID IS NULL
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction currentAction
        INNER JOIN Housing.BuildingAction parentAction
            ON parentAction.buildingActionID =
               currentAction.buildingActionParentID
        WHERE currentAction.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND currentAction.buildingActionTypeID_FK = 47
          AND parentAction.buildingActionTypeID_FK = 45
          AND currentAction.buildingActionActive = 1
          AND parentAction.buildingActionActive = 1
          AND currentAction.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND parentAction.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND currentAction.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND parentAction.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND currentAction.IdaraId_FK = @IdaraID_INT
          AND parentAction.IdaraId_FK = @IdaraID_INT
    )
    BEGIN
        THROW 50001,
            N'تعذر التحقق من مسار التسكين المباشر دون عدادات',
            1;
    END;
END;

------------------------------------------------------------
-- معالجة الفواتير والقراءات فقط عندما توجد حركة 46
------------------------------------------------------------
IF @CurrentActionTypeID IN (46, 47)
   AND @MeterReadActionID IS NOT NULL
BEGIN

        --------------------------------------------------------
        -- تعطيل فواتير التسكين المرتبطة بالقراءات فقط
        --
        -- BillTypeID_FK = 1:
        -- فاتورة قراءة تسكين
        --------------------------------------------------------
        UPDATE b
        SET
              b.BillActive = 0
            , b.CanceledBy = @CancelReason
        FROM Housing.Bills b
        INNER JOIN Housing.MeterRead mr
            ON mr.meterReadID = b.meterReadID
        WHERE mr.buildingActionID_FK =
              @MeterReadActionID
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND b.BillTypeID_FK = 1
          AND b.BillActive = 1;

        --------------------------------------------------------
        -- تعطيل قراءات التسكين
        --
        -- لا نشترط وجود قراءة، فقد يكون الطلب لا يزال
        -- بانتظار قيام القارئ بتسجيل القراءة
        --------------------------------------------------------
        UPDATE mr
        SET
              mr.meterReadActive = 0
            , mr.CanceledBy = @CancelReason
        FROM Housing.MeterRead mr
        WHERE mr.buildingActionID_FK =
              @MeterReadActionID
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND mr.meterReadActive = 1;
    END;

    ------------------------------------------------------------
    -- تسجيل حركة إلغاء التسكين
    ------------------------------------------------------------
    INSERT INTO Housing.BuildingAction
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
    VALUES
    (
          @CancelActionTypeID
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
        , 0
        , @IdaraID_INT
        , @entryData
        , @hostName
    );

    IF @@ROWCOUNT = 0
    BEGIN
        ;THROW 50002,
            N'حصل خطأ في إلغاء التسكين',
            1;
    END;

    SET @NewID = SCOPE_IDENTITY();

    IF @NewID IS NULL OR @NewID <= 0
    BEGIN
        ;THROW 50002,
            N'حصل خطأ في إلغاء التسكين - Identity',
            1;
    END;

    ------------------------------------------------------------
    -- إعداد بيانات سجل التدقيق
    ------------------------------------------------------------
    SET @Note =
          N'{'
        + N'"buildingActionID":"'
        + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'')
        + N'"'

        + N',"buildingActionTypeID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @CancelActionTypeID),
              N''
          )
        + N'"'

        + N',"PreviousActionTypeID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @CurrentActionTypeID),
              N''
          )
        + N'"'

        + N',"AllocationActionTypeID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @AssignActionTypeID),
              N''
          )
        + N'"'

        + N',"MeterReadActionID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @MeterReadActionID),
              N''
          )
        + N'"'

        + N',"residentInfoID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @residentInfoID),
              N''
          )
        + N'"'

        + N',"generalNo_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @GeneralNo),
              N''
          )
        + N'"'

        + N',"buildingDetailsID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @buildingDetailsID),
              N''
          )
        + N'"'

        + N',"buildingDetailsNo":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @buildingDetailsNo),
              N''
          )
        + N'"'

        + N',"buildingActionParentID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @LastActionID),
              N''
          )
        + N'"'

        + N',"AssignPeriodID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @AssignPeriodID),
              N''
          )
        + N'"'

        + N',"Notes":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @Notes),
              N''
          )
        + N'"'

        + N',"entryData":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @entryData),
              N''
          )
        + N'"'

        + N',"hostName":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @hostName),
              N''
          )
        + N'"}';

    ------------------------------------------------------------
    -- تسجيل العملية في AuditLog
    ------------------------------------------------------------
    INSERT INTO dbo.AuditLog
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
        , N'HISTORICALRESIDENTCANCEL'
        , @NewID
        , @entryData
        , @Note
    );

    ------------------------------------------------------------
    -- النتيجة حسب رقم فرصة التخصيص
    ------------------------------------------------------------
    IF @CancelActionTypeID = 39
    BEGIN
        SELECT
              1 AS IsSuccessful
            , N'تم إلغاء التسكين واحتسابه رفضاً للتخصيص للمرة الأولى'
              AS Message_;
    END;
    ELSE
    BEGIN
        SELECT
              1 AS IsSuccessful
            , N'تم إلغاء التسكين وإلغاء أحقية المستفيد في السكن نهائياً'
              AS Message_;
    END;

    RETURN;
END;

        
       

                  
        
       

        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        -- The outer Masters_CRUD handler rolls back the transaction.

        ;THROW;
    END CATCH
END