
CREATE   FUNCTION [Housing].[CalculteElectrictyBills_ByLastActiveRead_PeriodSource]
(
    @MeterID BIGINT
)
RETURNS TABLE
AS
RETURN

WITH Last2 AS
(
    SELECT TOP (2)
        mr.meterReadID,
        mr.meterID_FK,
        mr.billPeriodID_FK,
        mr.meterReadTypeID_FK,
        mr.generalNo_FK,
        mr.residentInfoID_FK,
        mr.buildingDetailsID,
        mr.buildingDetailsNo,
        mr.dateOfRead,
        mr.meterReadValue,
        rn = ROW_NUMBER() OVER (ORDER BY mr.meterReadID DESC)
    FROM Housing.MeterRead mr
    WHERE mr.meterReadActive = 1
      AND mr.meterID_FK = @MeterID
    ORDER BY mr.meterReadID DESC
),
R AS
(
    SELECT
        CurrentPeriodID   = MAX(CASE WHEN rn=1 THEN billPeriodID_FK END),
        PerviosPeriodID   = MAX(CASE WHEN rn=2 THEN billPeriodID_FK END),

        meterReadID       = MAX(CASE WHEN rn=1 THEN meterReadID END),
        generalNo_FK      = MAX(CASE WHEN rn=1 THEN generalNo_FK END),
        residentInfoID_FK = MAX(CASE WHEN rn=1 THEN residentInfoID_FK END),
        CurrentReadType   = MAX(CASE WHEN rn=1 THEN meterReadTypeID_FK END),
        CurrentRead       = MAX(CASE WHEN rn=1 THEN meterReadValue END),
        CurrentDate       = MAX(CASE WHEN rn=1 THEN dateOfRead END),

        CurrentBuildingID = MAX(CASE WHEN rn=1 THEN buildingDetailsID END),
        CurrentBuildingNo = MAX(CASE WHEN rn=1 THEN buildingDetailsNo END),

        LastReadType      = MAX(CASE WHEN rn=2 THEN meterReadTypeID_FK END),
        LastRead          = MAX(CASE WHEN rn=2 THEN meterReadValue END)
    FROM Last2
),
BP AS
(
    SELECT
        r.*,
        PeriodEndDate = CAST(ISNULL(bp.billPeriodEndDate, r.CurrentDate) AS DATE),
        PeriodMonth   = CAST(DATEPART(MONTH, CAST(ISNULL(bp.billPeriodEndDate, r.CurrentDate) AS DATE)) AS INT),
        PeriodYear    = CAST(DATEPART(YEAR,  CAST(ISNULL(bp.billPeriodEndDate, r.CurrentDate) AS DATE)) AS INT)
    FROM R r
    LEFT JOIN Housing.BillPeriod bp
      ON bp.billPeriodID = r.CurrentPeriodID
),
Tax AS
(
    SELECT
        bp.*,
        CurrentPeriodTax =
            ISNULL((
                SELECT TOP (1) CAST(t.taxRate AS DECIMAL(18,2))
                FROM dbo.Tax t
                WHERE bp.PeriodEndDate BETWEEN t.taxStartDate
                      AND ISNULL(t.taxEndDate, DATEADD(MONTH,2,GETDATE()))
                ORDER BY t.taxStartDate DESC
            ), 0)
    FROM BP bp
),

-- ✅ بيانات العداد (مرتبط / غير مرتبط)
M_Linked AS
(
    SELECT TOP (1)
        v.meterNo,
        v.meterID,
        v.meterName_A,
        v.meterName_E,
        v.meterDescription,
        v.buildingDetailsNo,
        v.buildingUtilityTypeID_FK,
        v.buildingDetailsID_FK,
        v.meterTypeID_FK,
        v.meterServiceTypeID_FK,
        v.meterServicePrice,
        IdaraId_FK = v.MeterIdaraId
    FROM Housing.V_GetListMetersLinkedWithBuildings v
    WHERE v.meterID = @MeterID
),
M_Fallback AS
(
    SELECT TOP (1)
        m.meterNo,
        m.meterID,
        m.meterName_A,
        m.meterName_E,
        m.meterDescription,

        buildingDetailsNo        = NULL,
        buildingUtilityTypeID_FK = NULL,
        buildingDetailsID_FK     = NULL,

        m.meterTypeID_FK,
        mt.meterServiceTypeID_FK,
        meterServicePrice        = CAST(NULL AS DECIMAL(18,2)),
        IdaraId_FK = m.IdaraId_FK  
    FROM Housing.Meter m
    INNER JOIN Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
    WHERE m.meterID = @MeterID
),
M AS
(
    SELECT *
    FROM M_Linked
    UNION ALL
    SELECT *
    FROM M_Fallback
    WHERE NOT EXISTS (SELECT 1 FROM M_Linked)
),

