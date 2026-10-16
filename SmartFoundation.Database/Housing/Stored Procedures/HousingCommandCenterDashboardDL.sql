
CREATE PROCEDURE [Housing].[HousingCommandCenterDashboardDL]

      @pageName_       NVARCHAR(400)
    , @idaraID         INT
    , @entrydata       INT
    , @hostname        NVARCHAR(400)

    , @targetIdaraID      BIGINT         = NULL
    , @section            NVARCHAR(20)   = NULL
    , @status             NVARCHAR(30)   = NULL
    
    , @searchText         NVARCHAR(4000) = NULL
    , @billChargeTypeID   INT            = NULL
    , @sortKey            NVARCHAR(30)   = NULL
    , @pageNumber         INT            = NULL
    , @pageSize           INT            = NULL
    , @residentInfoID     BIGINT         = NULL

AS

BEGIN
    SET NOCOUNT ON;

    /* ============================================================
       HCC FINANCE ONLY - eligible movements after first occupancy
       Financial dashboard (dt4/dt11) + finance detail modes.
       Non-finance detail routes return before any materialization.
       Do not modify historical source records.
       ============================================================ */
    IF (
           @targetIdaraID IS NULL
        OR LOWER(ISNULL(@section, N'')) = N'finance'
    )
    BEGIN
        ;WITH FirstOccupancy AS
        (
            SELECT
                  bd.IdaraId_FK AS IdaraID
                , a.residentInfoID_FK AS ResidentID
                , MIN(CAST(a.buildingActionDate AS DATE)) AS FirstDate
            FROM Housing.BuildingAction a
            INNER JOIN Housing.BuildingDetails bd
                ON bd.buildingDetailsID = a.buildingDetailsID_FK
            WHERE a.buildingActionTypeID_FK = 2
              AND a.residentInfoID_FK IS NOT NULL
              AND a.buildingActionDate IS NOT NULL
              AND bd.IdaraId_FK IS NOT NULL
              AND (@targetIdaraID IS NULL
                   OR bd.IdaraId_FK = @targetIdaraID)
            GROUP BY bd.IdaraId_FK, a.residentInfoID_FK
        )
        SELECT IdaraID, ResidentID, FirstDate
        INTO #HCCFinFirstOccupancy
        FROM FirstOccupancy;

        CREATE UNIQUE CLUSTERED INDEX IX_HCCFinFirstOccupancy
            ON #HCCFinFirstOccupancy (IdaraID, ResidentID);

        /* Claims: explicit resident only.  A whole billing month that
           overlaps the first occupancy date is included in full.
           PeriodMonth/Year are a fallback only if BOTH dates are NULL. */
        SELECT
              b.BillsID
            , b.BillNumber
            , b.BillChargeTypeID_FK
            , b.BillActive
            , b.TotalPrice
            , b.PeriodMonth
            , b.PeriodYear
            , b.BillsFromDate
            , b.BillsToDate
            , b.buildingDetailsID
            , b.buildingDetailsNo
            , b.PenaltyReason
            , b.entryDate
            , b.residentInfoID_FK
            , b.idaraID_FK
        INTO #HCCFinEligibleBills
        FROM Housing.Bills b
        INNER JOIN #HCCFinFirstOccupancy fo
            ON fo.IdaraID = b.idaraID_FK
           AND fo.ResidentID = b.residentInfoID_FK
        OUTER APPLY
        (
            SELECT CASE
                WHEN b.BillsFromDate IS NOT NULL
                 AND b.BillsToDate IS NOT NULL
                 AND b.BillsFromDate <= b.BillsToDate
                    THEN CAST(b.BillsToDate AS DATE)
                WHEN b.BillsFromDate IS NULL
                 AND b.BillsToDate IS NULL
                 AND b.PeriodYear BETWEEN 1900 AND 2099
                 AND b.PeriodMonth BETWEEN 1 AND 12
                    THEN EOMONTH(DATEFROMPARTS(
                         b.PeriodYear, b.PeriodMonth, 1))
                ELSE NULL
            END AS PeriodEnd
        ) billPeriod
        WHERE b.BillActive = 1
          AND b.TotalPrice > 0
          AND b.residentInfoID_FK IS NOT NULL
          AND (@targetIdaraID IS NULL
               OR b.idaraID_FK = @targetIdaraID)
          AND billPeriod.PeriodEnd >= fo.FirstDate;

        CREATE UNIQUE CLUSTERED INDEX IX_HCCFinEligibleBills
            ON #HCCFinEligibleBills (BillsID);

        /* Payments: DeductList.issueYear/issueMonth are authoritative.
           Hijri month boundaries must have full calendar coverage.
           Status 3/4, inactive movements, and pre-occupancy months
           remain historical and are not included in KPI balances. */
        ;WITH HijriMonths AS
        (
            SELECT
                  yearH
                , monthH
                , MAX(CAST(gregorianDate AS DATE)) AS PeriodEnd
            FROM dbo._GregorianHijriDate
            WHERE gregorianDate IS NOT NULL
              AND yearH BETWEEN 1300 AND 1600
            GROUP BY yearH, monthH
            HAVING MIN(dayH) = 1
               AND MAX(dayH) IN (29, 30)
               AND COUNT(DISTINCT dayH) = MAX(dayH)
               AND COUNT(DISTINCT CAST(gregorianDate AS DATE)) = MAX(dayH)
               AND DATEDIFF(DAY,
                      MIN(CAST(gregorianDate AS DATE)),
                      MAX(CAST(gregorianDate AS DATE))) + 1 = MAX(dayH)
        )
        SELECT
              p.paymentID
            , p.BillChargeTypeID_FK
            , p.amount
            , p.deductListID_FK
            , p.IdaraId_FK
            , p.residentInfoID_FK
            , p.buildingDetailsID_FK
            , p.entryDate
            , p.buildingPayementActive
            , p.buildingPaymentLinkStatusID_FK
        INTO #HCCFinEligiblePayments
        FROM Housing.BuildingPayment p
        INNER JOIN Housing.DeductList d
            ON d.deductListID = p.deductListID_FK
        INNER JOIN #HCCFinFirstOccupancy fo
            ON fo.IdaraID = p.IdaraId_FK
           AND fo.ResidentID = p.residentInfoID_FK
        OUTER APPLY
        (
            SELECT
                  TRY_CONVERT(INT, d.issueYear) AS Y
                , TRY_CONVERT(INT, d.issueMonth) AS M
        ) ym
        LEFT JOIN HijriMonths hm
            ON hm.yearH = ym.Y
           AND hm.monthH = ym.M
        OUTER APPLY
        (
            SELECT CASE
                WHEN ym.Y BETWEEN 1900 AND 2099
                 AND ym.M BETWEEN 1 AND 12
                    THEN EOMONTH(DATEFROMPARTS(ym.Y, ym.M, 1))
                WHEN ym.Y BETWEEN 1300 AND 1600
                 AND ym.M BETWEEN 1 AND 12
                    THEN hm.PeriodEnd
                ELSE NULL
            END AS PeriodEnd
        ) paymentPeriod
        WHERE p.buildingPayementActive = 1
          AND d.deductActive = 1
          AND p.buildingPaymentLinkStatusID_FK IN (1, 2)
          AND p.residentInfoID_FK IS NOT NULL
          AND (@targetIdaraID IS NULL
               OR p.IdaraId_FK = @targetIdaraID)
          AND paymentPeriod.PeriodEnd >= fo.FirstDate;

        CREATE UNIQUE CLUSTERED INDEX IX_HCCFinEligiblePayments
            ON #HCCFinEligiblePayments (paymentID);
    END;



    
/* ============================================================
   WAITING LIST DASHBOARD - DETAIL MODE
   ============================================================ */


/* ============================================================
   WAITING LIST DASHBOARD - DETAIL MODE
   ============================================================ */

IF @targetIdaraID IS NOT NULL
   AND LOWER(ISNULL(@section, N'')) = N'waitinglist'
BEGIN
    -- Maintain current scope until CanViewAllHousingDashboard is implemented.
    IF @idaraID IS NULL
       OR @targetIdaraID <> @idaraID
    BEGIN
        THROW 50001,
            N'غير مصرح بعرض قوائم انتظار هذه الإدارة',
            1;
    END;

    -- One record per (residentInfoID, WaitingClassID), not per person.
    -- In the unlikely event of more than one active root for the SAME
    -- resident and class, use the latest action to determine its stage.
    ;WITH WaitingCandidates AS
    (
        SELECT
              w.residentInfoID
            , w.WaitingClassID
            , c.idara_FK
            , w.LastActionTypeID
            , w.ActionID
            , w.GeneralNo
            , w.NationalID
            , w.fullname
            , w.ActionDecisionNo
            , w.ActionDecisionDate
            , w.WaitingClassName
            , w.LastActionTypeName
            , w.LastActionDate
            , w.buildingDetailsNo
            , CASE
                  WHEN w.LastActionTypeID IS NULL
                    OR w.LastActionTypeID IN (34, 35)
                      THEN N'WAITING'
                  WHEN w.LastActionTypeID IN
                       (26, 27, 38, 39, 40, 41, 43, 44)
                      THEN N'ALLOCATION'
                  WHEN w.LastActionTypeID IN (45, 46, 47)
                      THEN N'HOUSING'
              END AS WaitingStage
            , ROW_NUMBER() OVER
              (
                  PARTITION BY w.residentInfoID, w.WaitingClassID
                  ORDER BY
                      COALESCE(
                          w.LastActionEntryDate,
                          w.LastActionDate,
                          w.ActionDate
                      ) DESC,
                      COALESCE(w.LastActionID, w.ActionID) DESC,
                      w.ActionID DESC
              ) AS ClassRecordRank
        FROM Housing.V_WaitingList w
        INNER JOIN Housing.WaitingClass c
            ON c.waitingClassID = w.WaitingClassID
        WHERE
            w.IdaraId = @targetIdaraID
            AND w.residentInfoID IS NOT NULL
             AND EXISTS
    (
        SELECT 1
        FROM Housing.V_GetFullResidentDetails rd
        WHERE rd.residentInfoID = w.residentInfoID
          AND rd.IdaraID = @targetIdaraID
    )
            AND w.WaitingClassID IS NOT NULL
            AND c.waitingClassActive = 1
            -- Global MAIN classes and classes assigned to this Idara.
            AND (
                c.idara_FK IS NULL
                OR c.idara_FK = @targetIdaraID
            )
            -- Preserve approved root-action eligibility.
            AND (
                (c.idara_FK IS NULL AND w.ActionTypeID = 1)
                OR
                (c.idara_FK = @targetIdaraID
                 AND w.ActionTypeID IN (1, 7, 25))
            )
            -- Preserve the approved current-stage set.
            AND (
                w.LastActionTypeID IS NULL
                OR w.LastActionTypeID IN
                   (34, 35, 26, 27, 38, 39, 40, 41,
                    43, 44, 45, 46, 47)
            )
    )
    SELECT
          residentInfoID
        , WaitingClassID
        , idara_FK
        , LastActionTypeID
        , WaitingStage
        , ActionID
        , GeneralNo
        , NationalID
        , fullname
        , ActionDecisionNo
        , ActionDecisionDate
        , WaitingClassName
        , LastActionTypeName
        , LastActionDate
        , buildingDetailsNo
    INTO #HCC_WaitingData
    FROM WaitingCandidates
    WHERE ClassRecordRank = 1
      -- SIDE classes: WAITING and HOUSING (never ALLOCATION).
      -- Filter after deduplication to avoid resurrecting older entries.
      AND (idara_FK IS NULL OR WaitingStage IN (N'WAITING', N'HOUSING'))
    OPTION (RECOMPILE);

    -- Enforce exact one-row-per-resident-and-class invariant.
    CREATE UNIQUE CLUSTERED INDEX IX_HCC_WaitingData_ResidentClass
        ON #HCC_WaitingData (residentInfoID, WaitingClassID);

    /* ============================================================
       DETAIL MODE - paged waiting-class registrations
       @status = DETAIL_ALL / DETAIL_WAITING / DETAIL_ALLOCATION /
                 DETAIL_HOUSING / DETAIL_MAIN_WAITING /
                 DETAIL_SIDE_WAITING
       @billChargeTypeID = WaitingClassID (only for waitinglist)
       @searchText, @pageNumber, @pageSize as already routed by Masters_DataLoad
       Result Set 1: detail rows; Result Set 2: paging metadata
       Existing permission result set from Masters_DataLoad stays at index 0.
       ============================================================ */
    IF @status IN
    (
        N'DETAIL_ALL', N'DETAIL_WAITING', N'DETAIL_ALLOCATION',
        N'DETAIL_HOUSING', N'DETAIL_MAIN_WAITING', N'DETAIL_SIDE_WAITING'
    )
    BEGIN
        DECLARE @DetailPageNumber INT =
            CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
        DECLARE @DetailPageSize INT =
            CASE WHEN @pageSize IN (25, 50, 100) THEN @pageSize ELSE 25 END;
        DECLARE @DetailSearch NVARCHAR(4000) =
            NULLIF(LTRIM(RTRIM(@searchText)), N'');

        IF @billChargeTypeID IS NOT NULL AND @billChargeTypeID <= 0
        BEGIN
            THROW 50002, N'فئة قائمة الانتظار غير صحيحة', 1;
        END;

        -- ترتيب الانتظار الأصلي يحسب قبل البحث
        -- مع ترقيم منفصل لنتائج البحث والتصفح.
        
        ;WITH OrderedWaiting AS
        (
            SELECT
                  ROW_NUMBER() OVER
                  (
                      ORDER BY
                          w.ActionDecisionDate ASC,
                          w.ActionDecisionNo ASC,
                          w.GeneralNo ASC,
                          w.WaitingClassID ASC,
                          w.ActionID ASC
                  ) AS WaitingListOrder
                , w.residentInfoID
                , w.WaitingClassID
                , w.idara_FK
                , w.WaitingStage
                , w.ActionID
                , w.GeneralNo
                , w.NationalID
                , w.fullname
                , w.ActionDecisionNo
                , w.ActionDecisionDate
                , w.WaitingClassName
                , w.LastActionTypeID
                , w.LastActionTypeName
                , w.LastActionDate
                , w.buildingDetailsNo
        
            FROM #HCC_WaitingData w
        
            WHERE
                (
                    @billChargeTypeID IS NULL
                    OR w.WaitingClassID = @billChargeTypeID
                )
                AND
                (
                    @status = N'DETAIL_ALL'
        
                    OR (
                        @status = N'DETAIL_WAITING'
                        AND w.WaitingStage = N'WAITING'
                    )
        
                    OR (
                        @status = N'DETAIL_ALLOCATION'
                        AND w.WaitingStage = N'ALLOCATION'
                    )
        
                    OR (
                        @status = N'DETAIL_HOUSING'
                        AND w.WaitingStage = N'HOUSING'
                    )
        
                    OR (
                        @status = N'DETAIL_MAIN_WAITING'
                        AND w.WaitingStage = N'WAITING'
                        AND w.idara_FK IS NULL
                    )
        
                    OR (
                        @status = N'DETAIL_SIDE_WAITING'
                        AND w.WaitingStage = N'WAITING'
                        AND w.idara_FK IS NOT NULL
                    )
                )
        )
        SELECT
              ROW_NUMBER() OVER
              (
                  ORDER BY w.WaitingListOrder
              ) AS ResultRowNo
        
            , w.WaitingListOrder
            , w.residentInfoID
            , w.WaitingClassID
            , w.idara_FK
            , w.WaitingStage
            , w.ActionID
            , w.GeneralNo
            , w.NationalID
            , w.fullname
            , w.ActionDecisionNo
            , w.ActionDecisionDate
            , w.WaitingClassName
            , w.LastActionTypeID
            , w.LastActionTypeName
            , w.LastActionDate
            , w.buildingDetailsNo
        
        INTO #HCC_WaitingDetails
        
        FROM OrderedWaiting w
        
        WHERE
            @DetailSearch IS NULL
        
            OR w.fullname LIKE N'%' + @DetailSearch + N'%'
        
            OR w.NationalID LIKE N'%' + @DetailSearch + N'%'
        
            OR CONVERT(NVARCHAR(30), w.GeneralNo)
                LIKE N'%' + @DetailSearch + N'%'
        
            OR w.ActionDecisionNo
                LIKE N'%' + @DetailSearch + N'%'
        
            OR w.WaitingClassName
                LIKE N'%' + @DetailSearch + N'%'
        
        OPTION (RECOMPILE);

        -- Rank is enrichment only: never allow it to remove a counted registration.
        -- Apply only to the requested page to avoid an expensive view join.
        SELECT
              d.WaitingListOrder
            , d.ActionID
            , d.residentInfoID
            , d.GeneralNo
            , d.fullname AS FullName
            , d.NationalID
            , r.rankNameA AS RankName
            , d.WaitingClassID
            , d.WaitingClassName
            , CASE WHEN d.idara_FK IS NULL THEN N'MAIN' ELSE N'SIDE' END AS ClassType
            , d.ActionDecisionNo
            , d.ActionDecisionDate
            , d.LastActionTypeID
            , COALESCE(d.LastActionTypeName,
                CASE WHEN d.WaitingStage = N'WAITING' THEN N'في الانتظار' END
              ) AS LastActionTypeName
            , d.WaitingStage
            , d.LastActionDate
            , d.buildingDetailsNo
        FROM #HCC_WaitingDetails d
        OUTER APPLY
        (
            SELECT TOP (1) rd.rankNameA
            FROM Housing.V_GetFullResidentDetails rd
            WHERE rd.residentInfoID = d.residentInfoID
              AND rd.IdaraID = @targetIdaraID
            ORDER BY rd.residentDetailsID DESC
        ) r
        WHERE d.ResultRowNo >
          (CONVERT(BIGINT, @DetailPageNumber) - 1) * @DetailPageSize
  AND d.ResultRowNo <=
          CONVERT(BIGINT, @DetailPageNumber) * @DetailPageSize
ORDER BY d.ResultRowNo
OPTION (RECOMPILE);

        SELECT
              COUNT_BIG(*) AS TotalRows
            , @DetailPageNumber AS PageNumber
            , @DetailPageSize AS PageSize
            , CONVERT(BIGINT, CEILING(
                CONVERT(DECIMAL(20, 2), COUNT_BIG(*)) / @DetailPageSize
              )) AS TotalPages
        FROM #HCC_WaitingDetails;

        DROP TABLE #HCC_WaitingDetails;
        DROP TABLE #HCC_WaitingData;
        RETURN;
    END;

    /* Result Set 1 - Summary (class registrations, not unique people) */
    SELECT
          COUNT(*) AS TotalWaitingRecords
          -- Temporary compatibility alias for existing MVC ViewModel.
        , COUNT(*) AS TotalUniqueResidents
        , COUNT(CASE
              WHEN WaitingStage = N'WAITING' THEN 1
          END) AS WaitingResidents
        , COUNT(CASE
              WHEN WaitingStage = N'ALLOCATION' THEN 1
          END) AS AllocationResidents
        , COUNT(CASE
              WHEN WaitingStage = N'HOUSING' THEN 1
          END) AS HousingProcedureResidents
        , COUNT(CASE
              WHEN WaitingStage = N'WAITING' AND idara_FK IS NULL
                  THEN 1
          END) AS MainWaitingResidents
        , COUNT(CASE
              WHEN WaitingStage = N'WAITING' AND idara_FK IS NOT NULL
                  THEN 1
          END) AS SideWaitingResidents
    FROM #HCC_WaitingData;

    /* Result Set 2 - Class-level registrations */
    SELECT
          c.waitingClassID AS WaitingClassID
        , c.waitingClassName_A AS WaitingClassName
        , c.waitingClassSequence AS SortOrder
        , CASE
              WHEN c.idara_FK IS NULL THEN N'MAIN'
              ELSE N'SIDE'
          END AS ClassType
        , COUNT(CASE
              WHEN w.WaitingStage = N'WAITING' THEN 1
          END) AS WaitingResidents
        , COUNT(CASE
              WHEN w.WaitingStage = N'ALLOCATION' THEN 1
          END) AS AllocationResidents
        , COUNT(CASE
              WHEN w.WaitingStage = N'HOUSING' THEN 1
          END) AS HousingProcedureResidents
    FROM Housing.WaitingClass c
    LEFT JOIN #HCC_WaitingData w
        ON w.WaitingClassID = c.waitingClassID
    WHERE
        c.waitingClassActive = 1
        AND (
            c.idara_FK IS NULL
            OR c.idara_FK = @targetIdaraID
        )
    GROUP BY
          c.waitingClassID
        , c.waitingClassName_A
        , c.waitingClassSequence
        , c.idara_FK
    ORDER BY
          CASE WHEN c.idara_FK IS NULL THEN 0 ELSE 1 END
        , c.waitingClassSequence
        , c.waitingClassID;

    /* Result Set 3 - Allocation and housing stages (class registrations) */
    SELECT
          w.LastActionTypeID AS ActionTypeID
        , t.buildingActionTypeName_A AS ActionName
        , w.WaitingStage
        , COUNT(*) AS ResidentsCount
    FROM #HCC_WaitingData w
    INNER JOIN Housing.BuildingActionType t
        ON t.buildingActionTypeID = w.LastActionTypeID
    WHERE w.WaitingStage IN (N'ALLOCATION', N'HOUSING')
    GROUP BY
          w.LastActionTypeID
        , t.buildingActionTypeName_A
        , w.WaitingStage
    ORDER BY
          w.WaitingStage
        , w.LastActionTypeID;

    DROP TABLE #HCC_WaitingData;
    RETURN;
