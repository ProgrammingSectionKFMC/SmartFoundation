
CREATE   VIEW [Housing].[V_LastMeterRead_Type1]
AS
WITH LastReads AS
(
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY meterID_FK
               ORDER BY dateOfRead DESC, meterReadID DESC
           ) AS rn
    FROM Housing.MeterRead
    WHERE (billPeriodID_FK = 1 OR billPeriodID_FK IS NULL)
      AND meterReadTypeID_FK = 4
      AND meterReadActive = 1
)
SELECT
    meterReadID,
    meterReadTypeID_FK,
    meterID_FK,
    billPeriodID_FK,
    residentInfoID_FK,
    generalNo_FK,
    buildingDetailsID,
    buildingDetailsNo,
    dateOfRead,
    meterReadValue,
    buildingActionID_FK,
    meterReadActive,
    CanceledBy,
    IdaraID_FK,
    entryDate,
    entryData,
    hostName
FROM LastReads
WHERE rn = 1;