S AS
(
    SELECT
        s.buildingUtilityTypeID_FK,
        s.meterServiceTypeID_FK,

        s.meterSlideMinValue1,  s.meterSlideMaxValue1,  s.SlidePriceFactor1,
        s.meterSlideMinValue2,  s.meterSlideMaxValue2,  s.SlidePriceFactor2,
        s.meterSlideMinValue3,  s.meterSlideMaxValue3,  s.SlidePriceFactor3,
        s.meterSlideMinValue4,  s.meterSlideMaxValue4,  s.SlidePriceFactor4,
        s.meterSlideMinValue5,  s.meterSlideMaxValue5,  s.SlidePriceFactor5,
        s.meterSlideMinValue6,  s.meterSlideMaxValue6,  s.SlidePriceFactor6,
        s.meterSlideMinValue7,  s.meterSlideMaxValue7,  s.SlidePriceFactor7,
        s.meterSlideMinValue8,  s.meterSlideMaxValue8,  s.SlidePriceFactor8,
        s.meterSlideMinValue9,  s.meterSlideMaxValue9,  s.SlidePriceFactor9,
        s.meterSlideMinValue10, s.meterSlideMaxValue10, s.SlidePriceFactor10
    FROM Housing.V_GetListMeterSlidesPrice s
),

X AS
(
    SELECT
        t.PerviosPeriodID,
        t.CurrentPeriodID,
        t.PeriodMonth,
        t.PeriodYear,
        t.CurrentPeriodTax,

        meterNo          = m.meterNo,
        meterID          = m.meterID,
        meterName_A      = m.meterName_A,
        meterName_E      = m.meterName_E,
        meterDescription = m.meterDescription,

        buildingDetailsNo     = COALESCE(m.buildingDetailsNo, t.CurrentBuildingNo),
        buildingUtilityTypeID = m.buildingUtilityTypeID_FK,
        buildingDetailsID     = COALESCE(m.buildingDetailsID_FK, t.CurrentBuildingID),

        meterTypeID        = m.meterTypeID_FK,
        meterServiceTypeID = m.meterServiceTypeID_FK,

        t.meterReadID,
        t.generalNo_FK,
        t.residentInfoID_FK,

        CurrentRead = CAST(t.CurrentRead AS INT),
        LastRead    = CAST(t.LastRead AS INT),

        meterReadTypeIDForCurrentRead = CAST(t.CurrentReadType AS INT),
        meterReadTypeIDForLastRead    = CAST(t.LastReadType AS INT),

        s.meterSlideMinValue1,  s.meterSlideMaxValue1,  s.SlidePriceFactor1,
        s.meterSlideMinValue2,  s.meterSlideMaxValue2,  s.SlidePriceFactor2,
        s.meterSlideMinValue3,  s.meterSlideMaxValue3,  s.SlidePriceFactor3,
        s.meterSlideMinValue4,  s.meterSlideMaxValue4,  s.SlidePriceFactor4,
        s.meterSlideMinValue5,  s.meterSlideMaxValue5,  s.SlidePriceFactor5,
        s.meterSlideMinValue6,  s.meterSlideMaxValue6,  s.SlidePriceFactor6,
        s.meterSlideMinValue7,  s.meterSlideMaxValue7,  s.SlidePriceFactor7,
        s.meterSlideMinValue8,  s.meterSlideMaxValue8,  s.SlidePriceFactor8,
        s.meterSlideMinValue9,  s.meterSlideMaxValue9,  s.SlidePriceFactor9,
        s.meterSlideMinValue10, s.meterSlideMaxValue10, s.SlidePriceFactor10,

        meterServicePrice = m.meterServicePrice,

        IdaraId_FK = m.IdaraId_FK,

        meterMaxRead =
        (
            SELECT TOP (1) mt.meterMaxRead
            FROM Housing.MeterType mt
            WHERE mt.meterTypeID = m.meterTypeID_FK
              AND mt.meterServiceTypeID_FK = m.meterServiceTypeID_FK
        )
    FROM Tax t
    CROSS JOIN M m
    LEFT JOIN S s
      ON s.buildingUtilityTypeID_FK = m.buildingUtilityTypeID_FK
     AND s.meterServiceTypeID_FK    = m.meterServiceTypeID_FK
    WHERE t.CurrentRead IS NOT NULL
      AND t.LastRead IS NOT NULL
),

