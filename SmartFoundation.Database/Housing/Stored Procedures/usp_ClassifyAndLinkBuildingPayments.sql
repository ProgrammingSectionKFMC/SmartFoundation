
/*
   يعرض الاقتراحات عند @ApplyChanges=0، ويطبقها عند @ApplyChanges=1.
   مصدر التاريخ: paymentDate، ثم شهر/سنة المسير إذا كانت سنة ميلادية.
*/
CREATE   PROCEDURE [Housing].[usp_ClassifyAndLinkBuildingPayments]
    @PaymentID bigint = NULL,
    @DeductListID int = NULL,
    @ApplyChanges bit = 0,
    @ShowDetails bit = 0,
    @ReturnResults bit = 1,
    @ChangedBy nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ApplyChanges NOT IN (0,1)
        THROW 58100, N'ApplyChanges must be 0 or 1.', 1;

    CREATE TABLE #Proposal
    (
        paymentID bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NULL,
        effectivePaymentDate date NULL,
        effectivePaymentEndDate date NULL,
        firstOccupancyDate date NULL,
        candidateBuildingCount int NOT NULL,
        proposedBuildingDetailsID bigint NULL,
        oldStatusID int NULL,
        proposedStatusID int NOT NULL,
        proposalReason nvarchar(1000) NOT NULL
    );

    CREATE TABLE #ResidentMatch
    (
        generalNo bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NOT NULL
    );

    ;WITH RankedDetails AS
    (
        SELECT detailsRow.[generalNo_FK],detailsRow.[residentInfoID_FK],
               ROW_NUMBER() OVER(PARTITION BY detailsRow.[generalNo_FK]
                 ORDER BY detailsRow.[residentDetailsActive] DESC,detailsRow.[residentDetailsID] DESC) rowNumber
        FROM [Housing].[ResidentDetails] detailsRow
        WHERE detailsRow.[generalNo_FK] IS NOT NULL AND detailsRow.[residentInfoID_FK] IS NOT NULL
    )
    INSERT INTO #ResidentMatch(generalNo,residentInfoID)
    SELECT [generalNo_FK],[residentInfoID_FK] FROM RankedDetails WHERE rowNumber=1;

    ;WITH PaymentBase AS
    (
        SELECT
            paymentRow.[paymentID],
            paymentRow.[buildingPaymentLinkStatusID_FK] oldStatusID,
            COALESCE(paymentRow.[residentInfoID_FK], residentMatch.[residentInfoID]) residentInfoID,
            /* فترة المسير الميلادية أدق من تاريخ رفع/اعتماد المسير. */
            CASE
                WHEN deductRow.[issueYear] BETWEEN 1900 AND 9999
                 AND deductRow.[issueMonth] BETWEEN 1 AND 12
                THEN TRY_CONVERT(date,
                     CONCAT(deductRow.[issueYear], N'-',
                            RIGHT(N'0' + CONVERT(nvarchar(2), deductRow.[issueMonth]), 2),
                            N'-01'))
                ELSE CONVERT(date, deductRow.[paymentDate])
            END effectivePaymentDate,
            CASE
                WHEN deductRow.[issueYear] BETWEEN 1900 AND 9999
                 AND deductRow.[issueMonth] BETWEEN 1 AND 12
                THEN EOMONTH(TRY_CONVERT(date,
                     CONCAT(deductRow.[issueYear], N'-',
                            RIGHT(N'0' + CONVERT(nvarchar(2), deductRow.[issueMonth]), 2),
                            N'-01')))
                ELSE CONVERT(date, deductRow.[paymentDate])
            END effectivePaymentEndDate
        FROM [Housing].[BuildingPayment] paymentRow
        LEFT JOIN [Housing].[DeductList] deductRow
          ON deductRow.[deductListID] = paymentRow.[deductListID_FK]
        LEFT JOIN #ResidentMatch residentMatch
          ON residentMatch.[generalNo] = paymentRow.[generalNo_FK]
        WHERE (@PaymentID IS NULL OR paymentRow.[paymentID] = @PaymentID)
          AND (@DeductListID IS NULL OR paymentRow.[deductListID_FK] = @DeductListID)
          AND paymentRow.[buildingPayementActive] = 1
          AND (paymentRow.[buildingPaymentLinkStatusID_FK] IS NULL
               OR paymentRow.[buildingPaymentLinkStatusID_FK] IN (2,3,4))
    ),
    OccupancyRoots AS
    (
        SELECT
            actionRow.[buildingActionID] rootActionID,
            actionRow.[residentInfoID_FK],
            actionRow.[buildingDetailsID_FK],
            CONVERT(date, actionRow.[buildingActionDate]) occupancyDate
        FROM [Housing].[BuildingAction] actionRow
        WHERE actionRow.[buildingActionTypeID_FK] = 2
          AND actionRow.[buildingActionActive] = 1
          AND actionRow.[residentInfoID_FK] IS NOT NULL
          AND actionRow.[buildingDetailsID_FK] IS NOT NULL
          AND actionRow.[buildingActionDate] IS NOT NULL
    ),
    ActionTree AS
    (
        /* البداية من حركة التسكين نفسها. */
        SELECT rootRow.[rootActionID], actionRow.[buildingActionID],
               actionRow.[buildingActionTypeID_FK], actionRow.[buildingActionDate], 0 treeLevel
        FROM OccupancyRoots rootRow
        JOIN [Housing].[BuildingAction] actionRow
          ON actionRow.[buildingActionID] = rootRow.[rootActionID]

        UNION ALL

        /* تتبع كل الأبناء الفعالين حتى الإخلاء النهائي، ولو كان حفيدا للتسكين. */
        SELECT treeRow.[rootActionID], childRow.[buildingActionID],
               childRow.[buildingActionTypeID_FK], childRow.[buildingActionDate],
               treeRow.[treeLevel] + 1
        FROM ActionTree treeRow
        JOIN [Housing].[BuildingAction] childRow
          ON childRow.[buildingActionParentID] = treeRow.[buildingActionID]
         AND childRow.[buildingActionActive] = 1
        WHERE treeRow.[treeLevel] < 100
    ),
   ExitDates AS
