

CREATE   VIEW [Housing].[V_MeterLastBill]
AS
WITH x AS (
    SELECT
        b.*,
        rn = ROW_NUMBER() OVER (
            PARTITION BY b.meterID, b.meterServiceTypeID
            ORDER BY
                ISNULL(b.PeriodYear, 0) DESC,
                ISNULL(b.PeriodMonth, 0) DESC,
                ISNULL(b.CurrentPeriodID, 0) DESC,
                b.BillsID DESC
        )
    FROM Housing.Bills b
    WHERE b.BillActive = 1
      AND b.meterID IS NOT NULL
      AND b.meterServiceTypeID IS NOT NULL
)
SELECT
    -- نرجّع كل الأعمدة الأصلية بدون rn
    BillsID, BillsUID, BillChargeTypeID_FK, BillNumber, BillTypeID_FK,
    PerviosPeriodID, CurrentPeriodID, PeriodMonth, PeriodYear, CurrentPeriodTax,
    meterNo, meterID, meterName_A, meterName_E, meterDescription,
    buildingDetailsNo, buildingUtilityTypeID, buildingDetailsID,
    meterTypeID, meterServiceTypeID, meterReadID,
    residentInfoID_FK, generalNo_FK,
    CurrentRead, LastRead, ReadDiff,
    meterSlideMinValue1, meterSlideMaxValue1, SlidePriceFactor1, PriceForSlide1,
    meterSlideMinValue2, meterSlideMaxValue2, SlidePriceFactor2, PriceForSlide2,
    meterSlideMinValue3, meterSlideMaxValue3, SlidePriceFactor3, PriceForSlide3,
    meterSlideMinValue4, meterSlideMaxValue4, SlidePriceFactor4, PriceForSlide4,
    meterSlideMinValue5, meterSlideMaxValue5, SlidePriceFactor5, PriceForSlide5,
    meterSlideMinValue6, meterSlideMaxValue6, SlidePriceFactor6, PriceForSlide6,
    meterSlideMinValue7, meterSlideMaxValue7, SlidePriceFactor7, PriceForSlide7,
    meterSlideMinValue8, meterSlideMaxValue8, SlidePriceFactor8, PriceForSlide8,
    meterSlideMinValue9, meterSlideMaxValue9, SlidePriceFactor9, PriceForSlide9,
    meterSlideMinValue10, meterSlideMaxValue10, SlidePriceFactor10, PriceForSlide10,
    PRICE, PRICETAX,
    meterServicePrice, meterServicePriceTAX,
    TotalPrice,
    buildingRentTypeID_FK,
    BillsFromDate, BillsToDate,
    PenaltyReason,
    BillActive,
    idaraID_FK,
    entryDate, entryData, hostName
FROM x
WHERE rn = 1;