Calc AS
(
    SELECT
        x.*,
        ReadDiff =
            CASE
                WHEN x.CurrentRead < x.LastRead
                    THEN (ISNULL(x.meterMaxRead,0) - x.LastRead) + x.CurrentRead
                ELSE (x.CurrentRead - x.LastRead)
            END
    FROM X x
),

Qty AS
(
    SELECT
        c.*,

        Q1  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue1,0)  THEN c.ReadDiff ELSE ISNULL(c.meterSlideMaxValue1,0)  END AS DECIMAL(18,4)),
        Q2  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue1,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue2,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue1,0)
                        ELSE ISNULL(c.meterSlideMaxValue2,0) - ISNULL(c.meterSlideMaxValue1,0) END AS DECIMAL(18,4)),
        Q3  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue2,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue3,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue2,0)
                        ELSE ISNULL(c.meterSlideMaxValue3,0) - ISNULL(c.meterSlideMaxValue2,0) END AS DECIMAL(18,4)),
        Q4  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue3,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue4,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue3,0)
                        ELSE ISNULL(c.meterSlideMaxValue4,0) - ISNULL(c.meterSlideMaxValue3,0) END AS DECIMAL(18,4)),
        Q5  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue4,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue5,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue4,0)
                        ELSE ISNULL(c.meterSlideMaxValue5,0) - ISNULL(c.meterSlideMaxValue4,0) END AS DECIMAL(18,4)),
        Q6  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue5,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue6,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue5,0)
                        ELSE ISNULL(c.meterSlideMaxValue6,0) - ISNULL(c.meterSlideMaxValue5,0) END AS DECIMAL(18,4)),
        Q7  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue6,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue7,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue6,0)
                        ELSE ISNULL(c.meterSlideMaxValue7,0) - ISNULL(c.meterSlideMaxValue6,0) END AS DECIMAL(18,4)),
        Q8  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue7,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue8,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue7,0)
                        ELSE ISNULL(c.meterSlideMaxValue8,0) - ISNULL(c.meterSlideMaxValue7,0) END AS DECIMAL(18,4)),
        Q9  = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue8,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue9,0)  THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue8,0)
                        ELSE ISNULL(c.meterSlideMaxValue9,0) - ISNULL(c.meterSlideMaxValue8,0) END AS DECIMAL(18,4)),
        Q10 = CAST(CASE WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue9,0)  THEN 0
                        WHEN c.ReadDiff <= ISNULL(c.meterSlideMaxValue10,0) THEN c.ReadDiff - ISNULL(c.meterSlideMaxValue9,0)
                        ELSE ISNULL(c.meterSlideMaxValue10,0) - ISNULL(c.meterSlideMaxValue9,0) END AS DECIMAL(18,4))
    FROM Calc c
),

