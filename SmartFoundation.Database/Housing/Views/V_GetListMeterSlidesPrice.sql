

CREATE   VIEW [Housing].[V_GetListMeterSlidesPrice]
AS
SELECT
    ms.buildingUtilityTypeID_FK,
    ms.meterServiceTypeID_FK,

    meterSlideMinValue1  = MAX(CASE WHEN ms.meterSlideSequence = 1  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue1  = MAX(CASE WHEN ms.meterSlideSequence = 1  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor1    = MAX(CASE WHEN ms.meterSlideSequence = 1  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue2  = MAX(CASE WHEN ms.meterSlideSequence = 2  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue2  = MAX(CASE WHEN ms.meterSlideSequence = 2  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor2    = MAX(CASE WHEN ms.meterSlideSequence = 2  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue3  = MAX(CASE WHEN ms.meterSlideSequence = 3  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue3  = MAX(CASE WHEN ms.meterSlideSequence = 3  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor3    = MAX(CASE WHEN ms.meterSlideSequence = 3  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue4  = MAX(CASE WHEN ms.meterSlideSequence = 4  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue4  = MAX(CASE WHEN ms.meterSlideSequence = 4  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor4    = MAX(CASE WHEN ms.meterSlideSequence = 4  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue5  = MAX(CASE WHEN ms.meterSlideSequence = 5  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue5  = MAX(CASE WHEN ms.meterSlideSequence = 5  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor5    = MAX(CASE WHEN ms.meterSlideSequence = 5  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue6  = MAX(CASE WHEN ms.meterSlideSequence = 6  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue6  = MAX(CASE WHEN ms.meterSlideSequence = 6  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor6    = MAX(CASE WHEN ms.meterSlideSequence = 6  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue7  = MAX(CASE WHEN ms.meterSlideSequence = 7  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue7  = MAX(CASE WHEN ms.meterSlideSequence = 7  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor7    = MAX(CASE WHEN ms.meterSlideSequence = 7  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue8  = MAX(CASE WHEN ms.meterSlideSequence = 8  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue8  = MAX(CASE WHEN ms.meterSlideSequence = 8  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor8    = MAX(CASE WHEN ms.meterSlideSequence = 8  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue9  = MAX(CASE WHEN ms.meterSlideSequence = 9  THEN ms.meterSlideMinValue END),
    meterSlideMaxValue9  = MAX(CASE WHEN ms.meterSlideSequence = 9  THEN ms.meterSlideMaxValue END),
    SlidePriceFactor9    = MAX(CASE WHEN ms.meterSlideSequence = 9  THEN ms.meterSlidePriceFactor END),

    meterSlideMinValue10 = MAX(CASE WHEN ms.meterSlideSequence = 10 THEN ms.meterSlideMinValue END),
    meterSlideMaxValue10 = MAX(CASE WHEN ms.meterSlideSequence = 10 THEN ms.meterSlideMaxValue END),
    SlidePriceFactor10   = MAX(CASE WHEN ms.meterSlideSequence = 10 THEN ms.meterSlidePriceFactor END)

FROM  Housing.MeterSlide ms
GROUP BY
    ms.buildingUtilityTypeID_FK,
    ms.meterServiceTypeID_FK;
