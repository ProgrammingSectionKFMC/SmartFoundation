CREATE   PROCEDURE [Housing].[usp_ClassifyAndLinkBuildingPayments_V2]
    @PaymentID bigint = NULL,
    @DeductListID int = NULL,
    @ApplyChanges bit = 0,
    @ShowDetails bit = 0,
    @ReturnResults bit = 1,
    @ChangedBy nvarchar(100) = NULL,
@BillChargeTypeID_FK int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ApplyChanges NOT IN (0,1)
        THROW 58100, N'ApplyChanges must be 0 or 1.', 1;

    CREATE TABLE #ResidentMatch
    (
        generalNo bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NOT NULL
    );

    ;WITH RankedDetails AS
    (
        SELECT detailsRow.generalNo_FK,detailsRow.residentInfoID_FK,
               ROW_NUMBER() OVER(PARTITION BY detailsRow.generalNo_FK
                 ORDER BY detailsRow.residentDetailsActive DESC,detailsRow.residentDetailsID DESC) rowNumber
        FROM Housing.ResidentDetails detailsRow
        WHERE detailsRow.generalNo_FK IS NOT NULL AND detailsRow.residentInfoID_FK IS NOT NULL
    )
    INSERT #ResidentMatch(generalNo,residentInfoID)
    SELECT generalNo_FK,residentInfoID_FK FROM RankedDetails WHERE rowNumber=1;

    CREATE TABLE #PaymentBase
(
    paymentID bigint NOT NULL PRIMARY KEY,
    oldStatusID int NULL,
    residentInfoID bigint NULL,
    effectivePaymentDate date NULL,
    effectivePaymentEndDate date NULL,
    isHijriPeriod bit NOT NULL
);

    CREATE TABLE #HijriPeriodMap
(
      issueYear  int NOT NULL
    , issueMonth int NOT NULL
    , PeriodFrom date NOT NULL
    , PeriodTo   date NOT NULL
    , PRIMARY KEY (issueYear, issueMonth)
);

INSERT INTO #HijriPeriodMap
(
      issueYear
    , issueMonth
    , PeriodFrom
    , PeriodTo
)
SELECT
      g.yearH
    , g.monthH
    , MIN(CONVERT(date, g.gregorianDate))
    , MAX(CONVERT(date, g.gregorianDate))
FROM dbo._GregorianHijriDate g
WHERE g.yearH BETWEEN 1300 AND 1600
  AND g.monthH BETWEEN 1 AND 12
GROUP BY
      g.yearH
    , g.monthH;


INSERT #PaymentBase
(
      paymentID
    , oldStatusID
    , residentInfoID
    , effectivePaymentDate
    , effectivePaymentEndDate
    , isHijriPeriod
)
SELECT
      paymentRow.paymentID
    , paymentRow.buildingPaymentLinkStatusID_FK
    , COALESCE
      (
          paymentRow.residentInfoID_FK,
          residentMatch.residentInfoID
      )

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN hijri.PeriodFrom

          WHEN deductRow.issueYear BETWEEN 1900 AND 9999
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN TRY_CONVERT
                   (
                       date,
                       CONCAT
                       (
                           deductRow.issueYear,
                           N'-',
                           RIGHT
                           (
                               N'0'
                               + CONVERT
                                 (
                                     nvarchar(2),
                                     deductRow.issueMonth
                                 ),
                               2
                           ),
                           N'-01'
                       )
                   )

          ELSE CONVERT(date, deductRow.paymentDate)
      END

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN hijri.PeriodTo

          WHEN deductRow.issueYear BETWEEN 1900 AND 9999
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN EOMONTH
                   (
                       TRY_CONVERT
                       (
                           date,
                           CONCAT
                           (
                               deductRow.issueYear,
                               N'-',
                               RIGHT
                               (
                                   N'0'
                                   + CONVERT
                                     (
                                         nvarchar(2),
                                         deductRow.issueMonth
                                     ),
                                   2
                               ),
                               N'-01'
                           )
                       )
                   )

          ELSE CONVERT(date, deductRow.paymentDate)
      END

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN CONVERT(bit, 1)

          ELSE CONVERT(bit, 0)
      END

