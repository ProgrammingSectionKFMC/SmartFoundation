


CREATE   VIEW [Housing].[V_Occupant]
AS
SELECT 
     w.[ActionID]
    ,w.[ActionTypeID]

    ,ba.buildingActionDate       AS OccupentDate
    ,ba.buildingActionID         AS OccupentActionID
    ,ba.buildingActionTypeID_FK  AS OccupentActionTypeID
    ,ba.buildingActionDecisionDate  AS OccupentDecisionDate
    ,ba.buildingActionDecisionNo  AS OccupentDecisionNo

    ,w.[NationalID]
    ,w.[GeneralNo]
    ,w.[ActionDecisionNo]
    ,w.[ActionDecisionDate]
    ,w.[WaitingClassID]
    ,w.[WaitingClassName]
    ,w.[WaitingOrderTypeID]
    ,w.[WaitingOrderTypeName]
    ,w.[waitingClassSequence]
    ,w.[ActionDate]
    ,w.[residentInfoID]
    ,w.[fullname]
    ,w.[ActionNote]
    ,w.[IdaraId]
    ,w.[ActionIdaraName]
    ,w.[MainActionEntryData]
    ,w.[MainActionEntryDate]
    ,w.[ToIdaraID]
    ,w.[Toidaraname]
    ,w.[buildingDetailsID]
    ,w.[buildingDetailsNo]
    ,w.[LastActionTypeID]
    ,w.[LastActionID]
    ,w.[LastActionIdaraID]
    ,w.[LastActionIdaraName]
    ,w.[LastActionTypeName]
    ,w.[AssignPeriodID]
    ,w.[LastActionbuildingActionParentID]
    ,w.[LastActionNote]
    ,w.[LastActionEntryDate]
    ,w.[LastActionEntryData]
    ,w.[ResidentIdaraID]
FROM Housing.V_WaitingListWithLetters w
INNER JOIN Housing.BuildingActionType bat
    ON bat.buildingActionTypeID = w.LastActionTypeID
   AND bat.IsResident = 1
OUTER APPLY
(
    SELECT TOP (1)
          ba1.buildingActionDate
        , ba1.buildingActionID
        , ba1.buildingActionTypeID_FK
        , ba1.buildingActionDecisionDate
        , ba1.buildingActionDecisionNo
    FROM Housing.BuildingAction ba1
    WHERE ba1.residentInfoID_FK = w.residentInfoID
      AND ba1.buildingDetailsID_FK = w.buildingDetailsID
      AND ba1.buildingActionTypeID_FK = 2     -- ✅ تاريخ السكن فقط من نوع 2
      AND ba1.buildingActionActive = 1
    ORDER BY ba1.buildingActionDate DESC, ba1.buildingActionID DESC
) ba
WHERE ba.buildingActionID IS NOT NULL;   -- مثل INNER JOIN (لازم يوجد تسكين نوع 2)