END;




    /* ============================================================
   DETAIL MODE
   Housing Readiness - Building Details

   @section = readiness

   @status:
       OCCUPIED
       READY
       ALLOCATION
       MAINTENANCE
       QUALITY
       GENERAL_SERVICES
       HOUSING_DEPARTMENT
       EXECUTION
       VACANT_PENDING
       NO_ACTIVE_ACTION
       OTHER

   Result Set:
       Building Details
   ============================================================ */

IF
(
       @targetIdaraID IS NOT NULL
   AND LOWER(ISNULL(@section, N'')) = N'readiness'

   AND UPPER(ISNULL(@status, N'')) IN
       (
           N'OCCUPIED',
           N'READY',
           N'ALLOCATION',
           N'MAINTENANCE',
           N'QUALITY',
           N'GENERAL_SERVICES',
           N'HOUSING_DEPARTMENT',
           N'EXECUTION',
           N'VACANT_PENDING',
           N'NO_ACTIVE_ACTION',
           N'OTHER'
       )
)
BEGIN

    ;WITH CurrentHousing AS
    (
        SELECT

              b.buildingDetailsID
            , b.buildingDetailsNo

            , b.buildingDetailsRooms
            , b.buildingLevelsCount
            , b.buildingDetailsArea

            , ISNULL
              (
                  ml.militaryLocationName_A,
                  N'غير محدد'
              ) AS militaryLocationName_A

            , ISNULL
              (
                  bt.buildingTypeName_A,
                  N'غير محدد'
              ) AS buildingTypeName_A

            , ISNULL
              (
                  buty.buildingUtilityTypeName_A,
                  N'غير محدد'
              ) AS buildingUtilityTypeName_A

            , ISNULL
              (
                  bc.buildingClassName_A,
                  N'غير محدد'
              ) AS buildingClassName_A


            /* ====================================================
               Current action
               ==================================================== */

            , a.buildingActionID
            , a.buildingActionTypeID_FK

            , ISNULL
              (
                  at.buildingActionTypeName_A,
                  N'لا يوجد إجراء نشط'
              ) AS CurrentActionName

            , ISNULL
              (
                  NULLIF
                  (
                      LTRIM
                      (
                          RTRIM
                          (
                              at.buildingActionTypeBuildingAlias
                          )
                      ),
                      N''
                  ),
                  ISNULL
                  (
                      at.buildingActionTypeName_A,
                      N'لا يوجد إجراء نشط'
                  )
              ) AS CurrentBuildingStatus


            /* ====================================================
               Current status date
               ==================================================== */

            , COALESCE
              (
                  a.buildingActionDate,
                  a.entryDate
              ) AS CurrentStatusSince

            , CASE

                  WHEN COALESCE
                       (
                           a.buildingActionDate,
                           a.entryDate
                       ) IS NULL
                      THEN NULL

                  ELSE DATEDIFF
                       (
                           DAY,
                           COALESCE
                           (
                               a.buildingActionDate,
                               a.entryDate
                           ),
                           GETDATE()
                       )

              END AS DaysInCurrentStatus

            , a.buildingActionDate
                AS CurrentActionDate

            , a.buildingActionDecisionDate
                AS DecisionDate

            , a.entryDate
                AS ActionEntryDate

            , CASE

                  WHEN a.buildingActionDate IS NOT NULL
                      THEN N'ACTION_DATE'

                  WHEN a.entryDate IS NOT NULL
                      THEN N'ENTRY_DATE_FALLBACK'

                  ELSE N'UNKNOWN'

              END AS CurrentStatusDateSource


            /* ====================================================
               Beneficiary attached to current action
               ==================================================== */

            , a.generalNo_FK

            , rd.ResidentRankName
            , rd.ResidentFullName
            , rd.ResidentMilitaryUnit


            /* ====================================================
               Readiness classification
               MUST remain identical to dt6
               ==================================================== */

            , CASE

                  WHEN a.buildingActionTypeID_FK IS NULL
                      THEN N'NO_ACTIVE_ACTION'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           2,
                           24,
                           54,
                           55,
                           56,
                           57,
                           58,
                           59,
                           60,
                           61
                       )
                      THEN N'OCCUPIED'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           5,
                           39,
                           41,
                           42
                       )
                      THEN N'READY'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           38,
                           40,
                           45,
                           46,
                           47
                       )
                      THEN N'ALLOCATION'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           4,
                           9,
                           17,
                           31
                       )
                      THEN N'MAINTENANCE'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           10,
                           11
                       )
                      THEN N'QUALITY'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           12,
                           13
                       )
                      THEN N'GENERAL_SERVICES'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           14,
                           15,
                           16
                       )
                      THEN N'HOUSING_DEPARTMENT'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           29,
                           30
                       )
                      THEN N'EXECUTION'

                  WHEN a.buildingActionTypeID_FK = 3
                      THEN N'VACANT_PENDING'

                  ELSE N'OTHER'

              END AS ReadinessGroupKey


            , CASE

                  WHEN a.buildingActionTypeID_FK IS NULL
                      THEN N'لا يوجد إجراء نشط'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           2,
                           24,
                           54,
                           55,
                           56,
                           57,
                           58,
                           59,
                           60,
                           61
                       )
                      THEN N'مسكون حاليًا'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           5,
                           39,
                           41,
                           42
                       )
                      THEN N'جاهز للتسكين'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           38,
                           40,
                           45,
                           46,
                           47
                       )
                      THEN N'تحت إجراءات التخصيص'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           4,
                           9,
                           17,
                           31
                       )
                      THEN N'ضمن دورة الصيانة'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           10,
                           11
                       )
                      THEN N'ضمن دورة الجودة'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           12,
                           13
                       )
                      THEN N'تحت اجراءات النظافه'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           14,
                           15,
                           16
                       )
                      THEN N'تحت إجراءات قسم الإسكان'

                  WHEN a.buildingActionTypeID_FK IN
                       (
                           29,
                           30
                       )
                      THEN N'ضمن دورة قسم التنفيذ'

                  WHEN a.buildingActionTypeID_FK = 3
                      THEN N'خالٍ بانتظار اتخاذ إجراء'

                  ELSE N'حالة أخرى'

              END AS ReadinessGroupName


        FROM Housing.BuildingDetails b


        LEFT JOIN Housing.MilitaryLocation ml
            ON ml.militaryLocationID =
               b.militaryLocationID_FK


        LEFT JOIN Housing.BuildingType bt
            ON bt.buildingTypeID =
               b.buildingTypeID_FK


        LEFT JOIN Housing.BuildingUtilityType buty
            ON buty.buildingUtilityTypeID =
               b.buildingUtilityTypeID_FK


        LEFT JOIN Housing.BuildingClass bc
            ON bc.buildingClassID =
               b.buildingClassID_FK


        LEFT JOIN Housing.V_LastActionForBuilding la
            ON la.buildingDetailsID =
               b.buildingDetailsID


        LEFT JOIN Housing.BuildingAction a
            ON a.buildingActionID =
               la.buildingActionID


        LEFT JOIN Housing.BuildingActionType at
            ON at.buildingActionTypeID =
               a.buildingActionTypeID_FK


        /*
           OUTER APPLY لمنع تكرار الوحدة إذا كان للمستفيد
           أكثر من ResidentDetails.
        */
        OUTER APPLY
        (
            SELECT TOP (1)

                  r.rankNameA
                      AS ResidentRankName

                , r.FullName_A
                      AS ResidentFullName

                , r.militaryUnitName_A
                      AS ResidentMilitaryUnit

            FROM Housing.V_GetFullResidentDetails r

            WHERE
                r.residentInfoID =
                    a.residentInfoID_FK

            ORDER BY
                r.residentDetailsID DESC

        ) rd


        WHERE
                b.IdaraId_FK =
                    @targetIdaraID

            AND b.buildingDetailsActive = 1

            AND b.buildingUtilityTypeID_FK
                IN
                (
                    1,
                    11,
                    13,
                    15
                )
    ),

    FilteredHousing AS
    (
        SELECT
            h.*

        FROM CurrentHousing h

        WHERE
            h.ReadinessGroupKey =
                UPPER(@status)
    )

    SELECT

          h.buildingDetailsID
        , h.buildingDetailsNo

        , h.militaryLocationName_A
        , h.buildingTypeName_A
        , h.buildingUtilityTypeName_A
        , h.buildingClassName_A

        , h.buildingDetailsRooms
        , h.buildingLevelsCount
        , h.buildingDetailsArea

        , h.ReadinessGroupKey
        , h.ReadinessGroupName

        , h.buildingActionID
        , h.buildingActionTypeID_FK

        , h.CurrentActionName
        , h.CurrentBuildingStatus

        , h.CurrentStatusSince
        , h.DaysInCurrentStatus

        , h.CurrentActionDate
        , h.DecisionDate
        , h.ActionEntryDate
        , h.CurrentStatusDateSource

        , h.generalNo_FK

        , h.ResidentRankName
        , h.ResidentFullName
        , h.ResidentMilitaryUnit


        /*
           هذه الحقول موجودة في ViewModel الحالي،
           لكننا لا نخمن بيانات تاريخية غير مثبتة هنا.
           سنطورها لاحقًا إن احتجناها.
        */
        , CAST(NULL AS DATETIME)
            AS OccupiedSince

        , CAST(NULL AS INT)
            AS DaysOccupied

        , CAST(NULL AS DATETIME)
            AS VacantSince

        , CAST(NULL AS DATETIME)
            AS LastExitActionDate

        , CAST(NULL AS INT)
            AS DaysVacant

        , CAST(NULL AS NVARCHAR(100))
            AS LastResidentGeneralNo

        , CAST(NULL AS NVARCHAR(200))
            AS LastResidentRankName

        , CAST(NULL AS NVARCHAR(500))
            AS LastResidentFullName

        , CAST(NULL AS NVARCHAR(500))
            AS LastResidentMilitaryUnit


    
    FROM FilteredHousing h

    ORDER BY

        CASE
            WHEN h.CurrentStatusSince IS NULL
                THEN 1
            ELSE 0
        END,

        h.CurrentStatusSince ASC,

        h.buildingDetailsID

    OPTION (RECOMPILE);


    RETURN;

END





/* ============================================================
   DETAIL MODE
   Housing Occupancy - Building Details

   @section = occupancy

   @status:
       OCCUPIED
       VACANT

   Result Set:
       Building Details
   ============================================================ */

IF
(
       @targetIdaraID IS NOT NULL
   AND LOWER(ISNULL(@section, N'')) = N'occupancy'

   AND UPPER(ISNULL(@status, N'')) IN
       (
           N'OCCUPIED',
           N'VACANT'
       )
)
BEGIN

    ;WITH CurrentHousing AS
    (
        SELECT

              b.buildingDetailsID
            , b.buildingDetailsNo

            , b.buildingDetailsRooms
            , b.buildingLevelsCount
            , b.buildingDetailsArea

            , ISNULL
              (
                  ml.militaryLocationName_A,
                  N'غير محدد'
              ) AS militaryLocationName_A

            , ISNULL
              (
                  bt.buildingTypeName_A,
                  N'غير محدد'
              ) AS buildingTypeName_A

            , ISNULL
              (
                  buty.buildingUtilityTypeName_A,
                  N'غير محدد'
              ) AS buildingUtilityTypeName_A

            , ISNULL
              (
                  bc.buildingClassName_A,
                  N'غير محدد'
              ) AS buildingClassName_A


            /* ====================================================
               Current action
               ==================================================== */

            , a.buildingActionID
            , a.buildingActionTypeID_FK

            , ISNULL
              (
                  at.buildingActionTypeName_A,
                  N'لا يوجد إجراء نشط'
              ) AS CurrentActionName

            , ISNULL
              (
                  NULLIF
                  (
                      LTRIM
                      (
                          RTRIM
                          (
                              at.buildingActionTypeBuildingAlias
                          )
                      ),
                      N''
                  ),
                  ISNULL
                  (
                      at.buildingActionTypeName_A,
                      N'لا يوجد إجراء نشط'
                  )
              ) AS CurrentBuildingStatus


            /* ====================================================
               Current status date
               ==================================================== */

            , COALESCE
              (
                  a.buildingActionDate,
                  a.entryDate
              ) AS CurrentStatusSince

            , CASE

                  WHEN COALESCE
                       (
                           a.buildingActionDate,
                           a.entryDate
                       ) IS NULL
                      THEN NULL

                  ELSE DATEDIFF
                       (
                           DAY,
                           COALESCE
                           (
                               a.buildingActionDate,
                               a.entryDate
                           ),
                           GETDATE()
                       )

              END AS DaysInCurrentStatus

            , a.buildingActionDate
                AS CurrentActionDate

            , a.buildingActionDecisionDate
                AS DecisionDate

            , a.entryDate
                AS ActionEntryDate

            , CASE

                  WHEN a.buildingActionDate IS NOT NULL
                      THEN N'ACTION_DATE'

                  WHEN a.entryDate IS NOT NULL
                      THEN N'ENTRY_DATE_FALLBACK'

                  ELSE N'UNKNOWN'

              END AS CurrentStatusDateSource


            /* ====================================================
               Current beneficiary
               ==================================================== */

            , a.generalNo_FK

            , rd.ResidentRankName
            , rd.ResidentFullName
            , rd.ResidentMilitaryUnit


            /* ====================================================
               Occupancy classification

               MUST remain identical to dt2 / dt5:
               buildingActionRoot = 2 => OCCUPIED
               otherwise             => VACANT
               ==================================================== */

            , CASE

                  WHEN at.buildingActionRoot = 2
                      THEN N'OCCUPIED'

                  ELSE N'VACANT'

              END AS OccupancyGroupKey


            /* ====================================================
               Occupied fields

               عندما يكون آخر إجراء Root=2 فإن بداية الحالة
               الحالية هي بداية الإشغال الحالي.
               ==================================================== */

            , CASE

                  WHEN at.buildingActionRoot = 2
                      THEN COALESCE
                           (
                               a.buildingActionDate,
                               a.entryDate
                           )

                  ELSE NULL

              END AS OccupiedSince

            , CASE

                  WHEN at.buildingActionRoot = 2
                   AND COALESCE
                       (
                           a.buildingActionDate,
                           a.entryDate
                       ) IS NOT NULL

                      THEN DATEDIFF
                           (
                               DAY,
                               COALESCE
                               (
                                   a.buildingActionDate,
                                   a.entryDate
                               ),
                               GETDATE()
                           )

                  ELSE NULL

              END AS DaysOccupied


                          /* ====================================================
               Vacancy / previous occupant
               
               بداية الشغور = آخر إخلاء فعلي مسجل للمبنى
               الحركة 3 = إخلاء نهائي
               ==================================================== */

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN lastExit.LastExitDate
                  ELSE NULL
              END AS VacantSince

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN lastExit.LastExitDate
                  ELSE NULL
              END AS LastExitActionDate

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                   AND lastExit.LastExitDate IS NOT NULL
                      THEN DATEDIFF
                           (
                               DAY,
                               lastExit.LastExitDate,
                               GETDATE()
                           )
                  ELSE NULL
              END AS DaysVacant

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN CONVERT
                           (
                               NVARCHAR(100),
                               lastExit.generalNo_FK
                           )
                  ELSE NULL
              END AS LastResidentGeneralNo

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN lastResident.ResidentRankName
                  ELSE NULL
              END AS LastResidentRankName

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN lastResident.ResidentFullName
                  ELSE NULL
              END AS LastResidentFullName

            , CASE
                  WHEN ISNULL(at.buildingActionRoot, 0) <> 2
                      THEN lastResident.ResidentMilitaryUnit
                  ELSE NULL
              END AS LastResidentMilitaryUnit


        FROM Housing.BuildingDetails b


        LEFT JOIN Housing.MilitaryLocation ml
            ON ml.militaryLocationID =
               b.militaryLocationID_FK


        LEFT JOIN Housing.BuildingType bt
            ON bt.buildingTypeID =
               b.buildingTypeID_FK


        LEFT JOIN Housing.BuildingUtilityType buty
            ON buty.buildingUtilityTypeID =
               b.buildingUtilityTypeID_FK


        LEFT JOIN Housing.BuildingClass bc
            ON bc.buildingClassID =
               b.buildingClassID_FK


        LEFT JOIN Housing.V_LastActionForBuilding la
            ON la.buildingDetailsID =
               b.buildingDetailsID


        LEFT JOIN Housing.BuildingAction a
            ON a.buildingActionID =
               la.buildingActionID


        LEFT JOIN Housing.BuildingActionType at
            ON at.buildingActionTypeID =
               a.buildingActionTypeID_FK


        /*
           منع تكرار الوحدة في حالة وجود أكثر من ResidentDetails
           لنفس المستفيد.
        */
        OUTER APPLY
        (
            SELECT TOP (1)

                  r.rankNameA
                      AS ResidentRankName

                , r.FullName_A
                      AS ResidentFullName

                , r.militaryUnitName_A
                      AS ResidentMilitaryUnit

            FROM Housing.V_GetFullResidentDetails r

            WHERE
                r.residentInfoID =
                    a.residentInfoID_FK

            ORDER BY
                r.residentDetailsID DESC

        ) rd

                /* ====================================================
           Last physical exit for this building
           ==================================================== */

        OUTER APPLY
        (
            SELECT TOP (1)

                  e.buildingActionID
                      AS LastExitActionID

                , COALESCE
                  (
                      e.ExitDate,
                      e.buildingActionDate,
                      e.entryDate
                  ) AS LastExitDate

                , e.residentInfoID_FK
                , e.generalNo_FK

            FROM Housing.BuildingAction e

            WHERE
                e.buildingDetailsID_FK =
                    b.buildingDetailsID

                AND e.buildingActionActive = 1

                AND e.buildingActionTypeID_FK = 3

            ORDER BY

                COALESCE
                (
                    e.ExitDate,
                    e.buildingActionDate,
                    e.entryDate
                ) DESC,

                e.buildingActionID DESC

        ) lastExit


        /* ====================================================
           Previous resident details from the exit action
           ==================================================== */

        OUTER APPLY
        (
            SELECT TOP (1)

                  r.rankNameA
                      AS ResidentRankName

                , r.FullName_A
                      AS ResidentFullName

                , r.militaryUnitName_A
                      AS ResidentMilitaryUnit

            FROM Housing.V_GetFullResidentDetails r

            WHERE
                r.residentInfoID =
                    lastExit.residentInfoID_FK

            ORDER BY
                r.residentDetailsID DESC

        ) lastResident


        WHERE
                b.IdaraId_FK =
                    @targetIdaraID

            AND b.buildingDetailsActive = 1

            AND b.buildingUtilityTypeID_FK
                IN
                (
                    1,
                    11,
                    13,
                    15
                )
    ),

    FilteredHousing AS
    (
        SELECT
            h.*

        FROM CurrentHousing h

        WHERE
            h.OccupancyGroupKey =
                UPPER(@status)
    )

    SELECT

          h.buildingDetailsID
        , h.buildingDetailsNo

        , h.militaryLocationName_A
        , h.buildingTypeName_A
        , h.buildingUtilityTypeName_A
        , h.buildingClassName_A

        , h.buildingDetailsRooms
        , h.buildingLevelsCount
        , h.buildingDetailsArea


        /*
           BuildingDetails ViewModel يستخدم نفس الأعمدة
           في readiness و occupancy.
        */

        , h.OccupancyGroupKey
            AS ReadinessGroupKey

        , CASE

              WHEN h.OccupancyGroupKey = N'OCCUPIED'
                  THEN N'مسكون حاليًا'

              ELSE N'شاغر'

          END AS ReadinessGroupName


        , h.buildingActionID
        , h.buildingActionTypeID_FK

        , h.CurrentActionName
        , h.CurrentBuildingStatus

        , h.CurrentStatusSince
        , h.DaysInCurrentStatus

        , h.CurrentActionDate
        , h.DecisionDate
        , h.ActionEntryDate
        , h.CurrentStatusDateSource

        , h.generalNo_FK

        , h.ResidentRankName
        , h.ResidentFullName
        , h.ResidentMilitaryUnit

        , h.OccupiedSince
        , h.DaysOccupied


        /*
           بيانات الشغور التاريخية تحتاج تحديد آخر عملية إخلاء
           بصورة مستقلة.
           لا نخمنها في هذه المرحلة.
        */

                , h.VacantSince
        , h.LastExitActionDate
        , h.DaysVacant

        , h.LastResidentGeneralNo
        , h.LastResidentRankName
        , h.LastResidentFullName
        , h.LastResidentMilitaryUnit


    
    FROM FilteredHousing h

    ORDER BY

        CASE
            WHEN h.OccupiedSince IS NULL
                THEN 1
            ELSE 0
        END,

        h.OccupiedSince ASC,

        h.buildingDetailsID

    OPTION (RECOMPILE);


    RETURN;

END



    /* ============================================================
   DETAIL MODE
   Financial Details - CLAIMS

   @section = finance
   @status  = CLAIMS

   Result Sets:
     1) Residents page
     2) Paging / Meta
     3) Available charge types
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL
    AND LOWER(ISNULL(@section, N'')) = N'finance'
    AND UPPER(ISNULL(@status, N'')) = N'CLAIMS'
)
BEGIN

    /* ========================================================
       Normalize inputs
       ======================================================== */

    DECLARE @FinanceSearchText NVARCHAR(4000) =
    NULLIF(LTRIM(RTRIM(@searchText)), N'');

