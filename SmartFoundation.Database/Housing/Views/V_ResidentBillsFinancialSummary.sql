

CREATE   VIEW [Housing].[V_ResidentBillsFinancialSummary]
AS
SELECT
    f.residentInfoID,

    -- إجمالي فواتير الإيجار
    ISNULL(
        (
            SELECT SUM(r.TotalPrice)
            FROM Housing.Bills r
            WHERE r.residentInfoID_FK = f.residentInfoID and r.BillChargeTypeID_FK = 1
              AND r.BillActive = 1
        ), 0
    ) AS TotalRentBillsAmount,

    -- إجمالي المدفوع من الإيجار
    ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.residentInfoID_FK = f.residentInfoID
            and p.BillChargeTypeID_FK = 1
            and p.buildingPayementActive = 1
        ), 0
    ) AS TotalRentBillsPaid,

    -- إجمالي فواتير الكهرباء
    ISNULL(
        (
            SELECT SUM(r.TotalPrice)
            FROM Housing.Bills r
            WHERE r.residentInfoID_FK = f.residentInfoID and r.BillChargeTypeID_FK = 2
              AND r.BillActive = 1
        ), 0
    ) AS TotalElectrecityBillsAmount,

     -- إجمالي المدفوع من الكهرباء
    ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.residentInfoID_FK = f.residentInfoID
            and p.BillChargeTypeID_FK = 2
            and p.buildingPayementActive = 1
        ), 0
    ) AS TotalElectrecityBillsPaid,

     -- إجمالي فواتير الماء
    ISNULL(
        (
            SELECT SUM(r.TotalPrice)
            FROM Housing.Bills r
            WHERE r.residentInfoID_FK = f.residentInfoID and r.BillChargeTypeID_FK = 3
              AND r.BillActive = 1
        ), 0
    ) AS TotalWaterBillsAmount,

     -- إجمالي المدفوع من الماء
     ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.residentInfoID_FK = f.residentInfoID
            and p.BillChargeTypeID_FK = 3
            and p.buildingPayementActive = 1
        ), 0
    ) AS TotalWaterBillsPaid,


      -- إجمالي فواتير الغاز
    ISNULL(
        (
            SELECT SUM(r.TotalPrice)
            FROM Housing.Bills r
            WHERE r.residentInfoID_FK = f.residentInfoID and r.BillChargeTypeID_FK = 4
              AND r.BillActive = 1
        ), 0
    ) AS TotalGasBillsAmount,

     -- إجمالي المدفوع من الغاز
    ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.residentInfoID_FK = f.residentInfoID
            and p.BillChargeTypeID_FK = 4
            and p.buildingPayementActive = 1

        ), 0
    ) AS TotalGasBillsPaid,

       -- إجمالي فواتير الغرامات
    ISNULL(
        (
            SELECT SUM(r.TotalPrice)
            FROM Housing.Bills r
            WHERE r.residentInfoID_FK = f.residentInfoID and r.BillChargeTypeID_FK = 5
              AND r.BillActive = 1
        ), 0
    ) AS TotalFineBillsAmount,

     -- إجمالي المدفوع من الغرامات
    ISNULL(
        (
            SELECT SUM(p.amount)
            FROM Housing.BuildingPayment p
            WHERE p.residentInfoID_FK = f.residentInfoID
            and p.BillChargeTypeID_FK = 5
            and p.buildingPayementActive = 1
        ), 0
    ) AS TotalFineBillsPaid

 

FROM Housing.V_GetFullResidentDetails f;
