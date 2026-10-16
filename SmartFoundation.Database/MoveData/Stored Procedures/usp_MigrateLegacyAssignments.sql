CREATE PROCEDURE [MoveData].[usp_MigrateLegacyAssignments]
    @IdaraId bigint,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=@IdaraId)
        THROW 54500,N'The supplied IdaraId does not exist.',1;

    IF EXISTS
    (
        SELECT requiredType.ActionTypeID
        FROM (VALUES(38),(39),(40),(42),(45),(46),(47)) requiredType(ActionTypeID)
        WHERE NOT EXISTS
        (
            SELECT 1 FROM Housing.BuildingActionType targetType
            WHERE targetType.buildingActionTypeID=requiredType.ActionTypeID
        )
    )
        THROW 54501,N'Required allocation action types 38,39,40,42,45,46,47 do not exist.',1;

    DECLARE
        @PeriodsInserted bigint=0,
        @AllocationActionsInserted bigint=0,
        @LetterActionsInserted bigint=0,
        @HousingParentsUpdated bigint=0,
        @NoHouseCancellations bigint=0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Valid consecutive de-duplication of the old assignment table. */
        ;WITH OrderedAssignments AS
        (
            SELECT
                sourceAssign.*,
                LAG(sourceAssign.BuildingAssignID) OVER
                (
                    PARTITION BY sourceAssign.GeneralNo,sourceAssign.BuildingActionID_FK
                    ORDER BY sourceAssign.BuildingAssignID
                ) PreviousAssignID
            FROM KFMC.Housing.BuildingAssign sourceAssign
        )
        SELECT currentAssign.*
        INTO #ValidAssign
        FROM OrderedAssignments currentAssign
        JOIN KFMC.Housing.BuildingAction ownerAction
          ON ownerAction.buildingActionID=currentAssign.BuildingActionID_FK
         AND CONVERT(nvarchar(100),ownerAction.generalNo_FK)
             =CONVERT(nvarchar(100),currentAssign.GeneralNo)
         AND ownerAction.generalNo_FK NOT IN (0,1)
         AND EXISTS
         (
             SELECT 1 FROM KFMC.Housing.ResidentInfo validResident
             WHERE validResident.generalNo=ownerAction.generalNo_FK
         )
        /* Consume only assignments copied during the previous migration step. */
        JOIN Housing.BuildingAssign migratedAssign
          ON migratedAssign.BuildingAssignID=currentAssign.BuildingAssignID
        LEFT JOIN KFMC.Housing.BuildingAssign previousAssign
          ON previousAssign.BuildingAssignID=currentAssign.PreviousAssignID
        WHERE previousAssign.BuildingAssignID IS NULL
           OR EXISTS
           (
               SELECT currentAssign.BuildingAssignTypeID_FK,currentAssign.ParentBuildingAssignID,
                      currentAssign.BuildingNo,currentAssign.BuildingAssignStatusID_FK,currentAssign.MeterReadValue
               EXCEPT
               SELECT previousAssign.BuildingAssignTypeID_FK,previousAssign.ParentBuildingAssignID,
                      previousAssign.BuildingNo,previousAssign.BuildingAssignStatusID_FK,previousAssign.MeterReadValue
           );

        CREATE UNIQUE CLUSTERED INDEX IX_ValidAssign_ID ON #ValidAssign(BuildingAssignID);
        CREATE INDEX IX_ValidAssign_Action ON #ValidAssign(BuildingActionID_FK,GeneralNo,BuildingAssignTypeID_FK);

        /* One historical, allocation-closed but response-open period for each normal class. */
        CREATE TABLE #PeriodMap(WaitingClassID int PRIMARY KEY,AssignPeriodID bigint NOT NULL);

        DECLARE @WaitingClassID int,@AssignPeriodID bigint;
        DECLARE PeriodCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT waitingClassID
            FROM Housing.WaitingClass
            WHERE waitingClassID IN(1,2,3,4)
            ORDER BY waitingClassID;

        OPEN PeriodCursor;
        FETCH NEXT FROM PeriodCursor INTO @WaitingClassID;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @AssignPeriodID=AssignPeriodID
            FROM Housing.AssignPeriod
            WHERE IdaraId_FK=@IdaraId
              AND WaitingClassID_FK=@WaitingClassID
              AND AssignPeriodDescrption=CONCAT(N'Legacy allocation migration - WaitingClass ',@WaitingClassID);

            IF @AssignPeriodID IS NULL
            BEGIN
                INSERT Housing.AssignPeriod
                (
                    WaitingClassID_FK,AssignPeriodDescrption,AssignPeriodStartdate,
                    AssignPeriodEnddate,AssignPeriodActive,AssignPeriodClose,
                    AssignPeriodCloseNote,AssignPeriodFinalEND,IdaraId_FK,
                    entryDate,entryData,hostName
                )
                SELECT
                    @WaitingClassID,
                    CONCAT(N'Legacy allocation migration - WaitingClass ',@WaitingClassID),
                    MIN(validAssign.entryDate),MAX(validAssign.entryDate),1,0,
                    N'Closed legacy allocation period; pending responses remain open.',1,
                    @IdaraId,GETDATE(),NULL,N'Data Migration'
                FROM #ValidAssign validAssign
                JOIN KFMC.Housing.BuildingAction action27
                 ON action27.buildingActionID=validAssign.BuildingActionID_FK
                 AND action27.buildingActionTypeID_FK=27
                JOIN KFMC.Housing.BuildingAction waitingRoot
                  ON waitingRoot.buildingActionID=action27.buildingActionParentID
                 AND waitingRoot.buildingActionTypeID_FK=1
                 AND waitingRoot.buildingActionActive=1
                JOIN Housing.BuildingAction migratedRoot
                  ON migratedRoot.buildingActionID=waitingRoot.buildingActionID
                 AND migratedRoot.buildingActionTypeID_FK=1
                 AND migratedRoot.buildingActionActive=1
                JOIN Housing.BuildingAction migratedAction27
                  ON migratedAction27.buildingActionID=action27.buildingActionID
                 AND migratedAction27.buildingActionTypeID_FK=27
                 AND COALESCE(action27.buildingActionExtraType1,waitingRoot.buildingActionExtraType1)
                     =@WaitingClassID;

                SET @AssignPeriodID=SCOPE_IDENTITY();
                SET @PeriodsInserted+=1;
            END;

            INSERT #PeriodMap VALUES(@WaitingClassID,@AssignPeriodID);
            SET @AssignPeriodID=NULL;
            FETCH NEXT FROM PeriodCursor INTO @WaitingClassID;
        END;
        CLOSE PeriodCursor;
        DEALLOCATE PeriodCursor;

        /* Normal waiting-list allocations (root action type 1). */
        DECLARE
            @Action27ID bigint,@GeneralNo bigint,@ResidentInfoID bigint,
            @PeriodID bigint,@CurrentParentID bigint,@NoHouseCount int,
            @OfferID int,@OfferNo int,@BuildingNo nvarchar(400),@BuildingID bigint,
            @MeterReadValue int,@OfferEntryDate datetime,@OfferEntryData nvarchar(1000),
            @OfferHostName nvarchar(4000),@RejectionID int,@RejectionEntryDate datetime,
            @RejectionEntryData nvarchar(1000),@RejectionHostName nvarchar(4000),
            @NewActionID bigint,@HousingActionID bigint,@Marker nvarchar(400),
            @ActionType int,@InAssignPeriod int;

        DECLARE ActionCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT action27.buildingActionID,CONVERT(bigint,action27.generalNo_FK),
                   targetResident.residentInfoID,periodMap.AssignPeriodID,
                   (SELECT COUNT(*) FROM #ValidAssign noHouse
                    WHERE noHouse.BuildingActionID_FK=action27.buildingActionID
                      AND noHouse.BuildingAssignTypeID_FK=1
                      AND UPPER(LTRIM(RTRIM(ISNULL(noHouse.BuildingNo,N''))))=N'NO_HOUSE')
            FROM KFMC.Housing.BuildingAction action27
            JOIN KFMC.Housing.BuildingAction waitingRoot
              ON waitingRoot.buildingActionID=action27.buildingActionParentID
             AND waitingRoot.buildingActionTypeID_FK=1
             AND waitingRoot.buildingActionActive=1
            JOIN Housing.BuildingAction migratedRoot
              ON migratedRoot.buildingActionID=waitingRoot.buildingActionID
             AND migratedRoot.buildingActionTypeID_FK=1
             AND migratedRoot.buildingActionActive=1
            JOIN Housing.BuildingAction migratedAction27
              ON migratedAction27.buildingActionID=action27.buildingActionID
             AND migratedAction27.buildingActionTypeID_FK=27
            JOIN Housing.ResidentInfo targetResident
              ON targetResident.residentInfoID=CONVERT(bigint,
                 (SELECT TOP(1) sourceResident.residentInfoID
                  FROM KFMC.Housing.ResidentInfo sourceResident
                  WHERE sourceResident.generalNo=action27.generalNo_FK))
            JOIN #PeriodMap periodMap
              ON periodMap.WaitingClassID=
                 COALESCE(action27.buildingActionExtraType1,waitingRoot.buildingActionExtraType1)
            WHERE action27.buildingActionTypeID_FK=27
            ORDER BY action27.buildingActionID;

        OPEN ActionCursor;
        FETCH NEXT FROM ActionCursor
            INTO @Action27ID,@GeneralNo,@ResidentInfoID,@PeriodID,@NoHouseCount;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @CurrentParentID=@Action27ID;

            /* Two virtual allocations preserve only the final legal result: action 42. */
            IF @NoHouseCount>=2
            BEGIN
                SELECT TOP(1)
                    @OfferID=virtualOffer.BuildingAssignID,
                    @OfferEntryDate=COALESCE(virtualReject.entryDate,virtualOffer.entryDate),
                    @OfferEntryData=COALESCE(virtualReject.entryData,virtualOffer.entryData),
                    @OfferHostName=COALESCE(virtualReject.hostName,virtualOffer.hostName)
                FROM #ValidAssign virtualOffer
                OUTER APPLY
                (
                    SELECT TOP(1) rejected.*
                    FROM #ValidAssign rejected
                    WHERE rejected.BuildingAssignTypeID_FK=2
                      AND rejected.ParentBuildingAssignID=virtualOffer.BuildingAssignID
                    ORDER BY rejected.BuildingAssignID DESC
                ) virtualReject
                WHERE virtualOffer.BuildingActionID_FK=@Action27ID
                  AND virtualOffer.BuildingAssignTypeID_FK=1
                  AND UPPER(LTRIM(RTRIM(ISNULL(virtualOffer.BuildingNo,N''))))=N'NO_HOUSE'
                ORDER BY virtualOffer.BuildingAssignID DESC;

                SET @Marker=CONCAT(N'MoveData:NoHouse2:',@Action27ID);
                SELECT @NewActionID=buildingActionID
                FROM Housing.BuildingAction WHERE buildingActionExtraText4=@Marker;

                IF @NewActionID IS NULL
                BEGIN
                    INSERT Housing.BuildingAction
                    (
                        buildingActionTypeID_FK,residentInfoID_FK,generalNo_FK,
                        buildingActionActive,buildingActionParentID,AssignPeriodID_FK,
                        InAssignPeriod,buildingActionNote,buildingActionExtraText4,buildingActionExtraText5,
                        IdaraId_FK,entryDate,entryData,hostName
                    )
                    VALUES
                    (
                        42,@ResidentInfoID,@GeneralNo,1,@Action27ID,@PeriodID,0,
                        N'Eligibility cancelled after two legacy virtual allocations (No_house)',
                        @Marker,N'MIGRATION_GENERATED',@IdaraId,@OfferEntryDate,
                        MoveData.fn_MapEntryData(@OfferEntryData),
                        MoveData.fn_MapHostName(@OfferHostName,@OfferEntryData)
                    );
                    SET @NewActionID=SCOPE_IDENTITY();
                    SET @AllocationActionsInserted+=1;
                    SET @NoHouseCancellations+=1;
                END;
            END
            ELSE
            BEGIN
                DECLARE OfferCursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        realOffer.BuildingAssignID,
                        ROW_NUMBER() OVER(ORDER BY realOffer.BuildingAssignID),
                        realOffer.BuildingNo,sourceBuilding.buildingDetailsID,
                        realOffer.MeterReadValue,realOffer.entryDate,realOffer.entryData,realOffer.hostName,
                        rejected.BuildingAssignID,rejected.entryDate,rejected.entryData,rejected.hostName
                    FROM #ValidAssign realOffer
                    LEFT JOIN KFMC.Housing.BuildingDetails sourceBuilding
                      ON LTRIM(RTRIM(sourceBuilding.buildingDetailsNo))=LTRIM(RTRIM(realOffer.BuildingNo))
                    OUTER APPLY
                    (
                        SELECT TOP(1) rejectRow.*
                        FROM #ValidAssign rejectRow
                        WHERE rejectRow.BuildingAssignTypeID_FK=2
                          AND rejectRow.ParentBuildingAssignID=realOffer.BuildingAssignID
                        ORDER BY rejectRow.BuildingAssignID
                    ) rejected
                    WHERE realOffer.BuildingActionID_FK=@Action27ID
                      AND realOffer.BuildingAssignTypeID_FK=1
                      AND UPPER(LTRIM(RTRIM(ISNULL(realOffer.BuildingNo,N''))))<>N'NO_HOUSE'
                    ORDER BY realOffer.BuildingAssignID;

                OPEN OfferCursor;
                FETCH NEXT FROM OfferCursor INTO
                    @OfferID,@OfferNo,@BuildingNo,@BuildingID,@MeterReadValue,
                    @OfferEntryDate,@OfferEntryData,@OfferHostName,
                    @RejectionID,@RejectionEntryDate,@RejectionEntryData,@RejectionHostName;
                WHILE @@FETCH_STATUS=0
                BEGIN
                    SET @ActionType=CASE WHEN @OfferNo=1 THEN 38 ELSE 40 END;
                    SET @Marker=CONCAT(N'MoveData:Assign:',@OfferID,N':',@ActionType);
                    SET @NewActionID=NULL;
                    SELECT @NewActionID=buildingActionID
                    FROM Housing.BuildingAction WHERE buildingActionExtraText4=@Marker;

                    IF @NewActionID IS NULL
                    BEGIN
                        INSERT Housing.BuildingAction
                        (
                            buildingActionTypeID_FK,residentInfoID_FK,generalNo_FK,
                            buildingDetailsID_FK,buildingDetailsNo,buildingActionActive,
                            buildingActionParentID,AssignPeriodID_FK,InAssignPeriod,
                            buildingActionExtraText4,buildingActionExtraText5,IdaraId_FK,entryDate,entryData,hostName
                        )
                        VALUES
                        (
                            @ActionType,@ResidentInfoID,@GeneralNo,@BuildingID,@BuildingNo,1,
                            @CurrentParentID,@PeriodID,0,@Marker,N'MIGRATION_GENERATED',@IdaraId,@OfferEntryDate,
                            MoveData.fn_MapEntryData(@OfferEntryData),
                            MoveData.fn_MapHostName(@OfferHostName,@OfferEntryData)
                        );
                        SET @NewActionID=SCOPE_IDENTITY();
                        SET @AllocationActionsInserted+=1;
                    END;
                    SET @CurrentParentID=@NewActionID;

                    IF @RejectionID IS NOT NULL
                    BEGIN
                        SET @ActionType=CASE WHEN @OfferNo=1 THEN 39 ELSE 42 END;
                        SET @Marker=CONCAT(N'MoveData:Reject:',@RejectionID,N':',@ActionType);
                        SET @NewActionID=NULL;
                        SELECT @NewActionID=buildingActionID
                        FROM Housing.BuildingAction WHERE buildingActionExtraText4=@Marker;
                        IF @NewActionID IS NULL
                        BEGIN
                            INSERT Housing.BuildingAction
                            (
                                buildingActionTypeID_FK,residentInfoID_FK,generalNo_FK,
                                buildingDetailsID_FK,buildingDetailsNo,buildingActionActive,
                                buildingActionParentID,AssignPeriodID_FK,InAssignPeriod,
                                buildingActionExtraText4,buildingActionExtraText5,IdaraId_FK,entryDate,entryData,hostName
                            )
                            VALUES
                            (
                                @ActionType,@ResidentInfoID,@GeneralNo,@BuildingID,@BuildingNo,1,
                                @CurrentParentID,@PeriodID,0,@Marker,N'MIGRATION_GENERATED',@IdaraId,@RejectionEntryDate,
                                MoveData.fn_MapEntryData(@RejectionEntryData),
                                MoveData.fn_MapHostName(@RejectionHostName,@RejectionEntryData)
                            );
                            SET @NewActionID=SCOPE_IDENTITY();
                            SET @AllocationActionsInserted+=1;
                        END;
                        SET @CurrentParentID=@NewActionID;
                    END
                    ELSE IF @MeterReadValue IS NOT NULL
                    BEGIN
                        /* Accepted historical allocation: 45 -> 46 -> 47. */
                        DECLARE @StageType int;
                        DECLARE StageCursor CURSOR LOCAL FAST_FORWARD FOR
                            SELECT StageType FROM (VALUES(45),(46),(47)) stage(StageType) ORDER BY StageType;
                        OPEN StageCursor;
                        FETCH NEXT FROM StageCursor INTO @StageType;
                        WHILE @@FETCH_STATUS=0
                        BEGIN
                            SET @Marker=CONCAT(N'MoveData:Accept:',@OfferID,N':',@StageType);
                            SET @NewActionID=NULL;
                            SELECT @NewActionID=buildingActionID
                            FROM Housing.BuildingAction WHERE buildingActionExtraText4=@Marker;
                            IF @NewActionID IS NULL
                            BEGIN
                                INSERT Housing.BuildingAction
                                (
                                    buildingActionTypeID_FK,residentInfoID_FK,generalNo_FK,
                                    buildingDetailsID_FK,buildingDetailsNo,buildingActionActive,
                                    buildingActionParentID,AssignPeriodID_FK,InAssignPeriod,
                                    buildingActionExtraInt1,buildingActionExtraText4,buildingActionExtraText5,
                                    IdaraId_FK,entryDate,entryData,hostName
                                )
                                VALUES
                                (
                                    @StageType,@ResidentInfoID,@GeneralNo,@BuildingID,@BuildingNo,1,
                                    @CurrentParentID,@PeriodID,0,
                                    CASE WHEN @StageType IN(46,47) THEN @MeterReadValue END,
                                    @Marker,N'MIGRATION_GENERATED',@IdaraId,@OfferEntryDate,
                                    MoveData.fn_MapEntryData(@OfferEntryData),
                                    MoveData.fn_MapHostName(@OfferHostName,@OfferEntryData)
                                );
                                SET @NewActionID=SCOPE_IDENTITY();
                                SET @AllocationActionsInserted+=1;
                            END;
                            SET @CurrentParentID=@NewActionID;
                            FETCH NEXT FROM StageCursor INTO @StageType;
                        END;
                        CLOSE StageCursor;
                        DEALLOCATE StageCursor;

                        SELECT TOP(1) @HousingActionID=targetHousing.buildingActionID
                        FROM Housing.BuildingAction targetHousing
                        WHERE targetHousing.generalNo_FK=@GeneralNo
                          AND targetHousing.buildingActionTypeID_FK=2
                          AND targetHousing.buildingActionID>@Action27ID
                          AND UPPER(REPLACE(LTRIM(RTRIM(ISNULL(targetHousing.buildingDetailsNo,N''))),N' ',N''))
                              =UPPER(REPLACE(LTRIM(RTRIM(ISNULL(@BuildingNo,N''))),N' ',N''))
                        ORDER BY targetHousing.buildingActionID;

                        IF @HousingActionID IS NOT NULL
                        BEGIN
                            UPDATE Housing.BuildingAction
                            SET buildingActionParentID=@CurrentParentID
                            WHERE buildingActionID=@HousingActionID
                              AND ISNULL(buildingActionParentID,-1)<>@CurrentParentID;
                            SET @HousingParentsUpdated+=@@ROWCOUNT;
                        END;
                    END;

                    SET @RejectionID=NULL;
                    SET @HousingActionID=NULL;
                    FETCH NEXT FROM OfferCursor INTO
                        @OfferID,@OfferNo,@BuildingNo,@BuildingID,@MeterReadValue,
                        @OfferEntryDate,@OfferEntryData,@OfferHostName,
                        @RejectionID,@RejectionEntryDate,@RejectionEntryData,@RejectionHostName;
                END;
                CLOSE OfferCursor;
                DEALLOCATE OfferCursor;
            END;

            SET @NewActionID=NULL;
            FETCH NEXT FROM ActionCursor
                INTO @Action27ID,@GeneralNo,@ResidentInfoID,@PeriodID,@NoHouseCount;
        END;
        CLOSE ActionCursor;
        DEALLOCATE ActionCursor;

        /* Letter housing: accepted/not rejected pending -> 45; housed remains 7 -> 2. */
        DECLARE LetterCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                letterRoot.buildingActionID,CONVERT(bigint,letterRoot.generalNo_FK),
                targetResident.residentInfoID,realOffer.BuildingAssignID,
                realOffer.BuildingNo,sourceBuilding.buildingDetailsID,realOffer.entryDate,
                realOffer.entryData,realOffer.hostName
            FROM KFMC.Housing.BuildingAction oldAction27
            JOIN KFMC.Housing.BuildingAction letterRoot
              ON letterRoot.buildingActionID=oldAction27.buildingActionParentID
             AND letterRoot.buildingActionTypeID_FK=7
             AND letterRoot.buildingActionActive=1
            JOIN Housing.BuildingAction migratedLetterRoot
              ON migratedLetterRoot.buildingActionID=letterRoot.buildingActionID
             AND migratedLetterRoot.buildingActionTypeID_FK=7
             AND migratedLetterRoot.buildingActionActive=1
            JOIN Housing.ResidentInfo targetResident
              ON targetResident.residentInfoID=CONVERT(bigint,
                 (SELECT TOP(1) sourceResident.residentInfoID
                  FROM KFMC.Housing.ResidentInfo sourceResident
                  WHERE sourceResident.generalNo=letterRoot.generalNo_FK))
            CROSS APPLY
            (
                SELECT TOP(1) offer.*
                FROM #ValidAssign offer
                WHERE offer.BuildingActionID_FK=oldAction27.buildingActionID
                  AND offer.BuildingAssignTypeID_FK=1
                  AND UPPER(LTRIM(RTRIM(ISNULL(offer.BuildingNo,N''))))<>N'NO_HOUSE'
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM #ValidAssign rejectRow
                      WHERE rejectRow.BuildingAssignTypeID_FK=2
                        AND rejectRow.ParentBuildingAssignID=offer.BuildingAssignID
                  )
                ORDER BY offer.BuildingAssignID DESC
            ) realOffer
            LEFT JOIN KFMC.Housing.BuildingDetails sourceBuilding
              ON LTRIM(RTRIM(sourceBuilding.buildingDetailsNo))=LTRIM(RTRIM(realOffer.BuildingNo))
            WHERE NOT EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction housed
                WHERE housed.generalNo_FK=CONVERT(bigint,letterRoot.generalNo_FK)
                  AND housed.buildingActionTypeID_FK=2
                  AND housed.buildingActionID>oldAction27.buildingActionID
                  AND UPPER(REPLACE(LTRIM(RTRIM(ISNULL(housed.buildingDetailsNo,N''))),N' ',N''))
                      =UPPER(REPLACE(LTRIM(RTRIM(ISNULL(realOffer.BuildingNo,N''))),N' ',N''))
            );

        OPEN LetterCursor;
        FETCH NEXT FROM LetterCursor INTO
            @CurrentParentID,@GeneralNo,@ResidentInfoID,@OfferID,@BuildingNo,@BuildingID,
            @OfferEntryDate,@OfferEntryData,@OfferHostName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Marker=CONCAT(N'MoveData:Letter45:',@OfferID);
            IF NOT EXISTS(SELECT 1 FROM Housing.BuildingAction WHERE buildingActionExtraText4=@Marker)
            BEGIN
                INSERT Housing.BuildingAction
                (
                    buildingActionTypeID_FK,residentInfoID_FK,generalNo_FK,
                    buildingDetailsID_FK,buildingDetailsNo,buildingActionActive,
                    buildingActionParentID,AssignPeriodID_FK,InAssignPeriod,
                    buildingActionExtraText4,buildingActionExtraText5,IdaraId_FK,entryDate,entryData,hostName
                )
                VALUES
                (
                    45,@ResidentInfoID,@GeneralNo,@BuildingID,@BuildingNo,1,
                    @CurrentParentID,NULL,NULL,@Marker,N'MIGRATION_GENERATED',@IdaraId,@OfferEntryDate,
                    MoveData.fn_MapEntryData(@OfferEntryData),
                    MoveData.fn_MapHostName(@OfferHostName,@OfferEntryData)
                );
                SET @LetterActionsInserted+=1;
            END;

            FETCH NEXT FROM LetterCursor INTO
                @CurrentParentID,@GeneralNo,@ResidentInfoID,@OfferID,@BuildingNo,@BuildingID,
                @OfferEntryDate,@OfferEntryData,@OfferHostName;
        END;
        CLOSE LetterCursor;
        DEALLOCATE LetterCursor;

        SELECT
            @RollbackAfterTest RollbackAfterTest,
            @PeriodsInserted AssignPeriodsInserted,
            @AllocationActionsInserted AllocationActionsInserted,
            @LetterActionsInserted LetterActionsInserted,
            @HousingParentsUpdated HousingParentsUpdated,
            @NoHouseCancellations NoHouseCancellations,
            (SELECT COUNT_BIG(*) FROM Housing.AssignPeriod
             WHERE IdaraId_FK=@IdaraId
               AND AssignPeriodDescrption LIKE N'Legacy allocation migration - WaitingClass %') HistoricalAssignPeriods,
            (SELECT COUNT_BIG(*) FROM Housing.BuildingAction
             WHERE buildingActionExtraText4 LIKE N'MoveData:%') GeneratedAssignmentActions;

        IF @RollbackAfterTest=1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','StageCursor')>=-1
        BEGIN
            IF CURSOR_STATUS('local','StageCursor')>=0 CLOSE StageCursor;
            DEALLOCATE StageCursor;
        END;
        IF CURSOR_STATUS('local','OfferCursor')>=-1
        BEGIN
            IF CURSOR_STATUS('local','OfferCursor')>=0 CLOSE OfferCursor;
            DEALLOCATE OfferCursor;
        END;
        IF CURSOR_STATUS('local','ActionCursor')>=-1
        BEGIN
            IF CURSOR_STATUS('local','ActionCursor')>=0 CLOSE ActionCursor;
            DEALLOCATE ActionCursor;
        END;
        IF CURSOR_STATUS('local','LetterCursor')>=-1
        BEGIN
            IF CURSOR_STATUS('local','LetterCursor')>=0 CLOSE LetterCursor;
            DEALLOCATE LetterCursor;
        END;
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;