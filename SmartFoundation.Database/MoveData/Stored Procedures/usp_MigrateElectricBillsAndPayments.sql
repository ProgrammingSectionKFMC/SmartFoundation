CREATE PROCEDURE [MoveData].[usp_MigrateElectricBillsAndPayments]
    @IdaraId bigint,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=@IdaraId)
        THROW 56000, N'The supplied IdaraId does not exist.', 1;
    IF @IdaraId NOT BETWEEN 0 AND 2147483647
        THROW 56001, N'IdaraId cannot fit in int payment columns.', 1;
    IF NOT EXISTS (SELECT 1 FROM Housing.ResidentInfo)
        THROW 56002, N'Run MoveData.usp_MigrateResidents first.', 1;

    DECLARE @Bills bigint=0,@RentLists bigint=0,@RentPayments bigint=0,@LegacyExcelLogs bigint=0,
            @ElectricSettlementLists bigint=0,@ElectricPayments bigint=0,
            @BillLists bigint=0,@BillActions bigint=0,@BillDetails bigint=0;
    DECLARE @BillsIdentity bit=0,@DeductIdentity bit=0,@PaymentIdentity bit=0,
            @BillListIdentity bit=0,@BillActionIdentity bit=0,@BillDetailIdentity bit=0;

    /* Resolve each legacy entryData once. The original scalar functions are
       retained as the source of truth, but no longer execute once per row. */
    CREATE TABLE #EntryDataMap
    (
      EntryDataKey nvarchar(40) NOT NULL PRIMARY KEY,
      MappedEntryData nvarchar(40) NULL
    );

    INSERT INTO #EntryDataMap (EntryDataKey, MappedEntryData)
    SELECT sourceData.EntryDataKey,
           [MoveData].[fn_MapEntryData](NULLIF(sourceData.EntryDataKey,N''))
    FROM
    (
      SELECT DISTINCT ISNULL(CONVERT(nvarchar(40),entryData),N'') EntryDataKey FROM KFMC.Housing.Bills
      UNION
      SELECT DISTINCT ISNULL(CONVERT(nvarchar(40),entryData),N'') FROM KFMC.Housing.DeductList
      UNION
      SELECT DISTINCT ISNULL(CONVERT(nvarchar(40),entryData),N'') FROM KFMC.Housing.BillDeductList
      UNION
      SELECT DISTINCT ISNULL(CONVERT(nvarchar(40),entryData),N'') FROM KFMC.Housing.BillDeductAction
      UNION
      SELECT DISTINCT ISNULL(CONVERT(nvarchar(40),entryData),N'') FROM KFMC.Housing.BillsDeductListDetails
    ) sourceData;

    BEGIN TRY
      BEGIN TRANSACTION;

      /* Electricity bills: every historical KFMC bill is electricity.
         For 2024/10, KFMC contains duplicate active bills for the same resident,
         building, month, year, and amount. This also applies when generalNo_FK is
         NULL. Keep one bill only, preferring the one that has paid details, then
         the lowest BillsID. */
      SET IDENTITY_INSERT Housing.Bills ON; SET @BillsIdentity=1;
      ;WITH SourceBills AS
      (
        SELECT
          s.*,
          CASE
            WHEN ISNULL(s.BillActive,1)=1
             AND s.PeriodYear=2024
             AND s.PeriodMonth=10
            THEN ROW_NUMBER() OVER
            (
              
PARTITION BY
    s.generalNo_FK,
    s.buildingDetailsNo,
    s.PeriodYear,
    s.PeriodMonth,
    CAST(ISNULL(s.TotalPrice,0) AS decimal(18,2)),
    s.meterID,
    s.meterNo,
    s.meterReadID

              ORDER BY
                CASE WHEN EXISTS
                (
                  SELECT 1
                  FROM KFMC.Housing.BillsDeductListDetails d
                  WHERE d.billsID_FK=s.BillsID
                    AND d.billPaid=1
                    AND d.paidAmount IS NOT NULL
                ) THEN 1 ELSE 0 END DESC,
                s.BillsID
            )
            ELSE 1
          END AS migrationRowNo
        FROM KFMC.Housing.Bills s
      )
      INSERT INTO Housing.Bills
      (
        BillsID,BillsUID,BillChargeTypeID_FK,BillTypeID_FK,PerviosPeriodID,CurrentPeriodID,
        PeriodMonth,PeriodYear,CurrentPeriodTax,meterNo,meterID,meterName_A,meterName_E,
        meterDescription,buildingDetailsNo,buildingUtilityTypeID,buildingDetailsID,meterTypeID,
        meterServiceTypeID,meterReadID,residentInfoID_FK,generalNo_FK,CurrentRead,LastRead,ReadDiff,
        meterSlideMinValue1,meterSlideMaxValue1,SlidePriceFactor1,PriceForSlide1,
        meterSlideMinValue2,meterSlideMaxValue2,SlidePriceFactor2,PriceForSlide2,
        meterSlideMinValue3,meterSlideMaxValue3,SlidePriceFactor3,PriceForSlide3,
        PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,TotalPrice,BillsFromDate,BillsToDate,
        BillActive,idaraID_FK,entryDate,entryData,hostName
      )
      SELECT
        CONVERT(bigint,s.BillsID),s.BillsUID,2,s.BillTypeID_FK,COALESCE(CASE WHEN validPreviousType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK AND validPrevious.billPeriodStartDate<billDate.CurrentPeriodStart THEN validPrevious.billPeriodID END,derivedPrevious.billPeriodID),COALESCE(CASE WHEN validPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN validPeriod.billPeriodID END,CASE WHEN readPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN readPeriod.billPeriodID END),
        s.PeriodMonth,s.PeriodYear,s.CurrentPeriodTax,s.meterNo,s.meterID,s.meterName_A,s.meterName_E,
        s.meterDescription,s.buildingDetailsNo,s.buildingUtilityTypeID,s.buildingDetailsID,s.meterTypeID,
        