DECLARE @FinanceSearchGeneralNo BIGINT =
    TRY_CONVERT(BIGINT, @FinanceSearchText);
    

    DECLARE @FinancePageNumber INT =
        CASE
            WHEN ISNULL(@pageNumber, 0) <= 0 THEN 1
            ELSE @pageNumber
        END;

    DECLARE @FinancePageSize INT =
        CASE
            WHEN @pageSize IN (20, 25, 50)
                THEN @pageSize
            ELSE 25
        END;

    DECLARE @FinanceSortKey NVARCHAR(30) =
        UPPER
        (
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(@sortKey)), N''),
                N'TOTAL_DESC'
            )
        );

    IF @FinanceSortKey NOT IN
    (
        N'TOTAL_DESC',
        N'TOTAL_ASC',
        N'LATEST',
        N'OLDEST'
    )
    BEGIN
        SET @FinanceSortKey = N'TOTAL_DESC';
    END;


    /* ========================================================
       STEP 1
       Financial aggregation ONLY

       مهم:
       لا يوجد هنا أي Join على Resident أو BuildingAction.
       ======================================================== */

    SELECT
          b.residentInfoID_FK AS residentInfoID

        , COUNT_BIG(*) AS BillsCount

        , CAST
          (
              SUM(ISNULL(b.TotalPrice, 0))
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , MAX(b.entryDate) AS LastClaimDate

    INTO #FinanceClaimsCore

    FROM #HCCFinEligibleBills b

    WHERE
        b.BillActive = 1
        AND b.residentInfoID_FK IS NOT NULL
        AND b.idaraID_FK = @targetIdaraID
        AND b.TotalPrice > 0

        AND
        (
            @billChargeTypeID IS NULL
            OR b.BillChargeTypeID_FK = @billChargeTypeID
        )

    GROUP BY
        b.residentInfoID_FK

   


    /* ========================================================
       Temp index
       ======================================================== */

    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceClaimsCore_Resident
    ON #FinanceClaimsCore
    (
        residentInfoID
    );


    /* ========================================================
       STEP 2
       Search

       لا نقرأ Resident View إطلاقاً إذا لم يوجد Search.
       ======================================================== */

    IF @FinanceSearchText IS NOT NULL
BEGIN

    /* ========================================================
       Exact General Number Search

       إذا كانت قيمة البحث رقمية نعاملها كرقم عام مباشرة،
       بدون CONVERT وبدون LIKE.
       ======================================================== */

    IF @FinanceSearchGeneralNo IS NOT NULL
    BEGIN

        DELETE fc

        FROM #FinanceClaimsCore fc

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM Housing.V_GetFullResidentDetails rd

            WHERE
                rd.residentInfoID =
                    fc.residentInfoID

                AND rd.generalNo_FK =
                    @FinanceSearchGeneralNo
        );

    END

    ELSE

    BEGIN

        /* ====================================================
           Text Search
           ==================================================== */

        DELETE fc

        FROM #FinanceClaimsCore fc

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM Housing.V_GetFullResidentDetails rd

            WHERE
                rd.residentInfoID =
                    fc.residentInfoID

                AND
                (
                       rd.FullName_A
                       LIKE N'%' + @FinanceSearchText + N'%'

                    OR rd.rankNameA
                       LIKE N'%' + @FinanceSearchText + N'%'

                    OR rd.militaryUnitName_A
                       LIKE N'%' + @FinanceSearchText + N'%'
                )
        );

    END;

END;


    /* ========================================================
       STEP 3
       Meta - Scan temp table once only
       ======================================================== */

    DECLARE @FinanceTotalRows BIGINT;
    DECLARE @FinanceTotalPages BIGINT;
    DECLARE @FinanceTotalClaims DECIMAL(18,2);
    DECLARE @FinanceBillsCount BIGINT;

    SELECT
          @FinanceTotalRows =
              COUNT_BIG(*)

        , @FinanceTotalClaims =
              CAST
              (
                  ISNULL(SUM(TotalClaims), 0)
                  AS DECIMAL(18,2)
              )

        , @FinanceBillsCount =
              ISNULL(SUM(BillsCount), 0)

    FROM #FinanceClaimsCore;


    SET @FinanceTotalPages =
        CASE
            WHEN @FinanceTotalRows = 0
                THEN 0

            ELSE
                (
                    @FinanceTotalRows
                    + @FinancePageSize
                    - 1
                ) / @FinancePageSize
        END;


    IF
    (
        @FinanceTotalPages > 0
        AND @FinancePageNumber > @FinanceTotalPages
    )
    BEGIN
        SET @FinancePageNumber =
            CONVERT(INT, @FinanceTotalPages);
    END;


    /* ========================================================
       STEP 4
       Sort + Pagination BEFORE Resident/Action joins
       ======================================================== */

    DECLARE @FinanceStartRow BIGINT =
        (
            CAST(@FinancePageNumber AS BIGINT) - 1
        )
        * @FinancePageSize
        + 1;

    DECLARE @FinanceEndRow BIGINT =
        @FinanceStartRow
        + @FinancePageSize
        - 1;


    ;WITH OrderedClaims AS
    (
        SELECT
              fc.residentInfoID
            , fc.TotalClaims
            , fc.BillsCount
            , fc.LastClaimDate

            , ROW_NUMBER() OVER
              (
                  ORDER BY

                      CASE
                          WHEN @FinanceSortKey = N'TOTAL_DESC'
                              THEN fc.TotalClaims
                      END DESC,

                      CASE
                          WHEN @FinanceSortKey = N'TOTAL_ASC'
                              THEN fc.TotalClaims
                      END ASC,

                      CASE
                          WHEN @FinanceSortKey = N'LATEST'
                              THEN fc.LastClaimDate
                      END DESC,

                      CASE
                          WHEN @FinanceSortKey = N'OLDEST'
                              THEN fc.LastClaimDate
                      END ASC,

                      fc.residentInfoID ASC
              ) AS PageRowNumber

        FROM #FinanceClaimsCore fc
    )

    SELECT
          PageRowNumber
        , residentInfoID
        , TotalClaims
        , BillsCount
        , LastClaimDate

    INTO #FinanceClaimsPage

    FROM OrderedClaims

    WHERE
        PageRowNumber
        BETWEEN @FinanceStartRow
            AND @FinanceEndRow;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceClaimsPage_Resident
    ON #FinanceClaimsPage
    (
        residentInfoID
    );


    /* ========================================================
       Result Set 1

       هنا فقط نقرأ بيانات المستفيد وآخر إجراء.
       الحد الأقصى الطبيعي الآن = 50 مستفيد.
       ======================================================== */

    SELECT
          p.residentInfoID

        /* Beneficiary */

        , rd.generalNo_FK AS GeneralNo
        , rd.rankNameA AS RankName
        , rd.FullName_A AS FullName
        , rd.militaryUnitName_A AS MilitaryUnitName

        /* Financial */

        , p.TotalClaims
        , p.BillsCount
        , p.LastClaimDate

        /* Last active housing action */

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM #FinanceClaimsPage p

    LEFT JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = p.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

    ORDER BY
        p.PageRowNumber;


    /* ========================================================
       Result Set 2
       Paging / Meta
       ======================================================== */

    SELECT
          @targetIdaraID AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A
              FROM dbo.Idara i
              WHERE i.idaraID =
                    @targetIdaraID
          ) AS IdaraName

        , N'CLAIMS' AS Mode

        , @FinanceSearchText
            AS SearchText

        , @billChargeTypeID
            AS BillChargeTypeID

        , @FinanceSortKey
            AS SortKey

        , @FinancePageNumber
            AS PageNumber

        , @FinancePageSize
            AS PageSize

        , @FinanceTotalRows
            AS TotalRows

        , @FinanceTotalPages
            AS TotalPages

        , @FinanceTotalClaims
            AS TotalClaims

        , @FinanceBillsCount
            AS BillsCount;


    /* ========================================================
       Result Set 3
       Dynamic charge types
       ======================================================== */

    SELECT
          ct.BillChargeTypeID
        , ct.BillChargeTypeName_A

    FROM Housing.BillChargeType ct

    WHERE
        ct.BillChargeTypeActive = 1

        AND EXISTS
        (
            SELECT 1

            FROM #HCCFinEligibleBills b

            WHERE
                b.BillChargeTypeID_FK =
                    ct.BillChargeTypeID

                AND b.idaraID_FK =
                    @targetIdaraID

                AND b.BillActive = 1

                AND b.residentInfoID_FK
                    IS NOT NULL

                    AND b.TotalPrice > 0
        )

    ORDER BY
        ct.BillChargeTypeID;


    DROP TABLE #FinanceClaimsPage;
    DROP TABLE #FinanceClaimsCore;

    RETURN;

END





/* ============================================================
   DETAIL MODE
   Financial Details - PAYMENTS

   @section = finance
   @status  = PAYMENTS

   Result Sets:
     1) Residents page
     2) Paging / Meta
     3) Available charge types
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL
    AND LOWER(ISNULL(@section, N'')) = N'finance'
    AND UPPER(ISNULL(@status, N'')) = N'PAYMENTS'
)
BEGIN

    /* ========================================================
       Normalize inputs
       ======================================================== */

    DECLARE @PaymentsSearchText NVARCHAR(4000) =
        NULLIF(LTRIM(RTRIM(@searchText)), N'');

    DECLARE @PaymentsSearchGeneralNo BIGINT =
        TRY_CONVERT(BIGINT, @PaymentsSearchText);

    DECLARE @PaymentsPageNumber INT =
        CASE
            WHEN ISNULL(@pageNumber, 0) <= 0 THEN 1
            ELSE @pageNumber
        END;

    DECLARE @PaymentsPageSize INT =
        CASE
            WHEN @pageSize IN (25, 50)
                THEN @pageSize
            ELSE 25
        END;

    DECLARE @PaymentsSortKey NVARCHAR(30) =
        UPPER
        (
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(@sortKey)), N''),
                N'TOTAL_DESC'
            )
        );

    IF @PaymentsSortKey NOT IN
    (
        N'TOTAL_DESC',
        N'TOTAL_ASC',
        N'LATEST',
        N'OLDEST'
    )
    BEGIN
        SET @PaymentsSortKey = N'TOTAL_DESC';
    END;


    /* ========================================================
       STEP 1
       Payments aggregated to Resident Level
       ======================================================== */

    SELECT
          p.residentInfoID_FK AS residentInfoID

        , COUNT_BIG(*) AS PaymentsCount

        , CAST
          (
              SUM(ISNULL(p.amount, 0))
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , MAX(d.paymentDate) AS LastPaymentDate

    INTO #FinancePaymentsCore

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    WHERE
        p.buildingPayementActive = 1

        AND d.deductActive = 1

        AND p.buildingPaymentLinkStatusID_FK
            IN (1, 2)

        AND p.residentInfoID_FK
            IS NOT NULL

        AND p.IdaraId_FK =
            @targetIdaraID

        AND
        (
            @billChargeTypeID IS NULL
            OR p.BillChargeTypeID_FK =
               @billChargeTypeID
        )

    GROUP BY
        p.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinancePaymentsCore_Resident
    ON #FinancePaymentsCore
    (
        residentInfoID
    );


    /* ========================================================
       STEP 2
       Search
       ======================================================== */

    IF @PaymentsSearchText IS NOT NULL
    BEGIN

        /* GeneralNo exact search */

        IF @PaymentsSearchGeneralNo IS NOT NULL
        BEGIN

            DELETE fp

            FROM #FinancePaymentsCore fp

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fp.residentInfoID

                    AND rd.generalNo_FK =
                        @PaymentsSearchGeneralNo
            );

        END
        ELSE
        BEGIN

            /* Text search */

            DELETE fp

            FROM #FinancePaymentsCore fp

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fp.residentInfoID

                    AND
                    (
                           rd.FullName_A
                           LIKE N'%' + @PaymentsSearchText + N'%'

                        OR rd.rankNameA
                           LIKE N'%' + @PaymentsSearchText + N'%'

                        OR rd.militaryUnitName_A
                           LIKE N'%' + @PaymentsSearchText + N'%'
                    )
            );

        END;

    END;


    /* ========================================================
       STEP 3
       Meta
       ======================================================== */

    DECLARE @PaymentsTotalRows BIGINT;
    DECLARE @PaymentsTotalPages BIGINT;
    DECLARE @PaymentsTotalAmount DECIMAL(18,2);
    DECLARE @PaymentsRowsCount BIGINT;

    SELECT
          @PaymentsTotalRows =
              COUNT_BIG(*)

        , @PaymentsTotalAmount =
              CAST
              (
                  ISNULL(SUM(TotalPayments), 0)
                  AS DECIMAL(18,2)
              )

        , @PaymentsRowsCount =
              ISNULL(SUM(PaymentsCount), 0)

    FROM #FinancePaymentsCore;


    SET @PaymentsTotalPages =
        CASE
            WHEN @PaymentsTotalRows = 0
                THEN 0

            ELSE
                (
                    @PaymentsTotalRows
                    + @PaymentsPageSize
                    - 1
                ) / @PaymentsPageSize
        END;


    IF
    (
        @PaymentsTotalPages > 0
        AND @PaymentsPageNumber > @PaymentsTotalPages
    )
    BEGIN
        SET @PaymentsPageNumber =
            CONVERT(INT, @PaymentsTotalPages);
    END;


    /* ========================================================
       STEP 4
       Sort + Pagination before detail joins
       ======================================================== */

    DECLARE @PaymentsStartRow BIGINT =
        (
            CAST(@PaymentsPageNumber AS BIGINT) - 1
        )
        * @PaymentsPageSize
        + 1;

    DECLARE @PaymentsEndRow BIGINT =
        @PaymentsStartRow
        + @PaymentsPageSize
        - 1;


    ;WITH OrderedPayments AS
    (
        SELECT
              fp.residentInfoID
            , fp.TotalPayments
            , fp.PaymentsCount
            , fp.LastPaymentDate

            , ROW_NUMBER() OVER
              (
                  ORDER BY

                      CASE
                          WHEN @PaymentsSortKey = N'TOTAL_DESC'
                              THEN fp.TotalPayments
                      END DESC,

                      CASE
                          WHEN @PaymentsSortKey = N'TOTAL_ASC'
                              THEN fp.TotalPayments
                      END ASC,

                      CASE
                          WHEN @PaymentsSortKey = N'LATEST'
                              THEN fp.LastPaymentDate
                      END DESC,

                      CASE
                          WHEN @PaymentsSortKey = N'OLDEST'
                              THEN fp.LastPaymentDate
                      END ASC,

                      fp.residentInfoID ASC

              ) AS PageRowNumber

        FROM #FinancePaymentsCore fp
    )

    SELECT
          PageRowNumber
        , residentInfoID
        , TotalPayments
        , PaymentsCount
        , LastPaymentDate

    INTO #FinancePaymentsPage

    FROM OrderedPayments

    WHERE
        PageRowNumber
        BETWEEN @PaymentsStartRow
            AND @PaymentsEndRow;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinancePaymentsPage_Resident
    ON #FinancePaymentsPage
    (
        residentInfoID
    );


    /* ========================================================
       Result Set 1
       ======================================================== */

    SELECT
          p.residentInfoID

        /* Beneficiary */

        , rd.generalNo_FK AS GeneralNo
        , rd.rankNameA AS RankName
        , rd.FullName_A AS FullName
        , rd.militaryUnitName_A AS MilitaryUnitName

        /* Payments */

        , p.TotalPayments
        , p.PaymentsCount
        , p.LastPaymentDate

        /* Last active housing action */

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM #FinancePaymentsPage p

    LEFT JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = p.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

    ORDER BY
        p.PageRowNumber;


    /* ========================================================
       Result Set 2
       Paging / Meta
       ======================================================== */

    SELECT
          @targetIdaraID AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A
              FROM dbo.Idara i
              WHERE i.idaraID =
                    @targetIdaraID
          ) AS IdaraName

        , N'PAYMENTS' AS Mode

        , @PaymentsSearchText
            AS SearchText

        , @billChargeTypeID
            AS BillChargeTypeID

        , @PaymentsSortKey
            AS SortKey

        , @PaymentsPageNumber
            AS PageNumber

        , @PaymentsPageSize
            AS PageSize

        , @PaymentsTotalRows
            AS TotalRows

        , @PaymentsTotalPages
            AS TotalPages

        , @PaymentsTotalAmount
            AS TotalPayments

        , @PaymentsRowsCount
            AS PaymentsCount;


    /* ========================================================
       Result Set 3
       Dynamic payment charge types
       ======================================================== */

    SELECT
          ct.BillChargeTypeID
        , ct.BillChargeTypeName_A

    FROM Housing.BillChargeType ct

    WHERE
        ct.BillChargeTypeActive = 1

        AND EXISTS
        (
            SELECT 1

            FROM #HCCFinEligiblePayments bp

            INNER JOIN Housing.DeductList dl
                ON dl.deductListID =
                   bp.deductListID_FK

            WHERE
                bp.BillChargeTypeID_FK =
                    ct.BillChargeTypeID

                AND bp.IdaraId_FK =
                    @targetIdaraID

                AND bp.buildingPayementActive = 1

                AND dl.deductActive = 1

                AND bp.buildingPaymentLinkStatusID_FK
                    IN (1, 2)

                AND bp.residentInfoID_FK
                    IS NOT NULL
        )

    ORDER BY
        ct.BillChargeTypeID;


    DROP TABLE #FinancePaymentsPage;
    DROP TABLE #FinancePaymentsCore;

    RETURN;

END





/* ============================================================
   DETAIL MODE
   Financial Details - DEFICIT

   @section = finance
   @status  = DEFICIT

   التصنيف على الرصيد النهائي للمستفيد عبر جميع الأنواع

   Result Sets:
     1) Residents page
     2) Paging / Meta
     3) Empty charge-types result (Not Applicable)
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL
    AND LOWER(ISNULL(@section, N'')) = N'finance'
    AND UPPER(ISNULL(@status, N'')) = N'DEFICIT'
)
BEGIN

    /* ========================================================
       Normalize inputs
       ======================================================== */

    DECLARE @DeficitSearchText NVARCHAR(4000) =
        NULLIF(LTRIM(RTRIM(@searchText)), N'');

    DECLARE @DeficitSearchGeneralNo BIGINT =
        TRY_CONVERT(BIGINT, @DeficitSearchText);

    DECLARE @DeficitPageNumber INT =
        CASE
            WHEN ISNULL(@pageNumber, 0) <= 0 THEN 1
            ELSE @pageNumber
        END;

    DECLARE @DeficitPageSize INT =
        CASE
            WHEN @pageSize IN (25, 50)
                THEN @pageSize
            ELSE 25
        END;

    DECLARE @DeficitSortKey NVARCHAR(30) =
        UPPER
        (
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(@sortKey)), N''),
                N'BALANCE_DESC'
            )
        );

    IF @DeficitSortKey NOT IN
    (
        N'BALANCE_DESC',
        N'BALANCE_ASC',
        N'CLAIM_NEWEST',
        N'PAYMENT_NEWEST'
    )
    BEGIN
        SET @DeficitSortKey = N'BALANCE_DESC';
    END;


    /* ========================================================
       STEP 1
       Claims aggregated per resident
       ALL charge types
       ======================================================== */

    SELECT
          b.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(b.TotalPrice, 0))
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , COUNT_BIG(*) AS ClaimsCount

        , MAX(b.entryDate) AS LastClaimDate

    INTO #DeficitClaims

    FROM #HCCFinEligibleBills b



