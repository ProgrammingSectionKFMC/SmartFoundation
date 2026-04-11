-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
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

          
   ;WITH CurrentAssignPeriod AS
(
    SELECT TOP (1) a.AssignPeriodID
    FROM Housing.AssignPeriod a
    WHERE a.AssignPeriodActive = 1
      AND a.AssignPeriodClose = 1
      AND a.AssignPeriodStartdate IS NOT NULL
      AND (a.AssignPeriodEnddate IS NULL OR a.AssignPeriodEnddate > CAST(GETDATE() AS date))
      AND a.WaitingClassID_FK = @WaitingClassID
    ORDER BY a.AssignPeriodID DESC
)
SELECT 
    w.ActionID,
    ROW_NUMBER() OVER (
        ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
    ) AS WaitingListOrder,
    rd.FullName_A,
    w.NationalID,
    w.GeneralNo,
    w.ActionDecisionNo,
    CONVERT(nvarchar(10), w.ActionDecisionDate, 23) AS ActionDecisionDate,
    w.WaitingClassID,
    w.WaitingClassName,
    w.WaitingOrderTypeID,
    w.WaitingOrderTypeName,
    w.waitingClassSequence,
    w.residentInfoID,
    w.LastActionTypeID,
    w.LastActionID,
    ba.buildingActionTypeResidentAlias,
    w.buildingDetailsID,
    w.buildingDetailsNo,
    ISNULL(w.LastActionNote, w.ActionNote) AS ActionNote,
    w.IdaraId,
    ISNULL(cap.AssignPeriodID, 0) AS AssignPeriodID,
    CASE 
        WHEN w.LastActionTypeID IN (38,40) THEN N'1'
        ELSE N'0'
    END AS AssignStatus
FROM Housing.V_WaitingList w
INNER JOIN Housing.V_GetFullResidentDetails rd 
    ON w.residentInfoID = rd.residentInfoID
INNER JOIN Housing.BuildingActionType ba 
    ON w.LastActionTypeID = ba.buildingActionTypeID
OUTER APPLY
(
    SELECT AssignPeriodID
    FROM CurrentAssignPeriod
) cap
WHERE w.WaitingClassID = @WaitingClassID
  AND w.IdaraId = @idaraID
  AND w.LastActionTypeID IN (27,39,41);

  --AND w.LastActionTypeID IN (27,38,39,40,41,42);

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
            SELECT c.buildingDetailsID,c.buildingDetailsNo
            FROM [DATACORE].[Housing].[V_GetGeneralListForBuilding] c
            where c.BuildingIdaraID = 1 and c.buildingDetailsActive = 1 
            and (c.LastActionTypeID in(5,39,41) or c.LastActionTypeID is null )
            



   
END