Price AS
(
    SELECT
        q.*,

        -- ✅ إذا العامل NULL والسلايد مستخدم (Qn>0) => السعر NULL
        PriceForSlide1  = CASE WHEN q.Q1  > 0 AND q.SlidePriceFactor1  IS NULL THEN NULL ELSE CAST(q.Q1  * ISNULL(q.SlidePriceFactor1,0)  AS DECIMAL(18,2)) END,
        PriceForSlide2  = CASE WHEN q.Q2  > 0 AND q.SlidePriceFactor2  IS NULL THEN NULL ELSE CAST(q.Q2  * ISNULL(q.SlidePriceFactor2,0)  AS DECIMAL(18,2)) END,
        PriceForSlide3  = CASE WHEN q.Q3  > 0 AND q.SlidePriceFactor3  IS NULL THEN NULL ELSE CAST(q.Q3  * ISNULL(q.SlidePriceFactor3,0)  AS DECIMAL(18,2)) END,
        PriceForSlide4  = CASE WHEN q.Q4  > 0 AND q.SlidePriceFactor4  IS NULL THEN NULL ELSE CAST(q.Q4  * ISNULL(q.SlidePriceFactor4,0)  AS DECIMAL(18,2)) END,
        PriceForSlide5  = CASE WHEN q.Q5  > 0 AND q.SlidePriceFactor5  IS NULL THEN NULL ELSE CAST(q.Q5  * ISNULL(q.SlidePriceFactor5,0)  AS DECIMAL(18,2)) END,
        PriceForSlide6  = CASE WHEN q.Q6  > 0 AND q.SlidePriceFactor6  IS NULL THEN NULL ELSE CAST(q.Q6  * ISNULL(q.SlidePriceFactor6,0)  AS DECIMAL(18,2)) END,
        PriceForSlide7  = CASE WHEN q.Q7  > 0 AND q.SlidePriceFactor7  IS NULL THEN NULL ELSE CAST(q.Q7  * ISNULL(q.SlidePriceFactor7,0)  AS DECIMAL(18,2)) END,
        PriceForSlide8  = CASE WHEN q.Q8  > 0 AND q.SlidePriceFactor8  IS NULL THEN NULL ELSE CAST(q.Q8  * ISNULL(q.SlidePriceFactor8,0)  AS DECIMAL(18,2)) END,
        PriceForSlide9  = CASE WHEN q.Q9  > 0 AND q.SlidePriceFactor9  IS NULL THEN NULL ELSE CAST(q.Q9  * ISNULL(q.SlidePriceFactor9,0)  AS DECIMAL(18,2)) END,
        PriceForSlide10 = CASE WHEN q.Q10 > 0 AND q.SlidePriceFactor10 IS NULL THEN NULL ELSE CAST(q.Q10 * ISNULL(q.SlidePriceFactor10,0) AS DECIMAL(18,2)) END,

        MissingFactor =
            CASE WHEN (q.Q1  > 0 AND q.SlidePriceFactor1  IS NULL)
                   OR (q.Q2  > 0 AND q.SlidePriceFactor2  IS NULL)
                   OR (q.Q3  > 0 AND q.SlidePriceFactor3  IS NULL)
                   OR (q.Q4  > 0 AND q.SlidePriceFactor4  IS NULL)
                   OR (q.Q5  > 0 AND q.SlidePriceFactor5  IS NULL)
                   OR (q.Q6  > 0 AND q.SlidePriceFactor6  IS NULL)
                   OR (q.Q7  > 0 AND q.SlidePriceFactor7  IS NULL)
                   OR (q.Q8  > 0 AND q.SlidePriceFactor8  IS NULL)
                   OR (q.Q9  > 0 AND q.SlidePriceFactor9  IS NULL)
                   OR (q.Q10 > 0 AND q.SlidePriceFactor10 IS NULL)
                 THEN 1 ELSE 0 END
    FROM Qty q
),

