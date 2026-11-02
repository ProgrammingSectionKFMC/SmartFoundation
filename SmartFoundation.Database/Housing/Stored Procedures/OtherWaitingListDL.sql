-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[OtherWaitingListDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	, @WaitingClassID_nvar  NVARCHAR(400)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
    Declare @WaitingClassID int
    set @WaitingClassID = TRY_CAST(@WaitingClassID_nvar as int)
  -- WaitingList Data

         
   SELECT 
            w.ActionID,
            ROW_NUMBER() OVER (
            ORDER BY w.ActionDecisionDate ASC,w.ActionDecisionNo ASC, w.GeneralNo ASC
            ) AS WaitingListOrder,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
            rd.rankNameA,
            w.ActionDecisionNo,
            convert(nvarchar(10),w.[ActionDecisionDate],23) ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
            w.LastActionTypeID,
            w.LastActionID,
            isnull(w.LastActionNote,w.ActionNote) ActionNote,
            w.IdaraId

FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        left Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE 
    w.WaitingClassID = @WaitingClassID
      AND  (w.LastActionTypeID is null or w.LastActionTypeID in (34,35))
      AND (w.WaitingClassID not in(1,2,3,4,11))  
      AND (w.IdaraId = @idaraID)



     -- WaitingClass DDL
            SELECT c.waitingClassID,c.waitingClassName_A
            FROM [DATACORE].[Housing].[WaitingClass] c
            where (c.WaitingClassID not in(1,2,3,4,11)) and (c.idara_FK = @idaraID)
            AND c.waitingClassActive = 1
            order by c.waitingClassSequence asc



       
-- Houses DDL
-- Same house eligibility rules as Housing.AssignDL

SELECT
    c.buildingDetailsID,
    c.buildingDetailsNo
FROM Housing.V_GetGeneralListForBuilding c
WHERE c.BuildingIdaraID = @idaraID
  AND c.buildingDetailsActive = 1
  AND c.LastActionTypeID = 5

  -- At least one active bedroom
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

  -- No active physical occupancy
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

  -- No pending allocation or housing procedure
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
  );

            



   
END