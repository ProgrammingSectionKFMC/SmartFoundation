CREATE PROCEDURE [Housing].[BackfillResidentServiceBills]
(
      @ResidentInfoID   BIGINT
    , @GeneralNo        BIGINT
    , @BuildingDetailsID BIGINT
    , @OccupentDate     DATE
    , @IdaraID          BIGINT
    , @EntryData        NVARCHAR(20)
    , @HostName         NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionCount INT = @@TRANCOUNT;

    BEGIN TRY
        IF @TransactionCount = 0
            BEGIN TRANSACTION;

        /*
           بعض فواتير الخدمات الدورية القديمة لا تحفظ BillsFromDate/BillsToDate.
           في هذه الحالة تكون فترة BillPeriod هي مصدر التاريخ الصحيح، وليس تاريخ
           إنشاء الفاتورة. لذلك نستخدم تاريخي الفاتورة إن وجدا، ثم فترة الفوترة،
           ثم الشهر المخزن كحل أخير.
        */
        /* الفواتير الواقعة بالكامل من تاريخ السكن وما بعده. */
        UPDATE b
           SET b.residentInfoID_FK = @ResidentInfoID,
               b.generalNo_FK = @GeneralNo,
               b.BillsFromDate = COALESCE(b.BillsFromDate, CAST(billDate.BillFromDate AS datetime)),
               b.BillsToDate = COALESCE(b.BillsToDate, CAST(billDate.BillToDate AS datetime)),
               -- حقول التدقيق محدودة الطول (entryData = 20)، فلا تجمع قيماً تاريخية فيها.
               b.entryData = @EntryData,
               b.hostName = @HostName
        FROM Housing.Bills b
        LEFT JOIN Housing.BillPeriod bp
            ON bp.billPeriodID = b.CurrentPeriodID
           AND bp.IdaraId_FK = b.idaraID_FK
        CROSS APPLY
        (
            SELECT
                  COALESCE
                  (
                      CAST(b.BillsFromDate AS date),
                      CAST(bp.billPeriodStartDate AS date),
                      CASE
                          WHEN b.PeriodYear BETWEEN 1753 AND 9999
                           AND b.PeriodMonth BETWEEN 1 AND 12
                          THEN DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1)
                      END
                  ) AS BillFromDate
                , COALESCE
                  (
                      CAST(b.BillsToDate AS date),
                      CAST(bp.billPeriodEndDate AS date),
                      CASE
                          WHEN b.PeriodYear BETWEEN 1753 AND 9999
                           AND b.PeriodMonth BETWEEN 1 AND 12
                          THEN EOMONTH(DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1))
                      END
                  ) AS BillToDate
        ) billDate
        /* Historical imports may retain a legacy IdaraID on Bills.  The house
           is the authoritative scope for assigning its existing service bill. */
        WHERE b.buildingDetailsID = @BuildingDetailsID
          AND b.BillActive = 1
          AND b.BillChargeTypeID_FK IN (2, 3, 4)
          AND b.residentInfoID_FK IS NULL
          AND billDate.BillFromDate >= @OccupentDate
          /* لا تربط نسخة مكررة من فاتورة أقدم لنفس العداد والفترة والقراءات والمبلغ. */
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.Bills previousBill
              WHERE previousBill.BillsID < b.BillsID
                AND previousBill.BillActive = 1
                AND previousBill.buildingDetailsID = b.buildingDetailsID
                AND previousBill.BillChargeTypeID_FK = b.BillChargeTypeID_FK
                AND ISNULL(previousBill.meterServiceTypeID, -1) = ISNULL(b.meterServiceTypeID, -1)
                AND ISNULL(previousBill.meterID, -1) = ISNULL(b.meterID, -1)
                AND previousBill.PeriodMonth = b.PeriodMonth
                AND previousBill.PeriodYear = b.PeriodYear
                AND ISNULL(previousBill.LastRead, -1) = ISNULL(b.LastRead, -1)
                AND ISNULL(previousBill.CurrentRead, -1) = ISNULL(b.CurrentRead, -1)
                AND ISNULL(previousBill.ReadDiff, -1) = ISNULL(b.ReadDiff, -1)
                AND ISNULL(previousBill.TotalPrice, -1) = ISNULL(b.TotalPrice, -1)
                AND COALESCE(CAST(previousBill.BillsFromDate AS date), CASE WHEN previousBill.PeriodYear BETWEEN 1753 AND 9999 AND previousBill.PeriodMonth BETWEEN 1 AND 12 THEN DATEFROMPARTS(previousBill.PeriodYear, previousBill.PeriodMonth, 1) END) = billDate.BillFromDate
                AND COALESCE(CAST(previousBill.BillsToDate AS date), CASE WHEN previousBill.PeriodYear BETWEEN 1753 AND 9999 AND previousBill.PeriodMonth BETWEEN 1 AND 12 THEN EOMONTH(DATEFROMPARTS(previousBill.PeriodYear, previousBill.PeriodMonth, 1)) END) = billDate.BillToDate
          );

        DECLARE @BillsToSplit TABLE
        (
            BillsID BIGINT PRIMARY KEY,
            BillFromDate DATE NOT NULL,
            BillToDate DATE NOT NULL,
            VacantDays INT NOT NULL,
            TotalDays INT NOT NULL
        );

        INSERT INTO @BillsToSplit (BillsID, BillFromDate, BillToDate, VacantDays, TotalDays)
        SELECT b.BillsID,
               billDate.BillFromDate,
               billDate.BillToDate,
               (
                   (YEAR(@OccupentDate) - YEAR(billDate.BillFromDate)) * 360
                 + (MONTH(@OccupentDate) - MONTH(billDate.BillFromDate)) * 30
                 +
                   (CASE
                       WHEN @OccupentDate = EOMONTH(@OccupentDate)
                        AND DAY(@OccupentDate) < 30 THEN 30
                       WHEN DAY(@OccupentDate) > 30 THEN 30
                       ELSE DAY(@OccupentDate)
                    END)
                 - (CASE
                       WHEN billDate.BillFromDate = EOMONTH(billDate.BillFromDate)
                        AND DAY(billDate.BillFromDate) < 30 THEN 30
                       WHEN DAY(billDate.BillFromDate) > 30 THEN 30
                       ELSE DAY(billDate.BillFromDate)
                    END)
               ),
               (
                   (YEAR(billDate.BillToDate) - YEAR(billDate.BillFromDate)) * 360
                 + (MONTH(billDate.BillToDate) - MONTH(billDate.BillFromDate)) * 30
                 +
                   (CASE
                       WHEN billDate.BillToDate = EOMONTH(billDate.BillToDate)
                        AND DAY(billDate.BillToDate) < 30 THEN 30
                       WHEN DAY(billDate.BillToDate) > 30 THEN 30
                       ELSE DAY(billDate.BillToDate)
                    END)
                 - (CASE
                       WHEN billDate.BillFromDate = EOMONTH(billDate.BillFromDate)
                        AND DAY(billDate.BillFromDate) < 30 THEN 30
                       WHEN DAY(billDate.BillFromDate) > 30 THEN 30
                       ELSE DAY(billDate.BillFromDate)
                    END)
               ) + 1
        FROM Housing.Bills b
        LEFT JOIN Housing.BillPeriod bp
            ON bp.billPeriodID = b.CurrentPeriodID
           AND bp.IdaraId_FK = b.idaraID_FK
        CROSS APPLY
        (
            SELECT
                  COALESCE
                  (
                      CAST(b.BillsFromDate AS date),
                      CAST(bp.billPeriodStartDate AS date),
                      CASE
                          WHEN b.PeriodYear BETWEEN 1753 AND 9999
                           AND b.PeriodMonth BETWEEN 1 AND 12
                          THEN DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1)
                      END
                  ) AS BillFromDate
                , COALESCE
                  (
                      CAST(b.BillsToDate AS date),
                      CAST(bp.billPeriodEndDate AS date),
                      CASE
                          WHEN b.PeriodYear BETWEEN 1753 AND 9999
                           AND b.PeriodMonth BETWEEN 1 AND 12
                          THEN EOMONTH(DATEFROMPARTS(b.PeriodYear, b.PeriodMonth, 1))
                      END
                  ) AS BillToDate
        ) billDate
        WHERE b.buildingDetailsID = @BuildingDetailsID
          AND b.BillActive = 1
          AND b.BillChargeTypeID_FK IN (2, 3, 4)
          AND b.residentInfoID_FK IS NULL
          AND billDate.BillFromDate < @OccupentDate
          AND billDate.BillToDate >= @OccupentDate
          AND b.ParentBillsID_FK IS NULL
          /* لا تقسّم نسخة مكررة من فاتورة أقدم لنفس العداد والفترة والقراءات والمبلغ. */
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.Bills previousBill
              WHERE previousBill.BillsID < b.BillsID
                AND previousBill.BillActive = 1
                AND previousBill.buildingDetailsID = b.buildingDetailsID
                AND previousBill.BillChargeTypeID_FK = b.BillChargeTypeID_FK
                AND ISNULL(previousBill.meterServiceTypeID, -1) = ISNULL(b.meterServiceTypeID, -1)
                AND ISNULL(previousBill.meterID, -1) = ISNULL(b.meterID, -1)
                AND previousBill.PeriodMonth = b.PeriodMonth
                AND previousBill.PeriodYear = b.PeriodYear
                AND ISNULL(previousBill.LastRead, -1) = ISNULL(b.LastRead, -1)
                AND ISNULL(previousBill.CurrentRead, -1) = ISNULL(b.CurrentRead, -1)
                AND ISNULL(previousBill.ReadDiff, -1) = ISNULL(b.ReadDiff, -1)
                AND ISNULL(previousBill.TotalPrice, -1) = ISNULL(b.TotalPrice, -1)
                AND COALESCE(CAST(previousBill.BillsFromDate AS date), CASE WHEN previousBill.PeriodYear BETWEEN 1753 AND 9999 AND previousBill.PeriodMonth BETWEEN 1 AND 12 THEN DATEFROMPARTS(previousBill.PeriodYear, previousBill.PeriodMonth, 1) END) = billDate.BillFromDate
                AND COALESCE(CAST(previousBill.BillsToDate AS date), CASE WHEN previousBill.PeriodYear BETWEEN 1753 AND 9999 AND previousBill.PeriodMonth BETWEEN 1 AND 12 THEN EOMONTH(DATEFROMPARTS(previousBill.PeriodYear, previousBill.PeriodMonth, 1)) END) = billDate.BillToDate
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM Housing.Bills child
              WHERE child.ParentBillsID_FK = b.BillsID
                AND child.BillActive = 1
          );

        INSERT INTO Housing.Bills
        (
        [BillsUID],
        [BillChargeTypeID_FK],
        [BillTypeID_FK],
        [PerviosPeriodID],
        [CurrentPeriodID],
        [PeriodMonth],
        [PeriodYear],
        [CurrentPeriodTax],
        [meterNo],
        [meterID],
        [meterName_A],
        [meterName_E],
        [meterDescription],
        [buildingDetailsNo],
        [buildingUtilityTypeID],
        [buildingDetailsID],
        [meterTypeID],
        [meterServiceTypeID],
        [meterReadID],
        [residentInfoID_FK],
        [generalNo_FK],
        [CurrentRead],
        [LastRead],
        [ReadDiff],
        [meterSlideMinValue1],
        [meterSlideMaxValue1],
        [SlidePriceFactor1],
        [PriceForSlide1],
        [meterSlideMinValue2],
        [meterSlideMaxValue2],
        [SlidePriceFactor2],
        [PriceForSlide2],
        [meterSlideMinValue3],
        [meterSlideMaxValue3],
        [SlidePriceFactor3],
        [PriceForSlide3],
        [meterSlideMinValue4],
        [meterSlideMaxValue4],
        [SlidePriceFactor4],
        [PriceForSlide4],
        [meterSlideMinValue5],
        [meterSlideMaxValue5],
        [SlidePriceFactor5],
        [PriceForSlide5],
        [meterSlideMinValue6],
        [meterSlideMaxValue6],
        [SlidePriceFactor6],
        [PriceForSlide6],
        [meterSlideMinValue7],
        [meterSlideMaxValue7],
        [SlidePriceFactor7],
        [PriceForSlide7],
        [meterSlideMinValue8],
        [meterSlideMaxValue8],
        [SlidePriceFactor8],
        [PriceForSlide8],
        [meterSlideMinValue9],
        [meterSlideMaxValue9],
        [SlidePriceFactor9],
        [PriceForSlide9],
        [meterSlideMinValue10],
        [meterSlideMaxValue10],
        [SlidePriceFactor10],
        [PriceForSlide10],
        [PRICE],
        [PRICETAX],
        [meterServicePrice],
        [meterServicePriceTAX],
        [TotalPrice],
        [buildingRentTypeID_FK],
        [BillsFromDate],
        [BillsToDate],
        [PenaltyReason],
        [BillActive],
        [CanceledBy],
        [ParentBillsID_FK],
        [SplitType],
        [SplitDate],
        [SplitBy],
        [idaraID_FK],
        [entryDate],
        [entryData],
        [hostName]
        )
        SELECT
        NEWID(),
        b.[BillChargeTypeID_FK],
        b.[BillTypeID_FK],
        b.[PerviosPeriodID],
        b.[CurrentPeriodID],
        b.[PeriodMonth],
        b.[PeriodYear],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[CurrentPeriodTax] - ROUND(b.[CurrentPeriodTax] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[CurrentPeriodTax] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterNo],
        b.[meterID],
        b.[meterName_A],
        b.[meterName_E],
        b.[meterDescription],
        b.[buildingDetailsNo],
        b.[buildingUtilityTypeID],
        b.[buildingDetailsID],
        b.[meterTypeID],
        b.[meterServiceTypeID],
        b.[meterReadID],
        CASE WHEN p.SplitType = N'RESIDENT' THEN @ResidentInfoID ELSE NULL END,
        CASE WHEN p.SplitType = N'RESIDENT' THEN @GeneralNo ELSE NULL END,
        b.[CurrentRead],
        b.[LastRead],
        b.[ReadDiff],
        b.[meterSlideMinValue1],
        b.[meterSlideMaxValue1],
        b.[SlidePriceFactor1],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide1] - ROUND(b.[PriceForSlide1] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide1] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue2],
        b.[meterSlideMaxValue2],
        b.[SlidePriceFactor2],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide2] - ROUND(b.[PriceForSlide2] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide2] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue3],
        b.[meterSlideMaxValue3],
        b.[SlidePriceFactor3],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide3] - ROUND(b.[PriceForSlide3] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide3] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue4],
        b.[meterSlideMaxValue4],
        b.[SlidePriceFactor4],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide4] - ROUND(b.[PriceForSlide4] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide4] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue5],
        b.[meterSlideMaxValue5],
        b.[SlidePriceFactor5],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide5] - ROUND(b.[PriceForSlide5] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide5] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue6],
        b.[meterSlideMaxValue6],
        b.[SlidePriceFactor6],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide6] - ROUND(b.[PriceForSlide6] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide6] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue7],
        b.[meterSlideMaxValue7],
        b.[SlidePriceFactor7],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide7] - ROUND(b.[PriceForSlide7] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide7] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue8],
        b.[meterSlideMaxValue8],
        b.[SlidePriceFactor8],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide8] - ROUND(b.[PriceForSlide8] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide8] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue9],
        b.[meterSlideMaxValue9],
        b.[SlidePriceFactor9],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide9] - ROUND(b.[PriceForSlide9] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide9] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[meterSlideMinValue10],
        b.[meterSlideMaxValue10],
        b.[SlidePriceFactor10],
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PriceForSlide10] - ROUND(b.[PriceForSlide10] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PriceForSlide10] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PRICE] - ROUND(b.[PRICE] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PRICE] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[PRICETAX] - ROUND(b.[PRICETAX] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[PRICETAX] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[meterServicePrice] - ROUND(b.[meterServicePrice] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[meterServicePrice] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[meterServicePriceTAX] - ROUND(b.[meterServicePriceTAX] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[meterServicePriceTAX] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        CASE WHEN p.SplitType = N'RESIDENT'
                       THEN b.[TotalPrice] - ROUND(b.[TotalPrice] * c.VacantDays / NULLIF(c.TotalDays, 0), 2)
                       ELSE ROUND(b.[TotalPrice] * c.VacantDays / NULLIF(c.TotalDays, 0), 2) END,
        b.[buildingRentTypeID_FK],
        CASE WHEN p.SplitType = N'RESIDENT' THEN CAST(@OccupentDate AS datetime) ELSE CAST(c.BillFromDate AS datetime) END,
        CASE WHEN p.SplitType = N'RESIDENT' THEN CAST(c.BillToDate AS datetime) ELSE DATEADD(DAY, -1, CAST(@OccupentDate AS datetime)) END,
        b.[PenaltyReason],
        CAST(1 AS bit),
        NULL,
        b.BillsID,
        p.SplitType,
        GETDATE(),
        @EntryData,
        b.[idaraID_FK],
        GETDATE(),
        @EntryData,
        @HostName
        FROM Housing.Bills b
        INNER JOIN @BillsToSplit c ON c.BillsID = b.BillsID
        CROSS JOIN (VALUES (N'VACANT'), (N'RESIDENT')) p(SplitType);

        UPDATE b
           SET b.BillActive = 0,
               b.CanceledBy = CONCAT(N'SPLIT_FOR_RESIDENT:', @ResidentInfoID),
               -- حقول التدقيق محدودة الطول (entryData = 20)، فلا تجمع قيماً تاريخية فيها.
               b.entryData = @EntryData,
               b.hostName = @HostName
        FROM Housing.Bills b
        INNER JOIN @BillsToSplit s ON s.BillsID = b.BillsID;

        IF @TransactionCount = 0
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @TransactionCount = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

GO

