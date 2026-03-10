-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[HousingExtendDL] 
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
	    -- MeterReadForOccubentAndExit Data
 -- HousingExtend Data

          
   SELECT 
            w.ActionID,
            ROW_NUMBER() OVER (
            ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
            ) AS WaitingListOrder,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
             case 
            when w.LastActionTypeID = 2 then Null
            else
            w.LastActionDecisionNo
            END LastActionDecisionNo,
            case 
            when w.LastActionTypeID = 2 then Null
            else
            convert(nvarchar(10),w.[LastActionDecisionDate],23) 
            END LastActionDecisionDate,
            convert(nvarchar(10),w.[buildingActionFromDate],23) ExtendFromDate,
            convert(nvarchar(10),w.[buildingActionToDate],23) ExtendToDate,
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
            w.LastActionExtendReasonTypeID,
            ert.ExtendReasonTypeName_A,
             w.LastActionEntryDate,
            isnull(w.LastActionNote,w.ActionNote) ActionNote,
            w.IdaraId
           
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
        left join Housing.ExtendReasonType ert on w.LastActionExtendReasonTypeID = ert.ExtendReasonTypeID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (2,48,49,50,51,52,24)
      order by w.LastActionEntryDate desc
      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)


      Select e.ExtendReasonTypeID,e.ExtendReasonTypeName_A 
      from Housing.ExtendReasonType e
      where e.Active = 1



END