WHERE
    b.BillActive = 1
    AND b.residentInfoID_FK IS NOT NULL
    AND b.TotalPrice > 0
    AND b.idaraID_FK = @targetIdaraID

    GROUP BY
        b.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_DeficitClaims_Resident
    ON #DeficitClaims
    (
        residentInfoID
    );


    /* ========================================================
       STEP 2
       Payments aggregated per resident
       ALL charge types
       ======================================================== */

    SELECT
          p.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(p.amount, 0))
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , COUNT_BIG(*) AS PaymentsCount

        , MAX(d.paymentDate) AS LastPaymentDate

    INTO #DeficitPayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    WHERE
        p.buildingPayementActive = 1

        AND d.deductActive = 1

        AND p.buildingPaymentLinkStatusID_FK
            IN (1, 2)

        AND p.residentInfoID_FK
            IS NOT NULL

        AND p.IdaraId_FK =
            @targetIdaraID

    GROUP BY
        p.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_DeficitPayments_Resident
    ON #DeficitPayments
    (
        residentInfoID
    );


    /* ========================================================
       STEP 3
       Final resident balance

       Deficit:
       TotalClaims > TotalPayments
       ======================================================== */

    SELECT
          COALESCE(c.residentInfoID, p.residentInfoID)
            AS residentInfoID

        , CAST
          (
              ISNULL(c.TotalClaims, 0)
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST
          (
              ISNULL(p.TotalPayments, 0)
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , CAST
          (
              ISNULL(c.TotalClaims, 0)
              - ISNULL(p.TotalPayments, 0)
              AS DECIMAL(18,2)
          ) AS DeficitAmount

        , ISNULL(c.ClaimsCount, 0)
            AS ClaimsCount

        , ISNULL(p.PaymentsCount, 0)
            AS PaymentsCount

        , c.LastClaimDate

        , p.LastPaymentDate

    INTO #FinanceDeficitCore

    FROM #DeficitClaims c

    FULL OUTER JOIN #DeficitPayments p
        ON p.residentInfoID =
           c.residentInfoID

    WHERE
        ISNULL(c.TotalClaims, 0)
        >
        ISNULL(p.TotalPayments, 0);


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceDeficitCore_Resident
    ON #FinanceDeficitCore
    (
        residentInfoID
    );


    /* ========================================================
       STEP 4
       Search
       ======================================================== */

    IF @DeficitSearchText IS NOT NULL
    BEGIN

        IF @DeficitSearchGeneralNo IS NOT NULL
        BEGIN

            DELETE fd

            FROM #FinanceDeficitCore fd

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fd.residentInfoID

                    AND rd.generalNo_FK =
                        @DeficitSearchGeneralNo
            );

        END
        ELSE
        BEGIN

            DELETE fd

            FROM #FinanceDeficitCore fd

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fd.residentInfoID

                    AND
                    (
                           rd.FullName_A
                           LIKE N'%' + @DeficitSearchText + N'%'

                        OR rd.rankNameA
                           LIKE N'%' + @DeficitSearchText + N'%'

                        OR rd.militaryUnitName_A
                           LIKE N'%' + @DeficitSearchText + N'%'
                    )
            );

        END;

    END;


    /* ========================================================
       STEP 5
       Meta
       ======================================================== */

    DECLARE @DeficitTotalRows BIGINT;
    DECLARE @DeficitTotalPages BIGINT;

    DECLARE @DeficitTotalAmount DECIMAL(18,2);
    DECLARE @DeficitTotalClaims DECIMAL(18,2);
    DECLARE @DeficitTotalPayments DECIMAL(18,2);

    DECLARE @DeficitClaimsCount BIGINT;
    DECLARE @DeficitPaymentsCount BIGINT;


    SELECT
          @DeficitTotalRows =
              COUNT_BIG(*)

        , @DeficitTotalAmount =
              CAST
              (
                  ISNULL(SUM(DeficitAmount), 0)
                  AS DECIMAL(18,2)
              )

        , @DeficitTotalClaims =
              CAST
              (
                  ISNULL(SUM(TotalClaims), 0)
                  AS DECIMAL(18,2)
              )

        , @DeficitTotalPayments =
              CAST
              (
                  ISNULL(SUM(TotalPayments), 0)
                  AS DECIMAL(18,2)
              )

        , @DeficitClaimsCount =
              ISNULL(SUM(ClaimsCount), 0)

        , @DeficitPaymentsCount =
              ISNULL(SUM(PaymentsCount), 0)

    FROM #FinanceDeficitCore;


    SET @DeficitTotalPages =
        CASE
            WHEN @DeficitTotalRows = 0
                THEN 0
            ELSE
                (
                    @DeficitTotalRows
                    + @DeficitPageSize
                    - 1
                ) / @DeficitPageSize
        END;


    IF
    (
        @DeficitTotalPages > 0
        AND @DeficitPageNumber > @DeficitTotalPages
    )
    BEGIN
        SET @DeficitPageNumber =
            CONVERT(INT, @DeficitTotalPages);
    END;


    /* ========================================================
       STEP 6
       Sort + Pagination
       ======================================================== */

    DECLARE @DeficitStartRow BIGINT =
        (
            CAST(@DeficitPageNumber AS BIGINT) - 1
        )
        * @DeficitPageSize
        + 1;

    DECLARE @DeficitEndRow BIGINT =
        @DeficitStartRow
        + @DeficitPageSize
        - 1;


    ;WITH OrderedDeficit AS
    (
        SELECT
              fd.residentInfoID
            , fd.TotalClaims
            , fd.TotalPayments
            , fd.DeficitAmount
            , fd.ClaimsCount
            , fd.PaymentsCount
            , fd.LastClaimDate
            , fd.LastPaymentDate

            , ROW_NUMBER() OVER
              (
                  ORDER BY

                      CASE
                          WHEN @DeficitSortKey = N'BALANCE_DESC'
                              THEN fd.DeficitAmount
                      END DESC,

                      CASE
                          WHEN @DeficitSortKey = N'BALANCE_ASC'
                              THEN fd.DeficitAmount
                      END ASC,

                      CASE
                          WHEN @DeficitSortKey = N'CLAIM_NEWEST'
                              THEN fd.LastClaimDate
                      END DESC,

                      CASE
                          WHEN @DeficitSortKey = N'PAYMENT_NEWEST'
                              THEN fd.LastPaymentDate
                      END DESC,

                      fd.residentInfoID ASC

              ) AS PageRowNumber

        FROM #FinanceDeficitCore fd
    )

    SELECT
          PageRowNumber
        , residentInfoID
        , TotalClaims
        , TotalPayments
        , DeficitAmount
        , ClaimsCount
        , PaymentsCount
        , LastClaimDate
        , LastPaymentDate

    INTO #FinanceDeficitPage

    FROM OrderedDeficit

    WHERE
        PageRowNumber
        BETWEEN @DeficitStartRow
            AND @DeficitEndRow;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceDeficitPage_Resident
    ON #FinanceDeficitPage
    (
        residentInfoID
    );


    /* ========================================================
       Result Set 1
       ======================================================== */

    SELECT
          p.residentInfoID

        , rd.generalNo_FK AS GeneralNo
        , rd.rankNameA AS RankName
        , rd.FullName_A AS FullName
        , rd.militaryUnitName_A AS MilitaryUnitName

        , p.TotalClaims
        , p.TotalPayments
        , p.DeficitAmount

        , p.ClaimsCount
        , p.PaymentsCount

        , p.LastClaimDate
        , p.LastPaymentDate

        /* Last active housing action */

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM #FinanceDeficitPage p

    LEFT JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = p.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

    ORDER BY
        p.PageRowNumber;


    /* ========================================================
       Result Set 2
       Paging / Meta
       ======================================================== */

    SELECT
          @targetIdaraID AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A
              FROM dbo.Idara i
              WHERE i.idaraID =
                    @targetIdaraID
          ) AS IdaraName

        , N'DEFICIT' AS Mode

        , @DeficitSearchText
            AS SearchText

        /* Not applicable for final beneficiary balance */
        , CAST(NULL AS INT)
            AS BillChargeTypeID

        , @DeficitSortKey
            AS SortKey

        , @DeficitPageNumber
            AS PageNumber

        , @DeficitPageSize
            AS PageSize

        , @DeficitTotalRows
            AS TotalRows

        , @DeficitTotalPages
            AS TotalPages

        , @DeficitTotalClaims
            AS TotalClaims

        , @DeficitTotalPayments
            AS TotalPayments

        , @DeficitTotalAmount
            AS DeficitAmount

        , @DeficitClaimsCount
            AS ClaimsCount

        , @DeficitPaymentsCount
            AS PaymentsCount;


    /* ========================================================
       Result Set 3

       Charge Type filter is intentionally NOT applicable
       to beneficiary final deficit classification.
       ======================================================== */

    SELECT
          CAST(NULL AS INT)
              AS BillChargeTypeID

        , CAST(NULL AS NVARCHAR(100))
              AS BillChargeTypeName_A

    WHERE 1 = 0;


    DROP TABLE #FinanceDeficitPage;
    DROP TABLE #FinanceDeficitCore;
    DROP TABLE #DeficitPayments;
    DROP TABLE #DeficitClaims;

    RETURN;

END




/* ============================================================
   DETAIL MODE
   Financial Details - SURPLUS

   @section = finance
   @status  = SURPLUS

   Final beneficiary balance across ALL charge types.

   Result Sets:
     1) Residents page
     2) Paging / Meta
     3) Empty charge-types result
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL
    AND LOWER(ISNULL(@section, N'')) = N'finance'
    AND UPPER(ISNULL(@status, N'')) = N'SURPLUS'
)
BEGIN

    /* ========================================================
       Normalize inputs
       ======================================================== */

    DECLARE @SurplusSearchText NVARCHAR(4000) =
        NULLIF(LTRIM(RTRIM(@searchText)), N'');

    DECLARE @SurplusSearchGeneralNo BIGINT =
        TRY_CONVERT(BIGINT, @SurplusSearchText);

    DECLARE @SurplusPageNumber INT =
        CASE
            WHEN ISNULL(@pageNumber, 0) <= 0 THEN 1
            ELSE @pageNumber
        END;

    DECLARE @SurplusPageSize INT =
        CASE
            WHEN @pageSize IN (25, 50)
                THEN @pageSize
            ELSE 25
        END;

    DECLARE @SurplusSortKey NVARCHAR(30) =
        UPPER
        (
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(@sortKey)), N''),
                N'BALANCE_DESC'
            )
        );

    IF @SurplusSortKey NOT IN
    (
        N'BALANCE_DESC',
        N'BALANCE_ASC',
        N'PAYMENT_NEWEST',
        N'CLAIM_NEWEST'
    )
    BEGIN
        SET @SurplusSortKey = N'BALANCE_DESC';
    END;


    /* ========================================================
       STEP 1
       Claims aggregated per resident
       ======================================================== */

    SELECT
          b.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(b.TotalPrice, 0))
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , COUNT_BIG(*) AS ClaimsCount

        , MAX(b.entryDate) AS LastClaimDate

    INTO #SurplusClaims

    FROM #HCCFinEligibleBills b

    WHERE
        
    b.BillActive = 1
    AND b.residentInfoID_FK IS NOT NULL
    AND b.TotalPrice > 0
    AND b.idaraID_FK = @targetIdaraID

    GROUP BY
        b.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_SurplusClaims_Resident
    ON #SurplusClaims
    (
        residentInfoID
    );


    /* ========================================================
       STEP 2
       Payments aggregated per resident
       ======================================================== */

    SELECT
          p.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(p.amount, 0))
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , COUNT_BIG(*) AS PaymentsCount

        , MAX(d.paymentDate) AS LastPaymentDate

    INTO #SurplusPayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    WHERE
        p.buildingPayementActive = 1

        AND d.deductActive = 1

        AND p.buildingPaymentLinkStatusID_FK
            IN (1, 2)

        AND p.residentInfoID_FK
            IS NOT NULL

        AND p.IdaraId_FK =
            @targetIdaraID

    GROUP BY
        p.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_SurplusPayments_Resident
    ON #SurplusPayments
    (
        residentInfoID
    );


    /* ========================================================
       STEP 3
       Final resident balance

       Surplus:
       TotalPayments > TotalClaims
       ======================================================== */

    SELECT
          COALESCE(c.residentInfoID, p.residentInfoID)
            AS residentInfoID

        , CAST
          (
              ISNULL(c.TotalClaims, 0)
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST
          (
              ISNULL(p.TotalPayments, 0)
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , CAST
          (
              ISNULL(p.TotalPayments, 0)
              - ISNULL(c.TotalClaims, 0)
              AS DECIMAL(18,2)
          ) AS SurplusAmount

        , ISNULL(c.ClaimsCount, 0)
            AS ClaimsCount

        , ISNULL(p.PaymentsCount, 0)
            AS PaymentsCount

        , c.LastClaimDate
        , p.LastPaymentDate

    INTO #FinanceSurplusCore

    FROM #SurplusClaims c

    FULL OUTER JOIN #SurplusPayments p
        ON p.residentInfoID =
           c.residentInfoID

    WHERE
        ISNULL(p.TotalPayments, 0)
        >
        ISNULL(c.TotalClaims, 0);


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceSurplusCore_Resident
    ON #FinanceSurplusCore
    (
        residentInfoID
    );


    /* ========================================================
       STEP 4
       Search
       ======================================================== */

    IF @SurplusSearchText IS NOT NULL
    BEGIN

        IF @SurplusSearchGeneralNo IS NOT NULL
        BEGIN

            DELETE fs
            FROM #FinanceSurplusCore fs

            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.V_GetFullResidentDetails rd
                WHERE
                    rd.residentInfoID = fs.residentInfoID
                    AND rd.generalNo_FK =
                        @SurplusSearchGeneralNo
            );

        END
        ELSE
        BEGIN

            DELETE fs
            FROM #FinanceSurplusCore fs

            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.V_GetFullResidentDetails rd
                WHERE
                    rd.residentInfoID = fs.residentInfoID

                    AND
                    (
                           rd.FullName_A
                           LIKE N'%' + @SurplusSearchText + N'%'

                        OR rd.rankNameA
                           LIKE N'%' + @SurplusSearchText + N'%'

                        OR rd.militaryUnitName_A
                           LIKE N'%' + @SurplusSearchText + N'%'
                    )
            );

        END;

    END;


    /* ========================================================
       STEP 5
       Meta
       ======================================================== */

    DECLARE @SurplusTotalRows BIGINT;
    DECLARE @SurplusTotalPages BIGINT;

    DECLARE @SurplusTotalAmount DECIMAL(18,2);
    DECLARE @SurplusTotalClaims DECIMAL(18,2);
    DECLARE @SurplusTotalPayments DECIMAL(18,2);

    DECLARE @SurplusClaimsCount BIGINT;
    DECLARE @SurplusPaymentsCount BIGINT;


    SELECT
          @SurplusTotalRows =
              COUNT_BIG(*)

        , @SurplusTotalAmount =
              CAST
              (
                  ISNULL(SUM(SurplusAmount), 0)
                  AS DECIMAL(18,2)
              )

        , @SurplusTotalClaims =
              CAST
              (
                  ISNULL(SUM(TotalClaims), 0)
                  AS DECIMAL(18,2)
              )

        , @SurplusTotalPayments =
              CAST
              (
                  ISNULL(SUM(TotalPayments), 0)
                  AS DECIMAL(18,2)
              )

        , @SurplusClaimsCount =
              ISNULL(SUM(ClaimsCount), 0)

        , @SurplusPaymentsCount =
              ISNULL(SUM(PaymentsCount), 0)

    FROM #FinanceSurplusCore;


    SET @SurplusTotalPages =
        CASE
            WHEN @SurplusTotalRows = 0
                THEN 0
            ELSE
                (
                    @SurplusTotalRows
                    + @SurplusPageSize
                    - 1
                ) / @SurplusPageSize
        END;


    IF
    (
        @SurplusTotalPages > 0
        AND @SurplusPageNumber > @SurplusTotalPages
    )
    BEGIN
        SET @SurplusPageNumber =
            CONVERT(INT, @SurplusTotalPages);
    END;


    /* ========================================================
       STEP 6
       Sort + Pagination
       ======================================================== */

    DECLARE @SurplusStartRow BIGINT =
        (
            CAST(@SurplusPageNumber AS BIGINT) - 1
        )
        * @SurplusPageSize
        + 1;

    DECLARE @SurplusEndRow BIGINT =
        @SurplusStartRow
        + @SurplusPageSize
        - 1;


    ;WITH OrderedSurplus AS
    (
        SELECT
              fs.residentInfoID
            , fs.TotalClaims
            , fs.TotalPayments
            , fs.SurplusAmount
            , fs.ClaimsCount
            , fs.PaymentsCount
            , fs.LastClaimDate
            , fs.LastPaymentDate

            , ROW_NUMBER() OVER
              (
                  ORDER BY

                      CASE
                          WHEN @SurplusSortKey = N'BALANCE_DESC'
                              THEN fs.SurplusAmount
                      END DESC,

                      CASE
                          WHEN @SurplusSortKey = N'BALANCE_ASC'
                              THEN fs.SurplusAmount
                      END ASC,

                      CASE
                          WHEN @SurplusSortKey = N'PAYMENT_NEWEST'
                              THEN fs.LastPaymentDate
                      END DESC,

                      CASE
                          WHEN @SurplusSortKey = N'CLAIM_NEWEST'
                              THEN fs.LastClaimDate
                      END DESC,

                      fs.residentInfoID ASC

              ) AS PageRowNumber

        FROM #FinanceSurplusCore fs
    )

    SELECT
          PageRowNumber
        , residentInfoID
        , TotalClaims
        , TotalPayments
        , SurplusAmount
        , ClaimsCount
        , PaymentsCount
        , LastClaimDate
        , LastPaymentDate

    INTO #FinanceSurplusPage

    FROM OrderedSurplus

    WHERE
        PageRowNumber
        BETWEEN @SurplusStartRow
            AND @SurplusEndRow;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceSurplusPage_Resident
    ON #FinanceSurplusPage
    (
        residentInfoID
    );


    /* ========================================================
       Result Set 1
       ======================================================== */

    SELECT
          p.residentInfoID

        , rd.generalNo_FK AS GeneralNo
        , rd.rankNameA AS RankName
        , rd.FullName_A AS FullName
        , rd.militaryUnitName_A AS MilitaryUnitName

        , p.TotalClaims
        , p.TotalPayments
        , p.SurplusAmount

        , p.ClaimsCount
        , p.PaymentsCount

        , p.LastClaimDate
        , p.LastPaymentDate

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM #FinanceSurplusPage p

    LEFT JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = p.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

    ORDER BY
        p.PageRowNumber;


    /* ========================================================
       Result Set 2
       Paging / Meta
       ======================================================== */

    SELECT
          @targetIdaraID AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A
              FROM dbo.Idara i
              WHERE i.idaraID =
                    @targetIdaraID
          ) AS IdaraName

        , N'SURPLUS' AS Mode

        , @SurplusSearchText
            AS SearchText

        , CAST(NULL AS INT)
            AS BillChargeTypeID

        , @SurplusSortKey
            AS SortKey

        , @SurplusPageNumber
            AS PageNumber

        , @SurplusPageSize
            AS PageSize

        , @SurplusTotalRows
            AS TotalRows

        , @SurplusTotalPages
            AS TotalPages

        , @SurplusTotalClaims
            AS TotalClaims

        , @SurplusTotalPayments
            AS TotalPayments

        , @SurplusTotalAmount
            AS SurplusAmount

        , @SurplusClaimsCount
            AS ClaimsCount

        , @SurplusPaymentsCount
            AS PaymentsCount;


    /* ========================================================
       Result Set 3
       Charge Type filter not applicable
       ======================================================== */

    SELECT
          CAST(NULL AS INT)
              AS BillChargeTypeID

        , CAST(NULL AS NVARCHAR(100))
              AS BillChargeTypeName_A

    WHERE 1 = 0;


    DROP TABLE #FinanceSurplusPage;
    DROP TABLE #FinanceSurplusCore;
    DROP TABLE #SurplusPayments;
    DROP TABLE #SurplusClaims;

    RETURN;

END




