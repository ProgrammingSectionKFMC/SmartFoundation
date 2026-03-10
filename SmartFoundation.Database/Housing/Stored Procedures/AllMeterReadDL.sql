
CREATE PROCEDURE [Housing].[AllMeterReadDL]
      @pageName_              NVARCHAR(400)
    , @idaraID                INT
    , @entrydata              INT
    , @hostname               NVARCHAR(400)
    , @meterServiceTypeID_FK  INT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- 0) Vars + Dates
    ----------------------------------------------------------------
    DECLARE
        @AllmeterReaded   INT = 0,
        @AllMetersCount   INT = 0,
        @CurrentPeriodID  INT = NULL;

    DECLARE
        @MonthStart DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1),
        @MonthEnd   DATE = EOMONTH(GETDATE());

    ----------------------------------------------------------------
    -- 1) Current Period (آخر فترة فعّالة لنوع الخدمة والإدارة)
    ----------------------------------------------------------------
    SELECT @CurrentPeriodID = COALESCE(MAX(bp.billPeriodID), -1)
        FROM  Housing.BillPeriod bp
        JOIN  Housing.BillPeriodType bpt
          ON bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
        WHERE bpt.meterServiceTypeID_FK = @meterServiceTypeID_FK
          AND bp.IdaraId_FK = @idaraID
          AND bpt.billPeriodTypeActive = 1
          AND bp.billPeriodActive = 1;

    ----------------------------------------------------------------
    -- 2) Eligible Meters (Cache once)
    --    Best practice: TVF as source + #temp as cache for reuse
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#EligibleMeters') IS NOT NULL
        DROP TABLE #EligibleMeters;

    SELECT
        em.meterID,
        em.meterNo,
        em.meterServiceTypeID_FK
    INTO #EligibleMeters
    FROM Housing.FN_EligibleMeters(@idaraID, @MonthStart, @MonthEnd) em
    WHERE em.meterServiceTypeID_FK = @meterServiceTypeID_FK; -- مهم لتخفيف النتائج

    -- فهرس: نحتاج meterID للـ joins/exists + meterNo للـ order + meterServiceTypeID_FK للفلترة
    CREATE UNIQUE CLUSTERED INDEX IX_EligibleMeters ON #EligibleMeters(meterID);
    CREATE NONCLUSTERED INDEX IX_EligibleMeters_No ON #EligibleMeters(meterNo) INCLUDE (meterServiceTypeID_FK);

    ----------------------------------------------------------------
    -- 3) Counts
    ----------------------------------------------------------------
    SELECT @AllMetersCount = COUNT(*) FROM #EligibleMeters;

   SELECT @AllmeterReaded = COUNT(*)
    FROM #EligibleMeters em
    WHERE EXISTS
    (
        SELECT 1
        FROM  Housing.Bills b
        WHERE b.meterID = em.meterID
          AND b.meterServiceTypeID = @meterServiceTypeID_FK
          AND b.idaraID_FK = @idaraID
          AND b.BillActive = 1
          AND b.BillTypeID_FK = 2
          AND b.CurrentPeriodID = @CurrentPeriodID
    );

    ----------------------------------------------------------------
    -- RESULTSET (1) Periods + Counts
    ----------------------------------------------------------------
    SELECT
          bp.[billPeriodID]
        , bp.[billPeriodTypeID_FK]
        , bpt.billPeriodTypeName_A
        , bp.[billPeriodName_A]
        , bp.[billPeriodName_E]
        , DATEPART(YEAR, bp.[billPeriodStartDate]) AS billPeriodYear
        , CONVERT(NVARCHAR(10), bp.[billPeriodStartDate], 23) AS billPeriodStartDate
        , CONVERT(NVARCHAR(10), bp.[billPeriodEndDate], 23)   AS billPeriodEndDate
        , bp.[billPeriodActive]
        , bp.[ClosedBy]
        , bp.[IdaraId_FK]
        , @AllMetersCount AS AllMetersCount
        , @AllmeterReaded AS AllmeterReaded
        , (@AllMetersCount - @AllmeterReaded) AS AllMeterNotReaded
    FROM  Housing.BillPeriod bp
    INNER JOIN  Housing.BillPeriodType bpt
        ON bp.billPeriodTypeID_FK = bpt.billPeriodTypeID
    WHERE bpt.meterServiceTypeID_FK = @meterServiceTypeID_FK
      AND bp.IdaraId_FK = @idaraID
      AND bpt.billPeriodTypeActive = 1
      AND bp.billPeriodActive = 1;

    ----------------------------------------------------------------
    -- RESULTSET (2) Bills for Current Period
    ----------------------------------------------------------------
    IF @CurrentPeriodID IS NULL
    BEGIN
        SELECT TOP (0)
              b.[BillsID], b.[BillNumber], b.[PeriodMonth], b.[PeriodYear]
            , b.[meterNo], b.[meterID], b.[meterName_A]
            , b.[buildingDetailsNo], b.[buildingDetailsID]
            , b.[meterReadID], b.[CurrentRead], b.[LastRead], b.[ReadDiff]
            , b.[PriceForSlide1], b.[PriceForSlide2], b.[PriceForSlide3], b.[PriceForSlide4], b.[PriceForSlide5]
            , b.[PriceForSlide6], b.[PriceForSlide7], b.[PriceForSlide8], b.[PriceForSlide9], b.[PriceForSlide10]
            , b.[PRICE], b.[PRICETAX], b.[meterServicePrice], b.[meterServicePriceTAX]
            , (b.[meterServicePrice] + b.[meterServicePriceTAX]) AS meterServicePriceWithTAX
            , b.[TotalPrice]
            , CAST(0 AS DECIMAL(18,2)) AS previosBillTotalPrice
            , CAST(N'' AS NVARCHAR(200)) AS avrageMsg
            , CAST(N'' AS NVARCHAR(10))  AS avrageNo
            , b.[idaraID_FK]
            , CAST(N'' AS NVARCHAR(30)) AS entryDate
            , b.[entryData]
        FROM  Housing.Bills b
        WHERE 1 = 0;
    END
    ELSE
    BEGIN
        SELECT
              b.[BillsID]
            , b.[BillNumber]
            , b.[PeriodMonth]
            , b.[PeriodYear]
            , b.[meterNo]
            , b.[meterID]
            , b.[meterName_A]
            , b.[buildingDetailsNo]
            , b.[buildingDetailsID]
            , b.[meterReadID]
            , b.[CurrentRead]
            , b.[LastRead]
            , b.[ReadDiff]
            , b.[PriceForSlide1]
            , b.[PriceForSlide2]
            , b.[PriceForSlide3]
            , b.[PriceForSlide4]
            , b.[PriceForSlide5]
            , b.[PriceForSlide6]
            , b.[PriceForSlide7]
            , b.[PriceForSlide8]
            , b.[PriceForSlide9]
            , b.[PriceForSlide10]
            , b.[PRICE]
            , b.[PRICETAX]
            , b.[meterServicePrice]
            , b.[meterServicePriceTAX]
            , (b.[meterServicePrice] + b.[meterServicePriceTAX]) AS meterServicePriceWithTAX
            , b.[TotalPrice]
            , ISNULL(rp.TotalPrice, 0) AS previosBillTotalPrice

            , CASE
                WHEN ISNULL(rp.TotalPrice,0) = 0 THEN N'لا يوجد متوسط للساكن'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 2.00 THEN N'ارتفاع عالي جداً 🔺🔺'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.75 THEN N'ارتفاع عالي 🔺'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.50 THEN N'ارتفاع متوسط 📈'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.25 THEN N'ارتفاع خفيف 📈'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.00 THEN N'انخفاض عالي 🔻🔻'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.25 THEN N'انخفاض عالي 🔻'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.50 THEN N'انخفاض متوسط 📉'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.75 THEN N'انخفاض خفيف 📉'
                ELSE N'في الوضع الطبيعي'
              END AS avrageMsg

            , CASE
                WHEN ISNULL(rp.TotalPrice,0) = 0 THEN N'0'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 2.00 THEN N'5'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.75 THEN N'1'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.50 THEN N'2'
                WHEN b.TotalPrice >= ISNULL(rp.TotalPrice,0) * 1.25 THEN N'2'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.00 THEN N'6'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.25 THEN N'1'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.50 THEN N'2'
                WHEN b.TotalPrice <= ISNULL(rp.TotalPrice,0) * 0.75 THEN N'2'
                ELSE N'3'
              END AS avrageNo

            , b.[idaraID_FK]
            , CONVERT(NVARCHAR(10), b.[entryDate], 23) + N' ' + CONVERT(NVARCHAR(8), b.[entryDate], 108) AS entryDate
            , b.[entryData]
        FROM #EligibleMeters em
        INNER JOIN  Housing.Bills b
            ON b.meterID = em.meterID
           AND b.meterServiceTypeID = @meterServiceTypeID_FK
           AND b.idaraID_FK = @idaraID
           AND b.BillActive = 1
           AND b.BillTypeID_FK = 2
           AND b.CurrentPeriodID = @CurrentPeriodID
        OUTER APPLY (
            SELECT TOP (1) p.TotalPrice
            FROM  Housing.Bills p
            WHERE p.BillActive = 1
              AND p.BillTypeID_FK = 2
              AND p.residentInfoID_FK = b.residentInfoID_FK
              AND p.meterServiceTypeID = b.meterServiceTypeID
              AND p.BillsID <> b.BillsID
            ORDER BY
                ISNULL(p.PeriodYear, 0) DESC,
                ISNULL(p.PeriodMonth, 0) DESC,
                ISNULL(p.CurrentPeriodID, 0) DESC,
                p.BillsID DESC
        ) rp
        ORDER BY b.BillsID DESC;
    END

    ----------------------------------------------------------------
    -- RESULTSET (3) MeterServiceType Options (SARGable + idara)
    ----------------------------------------------------------------
    SELECT
          mst.meterServiceTypeID
        , mst.meterServiceTypeName_A
        , mst.BillChargeTypeID_FK
    FROM Housing.MeterServiceType mst
    INNER JOIN Housing.MeterServiceTypeLinkedWithIdara mi
        ON mst.meterServiceTypeID = mi.MeterServiceTypeID_FK
    WHERE mst.meterServiceTypeActive = 1
      AND mi.MeterServiceTypeLinkedWithIdaraActive = 1
      AND mi.Idara_FK = @idaraID
      AND mst.meterServiceTypeStartDate <= @MonthEnd
      AND (mst.meterServiceTypeEndDate IS NULL OR mst.meterServiceTypeEndDate >= @MonthStart)
      AND mi.MeterServiceTypeLinkedWithIdaraStartDate <= @MonthEnd
      AND (mi.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR mi.MeterServiceTypeLinkedWithIdaraEndDate >= @MonthStart)
    ORDER BY mst.meterServiceTypeName_A;

    ----------------------------------------------------------------
    -- RESULTSET (4) Meters WITHOUT bills in current period (DDL)
    ----------------------------------------------------------------
    if(@CurrentPeriodID = -1)
    BEGIN

    SELECT em.meterID, em.meterNo
            FROM #EligibleMeters em
            LEFT JOIN  Housing.Bills b
              ON  b.meterID = em.meterID
              AND b.meterServiceTypeID = @meterServiceTypeID_FK
              AND b.idaraID_FK = @idaraID
              AND b.BillActive = 1
              AND b.BillTypeID_FK = 2
              AND b.CurrentPeriodID = @CurrentPeriodID
            WHERE b.meterID IS not NULL
            ORDER BY em.meterNo;

    END
    ELSE
    BEGIN
    SELECT em.meterID, em.meterNo,em.meterServiceTypeID_FK
            FROM #EligibleMeters em
            LEFT JOIN  Housing.Bills b
              ON  b.meterID = em.meterID
              AND b.meterServiceTypeID = @meterServiceTypeID_FK
              AND b.idaraID_FK = @idaraID
              AND b.BillActive = 1
              AND b.BillTypeID_FK = 2
              AND b.CurrentPeriodID = @CurrentPeriodID
            WHERE b.meterID IS NULL
            ORDER BY em.meterNo;

    END
        
    
END
