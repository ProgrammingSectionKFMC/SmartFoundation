CREATE PROCEDURE [Housing].[AssignDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	,@WaitingClassID  INT
    ,@AssignPeriodID  bigint
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

          
   
-- Snapshot: قراءة قائمة الانتظار مرة واحدة
-- مع البحث عن التعارضات في جميع الإدارات

SELECT
    w.ActionID,
    w.ActionDecisionDate,
    w.GeneralNo,
    w.ActionDecisionNo,
    w.WaitingClassID,
    w.WaitingClassName,
    w.WaitingOrderTypeID,
    w.WaitingOrderTypeName,
    w.waitingClassSequence,
    w.residentInfoID,
    w.NationalID,
    w.LastActionTypeID,
    w.LastActionTypeName,
    w.LastActionID,
    w.LastActionEntryDate,
    w.buildingActionRoot,
    w.buildingDetailsID,
    w.buildingDetailsNo,
    w.ActionNote,
    w.LastActionNote,
    w.IdaraId,
    w.InAssignPeriod,
    w.LastActionIdaraName,
    w.ActionIdaraName
INTO #AssignWaitingSnapshot
FROM Housing.V_WaitingList w
WHERE
    (
        w.IdaraId = @idaraID
        AND w.WaitingClassID = @WaitingClassID
        AND w.LastActionTypeID IN (27,39,41,38,40)
    )
    OR w.buildingActionRoot = 2
    OR w.LastActionTypeID IN
       (38,40,45,46,47,57,58);

CREATE NONCLUSTERED INDEX IX_AssignWaitingSnapshot_Resident
ON #AssignWaitingSnapshot
(
    residentInfoID,
    ActionID
);

;WITH CurrentAssignPeriod AS
(
    SELECT TOP (1)
        a.AssignPeriodID
    FROM Housing.AssignPeriod a
    WHERE a.AssignPeriodActive = 1
      AND a.AssignPeriodClose = 1
      AND a.AssignPeriodStartdate IS NOT NULL
      AND
      (
          a.AssignPeriodEnddate IS NULL
          OR a.AssignPeriodEnddate > CAST(GETDATE() AS DATE)
      )
      AND a.WaitingClassID_FK = @WaitingClassID
      AND a.IdaraId_FK = @idaraID
    ORDER BY a.AssignPeriodID DESC
),
GuardConflicts AS
(
    SELECT
        candidate.ActionID AS CandidateActionID,

        ROW_NUMBER() OVER
        (
            PARTITION BY candidate.ActionID
            ORDER BY
                CASE
                    WHEN linked.LastActionTypeID IN (57,58) THEN 0
                    WHEN linked.LastActionTypeID = 2 THEN 1
                    WHEN linked.buildingActionRoot = 2 THEN 2
                    ELSE 3
                END,
                linked.LastActionID DESC,
                linked.ActionID DESC
        ) AS ConflictOrder,

        CASE
            WHEN linked.LastActionTypeID = 57
            THEN CONCAT(
                N'إخلاء المنزل ', house.No,
                N' قيد التدقيق المالي في إدارة ', idara.Name
            )

            WHEN linked.LastActionTypeID = 58
            THEN CONCAT(
                N'إخلاء المنزل ', house.No,
                N' بانتظار الاعتماد النهائي في إدارة ', idara.Name
            )

            WHEN linked.LastActionTypeID = 2
            THEN CONCAT(
                N'سجل تسكين قائم للمنزل ', house.No,
                N' في إدارة ', idara.Name
            )

            WHEN linked.LastActionTypeID IN (54,59,60)
            THEN CONCAT(
                N'إخلاء المنزل ', house.No,
                N' لم يكتمل (',
                COALESCE(
                    linked.LastActionTypeName,
                    N'إجراء الإخلاء'
                ),
                N') في إدارة ', idara.Name
            )

            WHEN linked.buildingActionRoot = 2
            THEN CONCAT(
                N'دورة سكن قائمة للمنزل ', house.No,
                N' (',
                COALESCE(
                    linked.LastActionTypeName,
                    N'الإشغال'
                ),
                N') في إدارة ', idara.Name
            )

            ELSE CONCAT(
                N'طلب تخصيص أو تسكين آخر (',
                COALESCE(
                    linked.LastActionTypeName,
                    N'قيد الإجراء'
                ),
                N') للمنزل ', house.No,
                N' في إدارة ', idara.Name
            )
        END AS ConflictReason

    FROM #AssignWaitingSnapshot candidate

    INNER JOIN #AssignWaitingSnapshot linked
        ON linked.residentInfoID = candidate.residentInfoID
       AND linked.ActionID <> candidate.ActionID
       AND
       (
           linked.buildingActionRoot = 2
           OR linked.LastActionTypeID IN
              (38,40,45,46,47,57,58)
       )

    CROSS APPLY
    (
        SELECT COALESCE(
            NULLIF(linked.buildingDetailsNo, N''),
            CONVERT(NVARCHAR(30), linked.buildingDetailsID),
            N'غير محدد'
        ) AS No
    ) house

    CROSS APPLY
    (
        SELECT COALESCE(
            NULLIF(linked.LastActionIdaraName, N''),
            NULLIF(linked.ActionIdaraName, N''),
            N'غير محددة'
        ) AS Name
    ) idara

    WHERE candidate.IdaraId = @idaraID
      AND candidate.WaitingClassID = @WaitingClassID
      AND
      (
          candidate.LastActionTypeID IN (27,39,41)
          OR
          (
              candidate.LastActionTypeID IN (38,40)
              AND
              (
                  candidate.InAssignPeriod = 0
                  OR candidate.InAssignPeriod IS NULL
              )
          )
      )
),
GuardSummary AS
(
    SELECT
        CandidateActionID,

        STRING_AGG(
            CONVERT(
                NVARCHAR(MAX),
                CASE
                    WHEN ConflictOrder = 1
                        THEN ConflictReason
                    ELSE N'، ويوجد أيضًا ' + ConflictReason
                END
            ),
            N''
        ) WITHIN GROUP
          (ORDER BY ConflictOrder) AS AssignmentBlockReason

    FROM GuardConflicts
    GROUP BY CandidateActionID
)
SELECT
    w.ActionID,

    ROW_NUMBER() OVER
    (
        ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
    ) AS WaitingListOrder,

    rd.FullName_A,
    w.NationalID,
    w.GeneralNo,
    w.ActionDecisionNo,

    CONVERT(
        NVARCHAR(10),
        w.ActionDecisionDate,
        23
    ) AS ActionDecisionDate,

    w.WaitingClassID,
    w.WaitingClassName,
    fr.rankNameA,
    w.WaitingOrderTypeID,
    w.WaitingOrderTypeName,
    w.waitingClassSequence,
    w.residentInfoID,
    w.LastActionTypeID,
    w.LastActionID,

    CASE
        WHEN gs.CandidateActionID IS NOT NULL
        THEN CONCAT(
            N'غير مؤهل للتخصيص — ',
            gs.AssignmentBlockReason
        )
        ELSE ba.buildingActionTypeResidentAlias
    END AS buildingActionTypeResidentAlias,

    w.buildingDetailsID,
    w.buildingDetailsNo,

    ISNULL(
        w.LastActionNote,
        w.ActionNote
    ) AS ActionNote,

    w.IdaraId,

    ISNULL(
        cap.AssignPeriodID,
        0
    ) AS AssignPeriodID,

    CASE
        WHEN w.LastActionTypeID IN (38,40)
            THEN N'1'
        ELSE N'0'
    END AS AssignStatus,

    CASE
        WHEN gs.CandidateActionID IS NULL
            THEN 0
        ELSE 1
    END AS IsAssignmentBlocked,

    ISNULL(
        gs.AssignmentBlockReason,
        N''
    ) AS AssignmentBlockReason

FROM #AssignWaitingSnapshot w

INNER JOIN Housing.V_GetFullResidentDetails rd
    ON w.residentInfoID = rd.residentInfoID

INNER JOIN Housing.BuildingActionType ba
    ON w.LastActionTypeID = ba.buildingActionTypeID

LEFT JOIN GuardSummary gs
    ON gs.CandidateActionID = w.ActionID

OUTER APPLY
(
    SELECT AssignPeriodID
    FROM CurrentAssignPeriod
) cap

LEFT JOIN Housing.V_GetFullResidentDetails fr
    ON w.residentInfoID = fr.residentInfoID

WHERE w.WaitingClassID = @WaitingClassID
  AND w.IdaraId = @idaraID
  AND
  (
      w.LastActionTypeID IN (27,39,41)
      OR
      (
          w.LastActionTypeID IN (38,40)
          AND
          (
              w.InAssignPeriod = 0
              OR w.InAssignPeriod IS NULL
          )
      )
  )

ORDER BY
    w.LastActionEntryDate DESC,
    ROW_NUMBER() OVER
    (
        ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
    ) ASC;


      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- WaitingClass DDL
            SELECT 
            c.waitingClassID
            ,c.waitingClassName_A
            FROM [DATACORE].[Housing].[WaitingClass] c
            where (c.idara_FK is null)

            order by c.waitingClassSequence asc


            -- SELECT 
            --cast(c.waitingClassID as nvarchar(20))+','+cast(isnull(a.AssignPeriodID,0) as nvarchar(20)) as waitingClassID
            --,c.waitingClassName_A
            --FROM [DATACORE].[Housing].[WaitingClass] c
            --left join Housing.AssignPeriod a on c.WaitingClassID = a.WaitingClassID_FK 
            --and a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1 
            --and a.AssignPeriodStartdate is not null 
            --and (a.AssignPeriodEnddate is null or cast(a.AssignPeriodEnddate as date) > cast(GETDATE() as date)) 
            --and a.IdaraId_FK = 1
            --where (c.idara_FK is null)

            --order by c.waitingClassSequence asc


     --AssignPeriod
   
            select 
             a.AssignPeriodID
            ,a.[AssignPeriodDescrption]
            ,convert(nvarchar(10),a.[AssignPeriodStartdate],111)+' '+convert(nvarchar,a.[AssignPeriodStartdate],108) AssignPeriodStartdate
            ,a.[AssignPeriodEnddate]
            ,a.[AssignPeriodActive]
            ,a.[IdaraId_FK]
            ,a.[entryDate]
            ,a.[entryData]
            ,a.[hostName]
            ,f.FullName
            ,w.waitingClassName_A
            
            from Housing.AssignPeriod a
            inner join dbo.V_GetFullSystemUsersDetails f on a.entryData = f.usersID
            left join Housing.WaitingClass w on a.WaitingClassID_FK = w.WaitingClassID
            where a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1
            and a.AssignPeriodStartdate is not null
            and (a.AssignPeriodEnddate is null or cast(a.AssignPeriodEnddate as date) > cast(GETDATE() as date))
            and a.IdaraId_FK = @idaraID
            and a.WaitingClassID_FK = @WaitingClassID





             -- Houses DDL
            SELECT
      c.buildingDetailsID
    , c.buildingDetailsNo
FROM Housing.V_GetGeneralListForBuilding c
WHERE c.BuildingIdaraID = @idaraID
  AND c.buildingDetailsActive = 1
  /* APH_HOUSE_ELIGIBILITY_20261028 */
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
  -- Physical occupancy 2/24/54/etc blocks. 57/58 do not block a house
  -- already operationally reset to 5 after the physical receipt and 57 gate.
  AND NOT EXISTS
  (
      SELECT 1 FROM Housing.V_Occupant occupant
      WHERE occupant.buildingDetailsID = c.buildingDetailsID
        AND (occupant.LastActionTypeID IS NULL
             OR occupant.LastActionTypeID NOT IN (57, 58))
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
  );
            



   
END