COALESCE(s.meterServiceTypeID,charge.MeterServiceTypeID_FK),

CASE
    WHEN s.meterReadID IS NOT NULL
     AND EXISTS
     (
         SELECT 1
         FROM [KFMC].[Housing].[MeterRead] originalRead

         INNER JOIN [KFMC].[Housing].[ResidentInfo] originalResident
             ON originalResident.[generalNo] =
                originalRead.[generalNo_FK]

         WHERE originalRead.[meterReadID] =
               s.[meterReadID]

           AND NOT EXISTS
           (
               SELECT 1
               FROM [KFMC].[Housing].[ResidentDetails] details
               WHERE details.[generalNo_FK] =
                     originalResident.[generalNo]
           )
     )
    THEN CAST(NULL AS int)
    ELSE s.meterReadID
END,

migratedResident.residentInfoID,
s.generalNo_FK,

        
        s.CurrentRead,s.LastRead,s.ReadDiff,
        s.meterSlideMinValue1,s.meterSlideMaxValue1,s.SlidePriceFactor1,s.PriceForSlide1,
        s.meterSlideMinValue2,s.meterSlideMaxValue2,s.SlidePriceFactor2,s.PriceForSlide2,
        s.meterSlideMinValue3,s.meterSlideMaxValue3,s.SlidePriceFactor3,s.PriceForSlide3,
        s.PRICE,s.PRICETAX,s.meterServicePrice,s.meterServicePriceTAX,s.TotalPrice,
        billDate.BillFromDate,billDate.BillToDate,
        s.BillActive,@IdaraId,s.entryDate,entryMap.MappedEntryData,
        CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
             ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      FROM SourceBills s
      JOIN Housing.BillChargeType charge ON charge.BillChargeTypeID=2
      LEFT JOIN Housing.BillPeriod validPeriod ON validPeriod.billPeriodID=s.CurrentPeriodID AND validPeriod.IdaraId_FK=@IdaraId
      LEFT JOIN Housing.BillPeriodType validPeriodType ON validPeriodType.billPeriodTypeID=validPeriod.billPeriodTypeID_FK
      LEFT JOIN Housing.BillPeriod validPrevious ON validPrevious.billPeriodID=s.PerviosPeriodID AND validPrevious.IdaraId_FK=@IdaraId
      LEFT JOIN Housing.BillPeriodType validPreviousType ON validPreviousType.billPeriodTypeID=validPrevious.billPeriodTypeID_FK
      LEFT JOIN Housing.MeterRead targetRead ON targetRead.meterReadID=CONVERT(bigint,s.meterReadID)
      LEFT JOIN Housing.BillPeriod readPeriod ON readPeriod.billPeriodID=targetRead.billPeriodID_FK AND readPeriod.IdaraId_FK=@IdaraId
      LEFT JOIN Housing.BillPeriodType readPeriodType ON readPeriodType.billPeriodTypeID=readPeriod.billPeriodTypeID_FK
      OUTER APPLY (SELECT COALESCE(CASE WHEN validPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN CAST(validPeriod.billPeriodStartDate AS date) END,CASE WHEN readPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN CAST(readPeriod.billPeriodStartDate AS date) END,CASE WHEN s.PeriodYear BETWEEN 1753 AND 9999 AND s.PeriodMonth BETWEEN 1 AND 12 THEN DATEFROMPARTS(s.PeriodYear,s.PeriodMonth,1) END) BillFromDate,COALESCE(CASE WHEN validPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN CAST(validPeriod.billPeriodEndDate AS date) END,CASE WHEN readPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN CAST(readPeriod.billPeriodEndDate AS date) END,CASE WHEN s.PeriodYear BETWEEN 1753 AND 9999 AND s.PeriodMonth BETWEEN 1 AND 12 THEN EOMONTH(DATEFROMPARTS(s.PeriodYear,s.PeriodMonth,1)) END) BillToDate,COALESCE(CASE WHEN validPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN validPeriod.billPeriodStartDate END,CASE WHEN readPeriodType.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK THEN readPeriod.billPeriodStartDate END) CurrentPeriodStart) billDate
      OUTER APPLY (SELECT TOP (1) bp.billPeriodID FROM Housing.BillPeriod bp JOIN Housing.BillPeriodType bpt ON bpt.billPeriodTypeID=bp.billPeriodTypeID_FK WHERE bp.IdaraId_FK=@IdaraId AND bpt.meterServiceTypeID_FK=charge.MeterServiceTypeID_FK AND bp.billPeriodStartDate<billDate.CurrentPeriodStart ORDER BY bp.billPeriodStartDate DESC,bp.billPeriodID DESC) derivedPrevious
      
