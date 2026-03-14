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
            ert.ExtendReasonTypeID,
             w.LastActionEntryDate,
            isnull(w.LastActionNote,w.ActionNote) ActionNote,
            w.IdaraId
            ,
            isnull(sum_.Remaining,0.00) Remaining
            , br.buildingRentAmount
            ,(br.buildingRentAmount * 40.00) InsuranceAmount
            ,(br.buildingRentAmount * 40.00) +isnull(sum_.Remaining,0.00) InsuranceAmountWithRemaining
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
        left join Housing.ExtendReasonType ert on w.LastActionExtendReasonTypeID = ert.ExtendReasonTypeID
        left join Housing.V_buildingWithRent br on w.buildingDetailsID = br.buildingDetailsID
         LEFT JOIN 
        (
         SELECT 
    e.residentInfoID,e.buildingDetailsID,
    SUM(e.SumBillsTotalPrice) AS SumBillsTotalPrice,
    SUM(e.SumTotalPaidBills) AS SumTotalPaidBills,
    case
        when SUM(e.Remaining) < 0 then SUM(e.Remaining) * -1
        else SUM(e.Remaining)
    end as Remaining,
    --SUM(e.Remaining) AS Remaining,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN N'مطالب بمبالغ للادارة'
        WHEN SUM(e.Remaining) < 0 THEN N'يوجد مبالغ زائدة للمستفيد'
        ELSE N'لايوجد مطالبات'
    END AS BillsStatus,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN 0
        WHEN SUM(e.Remaining) < 0 THEN 1
        ELSE 2
    END AS BillsStatusID
FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
GROUP BY e.residentInfoID,e.buildingDetailsID
        ) sum_ on w.residentInfoID = sum_.residentInfoID and w.buildingDetailsID = sum_.buildingDetailsID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (2,48,49,50,51,52,24)
      order by w.LastActionEntryDate desc
      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)


      Select e.ExtendReasonTypeID,e.ExtendReasonTypeName_A 
      from Housing.ExtendReasonType e
      where e.Active = 1



END