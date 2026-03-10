

CREATE   VIEW [Housing].[V_ResidentFinancialSummary]
AS
SELECT
    f.residentInfoID,

    -- إجمالي فواتير الإيجار
    ISNULL(
        (
            SELECT SUM(r.rentBillsAmount)
            FROM Housing.RentBills r
            WHERE r.residentInfoID_FK = f.residentInfoID
        ), 0
    ) AS TotalRentBillsAmount,

    -- إجمالي المدفوع من الإيجار
    ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.generalNo_FK = f.generalNo_FK
        ), 0
    ) AS TotalRentBillsPaid,

    -- إجمالي فواتير الخدمات
    ISNULL(
        (
            SELECT SUM(b.TotalPrice)
            FROM  Housing.Bills b
            INNER JOIN Housing.BillsDeductListDetails d
                ON b.BillsID = d.billsID_FK
            WHERE b.residentInfoID_FK = f.residentInfoID
              AND b.BillActive = 1
              AND d.billActive = 1
        ), 0
    ) AS TotalServiceBillsAmount,

    -- إجمالي المدفوع من فواتير الخدمات
    ISNULL(
        (
            SELECT SUM(d.paidAmount)
            FROM  Housing.Bills b
            INNER JOIN Housing.BillsDeductListDetails d
                ON b.BillsID = d.billsID_FK
            WHERE b.residentInfoID_FK = f.residentInfoID
              AND b.BillActive = 1
              AND d.billActive = 1
              AND d.billPaid = 1
              AND d.paidDate IS NOT NULL
        ), 0
    ) AS TotalServiceBillsPaid

FROM Housing.V_GetFullResidentDetails f;
