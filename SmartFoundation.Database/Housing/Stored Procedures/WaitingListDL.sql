-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[WaitingListDL] 
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
      AND 
      w.IdaraId = @idaraID
      AND  (w.LastActionTypeID is null or w.LastActionTypeID in (34,35))



     -- WaitingClass DDL
            SELECT c.waitingClassID,c.waitingClassName_A
            FROM [DATACORE].[Housing].[WaitingClass] c
            --where (c.idara_FK is null or c.idara_FK = @idaraID)
            order by c.waitingClassSequence asc




  
            



   
END
