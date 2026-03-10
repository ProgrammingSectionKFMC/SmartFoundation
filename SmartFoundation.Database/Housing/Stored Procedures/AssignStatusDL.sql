-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
Create PROCEDURE [Housing].[AssignStatusDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	,@AssignPeriodID  INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

      -- WaitingList Data

          
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
            isnull((select count(*) FROM Housing.V_WaitingList w  WHERE w.AssignPeriodID = @AssignPeriodID and w.LastActionTypeID in (38,40) ),0) Count_
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE w.AssignPeriodID = @AssignPeriodID
      AND w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (38,39,40,41,42,45)
      order by   w.waitingClassSequence asc
      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- AssignPeriod DDL
            SELECT c.AssignPeriodID,c.AssignPeriodDescrption
            FROM [DATACORE].[Housing].[AssignPeriod] c
            where  c.IdaraId_FK = @idaraID and c.AssignPeriodActive = 1 and c.AssignPeriodClose = 0 and c.AssignPeriodEnddate is not null
            and c.AssignPeriodFinalEND = 1 and c.AssignPeriodFinalEnddate is null
            order by c.AssignPeriodID asc



      -- BuildingActionTypeCases

      select 
      case 
      when bt.buildingActionTypeID in (39,41) then 0 
      when bt.buildingActionTypeID in (45) then 1 
      end buildingActionTypeID
      ,
       case 
      when bt.buildingActionTypeID in (39,41) then N'رفض المستفيد المنزل او لم يراجع لاستلامه' 
      when bt.buildingActionTypeID in (45) then N'وافق المستفيد على المنزل وتم اعتماده'
      end buildingActionTypeName_A 
      from Housing.BuildingActionType bt
      where bt.buildingActionTypeID in (39,45)

    order by bt.buildingActionTypeID desc

  



   
END