LEFT JOIN [KFMC].[Housing].[ResidentInfo] sourceResident
    ON sourceResident.[generalNo] = s.[generalNo_FK]

LEFT JOIN [Housing].[ResidentInfo] migratedResident
    ON migratedResident.[residentInfoID] =
       TRY_CONVERT(bigint, sourceResident.[residentInfoID])

   AND EXISTS
   (
       SELECT 1
       FROM [KFMC].[Housing].[ResidentDetails] eligibleDetails
       WHERE eligibleDetails.[generalNo_FK] =
             sourceResident.[generalNo]
   )

      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      WHERE s.migrationRowNo=1
        AND NOT EXISTS(SELECT 1 FROM Housing.Bills t WHERE t.BillsID=CONVERT(bigint,s.BillsID));
      SET @Bills=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.Bills OFF; SET @BillsIdentity=0;


      
/*
    Validate migrated electricity bills.

    A selected source bill must exist in DATACORE
    with the same BillsID, BillsUID, original generalNo
    and TotalPrice, and must be an electricity bill.

    October 2024 duplicates intentionally excluded by
    the migration rule are not required here.
*/

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            s.BillsID,
            s.BillsUID,
            s.generalNo_FK,
            s.TotalPrice,

            CASE
                WHEN ISNULL(s.BillActive, 1) = 1
                 AND s.PeriodYear = 2024
                 AND s.PeriodMonth = 10
                THEN ROW_NUMBER() OVER
                (
                    PARTITION BY
                        s.generalNo_FK,
                        s.buildingDetailsNo,
                        s.PeriodYear,
                        s.PeriodMonth,
                        CAST(
                            ISNULL(s.TotalPrice, 0)
                            AS decimal(18,2)
                        ),
                        s.meterID,
                        s.meterNo,
                        s.meterReadID

                    ORDER BY
                        CASE
                            WHEN EXISTS
                            (
                                SELECT 1
                                FROM KFMC.Housing.BillsDeductListDetails d
                                WHERE d.billsID_FK = s.BillsID
                                  AND d.billPaid = 1
                                  AND d.paidAmount IS NOT NULL
                            )
                            THEN 1
                            ELSE 0
                        END DESC,
                        s.BillsID
                )
                ELSE 1
            END AS migrationRowNo

        FROM KFMC.Housing.Bills s
    ) expected

    LEFT JOIN Housing.Bills targetBill
        ON targetBill.BillsID =
           CONVERT(bigint, expected.BillsID)

    WHERE expected.migrationRowNo = 1

      AND
      (
          targetBill.BillsID IS NULL

          OR targetBill.BillsUID IS NULL

          OR targetBill.BillsUID <> expected.BillsUID

          OR targetBill.BillChargeTypeID_FK IS NULL

          OR targetBill.BillChargeTypeID_FK <> 2

          OR EXISTS
          (
              SELECT
                  targetBill.generalNo_FK,
                  targetBill.TotalPrice

              EXCEPT

              SELECT
                  expected.generalNo_FK,
                  expected.TotalPrice
          )
      )
)
BEGIN
    THROW 56020,
        N'فشل التحقق من فواتير الكهرباء: توجد فاتورة مفقودة أو اختلاف في هويتها أو رقم المستفيد الأصلي أو مبلغها.',
        1;
END;



      /* Historical rent deduction lists. */
      SET IDENTITY_INSERT Housing.DeductList ON; SET @DeductIdentity=1;
      INSERT INTO Housing.DeductList
      (deductListID,deductTypeID_FK,DeductListStatusID_FK,deductUID,deductName,amountTypeID_FK,
       paymentTypeID_FK,issueMonth,issueYear,paymentNo,paymentDate,description,deductActive,
       BillChargeTypeID_FK,ToBillChargeTypeID_FK,ExtendInsuranceID_FK,IdaraId_FK,entryDate,entryData,hostName)
      SELECT s.deductListID,s.deductTypeID_FK,s.DeductListStatusID_FK,s.deductUID,s.deductName,
       s.amountTypeID_FK,s.paymentTypeID_FK,s.issueMonth,s.issueYear,s.paymentNo,s.paymentDate,
       s.description,s.deductActive,1,NULL,NULL,@IdaraId,s.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
            ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      FROM KFMC.Housing.DeductList s
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      
WHERE
(
    -- المسيرات النشطة
    s.deductActive = 1

    OR

    -- المسيرات الملغاة التي تحتوي على سدادات تاريخية
    (
        s.deductActive = 0

        AND EXISTS
        (
            SELECT 1
            FROM KFMC.Housing.BuildingPayment historicPay

            WHERE historicPay.deductListID_FK =
                  s.deductListID

              AND historicPay.buildingPayementActive = 1
        )
    )
)

