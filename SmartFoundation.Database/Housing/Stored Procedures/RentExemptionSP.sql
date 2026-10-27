
CREATE  PROCEDURE [Housing].[RentExemptionSP] 
(
      @Action                               NVARCHAR(200)
    , @residentRentExemptionID              BIGINT          = NULL
    , @residentRentExemptionTypeID_FK       BIGINT   = NULL
    , @residentInfoID_FK                    NVARCHAR(100)   = NULL
    , @residentRentExemptionStartDate       NVARCHAR(1000)  = NULL
    , @residentRentExemptionEndDate         NVARCHAR(1000)  = NULL
    , @residentRentExemptionDescription     NVARCHAR(1000)  = NULL
    , @residentRentExemptionLetterNo        NVARCHAR(1000)  = NULL
    , @residentRentExemptionLetterDate      NVARCHAR(1000)  = NULL
    , @buildingDetailsID_FK                 NVARCHAR(1000)  = NULL
    , @buildingDetailsNo                    NVARCHAR(1000)  = NULL
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
    DECLARE @RetroactiveThroughDate DATE = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
    DECLARE @CurrentMonthEnd DATE = EOMONTH(GETDATE());
    DECLARE @ExemptionStartDate DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@residentRentExemptionStartDate)), N''));
    DECLARE @ExemptionEndDate DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@residentRentExemptionEndDate)), N''));
    DECLARE @OccupentDate DATE = NULL;
    DECLARE @LastActionTypeID BIGINT = NULL;

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
                   IF NULLIF(LTRIM(RTRIM(@residentRentExemptionTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الاعفاء مطلوب', 1;
            END
            
            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الرقم المرجعي للمستفيد مطلوب', 1;
            END
            
            IF NULLIF(LTRIM(RTRIM(@residentRentExemptionStartDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ بداية الاعفاء مطلوب', 1;
            END
            
            
            IF NULLIF(LTRIM(RTRIM(@residentRentExemptionLetterNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم الخطاب مطلوب', 1;
            END
            
            IF NULLIF(LTRIM(RTRIM(@residentRentExemptionLetterDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ الخطاب مطلوب', 1;
            END
            
            IF NULLIF(LTRIM(RTRIM(@idaraID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الإدارة مطلوبة', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingDetailsNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم المنزل مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingDetailsID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم المنزل مطلوب', 1;
            END

            IF @ExemptionStartDate IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ بداية الاعفاء غير صحيح', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@residentRentExemptionEndDate)), N'') IS NOT NULL
               AND @ExemptionEndDate IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ نهاية الاعفاء غير صحيح', 1;
            END

            IF @ExemptionEndDate <= @ExemptionStartDate
            BEGIN
                ;THROW 50001, N'تاريخ نهاية الاعفاء يجب أن يكون اكبر من تاريخ بداية الاعفاء', 1;
            END

            IF @Action IN (N'ADDRENTEXEMPTION', N'EDITRENTEXEMPTION')
             BEGIN
                -- P2: validate current occupancy *chain* rather than any historical action 54.
                -- Serialized with Housing.ManageExitRentExemptionClosure APPLY at 57.
                DECLARE @ExemptionResidentID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N''));
                DECLARE @ExemptionBuildingID BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@buildingDetailsID_FK)), N''));
                DECLARE @ExemptionLockResult INT;
                DECLARE @ExemptionLockResource NVARCHAR(255);
                DECLARE @ExemptionCurrent TABLE
                (
                    WaitingRoot BIGINT NOT NULL,
                    CurrentActionID BIGINT NOT NULL,
                    CurrentStage BIGINT NOT NULL,
                    OccupancyStart DATE NOT NULL
                );

                IF @ExemptionResidentID IS NULL OR @ExemptionBuildingID IS NULL OR @IdaraID_INT IS NULL
                    THROW 50001, N'بيانات المستفيد أو المنزل أو الإدارة غير صالحة', 1;

                SET @ExemptionLockResource = CONCAT(N'EXIT_EXEMPTION:', @IdaraID_INT,
                    N':', @ExemptionResidentID, N':', @ExemptionBuildingID);
                EXEC @ExemptionLockResult = sys.sp_getapplock
                      @Resource = @ExemptionLockResource
                    , @LockMode = N'Exclusive'
                    , @LockOwner = N'Transaction'
                    , @LockTimeout = 15000;
                IF @ExemptionLockResult < 0
                    THROW 50001, N'تعذر حجز معالجة إعفاء المستفيد', 1;

                -- V_Occupant is the ordinary eligibility path. Once it no longer
                -- lists a physically vacated occupant at 54, the verified current
                -- 54/59/60 chain is a limited fallback until submission at 57.
                INSERT INTO @ExemptionCurrent
                    (WaitingRoot, CurrentActionID, CurrentStage, OccupancyStart)
                SELECT w.ActionID,
                       TRY_CONVERT(BIGINT, w.LastActionID),
                       TRY_CONVERT(BIGINT, w.LastActionTypeID),
                       originalOccupancy.OccupancyStart
                FROM Housing.V_WaitingList w
                JOIN Housing.BuildingAction tip
                  ON tip.buildingActionID = TRY_CONVERT(BIGINT, w.LastActionID)
                 AND tip.buildingActionActive = 1
                 AND tip.buildingActionTypeID_FK = TRY_CONVERT(BIGINT, w.LastActionTypeID)
                 AND tip.residentInfoID_FK = @ExemptionResidentID
                 AND tip.buildingDetailsID_FK = @ExemptionBuildingID
                 AND tip.IdaraId_FK = @IdaraID_INT
                CROSS APPLY
                (
                    SELECT TOP (1) TRY_CONVERT(DATE, occupancy.OccupentDate) AS OccupancyStart
                    FROM Housing.fn_BuildingAction_ChainToRoot(tip.buildingActionID) ancestor
                    JOIN Housing.BuildingAction occupancy
                      ON occupancy.buildingActionID = ancestor.buildingActionID
                    WHERE occupancy.buildingActionTypeID_FK = 2
                      AND occupancy.buildingActionActive = 1
                      AND occupancy.residentInfoID_FK = @ExemptionResidentID
                      AND occupancy.buildingDetailsID_FK = @ExemptionBuildingID
                      AND TRY_CONVERT(DATE, occupancy.OccupentDate) IS NOT NULL
                    ORDER BY ancestor.Lvl ASC
                ) originalOccupancy
                WHERE w.residentInfoID = @ExemptionResidentID
                  AND w.buildingDetailsID = @ExemptionBuildingID
                  AND w.IdaraId = @IdaraID_INT
                  AND
                  (
                      TRY_CONVERT(BIGINT, w.LastActionTypeID) IN (54, 59, 60)
                      OR EXISTS
                      (
                          SELECT 1 FROM Housing.V_Occupant vo
                          WHERE vo.ActionID = w.ActionID
                            AND vo.residentInfoID = @ExemptionResidentID
                            AND vo.buildingDetailsID = @ExemptionBuildingID
                            AND vo.IdaraId = @IdaraID_INT
                      )
                  );

                IF (SELECT COUNT_BIG(*) FROM @ExemptionCurrent) <> 1
                    THROW 50001, N'تعذر تحديد دورة الإشغال الحالية للإعفاء بشكل فريد', 1;

                SELECT @OccupentDate = OccupancyStart,
                       @LastActionTypeID = CurrentStage
                FROM @ExemptionCurrent;

                IF @OccupentDate IS NULL OR @LastActionTypeID IN (3, 57, 58)
                    THROW 50001, N'لا يمكن إضافة أو تعديل الإعفاء بعد إرساله للتدقيق المالي', 1;

                -- EDIT must not replace another resident's or another home's exemption.
                -- Hold the row lock through the existing EDIT_REPLACE operation.
                IF @Action = N'EDITRENTEXEMPTION' AND NOT EXISTS
                (
                    SELECT 1 FROM Housing.ResidentRentExemption e WITH (UPDLOCK, HOLDLOCK)
                    WHERE e.residentRentExemptionID = @residentRentExemptionID
                      AND e.residentRentExemptionActive = 1
                      AND e.residentInfoID_FK = @ExemptionResidentID
                      AND e.buildingDetailsID_FK = @ExemptionBuildingID
                      AND e.idaraID_FK = @IdaraID_INT
                )
                    THROW 50001, N'الإعفاء لا يتبع المستفيد والمنزل والإدارة المحددة', 1;

                -- Reject changes to an exemption already capped by any v1 exit
                -- cycle, even if a view is stale or a different chain is selected.
                IF @Action = N'EDITRENTEXEMPTION' AND EXISTS
                (
                    SELECT 1 FROM Housing.ExitRentExemptionClosure c
                    WHERE c.ResidentRentExemptionID_FK = @residentRentExemptionID
                      AND c.RestoredAt IS NULL
                )
                    THROW 50001, N'لا يمكن تعديل إعفاء أُغلق ضمن دورة إخلاء لم تُستعد', 1;

                IF @ExemptionStartDate < @OccupentDate
                BEGIN
                    DECLARE @OccupancyDateMessage NVARCHAR(2048) =
                        N'تاريخ بداية سكن المستفيد هو '
                        + CONVERT(NVARCHAR(10), @OccupentDate, 23)
                        + N'، ولا يمكن أن يكون تاريخ بداية الإعفاء قبله';
                    ;THROW 50001, @OccupancyDateMessage, 1;
                END

                DECLARE @ConflictingExemptionStartDate DATE = NULL;
                DECLARE @ConflictingExemptionEndDate DATE = NULL;

                SELECT TOP (1)
                      @ConflictingExemptionStartDate = TRY_CONVERT(DATE, exemption.residentRentExemptionStartDate)
                    , @ConflictingExemptionEndDate = TRY_CONVERT(DATE, exemption.residentRentExemptionEndDate)
                FROM Housing.ResidentRentExemption exemption
                WHERE exemption.residentInfoID_FK = @residentInfoID_FK
                  AND exemption.buildingDetailsID_FK = TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID_FK, N''))
                  AND (exemption.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
                  AND exemption.residentRentExemptionActive = 1
                  AND
                  (
                      @Action <> N'EDITRENTEXEMPTION'
                      OR exemption.residentRentExemptionID <> @residentRentExemptionID
                  )
                  AND TRY_CONVERT(DATE, exemption.residentRentExemptionStartDate) <= ISNULL(@ExemptionEndDate, CONVERT(DATE, N'9999-12-31'))
                  AND ISNULL(TRY_CONVERT(DATE, exemption.residentRentExemptionEndDate), CONVERT(DATE, N'9999-12-31')) >= @ExemptionStartDate
                ORDER BY exemption.residentRentExemptionStartDate, exemption.residentRentExemptionID;

                IF @ConflictingExemptionStartDate IS NOT NULL
                BEGIN
                    DECLARE @ConflictMessage NVARCHAR(2048) =
                        CASE
                            WHEN @ConflictingExemptionEndDate IS NULL THEN
                                N'لا يمكن حفظ الإعفاء لتداخل مدته مع إعفاء قائم ابتداءً من '
                                + CONVERT(NVARCHAR(10), @ConflictingExemptionStartDate, 23)
                                + N' بدون تاريخ نهاية'
                            ELSE
                                N'لا يمكن حفظ الإعفاء لتداخل مدته مع إعفاء قائم من '
                                + CONVERT(NVARCHAR(10), @ConflictingExemptionStartDate, 23)
                                + N' إلى '
                                + CONVERT(NVARCHAR(10), @ConflictingExemptionEndDate, 23)
                        END;
                    ;THROW 50001, @ConflictMessage, 1;
                END
            END

        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'ADDRENTEXEMPTION'
        BEGIN

            INSERT INTO  Housing.ResidentRentExemption
            (
                  [residentRentExemptionTypeID_FK]
                 ,[residentInfoID_FK]
                 ,[buildingDetailsID_FK]
                 ,[residentRentExemptionActive]
                 ,[residentRentExemptionLetterNo]
                 ,[residentRentExemptionLetterDate]
                 ,[residentRentExemptionStartDate]
                 ,[residentRentExemptionEndDate]
                 ,[residentRentExemptionDescription]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[entryDate]
                 ,[hostName]
            )
            VALUES
            (
                  @residentRentExemptionTypeID_FK
                , @residentInfoID_FK
                , @buildingDetailsID_FK
                , 1
                , @residentRentExemptionLetterNo
                , @residentRentExemptionLetterDate
                , @residentRentExemptionStartDate
                , @residentRentExemptionEndDate
                , @residentRentExemptionDescription
                , @IdaraID_INT
                , @entryData
                , GETDATE()
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الاعفاء', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الاعفاء - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"residentRentExemptionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"residentRentExemptionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"buildingDetailsID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID_FK), '') + N'"'
                + N',"residentRentExemptionActive": "1"'
                + N',"residentRentExemptionLetterNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterNo), '') + N'"'
                + N',"residentRentExemptionLetterDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterDate), '') + N'"'
                + N',"residentRentExemptionStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionStartDate), '') + N'"' 
                + N',"residentRentExemptionEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionEndDate), '') + N'"'
                + N',"residentRentExemptionDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionDescription), '') + N'"'
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
                  N'[Housing].[ResidentRentExemption]'
                , N'ADDRENTEXEMPTION'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            EXEC Housing.SyncRentExemptionPayments
                  @Action = N'GENERATE'
                , @ResidentRentExemptionID = @NewID
                , @ThroughDate = @RetroactiveThroughDate
                , @SourceType = N'ADD_RETROACTIVE'
                , @EntryData = @entryData
                , @HostName = @hostName;

            IF @tc = 0
                COMMIT TRANSACTION;

            SELECT 1 AS IsSuccessful, N'تم اضافة الاعفاء بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- EDITRENTEXEMPTION
        ----------------------------------------------------------------
        ELSE IF @Action = N'EDITRENTEXEMPTION'
        BEGIN
            IF @residentRentExemptionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.ResidentRentExemption c
                WHERE C.residentRentExemptionID = @residentRentExemptionID
                  AND c.residentRentExemptionActive = 1
                  AND (c.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'الاعفاء غير موجود', 1;
            END

            -- The current occupancy/exit stage was verified and locked above.
            -- Do not scan ANY historical 54/59/60/3 rows: canceled cycles
            -- remain marked active in the action audit trail.
            -- Preserve the existing EDIT_REPLACE settlement behavior separately.
            EXEC Housing.SyncRentExemptionPayments
                  @Action = N'CANCEL'
                , @ResidentRentExemptionID = @residentRentExemptionID
                , @SourceType = N'EDIT_REPLACE'
                , @EntryData = @entryData
                , @HostName = @hostName;

            IF (SELECT COUNT(*) FROM Housing.ResidentRentExemption e WHERE e.residentRentExemptionID = @residentRentExemptionID and e.residentRentExemptionEndDate is not null ) > 0
            BEGIN
                UPDATE  Housing.ResidentRentExemption
            SET residentRentExemptionActive = 0
            WHERE residentRentExemptionID = @residentRentExemptionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END
            END

            IF (SELECT COUNT(*) FROM Housing.ResidentRentExemption e WHERE e.residentRentExemptionID = @residentRentExemptionID and e.residentRentExemptionEndDate is null ) > 0
            BEGIN
                UPDATE  Housing.ResidentRentExemption
            SET residentRentExemptionActive = 0, residentRentExemptionEndDate = GETDATE()
            WHERE residentRentExemptionID = @residentRentExemptionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END
            END


            
            INSERT INTO  Housing.ResidentRentExemption
            (
                  [residentRentExemptionTypeID_FK]
                 ,[residentInfoID_FK]
                 ,[buildingDetailsID_FK]
                 ,[residentRentExemptionActive]
                 ,[residentRentExemptionLetterNo]
                 ,[residentRentExemptionLetterDate]
                 ,[residentRentExemptionStartDate]
                 ,[residentRentExemptionEndDate]
                 ,[residentRentExemptionDescription]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[entryDate]
                 ,[hostName]
            )
            VALUES
            (
                  @residentRentExemptionTypeID_FK
                , @residentInfoID_FK
                , @buildingDetailsID_FK
                , 1
                , @residentRentExemptionLetterNo
                , @residentRentExemptionLetterDate
                , @residentRentExemptionStartDate
                , @residentRentExemptionEndDate
                , @residentRentExemptionDescription
                , @IdaraID_INT
                , @entryData
                , GETDATE()
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الاعفاء', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة الاعفاء - Identity', 1; -- برمجي
            END




            SET @Note = N'{'
                + N'"residentRentExemptionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionID), '') + N'"'
                + N',"residentRentExemptionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"buildingDetailsID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID_FK), '') + N'"'
                + N',"residentRentExemptionActive": "1"'
                + N',"residentRentExemptionLetterNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterNo), '') + N'"'
                + N',"residentRentExemptionLetterDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterDate), '') + N'"'
                + N',"residentRentExemptionStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionStartDate), '') + N'"' 
                + N',"residentRentExemptionEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionEndDate), '') + N'"'
                + N',"residentRentExemptionDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionDescription), '') + N'"'
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
                  N'[Housing].[ResidentRentExemption]'
                , N'EDITRENTEXEMPTION'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            EXEC Housing.SyncRentExemptionPayments
                  @Action = N'GENERATE'
                , @ResidentRentExemptionID = @NewID
                , @ThroughDate = @CurrentMonthEnd
                , @SourceType = N'EDIT_RETROACTIVE'
                , @EntryData = @entryData
                , @HostName = @hostName;

            IF @tc = 0
                COMMIT TRANSACTION;

            SELECT 1 AS IsSuccessful, N'تم تحديث الاعفاء بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETERENTEXEMPTION'
        BEGIN
           IF @residentRentExemptionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.ResidentRentExemption c
                WHERE C.residentRentExemptionID = @residentRentExemptionID
                  AND c.residentRentExemptionActive = 1
                  AND (c.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'الاعفاء غير موجود', 1;
            END

            IF EXISTS
            (
                SELECT 1
                FROM Housing.ResidentRentExemption currentExemption
                INNER JOIN Housing.BuildingAction exitAction
                    ON exitAction.residentInfoID_FK = currentExemption.residentInfoID_FK
                   AND exitAction.buildingDetailsID_FK = currentExemption.buildingDetailsID_FK
                WHERE currentExemption.residentRentExemptionID = @residentRentExemptionID
                  AND exitAction.buildingActionActive = 1
                  AND exitAction.buildingActionTypeID_FK IN (24, 52, 54, 56, 57, 58, 59, 60, 61, 3)
            )
            BEGIN
                ;THROW 50001, N'لا يمكن إلغاء الإعفاء بعد بدء إجراءات الإخلاء أو الإمهال لتنفيذ تأمين احترازي على الساكن بالمطالبات', 1;
            END

            EXEC Housing.SyncRentExemptionPayments
                  @Action = N'CANCEL'
                , @ResidentRentExemptionID = @residentRentExemptionID
                , @SourceType = N'CANCEL_EXEMPTION'
                , @EntryData = @entryData
                , @HostName = @hostName;

            IF (SELECT COUNT(*) FROM Housing.ResidentRentExemption e WHERE e.residentRentExemptionID = @residentRentExemptionID and e.residentRentExemptionEndDate is not null ) > 0
            BEGIN
                UPDATE  Housing.ResidentRentExemption
            SET residentRentExemptionActive = 0,CanceldBy = @entryData, CanceldDate = GETDATE(),CanceldWhy=@residentRentExemptionDescription
            WHERE residentRentExemptionID = @residentRentExemptionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم الغاء الاعفاء', 1; -- برمجي/غير متوقع
            END
            END

            IF (SELECT COUNT(*) FROM Housing.ResidentRentExemption e WHERE e.residentRentExemptionID = @residentRentExemptionID and e.residentRentExemptionEndDate is null ) > 0
            BEGIN
                UPDATE  Housing.ResidentRentExemption
            SET residentRentExemptionActive = 0, residentRentExemptionEndDate = GETDATE(),CanceldBy = @entryData, CanceldDate = GETDATE(),CanceldWhy=@residentRentExemptionDescription
            WHERE residentRentExemptionID = @residentRentExemptionID;

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم الغاء الاعفاء', 1; -- برمجي/غير متوقع
            END
            END


            SET @Note = N'{'
                + N'"residentRentExemptionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionID), '') + N'"'
                + N',"residentRentExemptionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"buildingDetailsID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID_FK), '') + N'"'
                + N',"residentRentExemptionActive": "1"'
                + N',"residentRentExemptionLetterNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterNo), '') + N'"'
                + N',"residentRentExemptionLetterDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionLetterDate), '') + N'"'
                + N',"residentRentExemptionStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionStartDate), '') + N'"' 
                + N',"residentRentExemptionEndDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionEndDate), '') + N'"'
                + N',"residentRentExemptionDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @residentRentExemptionDescription), '') + N'"'
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
                  N'[Housing].[ResidentRentExemption]'
                , N'DELETERENTEXEMPTION'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            IF @tc = 0
                COMMIT TRANSACTION;

            SELECT 1 AS IsSuccessful, N'تم الغاء الاعفاء بنجاح' AS Message_;
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