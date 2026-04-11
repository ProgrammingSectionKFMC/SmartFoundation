
CREATE VIEW [Housing].[V_GetListAllMetersLastAndBeforeLastRead_WithWrap]
AS
WITH Reads AS
(
    SELECT
        mr.meterReadID,
        mr.meterID_FK,
        mr.meterReadValue,
        mr.dateOfRead,
        mr.entryDate,
        ROW_NUMBER() OVER
        (
            PARTITION BY mr.meterID_FK
            ORDER BY
                mr.meterReadID DESC,
                ISNULL(mr.dateOfRead, mr.entryDate) DESC
        ) AS rn
    FROM Housing.MeterRead mr
    WHERE mr.meterReadActive = 1
      AND EXISTS
      (
          SELECT 1
          FROM Housing.V_GetListMetersLinkedWithBuildings ml
          WHERE ml.meterID_FK = mr.meterID_FK
      )
),

LastRead AS
(
    SELECT
        meterID_FK,
        meterReadID     AS LastMeterReadID,
        meterReadValue  AS LastReadValue,
        ISNULL(dateOfRead, entryDate) AS LastReadDate
    FROM Reads
    WHERE rn = 1
),

BeforeLastRead AS
(
    SELECT
        meterID_FK,
        meterReadID     AS BeforeLastMeterReadID,
        meterReadValue  AS BeforeLastReadValue,
        ISNULL(dateOfRead, entryDate) AS BeforeLastReadDate
    FROM Reads
    WHERE rn = 2
),

MeterMax AS
(
    SELECT
        m.meterID,
        mt.meterMaxRead
    FROM Housing.Meter m
    INNER JOIN Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
)

SELECT
    l.meterID_FK,

    l.LastMeterReadID,
    l.LastReadValue,
    l.LastReadDate,

    b.BeforeLastMeterReadID,
    b.BeforeLastReadValue,
    b.BeforeLastReadDate,

    mm.meterMaxRead,

    ReadDiff =
        CASE
            WHEN b.BeforeLastReadValue IS NULL OR l.LastReadValue IS NULL THEN NULL
            WHEN l.LastReadValue >= b.BeforeLastReadValue
                THEN l.LastReadValue - b.BeforeLastReadValue
            WHEN l.LastReadValue < b.BeforeLastReadValue
                THEN (ISNULL(mm.meterMaxRead, 0) - b.BeforeLastReadValue) + l.LastReadValue
        END

FROM LastRead l
LEFT JOIN BeforeLastRead b
    ON b.meterID_FK = l.meterID_FK
LEFT JOIN MeterMax mm
    ON mm.meterID = l.meterID_FK;