AND NOT EXISTS
(
    SELECT 1
    FROM Housing.DeductList t
    WHERE t.deductListID = s.deductListID
);

      SET @RentLists=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.DeductList OFF; SET @DeductIdentity=0;

      /* Keep original electricity deduction lists for audit. */
      SET IDENTITY_INSERT Housing.BillDeductList ON; SET @BillListIdentity=1;
      INSERT INTO Housing.BillDeductList
      (billDeductListID,billDeductTypeID_FK,billDeductUID,billDeductName,amountTypeID_FK,
       issueMonth,issueYear,paymentNo,paymentDate,description,deductActive,PeriodID_FK,
       ParentDeductListID_FK,paymentTypeID_FK,superVisorSignture,superVisorGeneralNo,
       managerSignture,managerGeneralNo,entryDate,entryData,hostName)
      SELECT s.billDeductListID,s.billDeductTypeID_FK,s.billDeductUID,s.billDeductName,
       s.amountTypeID_FK,s.issueMonth,s.issueYear,s.paymentNo,s.paymentDate,s.description,
       s.deductActive,s.PeriodID_FK,s.ParentDeductListID_FK,s.paymentTypeID_FK,
       s.superVisorSignture,s.superVisorGeneralNo,s.managerSignture,s.managerGeneralNo,
       s.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
            ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      FROM KFMC.Housing.BillDeductList s
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      WHERE NOT EXISTS(SELECT 1 FROM Housing.BillDeductList t WHERE t.billDeductListID=s.billDeductListID);
      SET @BillLists=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.BillDeductList OFF; SET @BillListIdentity=0;

      /*
         BillDeductList is an electricity invoice-posting batch, not a payment batch.
         Create migration-only settlement lists so paid historical details can participate
         in DATACORE's aggregate Bills - BuildingPayment calculation.
      */
      INSERT INTO Housing.DeductList
      (deductTypeID_FK,DeductListStatusID_FK,deductUID,deductName,amountTypeID_FK,paymentTypeID_FK,
       issueMonth,issueYear,paymentNo,paymentDate,description,deductActive,BillChargeTypeID_FK,
       IdaraId_FK,entryDate,entryData,hostName)
      SELECT DISTINCT 6,NULL,
       CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'E|',s.billDeductListID,N'|',
              COALESCE(s.issueYear,YEAR(d.paidDate)),N'|',COALESCE(s.issueMonth,MONTH(d.paidDate))))),
       CONCAT(N'تسوية افتتاحية لحالة السداد - ',s.billDeductName,N' - ',
              COALESCE(s.issueYear,YEAR(d.paidDate)),N'/',COALESCE(s.issueMonth,MONTH(d.paidDate))),
       s.amountTypeID_FK,s.paymentTypeID_FK,
       COALESCE(s.issueMonth,MONTH(d.paidDate)),COALESCE(s.issueYear,YEAR(d.paidDate)),
       s.paymentNo,COALESCE(s.paymentDate,DATEFROMPARTS(COALESCE(s.issueYear,YEAR(d.paidDate)),COALESCE(s.issueMonth,MONTH(d.paidDate)),1)),s.description,
       s.deductActive,2,@IdaraId,s.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
            ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      FROM KFMC.Housing.BillDeductList s
      JOIN KFMC.Housing.BillsDeductListDetails d ON d.billDeductListID_FK=s.billDeductListID
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      WHERE d.billPaid=1 AND d.paidAmount IS NOT NULL AND d.paidDate IS NOT NULL
        AND NOT EXISTS
        (
          SELECT 1 FROM Housing.DeductList t
          WHERE t.deductUID=CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'E|',s.billDeductListID,N'|',
                COALESCE(s.issueYear,YEAR(d.paidDate)),N'|',COALESCE(s.issueMonth,MONTH(d.paidDate)))))
        );
      SET @ElectricSettlementLists=@@ROWCOUNT;

      /* Historical rent payments. */
      
/* Historical rent payments. */

SET IDENTITY_INSERT Housing.BuildingPayment ON;
SET @PaymentIdentity = 1;

INSERT INTO Housing.BuildingPayment
(
    paymentID,
    PaymentUID,
    buildingPaymentTypeID_FK,
    generalNo_FK,
    IDNumber,
    residentInfoID_FK,
    rankNameA,
    unitID,
    userName,
    buildingDetailsID_FK,
    amount,
    deductListID_FK,
    buildingPayementActive,
    BillChargeTypeID_FK,
    ExtendInsuranceID_FK,
    IdaraId_FK,
    entryDate,
    entryData,
    hostName,
    buildingPaymentLinkStatusID_FK,
    paymentLinkNote
)
SELECT
    CONVERT(bigint, p.paymentID),
    p.PaymentUID,
    p.buildingPaymentTypeID_FK,
    CONVERT(bigint, p.userID_FK),
    p.IDNumber,
    migratedResident.residentInfoID,
    p.rankNameA,
    CONVERT(nvarchar(100), p.unitID),
    p.userName,
    NULL,
    
p.amount,
p.deductListID_FK,

CASE
    WHEN d.deductActive = 0 THEN CONVERT(bit, 0)
    ELSE p.buildingPayementActive
END,

