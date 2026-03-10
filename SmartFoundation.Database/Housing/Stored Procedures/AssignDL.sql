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
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

          
   SELECT 
            w.ActionID,
            ROW_NUMBER() OVER (
            ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
            ) AS WaitingListOrder,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
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
            ba.buildingActionTypeResidentAlias,
            w.buildingDetailsID,
            w.buildingDetailsNo,
            isnull(w.LastActionNote,w.ActionNote) ActionNote,
            w.IdaraId,
            isnull((select top(1) a.AssignPeriodID from Housing.AssignPeriod a
            where a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1
            and a.AssignPeriodStartdate is not null
            and (a.AssignPeriodEnddate is null or cast(a.AssignPeriodEnddate as date) > cast(GETDATE() as date))
            order by a.AssignPeriodID desc),0) as AssignPeriodID
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE w.WaitingClassID = @WaitingClassID
      AND w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (27,38,39,40,41,42)

      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- WaitingClass DDL
            SELECT c.waitingClassID,c.waitingClassName_A
            FROM [DATACORE].[Housing].[WaitingClass] c
            where (c.idara_FK is null or c.idara_FK = @idaraID)
            order by c.waitingClassSequence asc




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
            
            from Housing.AssignPeriod a
            inner join dbo.V_GetFullSystemUsersDetails f on a.entryData = f.usersID
            where a.AssignPeriodActive = 1 and a.AssignPeriodClose = 1
            and a.AssignPeriodStartdate is not null
            and (a.AssignPeriodEnddate is null or cast(a.AssignPeriodEnddate as date) > cast(GETDATE() as date))
            and a.IdaraId_FK = @idaraID





             -- Houses DDL
            SELECT c.buildingDetailsID,c.buildingDetailsNo
            FROM [DATACORE].[Housing].[V_GetGeneralListForBuilding] c
            where c.BuildingIdaraID = @idaraID and c.buildingDetailsActive = 1 and c.LastActionTypeID in(5,39,41)
            



   
END
