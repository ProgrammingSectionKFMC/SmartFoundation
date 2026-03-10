

CREATE   FUNCTION [Housing].[GetListAllMetersReadByPeriodID]
(
    @PeriodID INT
)
RETURNS TABLE
AS
RETURN
WITH Meters AS
(
    -- ✅ مصدر واحد سريع (VIEW) بدل استدعاء دالة مرتين
    SELECT
        mb.meterNo,
        mb.meterID,
        mb.meterName_A,
        mb.meterName_E,
        mb.meterDescription,
        mb.buildingDetailsNo,
        mb.buildingUtilityTypeID_FK,
        mb.buildingDetailsID_FK,
        mb.meterTypeID_FK,

        mb.meterTypeConversionFactor,

        mb.meterServicePrice,
        mb.meterServicePriceStartDate,
        meterServicePriceEndDate =
            ISNULL(CAST(mb.meterServicePriceEndDate AS DATE),
                   DATEADD(YEAR, 10, CAST(mb.meterServicePriceStartDate AS DATE))),
        mb.meterServiceTypeID_FK
    FROM  Housing.V_GetListMetersLinkedWithBuildings mb
),
ReadsRanked AS
(
    -- ✅ أهم تحسين: فلترة period + active أولاً، ثم اختيار آخر قراءة لكل عداد
    SELECT
        mr.meterID_FK,
        mr.meterReadID,
        mr.meterReadValue,
        mr.generalNo_FK,
        mr.meterReadTypeID_FK,
        mr.billPeriodID_FK,
        rn = ROW_NUMBER() OVER
        (
            PARTITION BY mr.meterID_FK
            ORDER BY mr.dateOfRead DESC, mr.meterReadID DESC
        )
    FROM  Housing.MeterRead mr
    WHERE mr.billPeriodID_FK = @PeriodID
      AND mr.meterReadActive = 1
),
LastRead AS
(
    SELECT
        r.meterID_FK,
        r.meterReadID,
        r.meterReadValue,
        r.generalNo_FK,
        r.meterReadTypeID_FK,
        billPeriodID = r.billPeriodID_FK
    FROM ReadsRanked r
    WHERE r.rn = 1
),
Slides AS
(
    -- ✅ الشرائح حسب نوع الخدمة/المنفعة (كما عندك سابقاً)
    SELECT
        ms.buildingUtilityTypeID_FK,
        ms.meterSlideMinValue1,
        ms.meterSlideMaxValue1,
        ms.SlidePriceFactor1,

        ms.meterSlideMinValue2,
        ms.meterSlideMaxValue2,
        ms.SlidePriceFactor2,

        ms.meterSlideMinValue3,
        ms.meterSlideMaxValue3,
        ms.SlidePriceFactor3
    FROM  Housing.V_GetListMeterSlidesPrice ms
)
SELECT
    m.meterNo,
    m.meterID,
    m.meterName_A,
    m.meterName_E,
    m.meterDescription,
    m.buildingDetailsNo,
    m.buildingUtilityTypeID_FK,
    m.buildingDetailsID_FK,
    m.meterTypeID_FK,

    lr.meterReadTypeID_FK,

    CAST(ISNULL(lr.meterReadValue,0) * ISNULL(m.meterTypeConversionFactor,0) AS BIGINT) AS meterReadValue,
    lr.billPeriodID,

    m.meterServicePrice,
    m.meterServicePriceStartDate,
    m.meterServicePriceEndDate,
    m.meterServiceTypeID_FK,

    s.meterSlideMinValue1,
    s.meterSlideMaxValue1,
    s.SlidePriceFactor1,

    s.meterSlideMinValue2,
    s.meterSlideMaxValue2,
    s.SlidePriceFactor2,

    s.meterSlideMinValue3,
    s.meterSlideMaxValue3,
    s.SlidePriceFactor3,

    lr.meterReadID,
    lr.generalNo_FK
FROM Meters m
LEFT JOIN LastRead lr
    ON lr.meterID_FK = m.meterID
LEFT JOIN Slides s
    ON s.buildingUtilityTypeID_FK = m.buildingUtilityTypeID_FK;
