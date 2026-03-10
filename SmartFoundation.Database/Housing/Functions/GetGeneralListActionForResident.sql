








create FUNCTION [Housing].[GetGeneralListActionForResident]
(
   
)
RETURNS TABLE AS RETURN
(
   SELECT        
   ba.buildingActionID AS ActionID, 
   ba.buildingActionTypeID_FK AS ActionTypeID, 
   bat.buildingActionTypeName_A AS ActionTypeName, 
   ba.generalNo_FK AS GeneralNo, 
   ba.buildingPaymentTypeID_FK AS PaymentTypeID, 
   bpt.buildingPaymentTypeName_A AS PaymentTypeName, 
   ba.buildingDetailsNo AS BuildingNo, 
   CAST(ba.buildingActionDate as date) AS ActionDate, 
   ba.buildingActionDecisionNo AS ActionDecisionNo, 
   CAST(ba.buildingActionDecisionDate as date) AS ActionDecisionDate, 
   ba.buildingActionNote AS ActionNote, 
   CAST(ba.buildingActionFromDate as date) AS ActionFromDate,
   CAST(ba.buildingActionToDate as date) AS ActionToDate,
   ba.buildingActionExtraType1 AS WaitingClassID, 
   wc.waitingClassName_A AS WaitingClassName, 
   ba.buildingActionExtraType2 AS WaitingOrderTypeID, 
   wot.waitingOrderTypeName_A AS WaitingOrderTypeName,
   wc.waitingClassSequence,
   ba.buildingActionParentID AS buildingActionParentID,
   ba.entryDate,
   ba.entryData

FROM            Housing.BuildingAction AS ba 
INNER JOIN Housing.BuildingActionType AS bat ON ba.buildingActionTypeID_FK = bat.buildingActionTypeID  AND bat.buildingActionTypeActive = 1
left JOIN Housing.BuildingPaymentType AS bpt ON ba.buildingPaymentTypeID_FK = bpt.buildingPaymentTypeID  AND bpt.buildingPaymentTypeActive = 1
left JOIN Housing.WaitingClass AS wc ON ba.buildingActionExtraType1 = wc.waitingClassID 
left JOIN Housing.WaitingOrderType AS wot ON ba.buildingActionExtraType2 = wot.waitingOrderTypeID AND wot.waitingOrderTypeActive = 1
WHERE        (1 = 1) 
AND (ba.generalNo_FK is not null)
AND (ba.generalNo_FK <> '')
 

)