1,

    NULL,
    CONVERT(int, @IdaraId),
    d.entryDate,
    entryMap.MappedEntryData,

    CASE
        WHEN entryMap.MappedEntryData IS NULL
            THEN d.hostName
        ELSE CONCAT(
            ISNULL(d.hostName, N''),
            N'-',
            NULLIF(
                LTRIM(RTRIM(CONVERT(nvarchar(40), d.entryData))),
                N''
            )
        )
    END,

    CASE
        WHEN migratedResident.residentInfoID IS NULL THEN 3
        ELSE 2
    END,

    CASE
    WHEN d.deductActive = 0
        THEN N'سداد تاريخي غير نشط: المسير الأصلي ملغى في KFMC.'

    WHEN r.residentInfoID IS NULL
        THEN N'مستفيد غير معروف وقت الترحيل.'

    WHEN migratedResident.residentInfoID IS NULL
        THEN N'المستفيد غير مرتبط بسجل مؤهل في DATACORE وقت الترحيل؛ تم حفظ السداد دون ربط بالمستفيد.'

    ELSE N'سداد إيجار تاريخي بانتظار المطابقة الزمنية مع المبنى.'
END

FROM KFMC.Housing.BuildingPayment p

LEFT JOIN KFMC.Housing.ResidentInfo r
    ON r.generalNo = p.userID_FK

LEFT JOIN Housing.ResidentInfo migratedResident
    ON migratedResident.residentInfoID =
       TRY_CONVERT(bigint, r.residentInfoID)

   AND migratedResident.residentInfoUID =
       r.residentInfoUID

   AND EXISTS
   (
       SELECT 1
       FROM KFMC.Housing.ResidentDetails eligibleDetails
       WHERE eligibleDetails.generalNo_FK = r.generalNo
   )

INNER JOIN KFMC.Housing.DeductList d
    ON d.deductListID = p.deductListID_FK

INNER JOIN #EntryDataMap entryMap
    ON entryMap.EntryDataKey =
       ISNULL(CONVERT(nvarchar(40), d.entryData), N'')

WHERE p.buildingPayementActive = 1

  AND NOT EXISTS
  (
      SELECT 1
      FROM Housing.BuildingPayment t
      WHERE t.paymentID =
            CONVERT(bigint, p.paymentID)
  );

SET @RentPayments = @@ROWCOUNT;

SET IDENTITY_INSERT Housing.BuildingPayment OFF;
SET @PaymentIdentity = 0;



/*
    Historical rent payments integrity guard.

    Preserve every source payment with
    buildingPayementActive = 1.

    If the original deduction list was canceled,
    preserve the payment as inactive in DATACORE.
*/

IF EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BuildingPayment sourcePayment

    LEFT JOIN KFMC.Housing.DeductList sourceList
        ON sourceList.deductListID =
           sourcePayment.deductListID_FK

    LEFT JOIN Housing.DeductList targetList
        ON targetList.deductListID =
           sourcePayment.deductListID_FK

    LEFT JOIN Housing.BuildingPayment targetPayment
        ON targetPayment.paymentID =
           CONVERT(bigint, sourcePayment.paymentID)

    LEFT JOIN KFMC.Housing.ResidentInfo sourceResident
        ON sourceResident.generalNo =
           sourcePayment.userID_FK

    LEFT JOIN Housing.ResidentInfo migratedResident
        ON migratedResident.residentInfoID =
           TRY_CONVERT(bigint, sourceResident.residentInfoID)

       AND migratedResident.residentInfoUID =
           sourceResident.residentInfoUID

       AND EXISTS
       (
           SELECT 1
           FROM KFMC.Housing.ResidentDetails eligibleDetails
           WHERE eligibleDetails.generalNo_FK =
                 sourceResident.generalNo
       )

    WHERE sourcePayment.buildingPayementActive = 1

      AND
      (
          -- مسير المصدر غير موجود أو حالته غير معروفة
          sourceList.deductListID IS NULL

          OR sourceList.deductActive IS NULL

          -- المسير أو السداد لم يُنقل
          OR targetList.deductListID IS NULL

          OR targetPayment.paymentID IS NULL

          -- حالة المسير تغيرت
          OR EXISTS
          (
              SELECT targetList.deductActive
              EXCEPT
              SELECT sourceList.deductActive
          )

          -- نوع السداد يجب أن يبقى إيجارًا
          OR ISNULL(
              targetPayment.BillChargeTypeID_FK, -1
          ) <> 1

          -- التحقق من هوية السداد ومبلغه ونشاطه
          OR EXISTS
          (
              SELECT
                  CONVERT(bigint, sourcePayment.userID_FK),
                  sourcePayment.PaymentUID,
                  sourcePayment.amount,
                  sourcePayment.deductListID_FK,

                  CASE
                      WHEN sourceList.deductActive = 0
                          THEN CONVERT(bit, 0)
                      ELSE sourcePayment.buildingPayementActive
                  END,

                  migratedResident.residentInfoID

              EXCEPT

              SELECT
                  targetPayment.generalNo_FK,
                  targetPayment.PaymentUID,
                  targetPayment.amount,
                  targetPayment.deductListID_FK,
                  targetPayment.buildingPayementActive,
                  targetPayment.residentInfoID_FK
          )
      )
)
BEGIN
    THROW 56022,
        N'فشل التحقق من سدادات الإيجار: يوجد سداد مفقود أو اختلاف في المبلغ أو الهوية أو حالة النشاط أو المسير.',
        1;
