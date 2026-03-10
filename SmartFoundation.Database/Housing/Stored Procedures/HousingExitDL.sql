-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[HousingExitDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @NationalID NVARCHAR(400)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 -- HousingExit Data

 Declare @residentInfoID Bigint
 Set @residentInfoID = (select f.residentInfoID from  Housing.V_GetFullResidentDetails f where f.NationalID = @NationalID)

            SELECT 

            w.ActionID,
            ROW_NUMBER() OVER (
            ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
            ) AS WaitingListOrder,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
             case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24) then Null
            else
            w.LastActionDecisionNo
            END LastActionDecisionNo,
            case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24) then Null
            else
            convert(nvarchar(10),w.[LastActionDecisionDate],23) 
            END LastActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
             case 
            when w.LastActionTypeID is null Then N'0' 
            ELSE
            w.LastActionTypeID
            END LastActionTypeID,


            w.LastActionID,
            case 
            when w.LastActionTypeID in (54,55,56,57,58,59,60,3) Then convert(nvarchar(10),w.LastActionDate,23)
            ELSE
            Null
            END LastActionDate,
           
            case 
            when w.LastActionTypeID in (48,49,50,51,52) Then N'تحت اجراءات الامهال' 
            when w.LastActionTypeID is null Then N'لازال بقائمة الانتظار' 
            ELSE
            ba.buildingActionTypeResidentAlias
            END buildingActionTypeResidentAlias
            ,
            w.buildingDetailsID,
            w.buildingDetailsNo,
            case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24,54,55,56,57,58,59,60,3) then Null
            else
           isnull(w.LastActionNote,w.ActionNote)
            END ActionNote,

             case 
            when w.LastActionTypeID in (2,24) then 1
            else
            0
            END CanExit,
            b.TotalPrice penaltyPrice ,
            b.BillsID,
            b.PenaltyReason,
            

            w.IdaraId
           
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        left Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
        left join Housing.Bills b on w.residentInfoID = b.residentInfoID_FK and w.buildingDetailsID = b.buildingDetailsID and b.BillChargeTypeID_FK = 5 and b.BillActive = 1
    WHERE w.IdaraId = @idaraID
      AND  (w.LastActionTypeID in (2,48,49,50,51,52,24,54,55,56,57,58,59,60,3) or w.LastActionTypeID is null)
      AND w.residentInfoID = @residentInfoID
      order by w.LastActionEntryDate desc






END