/* ============================================================
   DETAIL MODE
   Financial Details - BALANCED

   @section = finance
   @status  = BALANCED

   Final beneficiary balance across ALL charge types.

   Balanced:
     TotalClaims = TotalPayments
     AND actual financial amount > 0

   Result Sets:
     1) Residents page
     2) Paging / Meta
     3) Empty charge-types result
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL
    AND LOWER(ISNULL(@section, N'')) = N'finance'
    AND UPPER(ISNULL(@status, N'')) = N'BALANCED'
)
BEGIN

    /* ========================================================
       Normalize inputs
       ======================================================== */

    DECLARE @BalancedSearchText NVARCHAR(4000) =
        NULLIF(LTRIM(RTRIM(@searchText)), N'');

    DECLARE @BalancedSearchGeneralNo BIGINT =
        TRY_CONVERT(BIGINT, @BalancedSearchText);

    DECLARE @BalancedPageNumber INT =
        CASE
            WHEN ISNULL(@pageNumber, 0) <= 0 THEN 1
            ELSE @pageNumber
        END;

    DECLARE @BalancedPageSize INT =
        CASE
            WHEN @pageSize IN (25, 50)
                THEN @pageSize
            ELSE 25
        END;

    DECLARE @BalancedSortKey NVARCHAR(30) =
        UPPER
        (
            ISNULL
            (
                NULLIF(LTRIM(RTRIM(@sortKey)), N''),
                N'ACTIVITY_NEWEST'
            )
        );

    IF @BalancedSortKey NOT IN
    (
        N'ACTIVITY_NEWEST',
        N'TOTAL_DESC',
        N'TOTAL_ASC'
    )
    BEGIN
        SET @BalancedSortKey = N'ACTIVITY_NEWEST';
    END;


    /* ========================================================
       STEP 1
       Claims aggregated per resident
       ======================================================== */

    SELECT
          b.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(b.TotalPrice, 0))
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , COUNT_BIG(*) AS ClaimsCount

        , MAX(b.entryDate) AS LastClaimDate

    INTO #BalancedClaims

    FROM #HCCFinEligibleBills b

    WHERE
    b.BillActive = 1
    AND b.residentInfoID_FK IS NOT NULL
    AND b.TotalPrice > 0
    AND b.idaraID_FK = @targetIdaraID

    GROUP BY
        b.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_BalancedClaims_Resident
    ON #BalancedClaims
    (
        residentInfoID
    );


    /* ========================================================
       STEP 2
       Payments aggregated per resident
       ======================================================== */

    SELECT
          p.residentInfoID_FK AS residentInfoID

        , CAST
          (
              SUM(ISNULL(p.amount, 0))
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , COUNT_BIG(*) AS PaymentsCount

        , MAX(d.paymentDate) AS LastPaymentDate

    INTO #BalancedPayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    WHERE
        p.buildingPayementActive = 1
        AND d.deductActive = 1

        AND p.buildingPaymentLinkStatusID_FK
            IN (1, 2)

        AND p.residentInfoID_FK
            IS NOT NULL

        AND p.IdaraId_FK =
            @targetIdaraID

    GROUP BY
        p.residentInfoID_FK;


    CREATE UNIQUE CLUSTERED INDEX
        IX_BalancedPayments_Resident
    ON #BalancedPayments
    (
        residentInfoID
    );


    /* ========================================================
       STEP 3
       Balanced residents

       Important:
       0 = 0 is NOT balanced.
       ======================================================== */

    SELECT
          c.residentInfoID

        , c.TotalClaims

        , p.TotalPayments

        , c.ClaimsCount
        , p.PaymentsCount

        , c.LastClaimDate
        , p.LastPaymentDate

        , CASE
              WHEN p.LastPaymentDate IS NULL
                  THEN c.LastClaimDate

              WHEN c.LastClaimDate IS NULL
                  THEN CAST(p.LastPaymentDate AS DATETIME)

              WHEN c.LastClaimDate
                   >= CAST(p.LastPaymentDate AS DATETIME)
                  THEN c.LastClaimDate

              ELSE CAST(p.LastPaymentDate AS DATETIME)
          END AS LastFinancialActivityDate

    INTO #FinanceBalancedCore

    FROM #BalancedClaims c

    INNER JOIN #BalancedPayments p
        ON p.residentInfoID =
           c.residentInfoID

    WHERE
        c.TotalClaims = p.TotalPayments

        AND c.TotalClaims > 0;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceBalancedCore_Resident
    ON #FinanceBalancedCore
    (
        residentInfoID
    );


    /* ========================================================
       STEP 4
       Search
       ======================================================== */

    IF @BalancedSearchText IS NOT NULL
    BEGIN

        IF @BalancedSearchGeneralNo IS NOT NULL
        BEGIN

            DELETE fb

            FROM #FinanceBalancedCore fb

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fb.residentInfoID

                    AND rd.generalNo_FK =
                        @BalancedSearchGeneralNo
            );

        END
        ELSE
        BEGIN

            DELETE fb

            FROM #FinanceBalancedCore fb

            WHERE NOT EXISTS
            (
                SELECT 1

                FROM Housing.V_GetFullResidentDetails rd

                WHERE
                    rd.residentInfoID =
                        fb.residentInfoID

                    AND
                    (
                           rd.FullName_A
                           LIKE N'%' + @BalancedSearchText + N'%'

                        OR rd.rankNameA
                           LIKE N'%' + @BalancedSearchText + N'%'

                        OR rd.militaryUnitName_A
                           LIKE N'%' + @BalancedSearchText + N'%'
                    )
            );

        END;

    END;


    /* ========================================================
       STEP 5
       Meta
       ======================================================== */

    DECLARE @BalancedTotalRows BIGINT;
    DECLARE @BalancedTotalPages BIGINT;

    DECLARE @BalancedTotalClaims DECIMAL(18,2);
    DECLARE @BalancedTotalPayments DECIMAL(18,2);

    DECLARE @BalancedClaimsCount BIGINT;
    DECLARE @BalancedPaymentsCount BIGINT;


    SELECT
          @BalancedTotalRows =
              COUNT_BIG(*)

        , @BalancedTotalClaims =
              CAST
              (
                  ISNULL(SUM(TotalClaims), 0)
                  AS DECIMAL(18,2)
              )

        , @BalancedTotalPayments =
              CAST
              (
                  ISNULL(SUM(TotalPayments), 0)
                  AS DECIMAL(18,2)
              )

        , @BalancedClaimsCount =
              ISNULL(SUM(ClaimsCount), 0)

        , @BalancedPaymentsCount =
              ISNULL(SUM(PaymentsCount), 0)

    FROM #FinanceBalancedCore;


    SET @BalancedTotalPages =
        CASE
            WHEN @BalancedTotalRows = 0
                THEN 0
            ELSE
                (
                    @BalancedTotalRows
                    + @BalancedPageSize
                    - 1
                ) / @BalancedPageSize
        END;


    IF
    (
        @BalancedTotalPages > 0
        AND @BalancedPageNumber > @BalancedTotalPages
    )
    BEGIN
        SET @BalancedPageNumber =
            CONVERT(INT, @BalancedTotalPages);
    END;


    /* ========================================================
       STEP 6
       Sort + Pagination
       ======================================================== */

    DECLARE @BalancedStartRow BIGINT =
        (
            CAST(@BalancedPageNumber AS BIGINT) - 1
        )
        * @BalancedPageSize
        + 1;

    DECLARE @BalancedEndRow BIGINT =
        @BalancedStartRow
        + @BalancedPageSize
        - 1;


    ;WITH OrderedBalanced AS
    (
        SELECT
              fb.residentInfoID
            , fb.TotalClaims
            , fb.TotalPayments
            , fb.ClaimsCount
            , fb.PaymentsCount
            , fb.LastClaimDate
            , fb.LastPaymentDate
            , fb.LastFinancialActivityDate

            , ROW_NUMBER() OVER
              (
                  ORDER BY

                      CASE
                          WHEN @BalancedSortKey = N'ACTIVITY_NEWEST'
                              THEN fb.LastFinancialActivityDate
                      END DESC,

                      CASE
                          WHEN @BalancedSortKey = N'TOTAL_DESC'
                              THEN fb.TotalClaims
                      END DESC,

                      CASE
                          WHEN @BalancedSortKey = N'TOTAL_ASC'
                              THEN fb.TotalClaims
                      END ASC,

                      fb.residentInfoID ASC

              ) AS PageRowNumber

        FROM #FinanceBalancedCore fb
    )

    SELECT
          PageRowNumber
        , residentInfoID
        , TotalClaims
        , TotalPayments
        , ClaimsCount
        , PaymentsCount
        , LastClaimDate
        , LastPaymentDate
        , LastFinancialActivityDate

    INTO #FinanceBalancedPage

    FROM OrderedBalanced

    WHERE
        PageRowNumber
        BETWEEN @BalancedStartRow
            AND @BalancedEndRow;


    CREATE UNIQUE CLUSTERED INDEX
        IX_FinanceBalancedPage_Resident
    ON #FinanceBalancedPage
    (
        residentInfoID
    );


    /* ========================================================
       Result Set 1
       ======================================================== */

    SELECT
          p.residentInfoID

        , rd.generalNo_FK AS GeneralNo
        , rd.rankNameA AS RankName
        , rd.FullName_A AS FullName
        , rd.militaryUnitName_A AS MilitaryUnitName

        , p.TotalClaims
        , p.TotalPayments

        , p.ClaimsCount
        , p.PaymentsCount

        , p.LastClaimDate
        , p.LastPaymentDate
        , p.LastFinancialActivityDate

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM #FinanceBalancedPage p

    LEFT JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           p.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = p.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

    ORDER BY
        p.PageRowNumber;


    /* ========================================================
       Result Set 2
       Paging / Meta
       ======================================================== */

    SELECT
          @targetIdaraID AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A
              FROM dbo.Idara i
              WHERE i.idaraID =
                    @targetIdaraID
          ) AS IdaraName

        , N'BALANCED' AS Mode

        , @BalancedSearchText
            AS SearchText

        , CAST(NULL AS INT)
            AS BillChargeTypeID

        , @BalancedSortKey
            AS SortKey

        , @BalancedPageNumber
            AS PageNumber

        , @BalancedPageSize
            AS PageSize

        , @BalancedTotalRows
            AS TotalRows

        , @BalancedTotalPages
            AS TotalPages

        , @BalancedTotalClaims
            AS TotalClaims

        , @BalancedTotalPayments
            AS TotalPayments

        , @BalancedClaimsCount
            AS ClaimsCount

        , @BalancedPaymentsCount
            AS PaymentsCount;


    /* ========================================================
       Result Set 3
       Charge Type filter not applicable
       ======================================================== */

    SELECT
          CAST(NULL AS INT)
              AS BillChargeTypeID

        , CAST(NULL AS NVARCHAR(100))
              AS BillChargeTypeName_A

    WHERE 1 = 0;


    DROP TABLE #FinanceBalancedPage;
    DROP TABLE #FinanceBalancedCore;
    DROP TABLE #BalancedPayments;
    DROP TABLE #BalancedClaims;

    RETURN;

END





/* ============================================================
   DETAIL MODE
   Resident Financial Details

   @section = finance
   @status  = RESIDENT

   parameter_01 = targetIdaraID
   parameter_02 = finance
   parameter_03 = RESIDENT
   parameter_09 = residentInfoID

   Result Sets:
     1) Beneficiary + final financial position
     2) Financial summary by charge type
     3) Claims transactions
     4) Payment transactions
   ============================================================ */

