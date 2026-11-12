
/* الرصيد العام للمستفيد: الحالة 2 فقط ولا يدخل في إخلاء مبنى. */
CREATE   VIEW [Housing].[V_SumUnallocatedPaymentsForResident]
AS
SELECT
    paymentRow.[residentInfoID_FK] [residentInfoID],
    paymentRow.[BillChargeTypeID_FK] [BillChargeTypeID],
    paymentRow.[IdaraId_FK] [IdaraId],
    SUM(paymentRow.[amount]) [UnallocatedAmount]
FROM [Housing].[BuildingPayment] paymentRow
JOIN [Housing].[DeductList] deductRow
  ON deductRow.[deductListID] = paymentRow.[deductListID_FK]
WHERE deductRow.[deductActive] = 1
  AND paymentRow.[buildingPayementActive] = 1
  AND paymentRow.[buildingPaymentLinkStatusID_FK] = 2
  AND paymentRow.[residentInfoID_FK] IS NOT NULL
GROUP BY paymentRow.[residentInfoID_FK], paymentRow.[BillChargeTypeID_FK],
         paymentRow.[IdaraId_FK];

GO