FinalPrice AS
(
    SELECT
        p.*,
        PRICE =
            CASE
                WHEN p.MissingFactor = 1 THEN NULL
                ELSE CAST(
                      (p.Q1  * ISNULL(p.SlidePriceFactor1,0))
                    + (p.Q2  * ISNULL(p.SlidePriceFactor2,0))
                    + (p.Q3  * ISNULL(p.SlidePriceFactor3,0))
                    + (p.Q4  * ISNULL(p.SlidePriceFactor4,0))
                    + (p.Q5  * ISNULL(p.SlidePriceFactor5,0))
                    + (p.Q6  * ISNULL(p.SlidePriceFactor6,0))
                    + (p.Q7  * ISNULL(p.SlidePriceFactor7,0))
                    + (p.Q8  * ISNULL(p.SlidePriceFactor8,0))
                    + (p.Q9  * ISNULL(p.SlidePriceFactor9,0))
                    + (p.Q10 * ISNULL(p.SlidePriceFactor10,0))
                AS DECIMAL(18,2))
            END
    FROM Price p
)

SELECT
    fp.PerviosPeriodID,
    fp.CurrentPeriodID,
    fp.PeriodMonth,
    fp.PeriodYear,
    fp.CurrentPeriodTax,

    fp.meterNo,
    fp.meterID,
    fp.meterName_A,
    fp.meterName_E,
    fp.meterDescription,

    fp.buildingDetailsNo,
    fp.buildingUtilityTypeID,
    fp.buildingDetailsID,

    fp.meterTypeID,
    fp.meterServiceTypeID,

    BillChargeTypeID_FK = mst.BillChargeTypeID_FK,

    fp.meterReadID,
    fp.generalNo_FK,
    fp.residentInfoID_FK,
    fp.CurrentRead,
    fp.LastRead,

    fp.meterReadTypeIDForCurrentRead,
    fp.meterReadTypeIDForLastRead,

    fp.ReadDiff,

    fp.meterSlideMinValue1,  fp.meterSlideMaxValue1,  fp.SlidePriceFactor1,  fp.PriceForSlide1,
    fp.meterSlideMinValue2,  fp.meterSlideMaxValue2,  fp.SlidePriceFactor2,  fp.PriceForSlide2,
    fp.meterSlideMinValue3,  fp.meterSlideMaxValue3,  fp.SlidePriceFactor3,  fp.PriceForSlide3,
    fp.meterSlideMinValue4,  fp.meterSlideMaxValue4,  fp.SlidePriceFactor4,  fp.PriceForSlide4,
    fp.meterSlideMinValue5,  fp.meterSlideMaxValue5,  fp.SlidePriceFactor5,  fp.PriceForSlide5,
    fp.meterSlideMinValue6,  fp.meterSlideMaxValue6,  fp.SlidePriceFactor6,  fp.PriceForSlide6,
    fp.meterSlideMinValue7,  fp.meterSlideMaxValue7,  fp.SlidePriceFactor7,  fp.PriceForSlide7,
    fp.meterSlideMinValue8,  fp.meterSlideMaxValue8,  fp.SlidePriceFactor8,  fp.PriceForSlide8,
    fp.meterSlideMinValue9,  fp.meterSlideMaxValue9,  fp.SlidePriceFactor9,  fp.PriceForSlide9,
    fp.meterSlideMinValue10, fp.meterSlideMaxValue10, fp.SlidePriceFactor10, fp.PriceForSlide10,

    fp.PRICE,

    PRICETAX =
        CASE WHEN fp.PRICE IS NULL THEN NULL
             ELSE CAST(fp.PRICE * (fp.CurrentPeriodTax/100.0) AS DECIMAL(18,2))
        END,

    fp.meterServicePrice,

    meterServicePriceTAX =
        CASE WHEN fp.meterServicePrice IS NULL THEN NULL
             ELSE CAST(fp.meterServicePrice * (fp.CurrentPeriodTax/100.0) AS DECIMAL(18,2))
        END,

    TotalPrice =
        CASE WHEN fp.PRICE IS NULL THEN NULL
             ELSE CAST(
                    ISNULL(fp.meterServicePrice,0)
                  + (ISNULL(fp.meterServicePrice,0) * (fp.CurrentPeriodTax/100.0))
                  + fp.PRICE
                  + (fp.PRICE * (fp.CurrentPeriodTax/100.0))
             AS DECIMAL(18,2))
        END,

        fp.IdaraId_FK

FROM FinalPrice fp
LEFT JOIN Housing.MeterServiceType mst
    ON mst.meterServiceTypeID = fp.meterServiceTypeID;