(
    SELECT
        [rootActionID],

        COALESCE(
            -- التاريخ المعتمد: الاستلام الفعلي للمنزل
            MIN(CASE
                WHEN [buildingActionTypeID_FK] = 54
                THEN CONVERT(date, [buildingActionDate])
            END),

            -- بديل للسجلات التاريخية التي لا يوجد لها إجراء 54
            MIN(CASE
                WHEN [buildingActionTypeID_FK] = 3
                THEN CONVERT(date, [buildingActionDate])
            END)
        ) AS exitDate

    FROM ActionTree
    WHERE [buildingActionTypeID_FK] IN (54, 3)
    GROUP BY [rootActionID]
),
    OccupancyPeriods AS
    (
        SELECT rootRow.[residentInfoID_FK], rootRow.[buildingDetailsID_FK],
               rootRow.[occupancyDate], exitRow.[exitDate]
        FROM OccupancyRoots rootRow
        LEFT JOIN ExitDates exitRow ON exitRow.[rootActionID] = rootRow.[rootActionID]
    ),
    CandidateBuildings AS
    (
        SELECT DISTINCT
            paymentBase.[paymentID], occupancy.[buildingDetailsID_FK]
        FROM PaymentBase paymentBase
        JOIN OccupancyPeriods occupancy
         ON occupancy.[residentInfoID_FK] = paymentBase.[residentInfoID]
         /* A Gregorian batch represents its whole month. Any overlap with occupancy is eligible. */
         AND paymentBase.[effectivePaymentEndDate] >= occupancy.[occupancyDate]
         AND paymentBase.[effectivePaymentDate] <= ISNULL(occupancy.[exitDate], CONVERT(date, GETDATE()))
    ),
    CandidateSummary AS
    (
        SELECT [paymentID], COUNT(*) candidateCount,
               MIN([buildingDetailsID_FK]) proposedBuildingDetailsID
        FROM CandidateBuildings
        GROUP BY [paymentID]
    ),
    FirstOccupancy AS
    (
        SELECT [residentInfoID_FK], MIN([occupancyDate]) firstOccupancyDate
        FROM OccupancyPeriods
        GROUP BY [residentInfoID_FK]
    )
    INSERT INTO #Proposal
    (
        paymentID, residentInfoID, effectivePaymentDate, effectivePaymentEndDate, firstOccupancyDate,
        candidateBuildingCount, proposedBuildingDetailsID,
        oldStatusID, proposedStatusID, proposalReason
    )
    SELECT
        paymentBase.[paymentID], paymentBase.[residentInfoID],
        paymentBase.[effectivePaymentDate], paymentBase.[effectivePaymentEndDate],
        firstOccupancy.[firstOccupancyDate],
        ISNULL(candidateSummary.[candidateCount], 0),
        CASE WHEN candidateSummary.[candidateCount] = 1
             THEN candidateSummary.[proposedBuildingDetailsID] END,
        paymentBase.[oldStatusID],
        CASE
            WHEN paymentBase.[residentInfoID] IS NULL THEN 3
            WHEN paymentBase.[effectivePaymentEndDate] IS NOT NULL
             AND firstOccupancy.[firstOccupancyDate] IS NOT NULL
             AND paymentBase.[effectivePaymentEndDate] < firstOccupancy.[firstOccupancyDate] THEN 4
            WHEN candidateSummary.[candidateCount] = 1 THEN 1
            ELSE 2
        END,
        CASE
            WHEN paymentBase.[residentInfoID] IS NULL
                THEN N'لم يتم العثور على ملف المستفيد.'
            WHEN paymentBase.[effectivePaymentDate] IS NULL
                THEN N'تعذر تحديد تاريخ ميلادي موثوق للسداد.'
            WHEN firstOccupancy.[firstOccupancyDate] IS NULL
                THEN N'المستفيد معروف ولكن لا توجد له فترة سكن.'
            WHEN paymentBase.[effectivePaymentEndDate] < firstOccupancy.[firstOccupancyDate]
                THEN N'السداد يسبق أول فترة سكن معروفة.'
            WHEN candidateSummary.[candidateCount] = 1
                THEN N'تم تحديد مبنى واحد من فترة السكن في تاريخ السداد.'
            WHEN candidateSummary.[candidateCount] > 1
                THEN N'تاريخ السداد يقع داخل أكثر من فترة سكن؛ بقي رصيدا عاما.'
            ELSE N'السداد بعد أول سكن ولكنه خارج فترة سكن محددة؛ بقي رصيدا عاما.'
        END
    FROM PaymentBase paymentBase
    LEFT JOIN CandidateSummary candidateSummary
      ON candidateSummary.[paymentID] = paymentBase.[paymentID]
    LEFT JOIN FirstOccupancy firstOccupancy
      ON firstOccupancy.[residentInfoID_FK] = paymentBase.[residentInfoID];

    IF @ReturnResults = 1
    BEGIN
        SELECT proposedStatusID, COUNT_BIG(*) paymentCount
        FROM #Proposal
        GROUP BY proposedStatusID
        ORDER BY proposedStatusID;

        IF @ShowDetails = 1
        BEGIN
            SELECT * FROM #Proposal
            ORDER BY proposedStatusID, paymentID;
        END;
    END;

    IF @ApplyChanges = 0 RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE paymentRow
        SET paymentRow.[residentInfoID_FK] = proposal.[residentInfoID],
            paymentRow.[buildingDetailsID_FK] =
                CASE WHEN proposal.[proposedStatusID] = 1
                     THEN CONVERT(nvarchar(400), proposal.[proposedBuildingDetailsID])
                     ELSE NULL END,
            paymentRow.[buildingPaymentLinkStatusID_FK] = proposal.[proposedStatusID],
            paymentRow.[paymentLinkNote] = proposal.[proposalReason]
        OUTPUT
            inserted.[paymentID], deleted.[buildingPaymentLinkStatusID_FK],
            inserted.[buildingPaymentLinkStatusID_FK], deleted.[buildingDetailsID_FK],
            inserted.[buildingDetailsID_FK], N'AUTO_TEMPORAL',
            inserted.[paymentLinkNote], @ChangedBy, GETDATE()
        INTO [Housing].[BuildingPaymentLinkAudit]
        (
            paymentID_FK, oldLinkStatusID, newLinkStatusID,
            oldBuildingDetailsID, newBuildingDetailsID,
            linkMethod, linkNote, changedBy, changedDate
        )
        FROM [Housing].[BuildingPayment] paymentRow
        JOIN #Proposal proposal ON proposal.[paymentID] = paymentRow.[paymentID]
        WHERE ISNULL(paymentRow.[residentInfoID_FK], -1) <> ISNULL(proposal.[residentInfoID], -1)
           OR ISNULL(paymentRow.[buildingPaymentLinkStatusID_FK], -1) <> proposal.[proposedStatusID]
           OR ISNULL(NULLIF(LTRIM(RTRIM(paymentRow.[buildingDetailsID_FK])), N''), N'-1') <>
              ISNULL(CASE WHEN proposal.[proposedStatusID] = 1
                          THEN CONVERT(nvarchar(400), proposal.[proposedBuildingDetailsID]) END, N'-1');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