IF
(
    @targetIdaraID IS NOT NULL

    AND @residentInfoID IS NOT NULL

    AND @residentInfoID > 0

    AND LOWER(ISNULL(@section, N'')) =
        N'finance'

    AND UPPER(ISNULL(@status, N'')) =
        N'RESIDENT'
)
BEGIN

    /* ========================================================
       STEP 1
       Claims
       Actual positive financial claims only
       ======================================================== */

    SELECT
          b.BillsID

        , b.BillNumber

        , b.BillChargeTypeID_FK
            AS BillChargeTypeID

        , ISNULL
          (
              ct.BillChargeTypeName_A,
              N'غير محدد'
          ) AS BillChargeTypeName

        , CAST
          (
              b.TotalPrice
              AS DECIMAL(18,2)
          ) AS Amount

        , b.PeriodMonth

        , b.PeriodYear

        , b.BillsFromDate

        , b.BillsToDate

        , b.buildingDetailsID
            AS BuildingDetailsID

        , COALESCE
          (
              NULLIF
              (
                  LTRIM
                  (
                      RTRIM(
                          b.buildingDetailsNo
                      )
                  ),
                  N''
              ),

              bd.buildingDetailsNo
          ) AS BuildingDetailsNo

        , b.PenaltyReason

        , b.entryDate
            AS ClaimEntryDate

    INTO #ResidentFinanceClaims

    FROM #HCCFinEligibleBills b

    LEFT JOIN Housing.BillChargeType ct
        ON ct.BillChargeTypeID =
           b.BillChargeTypeID_FK

    LEFT JOIN Housing.V_GetGeneralListForBuilding bd
        ON bd.buildingDetailsID =
           b.buildingDetailsID

    WHERE
        b.BillActive = 1

        AND b.residentInfoID_FK =
            @residentInfoID

        AND b.idaraID_FK =
            @targetIdaraID

        AND b.TotalPrice > 0;



    /* ========================================================
       STEP 2
       Payments

       Important:
       Same approved financial scope as Dashboard.

       Do NOT infer a building when payment building is empty.
       0 / empty / invalid = NULL.
       ======================================================== */

    SELECT
          p.paymentID

        , p.BillChargeTypeID_FK
            AS BillChargeTypeID

        , ISNULL
          (
              ct.BillChargeTypeName_A,
              N'غير محدد'
          ) AS BillChargeTypeName

        , CAST
          (
              ISNULL(p.amount, 0)
              AS DECIMAL(18,2)
          ) AS Amount

        , d.paymentDate
            AS PaymentDate

        , d.paymentNo
            AS PaymentNo

        , d.deductName
            AS DeductName

        , d.description
            AS PaymentDescription

        , parsed.BuildingDetailsID

        , bd.buildingDetailsNo
            AS BuildingDetailsNo

        , p.entryDate
            AS PaymentEntryDate

    INTO #ResidentFinancePayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    LEFT JOIN Housing.BillChargeType ct
        ON ct.BillChargeTypeID =
           p.BillChargeTypeID_FK

    OUTER APPLY
    (
        SELECT
            CASE
                WHEN TRY_CONVERT
                     (
                         BIGINT,
                         NULLIF
                         (
                             LTRIM
                             (
                                 RTRIM(
                                     p.buildingDetailsID_FK
                                 )
                             ),
                             N''
                         )
                     ) > 0

                THEN TRY_CONVERT
                     (
                         BIGINT,
                         NULLIF
                         (
                             LTRIM
                             (
                                 RTRIM(
                                     p.buildingDetailsID_FK
                                 )
                             ),
                             N''
                         )
                     )

                ELSE NULL

            END AS BuildingDetailsID

    ) parsed

    LEFT JOIN Housing.V_GetGeneralListForBuilding bd
        ON bd.buildingDetailsID =
           parsed.BuildingDetailsID

    WHERE
        d.deductActive = 1

        AND p.buildingPayementActive = 1

        AND p.buildingPaymentLinkStatusID_FK
            IN (1, 2)

        AND p.residentInfoID_FK =
            @residentInfoID

        AND p.IdaraId_FK =
            @targetIdaraID;



    /* ========================================================
       RESULT SET 1
       Beneficiary + Final Financial Position
       ======================================================== */

    ;WITH FinancialTotals AS
    (
        SELECT
              CAST
              (
                  ISNULL
                  (
                      (
                          SELECT
                              SUM(c.Amount)

                          FROM #ResidentFinanceClaims c
                      ),
                      0
                  )
                  AS DECIMAL(18,2)
              ) AS TotalClaims


            , CAST
              (
                  ISNULL
                  (
                      (
                          SELECT
                              SUM(p.Amount)

                          FROM #ResidentFinancePayments p
                      ),
                      0
                  )
                  AS DECIMAL(18,2)
              ) AS TotalPayments


            , (
                  SELECT COUNT_BIG(*)
                  FROM #ResidentFinanceClaims
              ) AS ClaimsCount


            , (
                  SELECT COUNT_BIG(*)
                  FROM #ResidentFinancePayments
              ) AS PaymentsCount


            , (
                  SELECT
                      MAX(c.ClaimEntryDate)

                  FROM #ResidentFinanceClaims c
              ) AS LastClaimDate


            , (
                  SELECT
                      MAX(p.PaymentDate)

                  FROM #ResidentFinancePayments p
              ) AS LastPaymentDate
    )

    SELECT
          rd.residentInfoID

        , rd.generalNo_FK
            AS GeneralNo

        , rd.rankNameA
            AS RankName

        , rd.FullName_A
            AS FullName

        , rd.militaryUnitName_A
            AS MilitaryUnitName


        /* ----------------------------------------------------
           Selected financial administration
           ---------------------------------------------------- */

        , @targetIdaraID
            AS IdaraID

        , (
              SELECT TOP (1)
                  i.idaraLongName_A

              FROM dbo.Idara i

              WHERE
                  i.idaraID =
                      @targetIdaraID
          ) AS IdaraName


        /* ----------------------------------------------------
           Final financial position
           ---------------------------------------------------- */

        , ft.TotalClaims

        , ft.TotalPayments

        , CAST
          (
              ft.TotalClaims -
              ft.TotalPayments
              AS DECIMAL(18,2)
          ) AS BalanceDifference


        , CASE

              WHEN
                  ft.TotalClaims >
                  ft.TotalPayments

                  THEN N'عجز'


              WHEN
                  ft.TotalPayments >
                  ft.TotalClaims

                  THEN N'فائض'


              ELSE N'متوازن'

          END AS FinancialStatus


        , CAST
          (
              ABS
              (
                  ft.TotalClaims -
                  ft.TotalPayments
              )
              AS DECIMAL(18,2)
          ) AS BalanceAmount


        , ft.ClaimsCount

        , ft.PaymentsCount

        , ft.LastClaimDate

        , ft.LastPaymentDate


        /* ----------------------------------------------------
           Last active housing action
           ---------------------------------------------------- */

        , a.buildingActionID
            AS LastActionID

        , a.buildingActionTypeID_FK
            AS LastActionTypeID

        , ISNULL
          (
              at.buildingActionTypeName_A,
              N'لا يوجد إجراء سكن نشط'
          ) AS HousingStatus

        -- Display-only: prefer last action building; otherwise latest actual occupancy.
        -- Do not change LastActionID / LastActionTypeID / LastActionDate.
        , COALESCE(
              a.buildingDetailsID_FK,
              lastOccupied.buildingDetailsID_FK
          ) AS LastActionBuildingID

        , COALESCE(
              NULLIF(LTRIM(RTRIM(a.buildingDetailsNo)), N''),
              currentActionBuilding.buildingDetailsNo,
              lastOccupied.buildingDetailsNo
          ) AS LastActionBuildingNo

        , COALESCE
          (
              a.buildingActionDate,
              a.entryDate
          ) AS LastActionDate

    FROM Housing.V_GetFullResidentDetails rd

    CROSS JOIN FinancialTotals ft

    LEFT JOIN Housing.V_LastActionForResident lar
        ON lar.residentInfoID =
           rd.residentInfoID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID =
           lar.buildingActionID

    LEFT JOIN Housing.BuildingActionType at
        ON at.buildingActionTypeID =
           a.buildingActionTypeID_FK

    -- Populate the number for the current action building if the action has an ID only.
    LEFT JOIN Housing.BuildingDetails currentActionBuilding
        ON currentActionBuilding.buildingDetailsID = a.buildingDetailsID_FK

    -- If the last action has no building, display the latest ACTUAL occupancy
    -- for this resident in the requested administration (not a proposed allocation).
    OUTER APPLY
    (
        SELECT TOP (1)
              occ.buildingDetailsID_FK
            , COALESCE(
                  NULLIF(LTRIM(RTRIM(occ.buildingDetailsNo)), N''),
                  occBuilding.buildingDetailsNo
              ) AS buildingDetailsNo
        FROM Housing.BuildingAction occ
        INNER JOIN Housing.BuildingDetails occBuilding
            ON occBuilding.buildingDetailsID = occ.buildingDetailsID_FK
        WHERE occ.residentInfoID_FK = rd.residentInfoID
          AND occ.buildingActionTypeID_FK = 2
          AND occ.buildingActionDate IS NOT NULL
          AND occBuilding.IdaraId_FK = @targetIdaraID
          AND a.buildingDetailsID_FK IS NULL
        ORDER BY occ.buildingActionDate DESC, occ.buildingActionID DESC
    ) lastOccupied

        WHERE
        rd.residentInfoID =
            @residentInfoID

        AND
        (
              (SELECT COUNT_BIG(*)
               FROM #ResidentFinanceClaims)

            + (SELECT COUNT_BIG(*)
               FROM #ResidentFinancePayments)
        ) > 0;



    /* ========================================================
       RESULT SET 2
       Financial Summary By Charge Type

       This is ANALYTICAL by type.
       It does NOT replace final beneficiary classification.
       ======================================================== */

    ;WITH ClaimsByType AS
    (
        SELECT
              c.BillChargeTypeID

            , MAX(
                  c.BillChargeTypeName
              ) AS BillChargeTypeName

            , COUNT_BIG(*)
                AS ClaimsCount

            , CAST
              (
                  SUM(c.Amount)
                  AS DECIMAL(18,2)
              ) AS TotalClaims

        FROM #ResidentFinanceClaims c

        GROUP BY
            c.BillChargeTypeID
    ),

    PaymentsByType AS
    (
        SELECT
              p.BillChargeTypeID

            , MAX(
                  p.BillChargeTypeName
              ) AS BillChargeTypeName

            , COUNT_BIG(*)
                AS PaymentsCount

            , CAST
              (
                  SUM(p.Amount)
                  AS DECIMAL(18,2)
              ) AS TotalPayments

        FROM #ResidentFinancePayments p

        GROUP BY
            p.BillChargeTypeID
    )

    SELECT
          COALESCE
          (
              c.BillChargeTypeID,
              p.BillChargeTypeID
          ) AS BillChargeTypeID

        , COALESCE
          (
              c.BillChargeTypeName,
              p.BillChargeTypeName,
              N'غير محدد'
          ) AS BillChargeTypeName

        , ISNULL
          (
              c.ClaimsCount,
              0
          ) AS ClaimsCount

        , ISNULL
          (
              p.PaymentsCount,
              0
          ) AS PaymentsCount

        , CAST
          (
              ISNULL(
                  c.TotalClaims,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST
          (
              ISNULL(
                  p.TotalPayments,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , CAST
          (
              ISNULL(
                  c.TotalClaims,
                  0
              )
              -
              ISNULL(
                  p.TotalPayments,
                  0
              )
              AS DECIMAL(18,2)
          ) AS Difference

        , CAST
          (
              ABS
              (
                  ISNULL(
                      c.TotalClaims,
                      0
                  )
                  -
                  ISNULL(
                      p.TotalPayments,
                      0
                  )
              )
              AS DECIMAL(18,2)
          ) AS BalanceAmountByType

        , CASE

              WHEN
                  ISNULL(c.TotalClaims, 0)
                  >
                  ISNULL(p.TotalPayments, 0)

                  THEN N'عجز'


              WHEN
                  ISNULL(p.TotalPayments, 0)
                  >
                  ISNULL(c.TotalClaims, 0)

                  THEN N'فائض'


              ELSE N'متوازن'

          END AS StatusByType

    FROM ClaimsByType c

    FULL OUTER JOIN PaymentsByType p
        ON p.BillChargeTypeID =
           c.BillChargeTypeID

    ORDER BY
        COALESCE
        (
            c.BillChargeTypeID,
            p.BillChargeTypeID
        );



    /* ========================================================
       RESULT SET 3
       Claims Transactions
       ======================================================== */

    SELECT
          c.BillsID

        , c.BillNumber

        , c.BillChargeTypeID

        , c.BillChargeTypeName

        , c.Amount

        , c.PeriodMonth

        , c.PeriodYear

        , c.BillsFromDate

        , c.BillsToDate

        , c.BuildingDetailsID

        , c.BuildingDetailsNo

        , c.PenaltyReason

        , c.ClaimEntryDate

    FROM #ResidentFinanceClaims c

    ORDER BY
          c.ClaimEntryDate DESC
        , c.BillsID DESC;



    /* ========================================================
       RESULT SET 4
       Payment Transactions
       ======================================================== */

    SELECT
          p.paymentID

        , p.BillChargeTypeID

        , p.BillChargeTypeName

        , p.Amount

        , p.PaymentDate

        , p.PaymentNo

        , p.DeductName

        , p.PaymentDescription

        , p.BuildingDetailsID

        , p.BuildingDetailsNo

        , p.PaymentEntryDate

    FROM #ResidentFinancePayments p

    ORDER BY
          p.PaymentDate DESC
        , p.paymentID DESC;



    /* ========================================================
       Cleanup
       ======================================================== */

    DROP TABLE #ResidentFinancePayments;

    DROP TABLE #ResidentFinanceClaims;

    RETURN;

END

    /* ============================================================
       DETAIL MODE - Completed Housing Workflow Cycles (dt10 provenance)
       @section=completedcycle, @status=ALLOCATION/HOUSING/EXTEND/EXIT
       @pageNumber/@pageSize=server-side pagination
       Result set 1 = completed cycles; result set 2 = paging/average
       Permission resultset is prepended by dbo.Masters_DataLoad.
       Same eligibility, dates, and beginning-selection as dt10.
       ============================================================ */
IF @targetIdaraID IS NOT NULL
   AND LOWER(ISNULL(@section, N'')) = N'completedcycle'
BEGIN
    -- Same interim department restriction as WaitingListDetails.
    -- Reconcile later with the separately approved CanViewAllHousingDashboard flag.
    IF @idaraID IS NULL OR @targetIdaraID <> @idaraID
    BEGIN
        THROW 50021, N'غير مصرح بعرض دورات هذه الإدارة', 1;
    END;

    IF UPPER(ISNULL(@status, N'')) NOT IN
       (N'ALLOCATION', N'HOUSING', N'EXTEND', N'EXIT')
    BEGIN
        THROW 50022, N'نوع دورة إجراءات الإسكان غير صحيح', 1;
    END;

    DECLARE @CWWorkflow NVARCHAR(30) = UPPER(@status);
    DECLARE @CWPageNumber INT = CASE
        WHEN @pageNumber BETWEEN 1 AND 1000000 THEN @pageNumber
        ELSE 1 END;
    DECLARE @CWPageSize INT = CASE
        WHEN @pageSize IN (25, 50) THEN @pageSize ELSE 25 END;
    DECLARE @CWOffset BIGINT = (CONVERT(BIGINT, @CWPageNumber) - 1) * @CWPageSize;

    ;WITH NativeCompletedEnds AS
    (
        SELECT
              e.IdaraId_FK AS idaraID
            , e.buildingActionID
            , e.buildingActionTypeID_FK AS EndActionTypeID
            , e.entryDate AS EndEntryDate
            , e.residentInfoID_FK
            , e.generalNo_FK
            , e.buildingDetailsID_FK
            , e.buildingDetailsNo
        FROM Housing.BuildingAction e
        INNER JOIN dbo.Idara i
            ON i.idaraID = e.IdaraId_FK
           AND i.idaraShowInCommandCenter = 1
        WHERE e.IdaraId_FK = @targetIdaraID
          AND e.buildingActionTypeID_FK IN (45, 42, 2, 24, 3)
          AND COALESCE(e.buildingActionExtraText5, N'')
              NOT IN (N'LEGACY', N'MIGRATION_GENERATED')
          AND e.entryDate IS NOT NULL
    ),
    CompletedCycles AS
    (
        SELECT
              e.idaraID
            , CASE
                  WHEN e.EndActionTypeID IN (45, 42) THEN N'ALLOCATION'
                  WHEN e.EndActionTypeID = 2 THEN N'HOUSING'
                  WHEN e.EndActionTypeID = 24 THEN N'EXTEND'
                  WHEN e.EndActionTypeID = 3 THEN N'EXIT'
              END AS WorkflowKey
            , e.EndActionTypeID
            , s.StartActionID
            , e.buildingActionID AS EndActionID
            , s.StartEntryDate
            , e.EndEntryDate
            , e.residentInfoID_FK
            , e.generalNo_FK
            , e.buildingDetailsID_FK
            , e.buildingDetailsNo
            , DATEDIFF_BIG(SECOND, s.StartEntryDate, e.EndEntryDate) AS DurationSeconds
            , CAST(
                  DATEDIFF_BIG(SECOND, s.StartEntryDate, e.EndEntryDate) / 86400.0
                  AS DECIMAL(18, 6)
              ) AS DurationDays
        FROM NativeCompletedEnds e
        OUTER APPLY
        (
            SELECT TOP (1)
                  c.buildingActionID AS StartActionID
                , c.entryDate AS StartEntryDate
            FROM Housing.fn_BuildingAction_ChainToRoot(e.buildingActionID) c
            INNER JOIN Housing.BuildingAction startOrigin
                ON startOrigin.buildingActionID = c.buildingActionID
            WHERE c.buildingActionTypeID_FK = CASE
                    WHEN e.EndActionTypeID IN (45, 42) THEN 27
                    WHEN e.EndActionTypeID = 2 THEN 45
                    WHEN e.EndActionTypeID = 24 THEN 48
                    WHEN e.EndActionTypeID = 3 THEN 54
                END
              AND COALESCE(startOrigin.buildingActionExtraText5, N'')
                   <> N'MIGRATION_GENERATED'
              AND c.entryDate IS NOT NULL
              AND c.entryDate <= e.EndEntryDate
            ORDER BY c.entryDate ASC, c.Lvl ASC, c.buildingActionID ASC
        ) s
        WHERE s.StartActionID IS NOT NULL
    )
    SELECT
          c.idaraID
        , c.WorkflowKey
        , c.EndActionTypeID
        , c.StartActionID
        , c.EndActionID
        , c.StartEntryDate
        , c.EndEntryDate
        , c.residentInfoID_FK
        , c.generalNo_FK
        , c.buildingDetailsID_FK
        , c.buildingDetailsNo
        , c.DurationSeconds
        , c.DurationDays
    INTO #HCC_CompletedWorkflowCycles
    FROM CompletedCycles c
    WHERE c.WorkflowKey = @CWWorkflow;

    ;WITH OrderedCycles AS
    (
        SELECT
              ROW_NUMBER() OVER
              (ORDER BY EndEntryDate DESC, EndActionID DESC) AS RowNo
            , *
        FROM #HCC_CompletedWorkflowCycles
    )
    SELECT
          RowNo
        , idaraID
        , WorkflowKey
        , EndActionTypeID
        , CASE
              WHEN EndActionTypeID = 45 THEN N'وافق المستفيد على المنزل'
              WHEN EndActionTypeID = 42 THEN N'إلغاء أحقية السكن'
              WHEN EndActionTypeID = 2 THEN N'تم التسكين'
              WHEN EndActionTypeID = 24 THEN N'ساكن وممهل (إجراء 24)'
              WHEN EndActionTypeID = 3 THEN N'تم الإخلاء'
              ELSE N'—'
          END AS EndOutcome
        , StartActionID
        , EndActionID
        , StartEntryDate
        , EndEntryDate
        , residentInfoID_FK
        , generalNo_FK
        , buildingDetailsID_FK
        , buildingDetailsNo
        , DurationSeconds
        , DurationDays
    FROM OrderedCycles
    WHERE RowNo > @CWOffset AND RowNo <= @CWOffset + @CWPageSize
    ORDER BY RowNo;

    SELECT
          COUNT(*) AS TotalRows
        , @CWPageNumber AS PageNumber
        , @CWPageSize AS PageSize
        , CAST(CEILING(COUNT(*) * 1.0 / @CWPageSize) AS INT) AS TotalPages
        , CAST(AVG(DurationDays) AS DECIMAL(18, 6)) AS AverageDays
    FROM #HCC_CompletedWorkflowCycles;

    DROP TABLE IF EXISTS #HCC_CompletedWorkflowCycles;
    RETURN;
END;

    /* ============================================================
       DETAIL MODE
       Current Housing Procedures
       ============================================================ */
/* ============================================================
   DETAIL MODE
   Current Housing Procedures

   @section = procedure

   @status:
       ALL
       ALLOCATION
       EXTEND
       EXIT
   ============================================================ */

IF
(
       @targetIdaraID IS NOT NULL
   AND LOWER(ISNULL(@section, N'')) = N'procedure'
   AND UPPER(ISNULL(@status, N'')) IN
       (
           N'ALL',
           N'ALLOCATION',
           N'HOUSING',
           N'EXTEND',
           N'EXIT'
       )
)
BEGIN

    ;WITH CurrentProcedures AS
    (
        SELECT

              b.IdaraId_FK
                  AS idaraID

            , b.buildingDetailsID
            , b.buildingDetailsNo


            /* =====================================================
               Beneficiary
               ===================================================== */

            , a.residentInfoID_FK
            , a.generalNo_FK

            , rd.ResidentRankName
            , rd.ResidentFullName
            , rd.ResidentMilitaryUnit


            /* =====================================================
               Current Action
               ===================================================== */

            , a.buildingActionID
                  AS CurrentActionID

            , a.buildingActionParentID
                  AS CurrentActionParentID

            , a.buildingActionTypeID_FK
                  AS CurrentActionTypeID

            , ISNULL
              (
                  at.buildingActionTypeName_A,
                  N'غير محدد'
              ) AS CurrentActionTypeName


            /* =====================================================
               Dates
               ===================================================== */

            , a.entryDate
                  AS CurrentEntryDate

            , a.buildingActionDate
                  AS CurrentActionDate

            , a.buildingActionDecisionNo
            , a.buildingActionDecisionDate

            , a.buildingActionFromDate
            , a.buildingActionToDate

            , a.buildingActionNote


            /*
               مدة الحالة الحالية تعتمد أساسًا على entryDate
               لأنه يمثل وقت دخول الحالة إلى النظام.

               buildingActionDate قد يكون تاريخ أعمال فقط
               وبدون دقة الوقت.
            */

            , COALESCE
              (
                  a.entryDate,
                  a.buildingActionDate
              ) AS CurrentStatusSince


            , CASE

                  WHEN a.entryDate IS NOT NULL
                      THEN N'ENTRY_DATE'

                  WHEN a.buildingActionDate IS NOT NULL
                      THEN N'ACTION_DATE_FALLBACK'

                  ELSE N'UNKNOWN'

              END AS CurrentStatusDateSource


            /* =====================================================
               Procedure Group

               نفس تعريف dt7 / dt8 / dt9 حرفيًا
               ===================================================== */

            , CASE

                  WHEN a.buildingActionTypeID_FK IN (38, 40)
    THEN N'ALLOCATION'

WHEN a.buildingActionTypeID_FK IN (45, 46, 47)
    THEN N'HOUSING'


                  WHEN a.buildingActionTypeID_FK IN
                       (
                           48,
                           49,
                           51,
                           52,
                           53,
                           61
                       )
                      THEN N'EXTEND'


                  WHEN a.buildingActionTypeID_FK IN
                       (
                           54,
                           56,
                           57,
                           58,
                           59,
                           60
                       )
                      THEN N'EXIT'

              END AS ProcedureGroupKey


            , CASE

                  WHEN a.buildingActionTypeID_FK IN (38, 40)
    THEN N'إجراءات التخصيص'

WHEN a.buildingActionTypeID_FK IN (45, 46, 47)
    THEN N'إجراءات التسكين'


                  WHEN a.buildingActionTypeID_FK IN
                       (
                           48,
                           49,
                           51,
                           52,
                           53,
                           61
                       )
                      THEN N'إجراءات الإمهال'


                  WHEN a.buildingActionTypeID_FK IN
                       (
                           54,
                           56,
                           57,
                           58,
                           59,
                           60
                       )
                      THEN N'إجراءات الإخلاء'

              END AS ProcedureGroupName


            /* =====================================================
               Current Action Source
               ===================================================== */

            , CASE

                  WHEN a.buildingActionExtraText5 = N'LEGACY'
                      THEN N'LEGACY_COPIED'

                  WHEN a.buildingActionExtraText5 = N'MIGRATION_GENERATED'
                      THEN N'MIGRATION_GENERATED'

                  -- Other values (including NULL) are not reserved migration markers.
                  ELSE N'OPERATIONAL_NATIVE'

              END AS CurrentActionSourceType


            , CASE

                  WHEN a.buildingActionExtraText5 = N'MIGRATION_GENERATED'
                      THEN 1

                  ELSE 0

              END AS IsMoveDataGenerated


        FROM Housing.BuildingDetails b


        INNER JOIN Housing.V_LastActionForBuilding la
            ON la.buildingDetailsID =
               b.buildingDetailsID


        INNER JOIN Housing.BuildingAction a
            ON a.buildingActionID =
               la.buildingActionID


        LEFT JOIN Housing.BuildingActionType at
            ON at.buildingActionTypeID =
               a.buildingActionTypeID_FK


        /*
           نستخدم OUTER APPLY بدل JOIN مباشر حتى لا يؤدي
           وجود أكثر من ResidentDetails إلى تكرار الإجراء
           وبالتالي تغيير أرقام الكروت.
        */
        OUTER APPLY
        (
            SELECT TOP (1)

                  r.rankNameA
                      AS ResidentRankName

                , r.FullName_A
                      AS ResidentFullName

                , r.militaryUnitName_A
                      AS ResidentMilitaryUnit

            FROM Housing.V_GetFullResidentDetails r

            WHERE
                r.residentInfoID =
                    a.residentInfoID_FK

            ORDER BY
                r.residentDetailsID DESC

        ) rd


        WHERE

                b.IdaraId_FK =
                    @targetIdaraID


            AND b.buildingDetailsActive = 1


            AND b.buildingUtilityTypeID_FK IN
                (
                    1,
                    11,
                    13,
                    15
                )


            AND a.buildingActionActive = 1


            AND a.buildingActionTypeID_FK IN
                (
                    /* Allocation */

                    38,
                    40,
                    45,
                    46,
                    47,


                    /* Extend */

                    48,
                    49,
                    51,
                    52,
                    53,
                    61,


                    /* Exit */

                    54,
                    56,
                    57,
                    58,
                    59,
                    60
                )
    ),


    /* ============================================================
       Apply requested card filter
       ============================================================ */

    FilteredProcedures AS
    (
        SELECT
            p.*

        FROM CurrentProcedures p

        WHERE

               UPPER(@status) = N'ALL'

            OR p.ProcedureGroupKey =
               UPPER(@status)
    )


    /* ============================================================
       Final Result
       ============================================================ */

    SELECT

          p.idaraID


        /* ========================================================
           Row number
           ======================================================== */

        , ROW_NUMBER() OVER
          (
              ORDER BY

                  CASE p.ProcedureGroupKey

                      WHEN N'ALLOCATION'
                          THEN 1

                      WHEN N'EXTEND'
                          THEN 2

                      WHEN N'EXIT'
                          THEN 3

                      ELSE 9

                  END,


                  CASE
                      WHEN s.StartEntryDate IS NULL
                          THEN 1

                      ELSE 0
                  END,


                  s.StartEntryDate ASC,

                  p.CurrentStatusSince ASC,

                  p.buildingDetailsID

          ) AS RowNo


        /* ========================================================
           Procedure
           ======================================================== */

        , p.ProcedureGroupKey

        , p.ProcedureGroupName


        /* ========================================================
           Beneficiary
           ======================================================== */

        , p.residentInfoID_FK

        , p.generalNo_FK

        , p.ResidentRankName

        , p.ResidentFullName

        , p.ResidentMilitaryUnit


        /* ========================================================
           Building
           ======================================================== */

        , p.buildingDetailsID

        , p.buildingDetailsNo


        /* ========================================================
           Procedure Start
           ======================================================== */

        , s.StartActionID

        , s.StartActionTypeID

        , sat.buildingActionTypeName_A
              AS StartActionTypeName


        , s.StartEntryDate
              AS ProcedureStartDate


        , CASE

              WHEN s.StartActionID IS NOT NULL
                  THEN N'CURRENT_SYSTEM'

              ELSE N'PRE_CURRENT_SYSTEM'

          END AS ProcedureStartSource


        /* ========================================================
           Total Procedure Duration
           ======================================================== */

        , CASE

              WHEN s.StartEntryDate IS NULL
                  THEN NULL

              ELSE DATEDIFF_BIG
                   (
                       SECOND,
                       s.StartEntryDate,
                       GETDATE()
                   )

          END AS ProcedureElapsedSeconds


        , CASE

              WHEN s.StartEntryDate IS NULL
                  THEN NULL

              ELSE CAST
                   (
                       DATEDIFF_BIG
                       (
                           SECOND,
                           s.StartEntryDate,
                           GETDATE()
                       )
                       / 86400.0

                       AS DECIMAL(18,6)
                   )

          END AS ProcedureElapsedDays


        /* ========================================================
           Current Action
           ======================================================== */

        , p.CurrentActionID

        , p.CurrentActionParentID

        , p.CurrentActionTypeID

        , p.CurrentActionTypeName

        , p.CurrentActionSourceType

        , p.IsMoveDataGenerated


        /* ========================================================
           Current Action Dates
           ======================================================== */

        , p.CurrentEntryDate

        , p.CurrentActionDate

        , p.CurrentStatusSince

        , p.CurrentStatusDateSource


        /* ========================================================
           Current Status Duration
           ======================================================== */

        , CASE

              WHEN p.CurrentStatusSince IS NULL
                  THEN NULL

              ELSE DATEDIFF_BIG
                   (
                       SECOND,
                       p.CurrentStatusSince,
                       GETDATE()
                   )

          END AS CurrentStatusElapsedSeconds


        , CASE

              WHEN p.CurrentStatusSince IS NULL
                  THEN NULL

              ELSE CAST
                   (
                       DATEDIFF_BIG
                       (
                           SECOND,
                           p.CurrentStatusSince,
                           GETDATE()
                       )
                       / 86400.0

                       AS DECIMAL(18,6)
                   )

          END AS CurrentStatusElapsedDays


        /* ========================================================
           Business Information
           ======================================================== */

        , p.buildingActionDecisionNo

        , p.buildingActionDecisionDate

        , p.buildingActionFromDate

        , p.buildingActionToDate

        , p.buildingActionNote


        /* ========================================================
           Verification / UI counters
           ======================================================== */

        , COUNT(*) OVER ()
              AS FilteredTotalCount


        , COUNT(*) OVER
          (
              PARTITION BY
                  p.ProcedureGroupKey

          ) AS ProcedureGroupCount


    FROM FilteredProcedures p


    /* ============================================================
       Find beginning of the SAME active procedure chain

       Allocation = 38
       Extend     = 48
       Exit       = 54

       البداية يجب أن تكون:
       - Native
       - ليست Legacy
       - ليست MoveData
       ============================================================ */

    OUTER APPLY
    (
        SELECT TOP (1)

              c.buildingActionID
                  AS StartActionID


            , c.buildingActionTypeID_FK
                  AS StartActionTypeID


            , c.entryDate
                  AS StartEntryDate


        FROM Housing.fn_BuildingAction_ChainToRoot
             (
                 p.CurrentActionID
             ) c


        INNER JOIN Housing.BuildingAction startOrigin
            ON startOrigin.buildingActionID =
               c.buildingActionID


        WHERE

                c.buildingActionTypeID_FK =
CASE p.ProcedureGroupKey

    WHEN N'ALLOCATION'
        THEN 38

    WHEN N'HOUSING'
        THEN 45

    WHEN N'EXTEND'
        THEN 48

    WHEN N'EXIT'
        THEN 54

END


            /*
               This card shows current operational procedure duration only.
               Exclude both frozen legacy and migration-generated starts.
               NULL/other values are allowed and do not define origin on their own.
            */
            AND COALESCE(startOrigin.buildingActionExtraText5, N'')
                NOT IN (N'LEGACY', N'MIGRATION_GENERATED')


            AND c.entryDate IS NOT NULL


        /*
           إذا تكرر Action البداية داخل نفس السلسلة
           بسبب تعديل أو إعادة تنفيذ، نستخدم أول بداية
           تشغيلية حقيقية.
        */
        ORDER BY

              c.entryDate ASC

            , c.Lvl ASC

            , c.buildingActionID ASC

    ) s


    LEFT JOIN Housing.BuildingActionType sat
        ON sat.buildingActionTypeID =
           s.StartActionTypeID


    /* ============================================================
       Stable ordering
       ============================================================ */

    ORDER BY

          CASE p.ProcedureGroupKey

    WHEN N'ALLOCATION' THEN 1
    WHEN N'HOUSING'    THEN 2
    WHEN N'EXTEND'     THEN 3
    WHEN N'EXIT'       THEN 4

    ELSE 9

END


        , CASE

              WHEN s.StartEntryDate IS NULL
                  THEN 1

              ELSE 0

          END


        , s.StartEntryDate ASC

        , p.CurrentStatusSince ASC

        , p.buildingDetailsID;


    RETURN;
END


    -------------------------------------------------------------------
    -- الإدارات المفعلة للظهور في لوحة القيادة
    -------------------------------------------------------------------
    SELECT
          i.idaraID
        , i.idaraClass_A
        , i.idaraClass_E
        , i.idaraLongName_A
        , i.idaraShortName_A
        , i.idaraLongName_E
        , i.idaraShortName_E
        , i.idaraCode
        , i.organizationID_FK
    FROM dbo.Idara i
    WHERE i.idaraShowInCommandCenter = 1
    ORDER BY i.idaraID ASC;



    -------------------------------------------------------------------
-- Housing Occupancy By Idara
-------------------------------------------------------------------
-------------------------------------------------------------------
-- Housing Occupancy By Idara
-------------------------------------------------------------------
SELECT
      i.idaraID

    , COUNT(b.buildingDetailsID) AS TotalHousingUnits

    , SUM(
        CASE
            WHEN b.buildingDetailsID IS NOT NULL
             AND t.buildingActionRoot = 2
            THEN 1
            ELSE 0
        END
      ) AS OccupiedHousingUnits

    , SUM(
        CASE
            WHEN b.buildingDetailsID IS NOT NULL
             AND ISNULL(t.buildingActionRoot, 0) <> 2
            THEN 1
            ELSE 0
        END
      ) AS UnoccupiedHousingUnits

    , CAST(
        CASE
            WHEN COUNT(b.buildingDetailsID) = 0 THEN 0
            ELSE
                SUM(
                    CASE
                        WHEN b.buildingDetailsID IS NOT NULL
                         AND t.buildingActionRoot = 2
                        THEN 1
                        ELSE 0
                    END
                ) * 100.0
                / COUNT(b.buildingDetailsID)
        END
        AS DECIMAL(6,2)
      ) AS OccupancyPercent

FROM dbo.Idara i

LEFT JOIN Housing.BuildingDetails b
    ON b.IdaraId_FK = i.idaraID
   AND b.buildingDetailsActive = 1
   AND b.buildingUtilityTypeID_FK IN (1, 11, 13, 15)

LEFT JOIN Housing.V_LastActionForBuilding la
    ON la.buildingDetailsID = b.buildingDetailsID

LEFT JOIN Housing.BuildingAction a
    ON a.buildingActionID = la.buildingActionID

LEFT JOIN Housing.BuildingActionType t
    ON t.buildingActionTypeID = a.buildingActionTypeID_FK

WHERE i.idaraShowInCommandCenter = 1

GROUP BY
    i.idaraID

ORDER BY
    i.idaraID ASC;



    ---------------------------------------------------------------
-- قوائم الانتظار الحالية لكل إدارة
---------------------------------------------------------------
;WITH WaitingCandidates AS
(
    SELECT
        w.IdaraId AS idaraID,
        w.ActionID,
        c.idara_FK AS ClassIdaraID,

        CASE
            WHEN w.LastActionTypeID IS NULL
              OR w.LastActionTypeID IN (34, 35)
                THEN N'WAITING'

            WHEN w.LastActionTypeID IN
                 (26, 27, 38, 39, 40, 41, 43, 44)
                THEN N'ALLOCATION'

            WHEN w.LastActionTypeID IN (45, 46, 47)
                THEN N'HOUSING'
        END AS WaitingStage,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                w.IdaraId,
                w.residentInfoID,
                w.WaitingClassID
            ORDER BY
                COALESCE(
                    w.LastActionEntryDate,
                    w.LastActionDate,
                    w.ActionDate
                ) DESC,
                COALESCE(
                    w.LastActionID,
                    w.ActionID
                ) DESC,
                w.ActionID DESC
        ) AS ClassRecordRank

    FROM Housing.V_WaitingList w

    INNER JOIN Housing.WaitingClass c
        ON c.waitingClassID = w.WaitingClassID

    INNER JOIN dbo.Idara di
        ON di.idaraID = w.IdaraId
       AND di.idaraShowInCommandCenter = 1

    WHERE w.residentInfoID IS NOT NULL
      AND w.WaitingClassID IS NOT NULL
      AND c.waitingClassActive = 1

      AND
      (
          (
              c.idara_FK IS NULL
              AND w.ActionTypeID = 1
          )
          OR
          (
              c.idara_FK = w.IdaraId
              AND w.ActionTypeID IN (1, 7, 25)
          )
      )

      AND
      (
          w.LastActionTypeID IS NULL
          OR w.LastActionTypeID IN
          (
              34, 35,
              26, 27, 38, 39, 40, 41, 43, 44,
              45, 46, 47
          )
      )
),
WaitingChosen AS
(
    SELECT
        idaraID,
        ActionID,
        ClassIdaraID,
        WaitingStage
    FROM WaitingCandidates
    WHERE ClassRecordRank = 1
      AND
      (
          ClassIdaraID IS NULL
          OR WaitingStage IN (N'WAITING', N'HOUSING')
      )
)
SELECT
    i.idaraID,

    -- اسم التوافق مع MVC الحالي.
    -- المقصود به المنتظرون فعليًا فقط.
    COUNT(
        CASE
            WHEN w.WaitingStage = N'WAITING' THEN 1
        END
    ) AS CurrentWaitingCount,

    COUNT(w.ActionID) AS TotalWaitingRecords,

    COUNT(
        CASE
            WHEN w.WaitingStage = N'WAITING' THEN 1
        END
    ) AS WaitingResidents,

    COUNT(
        CASE
            WHEN w.WaitingStage = N'ALLOCATION' THEN 1
        END
    ) AS AllocationResidents,

    COUNT(
        CASE
            WHEN w.WaitingStage = N'HOUSING' THEN 1
        END
    ) AS HousingResidents,

    COUNT(
        CASE
            WHEN w.WaitingStage = N'WAITING'
             AND w.ClassIdaraID IS NULL
                THEN 1
        END
    ) AS MainWaitingResidents,

    COUNT(
        CASE
            WHEN w.WaitingStage = N'WAITING'
             AND w.ClassIdaraID IS NOT NULL
                THEN 1
        END
    ) AS SideWaitingResidents

FROM dbo.Idara i

LEFT JOIN WaitingChosen w
    ON w.idaraID = i.idaraID

WHERE i.idaraShowInCommandCenter = 1

GROUP BY i.idaraID
ORDER BY i.idaraID ASC
OPTION (RECOMPILE);




---------------------------------------------------------------
-- dt4
-- Financial Efficiency By Idara
-- الكفاءة المالية مبنية على رصيد كل مستفيد على حدة
---------------------------------------------------------------

;WITH ClaimsByBeneficiary AS
(
    SELECT
          b.idaraID_FK AS idaraID
        , b.residentInfoID_FK

        , SUM(
            ISNULL(
                b.TotalPrice,
                0
            )
          ) AS TotalClaims

    FROM #HCCFinEligibleBills b

    WHERE
        b.BillActive = 1

        AND
        b.residentInfoID_FK IS NOT NULL

        AND
        b.TotalPrice > 0

    GROUP BY
          b.idaraID_FK
        , b.residentInfoID_FK
),

PaymentsByBeneficiary AS
(
    SELECT
          p.IdaraId_FK AS idaraID
        , p.residentInfoID_FK

        , SUM(
            ISNULL(
                p.amount,
                0
            )
          ) AS TotalPayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    WHERE
        d.deductActive = 1

        AND
        p.buildingPayementActive = 1

        AND
        p.residentInfoID_FK IS NOT NULL

        AND
        p.buildingPaymentLinkStatusID_FK IN
        (
            1,
            2
        )

    GROUP BY
          p.IdaraId_FK
        , p.residentInfoID_FK
),

BeneficiaryBalances AS
(
    SELECT
          COALESCE(
              c.idaraID,
              p.idaraID
          ) AS idaraID

        , COALESCE(
              c.residentInfoID_FK,
              p.residentInfoID_FK
          ) AS residentInfoID_FK

        , CAST(
              ISNULL(
                  c.TotalClaims,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST(
              ISNULL(
                  p.TotalPayments,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , CAST(
              ISNULL(
                  c.TotalClaims,
                  0
              )
              -
              ISNULL(
                  p.TotalPayments,
                  0
              )
              AS DECIMAL(18,2)
          ) AS BalanceDifference

    FROM ClaimsByBeneficiary c

    FULL OUTER JOIN PaymentsByBeneficiary p

        ON p.idaraID =
           c.idaraID

       AND p.residentInfoID_FK =
           c.residentInfoID_FK
),

ActiveBeneficiaryBalances AS
(
    SELECT
          idaraID
        , residentInfoID_FK
        , TotalClaims
        , TotalPayments
        , BalanceDifference

    FROM BeneficiaryBalances

    WHERE
           TotalClaims <> 0
        OR TotalPayments <> 0
),

FinancialByIdara AS
(
    SELECT
          idaraID

        ------------------------------------------------------
        -- جميع المستفيدين الذين لديهم حركة مالية
        ------------------------------------------------------
        , COUNT(*) AS FinancialBeneficiariesCount

        ------------------------------------------------------
        -- متوازن
        ------------------------------------------------------
        , SUM(
            CASE
                WHEN TotalClaims = TotalPayments
                    THEN 1
                ELSE 0
            END
          ) AS BalancedBeneficiariesCount

        ------------------------------------------------------
        -- عجز: مطالباته أكبر من سداده
        ------------------------------------------------------
        , SUM(
            CASE
                WHEN TotalClaims > TotalPayments
                    THEN 1
                ELSE 0
            END
          ) AS DeficitBeneficiariesCount

        ------------------------------------------------------
        -- فائض: سداده أكبر من مطالباته
        ------------------------------------------------------
        , SUM(
            CASE
                WHEN TotalPayments > TotalClaims
                    THEN 1
                ELSE 0
            END
          ) AS SurplusBeneficiariesCount

        ------------------------------------------------------
        -- إجمالي المطالبات والسدادات
        ------------------------------------------------------
        , SUM(
            TotalClaims
          ) AS TotalClaims

        , SUM(
            TotalPayments
          ) AS TotalPayments

        ------------------------------------------------------
        -- المبالغ المطلوب تحصيلها
        ------------------------------------------------------
        , SUM(
            CASE
                WHEN TotalClaims > TotalPayments
                    THEN
                        TotalClaims -
                        TotalPayments

                ELSE 0
            END
          ) AS AmountToCollect

        ------------------------------------------------------
        -- المبالغ المطلوب إعادتها
        ------------------------------------------------------
        , SUM(
            CASE
                WHEN TotalPayments > TotalClaims
                    THEN
                        TotalPayments -
                        TotalClaims

                ELSE 0
            END
          ) AS AmountToRefund

        ------------------------------------------------------
        -- مجموع الفجوات المالية الفردية
        ------------------------------------------------------
        , SUM(
            ABS(
                TotalClaims -
                TotalPayments
            )
          ) AS TotalFinancialGap

    FROM ActiveBeneficiaryBalances

    GROUP BY
        idaraID
)

SELECT
      i.idaraID
    , i.idaraLongName_A

    ----------------------------------------------------------
    -- المستفيدون
    ----------------------------------------------------------
    , ISNULL(
        f.FinancialBeneficiariesCount,
        0
      ) AS FinancialBeneficiariesCount

    , ISNULL(
        f.BalancedBeneficiariesCount,
        0
      ) AS BalancedBeneficiariesCount

    , ISNULL(
        f.DeficitBeneficiariesCount,
        0
      ) AS DeficitBeneficiariesCount

    , ISNULL(
        f.SurplusBeneficiariesCount,
        0
      ) AS SurplusBeneficiariesCount

    ----------------------------------------------------------
    -- الإجماليات المالية
    ----------------------------------------------------------
    , CAST(
        ISNULL(
            f.TotalClaims,
            0
        )
        AS DECIMAL(18,2)
      ) AS TotalClaims

    , CAST(
        ISNULL(
            f.TotalPayments,
            0
        )
        AS DECIMAL(18,2)
      ) AS TotalPayments

    ----------------------------------------------------------
    -- مطلوب التحصيل / الإعادة
    ----------------------------------------------------------
    , CAST(
        ISNULL(
            f.AmountToCollect,
            0
        )
        AS DECIMAL(18,2)
      ) AS AmountToCollect

    , CAST(
        ISNULL(
            f.AmountToRefund,
            0
        )
        AS DECIMAL(18,2)
      ) AS AmountToRefund

    ----------------------------------------------------------
    -- مجموع الفجوة المالية
    ----------------------------------------------------------
    , CAST(
        ISNULL(
            f.TotalFinancialGap,
            0
        )
        AS DECIMAL(18,2)
      ) AS TotalFinancialGap

    ----------------------------------------------------------
    -- صافي المركز المالي
    --
    -- سالب = عجز إجمالي
    -- موجب = فائض إجمالي
    -- صفر  = متوازن إجمالاً
    ----------------------------------------------------------
    , CAST(
        ISNULL(
            f.TotalPayments,
            0
        )
        -
        ISNULL(
            f.TotalClaims,
            0
        )
        AS DECIMAL(18,2)
      ) AS NetFinancialPosition

    ----------------------------------------------------------
    -- نسبة المستفيدين المتوازنين
    ----------------------------------------------------------
    , CAST(
        CASE

            WHEN
                ISNULL(
                    f.FinancialBeneficiariesCount,
                    0
                ) = 0
                THEN NULL

            ELSE
                f.BalancedBeneficiariesCount
                * 100.0
                /
                f.FinancialBeneficiariesCount

        END
        AS DECIMAL(6,2)
      ) AS BalancedBeneficiariesPercent

    ----------------------------------------------------------
    -- الكفاءة المالية
    --
    -- تعتمد على مجموع الفروقات الفردية للمستفيدين
    -- ولا تسمح لفائض مستفيد بإخفاء عجز مستفيد آخر
    ----------------------------------------------------------
    , CAST(
        CASE

            --------------------------------------------------
            -- لا توجد حركة مالية
            --------------------------------------------------
            WHEN
                ISNULL(
                    f.FinancialBeneficiariesCount,
                    0
                ) = 0
                THEN NULL

            --------------------------------------------------
            -- سدادات بدون مطالبات
            --------------------------------------------------
            WHEN
                ISNULL(
                    f.TotalClaims,
                    0
                ) = 0

                AND
                ISNULL(
                    f.TotalPayments,
                    0
                ) <> 0
                THEN 0.0

            --------------------------------------------------
            -- حماية إضافية
            --------------------------------------------------
            WHEN
                ISNULL(
                    f.TotalClaims,
                    0
                ) = 0
                THEN NULL

            --------------------------------------------------
            -- إذا وصلت الفجوة إلى قيمة المطالبات أو تجاوزتها
            --------------------------------------------------
            WHEN
                ISNULL(
                    f.TotalFinancialGap,
                    0
                )
                >=
                f.TotalClaims
                THEN 0.0

            --------------------------------------------------
            -- الكفاءة
            --------------------------------------------------
            ELSE
                100.0
                -
                (
                    f.TotalFinancialGap
                    * 100.0
                    /
                    f.TotalClaims
                )

        END
        AS DECIMAL(6,2)
      ) AS FinancialEfficiencyPercent

FROM dbo.Idara i

LEFT JOIN FinancialByIdara f
    ON f.idaraID =
       i.idaraID

WHERE
    i.idaraShowInCommandCenter = 1

ORDER BY
    i.idaraID;



---------------------------------------------------------------
-- Housing Occupancy By Military Location
-- dt5
---------------------------------------------------------------
SELECT
      i.idaraID
    , b.militaryLocationID_FK
    , ISNULL(m.militaryLocationName_A, N'غير محدد')
        AS militaryLocationName_A

    , COUNT(b.buildingDetailsID)
        AS TotalHousingUnits

    , SUM(
        CASE
            WHEN t.buildingActionRoot = 2
                THEN 1
            ELSE 0
        END
      ) AS OccupiedHousingUnits

    , SUM(
        CASE
            WHEN ISNULL(t.buildingActionRoot, 0) <> 2
                THEN 1
            ELSE 0
        END
      ) AS UnoccupiedHousingUnits

    , CAST(
        CASE
            WHEN COUNT(b.buildingDetailsID) = 0
                THEN 0
            ELSE
                SUM(
                    CASE
                        WHEN t.buildingActionRoot = 2
                            THEN 1
                        ELSE 0
                    END
                ) * 100.0
                / COUNT(b.buildingDetailsID)
        END
        AS DECIMAL(6,2)
      ) AS OccupancyPercent

FROM dbo.Idara i

INNER JOIN Housing.BuildingDetails b
    ON b.IdaraId_FK = i.idaraID
   AND b.buildingDetailsActive = 1
   AND b.buildingUtilityTypeID_FK IN (1, 11, 13, 15)

LEFT JOIN Housing.MilitaryLocation m
    ON m.militaryLocationID =
       b.militaryLocationID_FK

LEFT JOIN Housing.V_LastActionForBuilding la
    ON la.buildingDetailsID =
       b.buildingDetailsID

LEFT JOIN Housing.BuildingAction a
    ON a.buildingActionID =
       la.buildingActionID

LEFT JOIN Housing.BuildingActionType t
    ON t.buildingActionTypeID =
       a.buildingActionTypeID_FK

WHERE i.idaraShowInCommandCenter = 1

GROUP BY
      i.idaraID
    , b.militaryLocationID_FK
    , m.militaryLocationName_A

ORDER BY
      i.idaraID
    , m.militaryLocationName_A;






    /* =========================================================
   dt6 - Housing Readiness / Current Operational Status
   ========================================================= */

;WITH CurrentHousing AS
(
    SELECT
          i.idaraID
        , b.buildingDetailsID
        , a.buildingActionTypeID_FK

        , ISNULL(
            t.buildingActionTypeName_A,
            N'لا يوجد إجراء نشط'
          ) AS ActionTypeName

        , ISNULL(
            NULLIF(
                LTRIM(RTRIM(t.buildingActionTypeBuildingAlias)),
                N''
            ),
            ISNULL(
                t.buildingActionTypeName_A,
                N'لا يوجد إجراء نشط'
            )
          ) AS BuildingStatus

        , t.buildingActionRoot

        , CASE

            /* لا يوجد إجراء نشط */
            WHEN a.buildingActionTypeID_FK IS NULL
                THEN N'NO_ACTIVE_ACTION'

            /* مسكون حاليًا */
            WHEN a.buildingActionTypeID_FK IN
                 (2, 24, 54, 55, 56, 57, 58, 59, 60, 61)
                THEN N'OCCUPIED'

            /* جاهز للتسكين */
            WHEN a.buildingActionTypeID_FK IN
                 (5, 39, 41, 42)
                THEN N'READY'

            /* تحت إجراءات التخصيص */
            WHEN a.buildingActionTypeID_FK IN
                 (38, 40, 45, 46, 47)
                THEN N'ALLOCATION'

            /* ضمن دورة الصيانة */
            WHEN a.buildingActionTypeID_FK IN
                 (4, 9, 17, 31)
                THEN N'MAINTENANCE'

            /* ضمن دورة الجودة */
            WHEN a.buildingActionTypeID_FK IN
                 (10, 11)
                THEN N'QUALITY'

            /* الخدمات العامة */
            WHEN a.buildingActionTypeID_FK IN
                 (12, 13)
                THEN N'GENERAL_SERVICES'

            /* قسم الإسكان */
            WHEN a.buildingActionTypeID_FK IN
                 (14, 15, 16)
                THEN N'HOUSING_DEPARTMENT'

            /* قسم التنفيذ */
            WHEN a.buildingActionTypeID_FK IN
                 (29, 30)
                THEN N'EXECUTION'

            /* خالٍ بانتظار اتخاذ إجراء */
            WHEN a.buildingActionTypeID_FK = 3
                THEN N'VACANT_PENDING'

            /* أي حالة لم نصنفها بعد */
            ELSE N'OTHER'

          END AS ReadinessGroupKey

        , CASE

            WHEN a.buildingActionTypeID_FK IS NULL
                THEN N'لا يوجد إجراء نشط'

            WHEN a.buildingActionTypeID_FK IN
                 (2, 24, 54, 55, 56, 57, 58, 59, 60, 61)
                THEN N'مسكون حاليًا'

            WHEN a.buildingActionTypeID_FK IN
                 (5, 39, 41, 42)
                THEN N'جاهز للتسكين'

            WHEN a.buildingActionTypeID_FK IN
                 (38, 40, 45, 46, 47)
                THEN N'تحت إجراءات التخصيص'

            WHEN a.buildingActionTypeID_FK IN
                 (4, 9, 17, 31)
                THEN N'ضمن دورة الصيانة'

            WHEN a.buildingActionTypeID_FK IN
                 (10, 11)
                THEN N'ضمن دورة الجودة'

            WHEN a.buildingActionTypeID_FK IN
                 (12, 13)
                THEN N'تحت اجراءات النظافه'

            WHEN a.buildingActionTypeID_FK IN
                 (14, 15, 16)
                THEN N'تحت إجراءات قسم الإسكان'

            WHEN a.buildingActionTypeID_FK IN
                 (29, 30)
                THEN N'ضمن دورة قسم التنفيذ'

            WHEN a.buildingActionTypeID_FK = 3
                THEN N'خالٍ بانتظار اتخاذ إجراء'

            ELSE N'حالة أخرى'

          END AS ReadinessGroupName

        , CASE

            WHEN a.buildingActionTypeID_FK IN
                 (2, 24, 54, 55, 56, 57, 58, 59, 60, 61)
                THEN 1

            WHEN a.buildingActionTypeID_FK IN
                 (5, 39, 41, 42)
                THEN 2

            WHEN a.buildingActionTypeID_FK IN
                 (38, 40, 45, 46, 47)
                THEN 3

            WHEN a.buildingActionTypeID_FK IN
                 (4, 9, 17, 31)
                THEN 4

            WHEN a.buildingActionTypeID_FK IN
                 (10, 11)
                THEN 5

            WHEN a.buildingActionTypeID_FK IN
                 (12, 13)
                THEN 6

            WHEN a.buildingActionTypeID_FK IN
                 (14, 15, 16)
                THEN 7

            WHEN a.buildingActionTypeID_FK IN
                 (29, 30)
                THEN 8

            WHEN a.buildingActionTypeID_FK = 3
                THEN 9

            WHEN a.buildingActionTypeID_FK IS NULL
                THEN 10

            ELSE 99

          END AS ReadinessGroupOrder

    FROM dbo.Idara i

    INNER JOIN Housing.BuildingDetails b
        ON b.IdaraId_FK = i.idaraID
       AND b.buildingDetailsActive = 1
       AND b.buildingUtilityTypeID_FK IN (1,11,13,15)

    LEFT JOIN Housing.V_LastActionForBuilding la
        ON la.buildingDetailsID = b.buildingDetailsID

    LEFT JOIN Housing.BuildingAction a
        ON a.buildingActionID = la.buildingActionID

    LEFT JOIN Housing.BuildingActionType t
        ON t.buildingActionTypeID =
           a.buildingActionTypeID_FK

    WHERE i.idaraShowInCommandCenter = 1
),
Grouped AS
(
    SELECT
          idaraID
        , ReadinessGroupKey
        , ReadinessGroupName
        , ReadinessGroupOrder
        , buildingActionTypeID_FK
        , ActionTypeName
        , BuildingStatus
        , buildingActionRoot
        , COUNT(buildingDetailsID) AS HousingUnitsCount

    FROM CurrentHousing

    GROUP BY
          idaraID
        , ReadinessGroupKey
        , ReadinessGroupName
        , ReadinessGroupOrder
        , buildingActionTypeID_FK
        , ActionTypeName
        , BuildingStatus
        , buildingActionRoot
)
SELECT
      idaraID
    , ReadinessGroupKey
    , ReadinessGroupName
    , ReadinessGroupOrder

    , buildingActionTypeID_FK
    , ActionTypeName
    , BuildingStatus
    , buildingActionRoot

    , HousingUnitsCount

    , SUM(HousingUnitsCount) OVER
      (
          PARTITION BY
              idaraID,
              ReadinessGroupKey
      ) AS GroupHousingUnitsCount

    , SUM(HousingUnitsCount) OVER
      (
          PARTITION BY idaraID
      ) AS TotalHousingUnits

FROM Grouped

ORDER BY
      idaraID
    , ReadinessGroupOrder
    , HousingUnitsCount DESC
    , ActionTypeName;



    /* ============================================================
   dt7 / dt8 / dt9
   Housing Procedures - Current Operational Workload
   ============================================================ */

DROP TABLE IF EXISTS #HCC_CurrentProcedures;


/* ============================================================
   Base:
   آخر Action فعّال لكل وحدة سكنية
   ونحتفظ فقط بالإجراءات التشغيلية الجارية
   ============================================================ */

SELECT

      b.IdaraId_FK
          AS idaraID

    , b.buildingDetailsID

    , b.buildingDetailsNo

    , a.buildingActionID

    , a.buildingActionParentID

    , a.buildingActionTypeID_FK
          AS ActionTypeID

    , ISNULL
      (
          at.buildingActionTypeName_A,
          N'غير محدد'
      ) AS ActionTypeName

    , a.generalNo_FK

    , a.entryDate

    , a.buildingActionDate

    , a.buildingActionDecisionDate

    , COALESCE
      (
          a.buildingActionDate,
          a.entryDate
      ) AS CurrentStatusSince

    , CASE
          WHEN a.buildingActionDate IS NOT NULL
              THEN N'ACTION_DATE'

          WHEN a.entryDate IS NOT NULL
              THEN N'ENTRY_DATE_FALLBACK'

          ELSE N'UNKNOWN'
      END AS CurrentStatusDateSource


    /* ========================================================
       المجموعة التشغيلية
       ======================================================== */

    , CASE

          WHEN a.buildingActionTypeID_FK IN (38, 40)
    THEN N'ALLOCATION'

WHEN a.buildingActionTypeID_FK IN (45, 46, 47)
    THEN N'HOUSING'


          WHEN a.buildingActionTypeID_FK IN
               (
                   48,
                   49,
                   51,
                   52,
                   53,
                   61
               )
              THEN N'EXTEND'


          WHEN a.buildingActionTypeID_FK IN
               (
                   54,
                   56,
                   57,
                   58,
                   59,
                   60
               )
              THEN N'EXIT'

      END AS ProcedureGroupKey


    , CASE

          WHEN a.buildingActionTypeID_FK IN (38, 40)
    THEN N'إجراءات التخصيص'

WHEN a.buildingActionTypeID_FK IN (45, 46, 47)
    THEN N'إجراءات التسكين'


          WHEN a.buildingActionTypeID_FK IN
               (
                   48,
                   49,
                   51,
                   52,
                   53,
                   61
               )
              THEN N'إجراءات الإمهال'


          WHEN a.buildingActionTypeID_FK IN
               (
                   54,
                   56,
                   57,
                   58,
                   59,
                   60
               )
              THEN N'إجراءات الإخلاء'

      END AS ProcedureGroupName


    , CASE

          WHEN COALESCE
               (
                   a.buildingActionDate,
                   a.entryDate
               ) IS NULL
              THEN NULL

          ELSE DATEDIFF
               (
                   DAY,

                   COALESCE
                   (
                       a.buildingActionDate,
                       a.entryDate
                   ),

                   GETDATE()
               )

      END AS DaysInCurrentStatus


    /*
       هذه العلامة لا تعني أن بقية السجلات Native.
       فقط تخبرنا أن هذا السجل أُنشئ صراحة بواسطة MoveData.
    */
    , CASE
          WHEN a.buildingActionExtraText5 = N'MIGRATION_GENERATED'
              THEN 1
          ELSE 0
      END AS IsMoveDataGenerated

INTO #HCC_CurrentProcedures

FROM Housing.BuildingDetails b

INNER JOIN Housing.V_LastActionForBuilding la
    ON la.buildingDetailsID =
       b.buildingDetailsID

INNER JOIN Housing.BuildingAction a
    ON a.buildingActionID =
       la.buildingActionID

LEFT JOIN Housing.BuildingActionType at
    ON at.buildingActionTypeID =
       a.buildingActionTypeID_FK

INNER JOIN dbo.Idara i
    ON i.idaraID =
       b.IdaraId_FK

WHERE

        i.idaraShowInCommandCenter = 1

    AND b.buildingDetailsActive = 1

    AND b.buildingUtilityTypeID_FK
        IN
        (
            1,
            11,
            13,
            15
        )

    AND a.buildingActionActive = 1

    AND a.buildingActionTypeID_FK IN
        (
            /* Allocation */
            38,
            40,
            45,
            46,
            47,

            /* Extend */
            48,
            49,
            51,
            52,
            53,
            61,

            /* Exit */
            54,
            56,
            57,
            58,
            59,
            60
        );


/* ============================================================
   dt7
   Summary By Idara

   صف واحد لكل إدارة حتى لو لا يوجد أي إجراء جاري
   ============================================================ */

SELECT

      i.idaraID

    , COUNT
      (
          p.buildingActionID
      ) AS TotalCurrentProcedures


    , SUM
      (
          CASE
              WHEN p.ProcedureGroupKey =
                   N'ALLOCATION'
                  THEN 1
              ELSE 0
          END
      ) AS AllocationCurrent

      , SUM
  (
      CASE
          WHEN p.ProcedureGroupKey = N'HOUSING'
              THEN 1
          ELSE 0
      END
  ) AS HousingCurrent


    , SUM
      (
          CASE
              WHEN p.ProcedureGroupKey =
                   N'EXTEND'
                  THEN 1
              ELSE 0
          END
      ) AS ExtendCurrent


    , SUM
      (
          CASE
              WHEN p.ProcedureGroupKey =
                   N'EXIT'
                  THEN 1
              ELSE 0
          END
      ) AS ExitCurrent

FROM dbo.Idara i

LEFT JOIN #HCC_CurrentProcedures p
    ON p.idaraID =
       i.idaraID

WHERE
    i.idaraShowInCommandCenter = 1

GROUP BY
    i.idaraID

ORDER BY
    i.idaraID;


/* ============================================================
   dt8
   Current Procedure Stage Distribution
   ============================================================ */

SELECT

      p.idaraID

    , p.ProcedureGroupKey

    , p.ProcedureGroupName

    , p.ActionTypeID

    , p.ActionTypeName

    , COUNT(*) AS CurrentCases

    , MIN
      (
          p.CurrentStatusSince
      ) AS OldestCurrentStatusDate

    , MAX
      (
          p.DaysInCurrentStatus
      ) AS OldestCurrentStatusDays

FROM #HCC_CurrentProcedures p

GROUP BY

      p.idaraID

    , p.ProcedureGroupKey

    , p.ProcedureGroupName

    , p.ActionTypeID

    , p.ActionTypeName

ORDER BY

      p.idaraID

    , CASE p.ProcedureGroupKey
    WHEN N'ALLOCATION' THEN 1
    WHEN N'HOUSING'    THEN 2
    WHEN N'EXTEND'     THEN 3
    WHEN N'EXIT'       THEN 4
    ELSE 9
END

    , CurrentCases DESC

    , p.ActionTypeID;


/* ============================================================
   dt9
   Oldest Current Procedures

   أعلى 20 حالة لكل إدارة
   ============================================================ */

;WITH RankedCurrentProcedures AS
(
    SELECT

          p.*

        , ROW_NUMBER() OVER
          (
              PARTITION BY
                  p.idaraID

              ORDER BY

                  CASE
                      WHEN p.DaysInCurrentStatus
                           IS NULL
                          THEN 1
                      ELSE 0
                  END

                , p.DaysInCurrentStatus DESC

                , p.buildingActionID ASC

          ) AS RowNo

    FROM #HCC_CurrentProcedures p
)

SELECT

      idaraID

    , RowNo

    , ProcedureGroupKey

    , ProcedureGroupName

    , buildingDetailsID

    , buildingDetailsNo

    , generalNo_FK

    , buildingActionID

    , buildingActionParentID

    , ActionTypeID

    , ActionTypeName

    , CurrentStatusSince

    , CurrentStatusDateSource

    , DaysInCurrentStatus

    , IsMoveDataGenerated

FROM RankedCurrentProcedures

WHERE
    RowNo <= 20

ORDER BY

      idaraID

    , RowNo;


/* ============================================================
   Cleanup
   ============================================================ */

DROP TABLE IF EXISTS #HCC_CurrentProcedures;




/* ============================================================
   dt10 - Housing Workflow Performance
   Four separate completed workflows (operational ends; legacy starts allowed):
   ALLOCATION  27 -> 45 / 42   target 30 days
   HOUSING     45 -> 2        target  5 days
   EXTEND      48 -> 24       target  5 days
   EXIT        54 -> 3        target  5 days

   Keep existing result-set position and columns.
   Append approval/cancellation breakdown for allocation.
   Dates use entryDate exactly as the previous dt10 did.
   ============================================================ */

;WITH EnabledIdaras AS
(
    SELECT i.idaraID
    FROM dbo.Idara i
    WHERE i.idaraShowInCommandCenter = 1
),
NativeCompletedEnds AS
(
    SELECT
          a.IdaraId_FK AS idaraID
        , a.buildingActionID
        , a.buildingActionTypeID_FK AS EndActionTypeID
        , a.entryDate AS EndEntryDate
    FROM Housing.BuildingAction a
    INNER JOIN EnabledIdaras i
        ON i.idaraID = a.IdaraId_FK
    WHERE a.buildingActionTypeID_FK IN (45, 42, 2, 24, 3)
      -- A completed workflow must have an operational (not migrated) end.
      AND COALESCE(a.buildingActionExtraText5, N'')
          NOT IN (N'LEGACY', N'MIGRATION_GENERATED')
      AND a.entryDate IS NOT NULL
),
CompletedCycles AS
(
    SELECT
          e.idaraID
        , CASE
              WHEN e.EndActionTypeID IN (45, 42) THEN N'ALLOCATION'
              WHEN e.EndActionTypeID = 2 THEN N'HOUSING'
              WHEN e.EndActionTypeID = 24 THEN N'EXTEND'
              WHEN e.EndActionTypeID = 3 THEN N'EXIT'
          END AS WorkflowKey
        , CASE
              WHEN e.EndActionTypeID IN (45, 42) THEN N'التخصيص'
              WHEN e.EndActionTypeID = 2 THEN N'التسكين'
              WHEN e.EndActionTypeID = 24 THEN N'الإمهال'
              WHEN e.EndActionTypeID = 3 THEN N'الإخلاء'
          END AS WorkflowName
        , e.EndActionTypeID
        , s.StartActionID
        , e.buildingActionID AS EndActionID
        , s.StartEntryDate
        , e.EndEntryDate
        , CAST(
              DATEDIFF_BIG(SECOND, s.StartEntryDate, e.EndEntryDate)
              / 86400.0 AS DECIMAL(18, 6)
          ) AS DurationDays
    FROM NativeCompletedEnds e
    OUTER APPLY
    (
        SELECT TOP (1)
              c.buildingActionID AS StartActionID
            , c.entryDate AS StartEntryDate
        FROM Housing.fn_BuildingAction_ChainToRoot(e.buildingActionID) c
        INNER JOIN Housing.BuildingAction startOrigin
            ON startOrigin.buildingActionID = c.buildingActionID
        WHERE c.buildingActionTypeID_FK =
              CASE
                  WHEN e.EndActionTypeID IN (45, 42) THEN 27
                  WHEN e.EndActionTypeID = 2 THEN 45
                  WHEN e.EndActionTypeID = 24 THEN 48
                  WHEN e.EndActionTypeID = 3 THEN 54
              END
          -- Historical starts are allowed when the finish is operational.
          -- Only starts synthesized by the migration are excluded.
          AND COALESCE(startOrigin.buildingActionExtraText5, N'')
               <> N'MIGRATION_GENERATED'
          AND c.entryDate IS NOT NULL
          AND c.entryDate <= e.EndEntryDate
        -- Earliest genuine start in this chain, including a retained legacy start.
        ORDER BY c.entryDate ASC, c.Lvl ASC, c.buildingActionID ASC
    ) s
    WHERE s.StartActionID IS NOT NULL
),
CyclesWithMedian AS
(
    SELECT
          c.*
        , PERCENTILE_CONT(0.5) WITHIN GROUP
          (ORDER BY c.DurationDays) OVER
          (PARTITION BY c.idaraID, c.WorkflowKey) AS MedianDays
    FROM CompletedCycles c
),
Performance AS
(
    SELECT
          idaraID
        , WorkflowKey
        , MAX(WorkflowName) AS WorkflowName
        , COUNT(*) AS CompletedCount
        , CAST(AVG(DurationDays) AS DECIMAL(18, 6)) AS AverageDays
        , CAST(MAX(MedianDays) AS DECIMAL(18, 6)) AS MedianDays
        , MIN(DurationDays) AS MinimumDays
        , MAX(DurationDays) AS MaximumDays
        , MAX(EndEntryDate) AS LastCompletedDate
        , SUM(CASE WHEN EndActionTypeID = 45 THEN 1 ELSE 0 END)
          AS ApprovedAllocationCount
        , SUM(CASE WHEN EndActionTypeID = 42 THEN 1 ELSE 0 END)
          AS CancelledAllocationCount
    FROM CyclesWithMedian
    GROUP BY idaraID, WorkflowKey
),
WorkflowTypes AS
(
    SELECT N'ALLOCATION' AS WorkflowKey, N'التخصيص' AS WorkflowName, 1 AS SortOrder
    UNION ALL SELECT N'HOUSING', N'التسكين', 2
    UNION ALL SELECT N'EXTEND', N'الإمهال', 3
    UNION ALL SELECT N'EXIT', N'الإخلاء', 4
)
SELECT
      i.idaraID
    , w.WorkflowKey
    , w.WorkflowName
    , ISNULL(p.CompletedCount, 0) AS CompletedCount
    , p.AverageDays
    , p.MedianDays
    , p.MinimumDays
    , p.MaximumDays
    , p.LastCompletedDate
    , ISNULL(p.ApprovedAllocationCount, 0) AS ApprovedAllocationCount
    , ISNULL(p.CancelledAllocationCount, 0) AS CancelledAllocationCount
FROM EnabledIdaras i
CROSS JOIN WorkflowTypes w
LEFT JOIN Performance p
    ON p.idaraID = i.idaraID
   AND p.WorkflowKey = w.WorkflowKey
ORDER BY i.idaraID, w.SortOrder;


   /* ============================================================
   dt11
   Financial Analysis By Bill Charge Type

   TotalClaims:
   مطالبات المستفيدين فقط.

   TotalPayments:
   نفس نطاق السدادات المستخدم في dt4.

   DeficitByType / SurplusByType:
   يتم احتسابهما لكل مستفيد داخل كل نوع أولاً،
   ثم تجميعهما على مستوى الإدارة والنوع.
   ============================================================ */

;WITH ClaimsByResidentType AS
(
    SELECT
          b.idaraID_FK AS idaraID

        , ISNULL(
              b.BillChargeTypeID_FK,
              -1
          ) AS ChargeTypeKey

        , b.residentInfoID_FK
            AS residentInfoID

        , COUNT_BIG(*)
            AS BillsCount

        , CAST(
              SUM(
                  ISNULL(
                      b.TotalPrice,
                      0
                  )
              )
              AS DECIMAL(18,2)
          ) AS TotalClaims

    FROM #HCCFinEligibleBills b

    INNER JOIN dbo.Idara i
        ON i.idaraID =
           b.idaraID_FK

    WHERE
        b.BillActive = 1

        AND
        b.residentInfoID_FK IS NOT NULL

        AND
        i.idaraShowInCommandCenter = 1

        AND
    b.TotalPrice > 0

    GROUP BY
          b.idaraID_FK

        , ISNULL(
              b.BillChargeTypeID_FK,
              -1
          )

        , b.residentInfoID_FK
),

PaymentsByResidentType AS
(
    SELECT
          p.IdaraId_FK AS idaraID

        , ISNULL(
              p.BillChargeTypeID_FK,
              -1
          ) AS ChargeTypeKey

        , p.residentInfoID_FK
            AS residentInfoID

        , CAST(
              SUM(
                  ISNULL(
                      p.amount,
                      0
                  )
              )
              AS DECIMAL(18,2)
          ) AS TotalPayments

    FROM #HCCFinEligiblePayments p

    INNER JOIN Housing.DeductList d
        ON d.deductListID =
           p.deductListID_FK

    INNER JOIN dbo.Idara i
        ON i.idaraID =
           p.IdaraId_FK

    WHERE
        d.deductActive = 1

        AND
        p.buildingPayementActive = 1

        AND
        p.buildingPaymentLinkStatusID_FK IN (1, 2)

        AND
        p.residentInfoID_FK IS NOT NULL

        AND
        i.idaraShowInCommandCenter = 1

    GROUP BY
          p.IdaraId_FK

        , ISNULL(
              p.BillChargeTypeID_FK,
              -1
          )

        , p.residentInfoID_FK
),

ResidentTypeFinancial AS
(
    SELECT
          COALESCE(
              c.idaraID,
              p.idaraID
          ) AS idaraID

        , COALESCE(
              c.ChargeTypeKey,
              p.ChargeTypeKey
          ) AS ChargeTypeKey

        , COALESCE(
              c.residentInfoID,
              p.residentInfoID
          ) AS residentInfoID

        , ISNULL(
              c.BillsCount,
              0
          ) AS BillsCount

        , CASE
              WHEN c.residentInfoID IS NOT NULL
                  THEN CAST(1 AS BIGINT)
              ELSE CAST(0 AS BIGINT)
          END AS HasClaims

        , CAST(
              ISNULL(
                  c.TotalClaims,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST(
              ISNULL(
                  p.TotalPayments,
                  0
              )
              AS DECIMAL(18,2)
          ) AS TotalPayments

    FROM ClaimsByResidentType c

    FULL OUTER JOIN PaymentsByResidentType p
        ON p.idaraID =
           c.idaraID

       AND p.ChargeTypeKey =
           c.ChargeTypeKey

       AND p.residentInfoID =
           c.residentInfoID
),

FinancialByType AS
(
    SELECT
          idaraID

        , ChargeTypeKey

        , COUNT_BIG(*)
            AS FinancialBeneficiariesCount

        , SUM(
              BillsCount
          ) AS BillsCount

        , SUM(
              HasClaims
          ) AS BeneficiariesCount

        , CAST(
              SUM(
                  TotalClaims
              )
              AS DECIMAL(18,2)
          ) AS TotalClaims

        , CAST(
              SUM(
                  TotalPayments
              )
              AS DECIMAL(18,2)
          ) AS TotalPayments

        , CAST(
              SUM(
                  CASE
                      WHEN TotalClaims > TotalPayments
                          THEN TotalClaims - TotalPayments
                      ELSE 0
                  END
              )
              AS DECIMAL(18,2)
          ) AS DeficitByType

        , CAST(
              SUM(
                  CASE
                      WHEN TotalPayments > TotalClaims
                          THEN TotalPayments - TotalClaims
                      ELSE 0
                  END
              )
              AS DECIMAL(18,2)
          ) AS SurplusByType

        , CAST(
              SUM(
                  TotalPayments -
                  TotalClaims
              )
              AS DECIMAL(18,2)
          ) AS NetByType

    FROM ResidentTypeFinancial

    GROUP BY
          idaraID
        , ChargeTypeKey
),

WithTotals AS
(
    SELECT
          f.*

        , SUM(
              f.TotalClaims
          ) OVER
          (
              PARTITION BY
                  f.idaraID
          ) AS IdaraTotalClaims

    FROM FinancialByType f
)

SELECT
      f.idaraID

    , CASE
          WHEN f.ChargeTypeKey = -1
              THEN NULL
          ELSE f.ChargeTypeKey
      END AS BillChargeTypeID

    , ISNULL(
          ct.BillChargeTypeName_A,
          N'غير محدد'
      ) AS BillChargeTypeName

    , f.FinancialBeneficiariesCount

    , f.BillsCount

    , f.BeneficiariesCount

    , f.TotalClaims

    , f.TotalPayments

    , f.DeficitByType

    , f.SurplusByType

    , f.NetByType

    , CAST(
          CASE

              WHEN
                  ISNULL(
                      f.IdaraTotalClaims,
                      0
                  ) <= 0
                  THEN 0

              ELSE
                  f.TotalClaims
                  * 100.0
                  /
                  f.IdaraTotalClaims

          END
          AS DECIMAL(6,2)
      ) AS ClaimsPercent

FROM WithTotals f

LEFT JOIN Housing.BillChargeType ct
    ON ct.BillChargeTypeID =
       CASE
           WHEN f.ChargeTypeKey = -1
               THEN NULL
           ELSE f.ChargeTypeKey
       END

ORDER BY
      f.idaraID
    , f.TotalClaims DESC
    , BillChargeTypeID;










END