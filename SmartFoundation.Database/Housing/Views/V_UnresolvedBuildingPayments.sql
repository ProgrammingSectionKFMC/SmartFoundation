
/* قائمة المراجعة: مستفيد غير معروف أو سداد سابق للسكن. */
CREATE   VIEW [Housing].[V_UnresolvedBuildingPayments]
AS
SELECT paymentRow.*, statusRow.[buildingPaymentLinkStatusName_A]
FROM [Housing].[BuildingPayment] paymentRow
JOIN [Housing].[BuildingPaymentLinkStatus] statusRow
  ON statusRow.[buildingPaymentLinkStatusID] = paymentRow.[buildingPaymentLinkStatusID_FK]
WHERE paymentRow.[buildingPaymentLinkStatusID_FK] IN (3,4);

GO