FROM Housing.BuildingPayment paymentRow

LEFT JOIN Housing.DeductList deductRow
    ON deductRow.deductListID =
       paymentRow.deductListID_FK

LEFT JOIN #ResidentMatch residentMatch
    ON residentMatch.generalNo =
       paymentRow.generalNo_FK

LEFT JOIN #HijriPeriodMap hijri
    ON hijri.issueYear = deductRow.issueYear
   AND hijri.issueMonth = deductRow.issueMonth

WHERE
      (@PaymentID IS NULL OR paymentRow.paymentID = @PaymentID)

  AND (@DeductListID IS NULL
       OR paymentRow.deductListID_FK = @DeductListID)

  AND paymentRow.buildingPayementActive = 1

  AND
  (
      @BillChargeTypeID_FK IS NULL
      OR paymentRow.BillChargeTypeID_FK =
         @BillChargeTypeID_FK
  )

  AND
(
       paymentRow.buildingPaymentLinkStatusID_FK IS NULL

    OR paymentRow.buildingPaymentLinkStatusID_FK IN (2,3,4)

    OR
    (
        paymentRow.buildingPaymentLinkStatusID_FK = 1
        AND deductRow.issueYear BETWEEN 1300 AND 1600
        AND deductRow.issueMonth BETWEEN 1 AND 12
    )
)

OPTION(RECOMPILE);

    CREATE INDEX IX_PaymentBase_ResidentDates
      ON #PaymentBase(residentInfoID,effectivePaymentDate,effectivePaymentEndDate) INCLUDE(paymentID,oldStatusID);

    CREATE TABLE #OccupancyRoots
    (
        rootActionID bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        occupancyDate date NOT NULL
    );

    INSERT #OccupancyRoots(rootActionID,residentInfoID,buildingDetailsID,occupancyDate)
    SELECT actionRow.buildingActionID,actionRow.residentInfoID_FK,actionRow.buildingDetailsID_FK,
           CONVERT(date,actionRow.buildingActionDate)
    FROM Housing.BuildingAction actionRow
    WHERE actionRow.buildingActionTypeID_FK=2 AND actionRow.buildingActionActive=1
      AND actionRow.residentInfoID_FK IS NOT NULL AND actionRow.buildingDetailsID_FK IS NOT NULL
      AND actionRow.buildingActionDate IS NOT NULL;

    CREATE INDEX IX_OccupancyRoots_Resident
      ON #OccupancyRoots(residentInfoID,occupancyDate) INCLUDE(rootActionID,buildingDetailsID);

    CREATE TABLE #ActionTree
    (
        rootActionID bigint NOT NULL,
        buildingActionID bigint NOT NULL,
        buildingActionTypeID int NULL,
        buildingActionDate datetime NULL,
        treeLevel int NOT NULL
    );

    ;WITH ActionTree AS
    (
        SELECT rootRow.rootActionID,actionRow.buildingActionID,
               actionRow.buildingActionTypeID_FK,actionRow.buildingActionDate,0 treeLevel
        FROM #OccupancyRoots rootRow
        JOIN Housing.BuildingAction actionRow ON actionRow.buildingActionID=rootRow.rootActionID
        UNION ALL
        SELECT treeRow.rootActionID,childRow.buildingActionID,
               childRow.buildingActionTypeID_FK,childRow.buildingActionDate,treeRow.treeLevel+1
        FROM ActionTree treeRow
        JOIN Housing.BuildingAction childRow
          ON childRow.buildingActionParentID=treeRow.buildingActionID
         AND childRow.buildingActionActive=1
        WHERE treeRow.treeLevel<100
    )
    INSERT #ActionTree(rootActionID,buildingActionID,buildingActionTypeID,buildingActionDate,treeLevel)
    SELECT rootActionID,buildingActionID,buildingActionTypeID_FK,buildingActionDate,treeLevel
    FROM ActionTree OPTION(MAXRECURSION 0);

    CREATE INDEX IX_ActionTree_RootType
      ON #ActionTree(rootActionID,buildingActionTypeID) INCLUDE(buildingActionDate);

    CREATE TABLE #OccupancyPeriods
    (
        residentInfoID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        occupancyDate date NOT NULL,
        exitDate date NULL,
        rootActionID bigint NOT NULL PRIMARY KEY
    );

    INSERT #OccupancyPeriods(residentInfoID,buildingDetailsID,occupancyDate,exitDate,rootActionID)
    SELECT rootRow.residentInfoID,rootRow.buildingDetailsID,rootRow.occupancyDate,
           MIN(CASE WHEN treeRow.buildingActionTypeID=3 THEN CONVERT(date,treeRow.buildingActionDate) END),
           rootRow.rootActionID
    FROM #OccupancyRoots rootRow
    LEFT JOIN #ActionTree treeRow ON treeRow.rootActionID=rootRow.rootActionID
    GROUP BY rootRow.residentInfoID,rootRow.buildingDetailsID,rootRow.occupancyDate,rootRow.rootActionID;

    CREATE INDEX IX_OccupancyPeriods_ResidentDates
      ON #OccupancyPeriods(residentInfoID,occupancyDate,exitDate) INCLUDE(buildingDetailsID);

    CREATE TABLE #CandidateBuildings
    (
        paymentID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        CONSTRAINT PK_CandidateBuildings PRIMARY KEY(paymentID,buildingDetailsID)
    );

    INSERT #CandidateBuildings(paymentID,buildingDetailsID)
    SELECT DISTINCT paymentBase.paymentID,occupancy.buildingDetailsID
    FROM #PaymentBase paymentBase
