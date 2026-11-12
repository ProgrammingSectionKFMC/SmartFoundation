-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[AssignStatusDL] 
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


    -- تحميل سجلات المحضر المطلوب مرة واحدة
-- قبل عمليات الربط وتتبع السلاسل

SELECT w.*
INTO #AssignStatusWaiting
FROM Housing.V_WaitingList w
WHERE w.AssignPeriodID = @AssignPeriodID
  AND w.IdaraId = @idaraID
  AND w.LastActionTypeID IN (27,38,39,40,41,42,45);

CREATE NONCLUSTERED INDEX
    IX_AssignStatusWaiting_ActionID
ON #AssignStatusWaiting (ActionID);
	   
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
            
            
            CASE AllocationState.StatusOrder
                WHEN 1 THEN
                    N'تم التخصيص له في هذا المحضر وبانتظار المعالجة'
            
                WHEN 2 THEN
                    N'تم التخصيص له في هذا المحضر وتمت معالجته'
            
                ELSE
                    N'لم يتم التخصيص له في هذا المحضر'
            END AS AssignmentPeriodStatus,

            CASE AllocationState.StatusOrder
                WHEN 1 THEN
                    1
            
                WHEN 2 THEN
                   2
            
                ELSE
                    3
            END AS AssignmentPeriodStatusint,
            
            

            ba.buildingActionTypeResidentAlias,

            w.buildingDetailsID,
            w.buildingDetailsNo,
            ml.militaryLocationName_A,
            isnull(w.LastActionNote,w.ActionNote) ActionNote,
            w.IdaraId,
            w.AssignPeriodID,

SUM(
    CASE
        WHEN w.LastActionTypeID IN (38, 40)
            THEN 1
        ELSE 0
    END
) OVER () AS Count_,
            
            rd.militaryUnitName_A
            
            
            
            
    FROM #AssignStatusWaiting w
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
        LEFT JOIN Housing.BuildingDetails bd
    ON bd.buildingDetailsID = w.buildingDetailsID

LEFT JOIN Housing.MilitaryLocation ml
    ON ml.militaryLocationID = bd.militaryLocationID_FK
        
-- التحقق من تخصيص المنزل داخل المحضر المحدد
OUTER APPLY
(
    SELECT TOP (1)
        h.buildingActionID AS AllocationActionID
    FROM Housing.fn_BuildingAction_ChainToRoot(
        w.LastActionID
    ) h
    WHERE h.AssignPeriodID_FK = @AssignPeriodID
      AND h.buildingActionTypeID_FK IN (38, 40)
      AND h.residentInfoID_FK = w.residentInfoID
    ORDER BY h.buildingActionID DESC
) CurrentAllocation

-- تحديد الحالة والترتيب مرة واحدة
CROSS APPLY
(
    SELECT
        CASE
            WHEN CurrentAllocation.AllocationActionID IS NOT NULL
                 AND w.LastActionTypeID IN (38, 40)
            THEN 1

            WHEN CurrentAllocation.AllocationActionID IS NOT NULL
                 AND w.LastActionTypeID IN (39, 41, 42, 45)
            THEN 2

            ELSE 3
        END AS StatusOrder
) AllocationState

    WHERE w.AssignPeriodID = @AssignPeriodID
      AND w.IdaraId = @idaraID
      --AND  w.LastActionTypeID in (38,39,40,41,42,45)
      AND w.LastActionTypeID IN (27,38,39,40,41,42,45)
      

ORDER BY

    -- 1: مخصص له وينتظر المعالجة
    -- 2: مخصص له وتمت معالجته
    -- 3: لم يتم تخصيص منزل له
    AllocationState.StatusOrder ASC,

    -- ترتيب الإجراءات داخل كل مجموعة
    CASE
        WHEN w.LastActionTypeID = 38 THEN 1
        WHEN w.LastActionTypeID = 40 THEN 2
        WHEN w.LastActionTypeID = 45 THEN 3
        WHEN w.LastActionTypeID = 39 THEN 4
        WHEN w.LastActionTypeID = 41 THEN 5
        WHEN w.LastActionTypeID = 42 THEN 6
        WHEN w.LastActionTypeID = 27 THEN 7
        ELSE 999
    END ASC,

    w.ActionDecisionDate ASC,
    w.GeneralNo ASC,
    w.ActionID ASC;



      --AND (w.InAssignPeriod = 0 or w.InAssignPeriod is null)
      --order by   w.waitingClassSequence asc
      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- AssignPeriod DDL
            SELECT c.AssignPeriodID,N'محضر تخصيص '+wc.waitingClassName_A+N' برقم '+CONVERT(nvarchar(100),c.AssignPeriodID) as AssignPeriodDescrptionText
            FROM [DATACORE].[Housing].[AssignPeriod] c
            inner join Housing.WaitingClass wc on c.WaitingClassID_FK = wc.WaitingClassID
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

GO