END;



      /* Mark active legacy Excel deduction lists after their payments are available.
         The original workbooks no longer exist, so a stable synthetic hash identifies
         each migrated list without inventing a file name. */
      INSERT INTO Housing.UploadExcelImportLog
      (
        FileHash,OriginalFileName,UploadedAt,InsertedRows,Notes,DeductListID_FK
      )
      SELECT
        LOWER
        (
          CONVERT
          (
            varchar(64),
            HASHBYTES
            (
              'SHA2_256',
              CONCAT(N'LEGACY-KFMC-EXCEL:',sourceDeduct.deductListID)
            ),
            2
          )
        ),
        NULL,
        COALESCE(sourceDeduct.entryDate,SYSDATETIME()),
        paymentCount.InsertedRows,
        N'مسير Excel قديم تم التعرف عليه من صيغة اسم المسير أثناء الترحيل.',
        targetDeduct.deductListID
      FROM KFMC.Housing.DeductList sourceDeduct
      JOIN Housing.DeductList targetDeduct
        ON targetDeduct.deductListID=sourceDeduct.deductListID
      CROSS APPLY
      (
        SELECT COUNT(*) InsertedRows
        FROM Housing.BuildingPayment targetPayment
        WHERE targetPayment.deductListID_FK=targetDeduct.deductListID
      ) paymentCount
      CROSS APPLY
      (
        SELECT LOWER
        (
          CONVERT
          (
            varchar(64),
            HASHBYTES
            (
              'SHA2_256',
              CONCAT(N'LEGACY-KFMC-EXCEL:',sourceDeduct.deductListID)
            ),
            2
          )
        ) FileHash
      ) legacyFingerprint
      WHERE sourceDeduct.deductActive=1
        AND LTRIM(RTRIM(sourceDeduct.deductName)) LIKE N'مسير استقطاع%'
        AND NOT EXISTS
        (
          SELECT 1
          FROM Housing.UploadExcelImportLog existingLog
          WHERE existingLog.DeductListID_FK=targetDeduct.deductListID
             OR existingLog.FileHash=legacyFingerprint.FileHash
        );
      SET @LegacyExcelLogs=@@ROWCOUNT;

      SET IDENTITY_INSERT Housing.BillDeductAction ON; SET @BillActionIdentity=1;
      INSERT INTO Housing.BillDeductAction
      (billDeductActionID,billDeductListID_FK,billDeductListStatusID_FK,
       billDeductDigitalSignture,billDeductNote,billDeductActive,entryDate,entryData,hostName)
      SELECT s.billDeductActionID,s.billDeductListID_FK,s.billDeductListStatusID_FK,
       s.billDeductDigitalSignture,s.billDeductNote,s.billDeductActive,
       s.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
            ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      FROM KFMC.Housing.BillDeductAction s
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      WHERE NOT EXISTS(SELECT 1 FROM Housing.BillDeductAction t WHERE t.billDeductActionID=s.billDeductActionID);
      SET @BillActions=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.BillDeductAction OFF; SET @BillActionIdentity=0;

      SET IDENTITY_INSERT Housing.BillsDeductListDetails ON; SET @BillDetailIdentity=1;
      INSERT INTO Housing.BillsDeductListDetails
      (billsDeductListDetailsID,billsDeductListDetailsUID,billDeductListDestainationID_FK,
       billDeductListID_FK,billsID_FK,billAmount,billActive,billPaid,paymentType,paidNumber,
       paidDate,paidAmount,Note,entryDate,entryData,hostName)
      SELECT s.billsDeductListDetailsID,s.billsDeductListDetailsUID,s.billDeductListDestainationID_FK,
       s.billDeductListID_FK,CONVERT(bigint,s.billsID_FK),s.billAmount,s.billActive,s.billPaid,
       s.paymentType,s.paidNumber,s.paidDate,s.paidAmount,s.Note,s.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN s.hostName
            ELSE CONCAT(ISNULL(s.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),s.entryData))),N'')) END
      
FROM KFMC.Housing.BillsDeductListDetails s

-- الفاتورة الأصلية في KFMC
INNER JOIN KFMC.Housing.Bills sourceBill
    ON sourceBill.BillsID = s.billsID_FK

-- الفاتورة المنقولة إلى DATACORE
INNER JOIN Housing.Bills migratedBill
    ON migratedBill.BillsID =
       CONVERT(bigint, sourceBill.BillsID)

   -- التأكد من أن الفاتورتين لهما الهوية نفسها
   AND migratedBill.BillsUID = sourceBill.BillsUID

   -- منع ربط تفاصيل الكهرباء بفاتورة إيجار أو ماء
   AND migratedBill.BillChargeTypeID_FK = 2

JOIN #EntryDataMap entryMap
    ON entryMap.EntryDataKey =
       ISNULL(CONVERT(nvarchar(40), s.entryData), N'')

      WHERE NOT EXISTS(SELECT 1 FROM Housing.BillsDeductListDetails t
                       WHERE t.billsDeductListDetailsID=s.billsDeductListDetailsID);
      SET @BillDetails=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.BillsDeductListDetails OFF; SET @BillDetailIdentity=0;



      
/*
    Verify ALL electricity bill details:
    paid, unpaid, active and inactive.

    No source detail may be silently skipped
    or linked to a different electricity bill.
*/