JOIN #OccupancyPeriods occupancy
  ON occupancy.residentInfoID =
     paymentBase.residentInfoID

 AND paymentBase.isHijriPeriod = 0

 AND paymentBase.effectivePaymentEndDate >=
     occupancy.occupancyDate

 AND paymentBase.effectivePaymentDate <=
     ISNULL
     (
         occupancy.exitDate,
         CONVERT(date, GETDATE())
     )
     AND paymentBase.effectivePaymentEndDate>=occupancy.occupancyDate
     AND paymentBase.effectivePaymentDate<=ISNULL(occupancy.exitDate,CONVERT(date,GETDATE()));

    CREATE TABLE #CandidateSummary
    (
        paymentID bigint NOT NULL PRIMARY KEY,
        candidateCount int NOT NULL,
        proposedBuildingDetailsID bigint NULL
    );
    INSERT #CandidateSummary
    SELECT paymentID,COUNT(*),MIN(buildingDetailsID) FROM #CandidateBuildings GROUP BY paymentID;

    CREATE TABLE #FirstOccupancy
    (
        residentInfoID bigint NOT NULL PRIMARY KEY,
        firstOccupancyDate date NOT NULL
    );
    INSERT #FirstOccupancy
    SELECT residentInfoID,MIN(occupancyDate) FROM #OccupancyPeriods GROUP BY residentInfoID;

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

    INSERT #Proposal
