

CREATE   VIEW [Housing].[V_ResidentServiceAverageBills]
AS
SELECT
    b.residentInfoID_FK,
    b.meterServiceTypeID,

    AvgTotalPrice = 
        CAST(
            AVG(CAST(b.TotalPrice AS DECIMAL(18,2))) 
        AS DECIMAL(18,2)),

    CountBills = COUNT(*)

FROM  Housing.Bills b
WHERE b.residentInfoID_FK IS NOT NULL
  AND b.meterServiceTypeID IS NOT NULL
  AND b.BillActive = 1
  AND b.TotalPrice IS NOT NULL
GROUP BY 
    b.residentInfoID_FK,
    b.meterServiceTypeID;