IF EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BillsDeductListDetails s

    LEFT JOIN KFMC.Housing.Bills sourceBill
        ON sourceBill.BillsID = s.billsID_FK

    LEFT JOIN Housing.Bills targetBill
        ON targetBill.BillsID =
           CONVERT(bigint, s.billsID_FK)
       AND targetBill.BillsUID = sourceBill.BillsUID
       AND targetBill.BillChargeTypeID_FK = 2

    LEFT JOIN Housing.BillDeductList targetList
        ON targetList.billDeductListID =
           s.billDeductListID_FK

    LEFT JOIN Housing.BillsDeductListDetails targetDetail
        ON targetDetail.billsDeductListDetailsID =
           s.billsDeductListDetailsID

    WHERE
        sourceBill.BillsID IS NULL

        OR targetBill.BillsID IS NULL

        OR targetList.billDeductListID IS NULL

        OR targetDetail.billsDeductListDetailsID IS NULL

        OR EXISTS
        (
            SELECT
                targetDetail.billsDeductListDetailsUID,
                targetDetail.billDeductListDestainationID_FK,
                targetDetail.billDeductListID_FK,
                targetDetail.billsID_FK,
                targetDetail.billAmount,
                targetDetail.billActive,
                targetDetail.billPaid,
                targetDetail.paymentType,
                targetDetail.paidNumber,
                targetDetail.paidDate,
                targetDetail.paidAmount

            EXCEPT

            SELECT
                s.billsDeductListDetailsUID,
                s.billDeductListDestainationID_FK,
                s.billDeductListID_FK,
                CONVERT(bigint, s.billsID_FK),
                s.billAmount,
                s.billActive,
                s.billPaid,
                s.paymentType,
                s.paidNumber,
                s.paidDate,
                s.paidAmount
        )
)
BEGIN
    ;THROW 56023,
        N'فشل ترحيل تفاصيل فواتير الكهرباء: يوجد تفصيل مفقود أو اختلاف في هوية الفاتورة أو المسير أو المبلغ أو حالة السداد.',
        1;
END;

      /*
         Derive opening payment entries only from details explicitly marked as paid.
         These rows preserve historical paid status; BillDeductList itself remains a bill batch.
      */
      INSERT INTO Housing.BuildingPayment
      (PaymentUID,buildingPaymentTypeID_FK,generalNo_FK,IDNumber,residentInfoID_FK,
       buildingDetailsID_FK,amount,deductListID_FK,buildingPayementActive,
       BillChargeTypeID_FK,IdaraId_FK,entryDate,entryData,hostName)
      SELECT d.billsDeductListDetailsUID,COALESCE(d.paymentType,1),CONVERT(bigint,b.generalNo_FK),
       r.NationalID,
migratedResident.residentInfoID,
CONVERT(nvarchar(400),b.buildingDetailsID),
       d.paidAmount,targetList.deductListID,1,2,CONVERT(int,@IdaraId),d.entryDate,
       entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN d.hostName
            ELSE CONCAT(ISNULL(d.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),d.entryData))),N'')) END
      FROM KFMC.Housing.BillsDeductListDetails d
      
INNER JOIN KFMC.Housing.Bills b
    ON b.BillsID = d.billsID_FK

-- التحقق من هوية فاتورة الكهرباء المنقولة
INNER JOIN Housing.Bills migratedBill
    ON migratedBill.BillsID =
       CONVERT(bigint, b.BillsID)
   AND migratedBill.BillsUID = b.BillsUID
   AND migratedBill.BillChargeTypeID_FK = 2

-- المستفيد الأصلي في KFMC
LEFT JOIN KFMC.Housing.ResidentInfo r
    ON r.generalNo = b.generalNo_FK

-- ربط السداد بالمستفيد المؤهل الموجود فعليًا في DATACORE
LEFT JOIN Housing.ResidentInfo migratedResident
    ON migratedResident.residentInfoID =
       TRY_CONVERT(bigint, r.residentInfoID)

   AND migratedResident.residentInfoUID =
       r.residentInfoUID

   AND EXISTS
   (
       SELECT 1
       FROM KFMC.Housing.ResidentDetails eligibleDetails
       WHERE eligibleDetails.generalNo_FK = r.generalNo
   )

      JOIN KFMC.Housing.BillDeductList sourceList ON sourceList.billDeductListID=d.billDeductListID_FK
      JOIN Housing.DeductList targetList ON targetList.deductUID=
       CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'E|',sourceList.billDeductListID,N'|',
              COALESCE(sourceList.issueYear,YEAR(d.paidDate)),N'|',COALESCE(sourceList.issueMonth,MONTH(d.paidDate)))))
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),d.entryData),N'')
      WHERE d.billPaid=1 AND d.paidAmount IS NOT NULL
        AND NOT EXISTS(SELECT 1 FROM Housing.BuildingPayment p WHERE p.PaymentUID=d.billsDeductListDetailsUID);
      SET @ElectricPayments=@@ROWCOUNT;


      
/*
    Financial integrity guard for historical
    electricity payments.

    Every paid KFMC electricity detail must:
    1. Exist in DATACORE with its original identity.
    2. Reference the correct electricity bill.
    3. Have a corresponding payment.
    4. Preserve the payment amount and generalNo.
    5. Reference only an eligible migrated resident.
    6. Reference the correct settlement list.
*/