SELECT
       paymentBase.paymentID,
       paymentBase.residentInfoID,
       paymentBase.effectivePaymentDate,
       paymentBase.effectivePaymentEndDate,
       firstOccupancy.firstOccupancyDate,
       ISNULL(candidateSummary.candidateCount,0),

       CASE
            WHEN paymentBase.isHijriPeriod = 0
             AND candidateSummary.candidateCount = 1
                THEN candidateSummary.proposedBuildingDetailsID
            ELSE NULL
       END,

       paymentBase.oldStatusID,

       CASE
            WHEN paymentBase.residentInfoID IS NULL
                THEN 3

            WHEN paymentBase.isHijriPeriod = 1
             AND paymentBase.effectivePaymentEndDate IS NOT NULL
             AND firstOccupancy.firstOccupancyDate IS NOT NULL
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN 4

            WHEN paymentBase.isHijriPeriod = 1
                THEN 2

            WHEN paymentBase.effectivePaymentEndDate IS NOT NULL
             AND firstOccupancy.firstOccupancyDate IS NOT NULL
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN 4

            WHEN candidateSummary.candidateCount = 1
                THEN 1

            ELSE 2
       END,

       CASE
            WHEN paymentBase.residentInfoID IS NULL
                THEN N'لم يتم العثور على ملف المستفيد.'

            WHEN paymentBase.effectivePaymentDate IS NULL
                THEN N'تعذر تحديد تاريخ ميلادي موثوق للسداد.'

            WHEN firstOccupancy.firstOccupancyDate IS NULL
                THEN N'المستفيد معروف ولكن لا توجد له فترة سكن.'

            WHEN paymentBase.isHijriPeriod = 1
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN N'السداد الهجري يسبق أول فترة سكن معروفة.'

            WHEN paymentBase.isHijriPeriod = 1
                THEN N'سداد تاريخي بفترة هجرية؛ تم الاحتفاظ به كرصد عام للمستفيد دون ربطه بمبنى.'

            WHEN paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN N'السداد يسبق أول فترة سكن معروفة.'

            WHEN candidateSummary.candidateCount = 1
                THEN N'تم تحديد مبنى واحد من فترة السكن في تاريخ السداد.'

            WHEN candidateSummary.candidateCount > 1
                THEN N'تاريخ السداد يقع داخل أكثر من فترة سكن؛ بقي رصيدا عاما.'

            ELSE N'السداد بعد أول سكن ولكنه خارج فترة سكن محددة؛ بقي رصيدا عاما.'
       END

FROM #PaymentBase paymentBase

LEFT JOIN #CandidateSummary candidateSummary
    ON candidateSummary.paymentID = paymentBase.paymentID

LEFT JOIN #FirstOccupancy firstOccupancy
    ON firstOccupancy.residentInfoID = paymentBase.residentInfoID;

    IF @ReturnResults=1
    BEGIN
        SELECT proposedStatusID,COUNT_BIG(*) paymentCount FROM #Proposal
        GROUP BY proposedStatusID ORDER BY proposedStatusID;
        IF @ShowDetails=1 SELECT * FROM #Proposal ORDER BY proposedStatusID,paymentID;
    END;

    IF @ApplyChanges=0 RETURN;

    BEGIN TRY
      BEGIN TRANSACTION;
      UPDATE paymentRow
      SET paymentRow.residentInfoID_FK=proposal.residentInfoID,
          paymentRow.buildingDetailsID_FK=CASE WHEN proposal.proposedStatusID=1 THEN CONVERT(nvarchar(400),proposal.proposedBuildingDetailsID) ELSE NULL END,
          paymentRow.buildingPaymentLinkStatusID_FK=proposal.proposedStatusID,
          paymentRow.paymentLinkNote=proposal.proposalReason
      OUTPUT inserted.paymentID,deleted.buildingPaymentLinkStatusID_FK,inserted.buildingPaymentLinkStatusID_FK,
             deleted.buildingDetailsID_FK,inserted.buildingDetailsID_FK,N'AUTO_TEMPORAL',inserted.paymentLinkNote,@ChangedBy,GETDATE()
      INTO Housing.BuildingPaymentLinkAudit
      (paymentID_FK,oldLinkStatusID,newLinkStatusID,oldBuildingDetailsID,newBuildingDetailsID,linkMethod,linkNote,changedBy,changedDate)
      FROM Housing.BuildingPayment paymentRow JOIN #Proposal proposal ON proposal.paymentID=paymentRow.paymentID
      WHERE ISNULL(paymentRow.residentInfoID_FK,-1)<>ISNULL(proposal.residentInfoID,-1)
         OR ISNULL(paymentRow.buildingPaymentLinkStatusID_FK,-1)<>proposal.proposedStatusID
         OR ISNULL(NULLIF(LTRIM(RTRIM(paymentRow.buildingDetailsID_FK)),N''),N'-1')<>
            ISNULL(CASE WHEN proposal.proposedStatusID=1 THEN CONVERT(nvarchar(400),proposal.proposedBuildingDetailsID) END,N'-1');
      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH;
END;