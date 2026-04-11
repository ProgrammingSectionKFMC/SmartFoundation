-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[HousingResidentDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
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
            w.AssignPeriodID,
            (select count(*) from Housing.MeterForBuilding m 
            where m.buildingDetailsID_FK = w.buildingDetailsID 
            and m.IdaraID_FK = w.IdaraId 
            and m.meterForBuildingActive = 1) meterscount
           
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (45,46,47,2)
      order by w.LastActionTypeID desc,  w.waitingClassSequence asc
      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- AssignPeriod DDL
            --SELECT c.AssignPeriodID,c.AssignPeriodDescrption
            --FROM [DATACORE].[Housing].[AssignPeriod] c
            --where  c.IdaraId_FK = @idaraID and c.AssignPeriodActive = 1 and c.AssignPeriodClose = 0 and c.AssignPeriodEnddate is not null
            --and c.AssignPeriodFinalEND = 1 and c.AssignPeriodFinalEnddate is null
            --order by c.AssignPeriodID asc


  



   
END