IF EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BillsDeductListDetails d

    INNER JOIN KFMC.Housing.Bills b
        ON b.BillsID = d.billsID_FK

    INNER JOIN KFMC.Housing.BillDeductList sourceList
        ON sourceList.billDeductListID =
           d.billDeductListID_FK

    LEFT JOIN KFMC.Housing.ResidentInfo r
        ON r.generalNo = b.generalNo_FK

    LEFT JOIN Housing.ResidentInfo migratedResident
        ON migratedResident.residentInfoID =
           TRY_CONVERT(bigint, r.residentInfoID)

       AND migratedResident.residentInfoUID =
           r.residentInfoUID

       AND EXISTS
       (
           SELECT 1
           FROM KFMC.Housing.ResidentDetails eligible
           WHERE eligible.generalNo_FK = r.generalNo
       )

    WHERE d.billPaid = 1
      AND d.paidAmount IS NOT NULL

      AND
      (
          -- التأكد من نقل تفصيل السداد نفسه
          NOT EXISTS
          (
              SELECT 1
              FROM Housing.BillsDeductListDetails targetDetail

              INNER JOIN Housing.Bills targetBill
                  ON targetBill.BillsID =
                     targetDetail.billsID_FK

              WHERE targetDetail.billsDeductListDetailsID =
                    d.billsDeductListDetailsID

                AND targetDetail.billsDeductListDetailsUID =
                    d.billsDeductListDetailsUID

                AND targetDetail.billDeductListID_FK =
                    d.billDeductListID_FK

                AND targetDetail.billPaid = 1

                AND targetBill.BillsID =
                    CONVERT(bigint, b.BillsID)

                AND targetBill.BillsUID = b.BillsUID

                AND targetBill.BillChargeTypeID_FK = 2

                AND NOT EXISTS
                (
                    SELECT
                        targetDetail.paidAmount,
                        targetDetail.paidDate

                    EXCEPT

                    SELECT
                        d.paidAmount,
                        d.paidDate
                )
          )

          OR

          -- التأكد من نقل السداد المالي الصحيح
          NOT EXISTS
          (
              SELECT 1
              FROM Housing.BuildingPayment payment

              INNER JOIN Housing.DeductList targetList
                  ON targetList.deductListID =
                     payment.deductListID_FK

              WHERE payment.PaymentUID =
                    d.billsDeductListDetailsUID

                AND payment.BillChargeTypeID_FK = 2

                AND payment.buildingPayementActive = 1

                AND targetList.BillChargeTypeID_FK = 2

                AND targetList.deductUID =
                    CONVERT
                    (
                        uniqueidentifier,
                        HASHBYTES
                        (
                            'MD5',
                            CONCAT
                            (
                                N'E|',
                                sourceList.billDeductListID,
                                N'|',
                                COALESCE(
                                    sourceList.issueYear,
                                    YEAR(d.paidDate)
                                ),
                                N'|',
                                COALESCE(
                                    sourceList.issueMonth,
                                    MONTH(d.paidDate)
                                )
                            )
                        )
                    )

                -- مقارنة آمنة تشمل قيم NULL
                AND NOT EXISTS
                (
                    SELECT
                        payment.generalNo_FK,
                        payment.amount,
                        payment.residentInfoID_FK

                    EXCEPT

                    SELECT
                        CONVERT(bigint, b.generalNo_FK),
                        d.paidAmount,
                        migratedResident.residentInfoID
                )
          )
      )
)
BEGIN
    ;THROW 56021,
        N'فشل التحقق المالي: يوجد تفصيل سداد كهرباء مفقود أو سداد غير مطابق للفاتورة الأصلية أو المستفيد أو المبلغ أو المسير.',
        1;
END;


      SELECT @RollbackAfterTest RollbackAfterTest,@Bills ElectricBillsInserted,
       @RentLists RentDeductListsInserted,@RentPayments RentPaymentsInserted,
       @LegacyExcelLogs LegacyExcelImportLogsInserted,
       @ElectricSettlementLists ElectricSettlementListsInserted,
       @ElectricPayments ElectricOpeningPaymentsInserted,
       @BillLists BillDeductListsInserted,@BillActions BillDeductActionsInserted,
       @BillDetails BillDeductDetailsInserted,
       (SELECT SUM(TotalPrice) FROM Housing.Bills WHERE BillChargeTypeID_FK=2) ElectricBillsTotal,
       (SELECT SUM(amount) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=1) RentPaymentsTotal,
       (SELECT SUM(amount) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=2) ElectricPaymentsTotal;

      IF @RollbackAfterTest=1 ROLLBACK TRANSACTION; ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF @BillDetailIdentity=1 SET IDENTITY_INSERT Housing.BillsDeductListDetails OFF;
      IF @BillActionIdentity=1 SET IDENTITY_INSERT Housing.BillDeductAction OFF;
      IF @PaymentIdentity=1 SET IDENTITY_INSERT Housing.BuildingPayment OFF;
      IF @BillListIdentity=1 SET IDENTITY_INSERT Housing.BillDeductList OFF;
      IF @DeductIdentity=1 SET IDENTITY_INSERT Housing.DeductList OFF;
      IF @BillsIdentity=1 SET IDENTITY_INSERT Housing.Bills OFF;
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH;
END;