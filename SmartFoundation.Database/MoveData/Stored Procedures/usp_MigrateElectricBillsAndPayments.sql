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

    /* Only KFMC active residents whose eligible record was migrated in stage 2.
       Do not require ResidentDetails or match residentInfoUID; stage 2 defines eligibility.
       Payment/bill scopes and all subsequent parity checks use this exact same mapping. */
    SELECT CAST(src.generalNo AS bigint) AS GeneralNo,
           CAST(src.residentInfoID AS bigint) AS ResidentInfoID
    INTO #EligibleResidentScope
    FROM KFMC.Housing.ResidentInfo AS src
    JOIN Housing.ResidentInfo AS tgt
      ON tgt.residentInfoID=TRY_CONVERT(bigint,src.residentInfoID)
     AND tgt.residentInfoActive=1
    WHERE src.residentInfoActive=1
      AND TRY_CONVERT(bigint,src.generalNo) IS NOT NULL
      AND TRY_CONVERT(bigint,src.generalNo) NOT IN (0,1,18)
      AND EXISTS
      (
          SELECT 1
          FROM KFMC.Housing.BuildingAction a
          WHERE a.generalNo_FK=TRY_CONVERT(bigint,src.generalNo)
          GROUP BY a.generalNo_FK
          HAVING COUNT_BIG(*)>1
             OR MAX(CASE WHEN a.buildingActionTypeID_FK<>6 THEN 1 ELSE 0 END)=1
      );

    CREATE UNIQUE CLUSTERED INDEX IX_EligibleResidentScope_GeneralNo
        ON #EligibleResidentScope(GeneralNo);
    CREATE UNIQUE INDEX IX_EligibleResidentScope_ResidentInfoID
        ON #EligibleResidentScope(ResidentInfoID);

    /* The only permitted imported electricity bills are:
       (A) source bills with a truly NULL generalNo_FK (independent bills), OR
       (B) source bills associated with a verified active migrated resident.
       Do NOT treat 0, 1, 18, blank/non-numeric or unknown non-NULL as independent.
       Do NOT assign a NULL-generalNo bill to any beneficiary. */
    SELECT TRY_CONVERT(bigint,b.BillsID) AS BillsID,
           TRY_CONVERT(bigint,b.generalNo_FK) AS GeneralNo,
           eligible.ResidentInfoID
    INTO #EligibleElectricBills
    FROM KFMC.Housing.Bills b
    LEFT JOIN #EligibleResidentScope eligible
      ON eligible.GeneralNo=TRY_CONVERT(bigint,b.generalNo_FK)
    WHERE b.generalNo_FK IS NULL
       OR eligible.GeneralNo IS NOT NULL;

    CREATE UNIQUE CLUSTERED INDEX IX_EligibleElectricBills_BillsID
        ON #EligibleElectricBills(BillsID);

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
          eligibleBill.ResidentInfoID AS EligibleResidentInfoID,
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
        JOIN #EligibleElectricBills eligibleBill
          ON eligibleBill.BillsID=TRY_CONVERT(bigint,s.BillsID)
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

s.meterReadID,

s.EligibleResidentInfoID,
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
      
 /* ResidentInfoID in SourceBills was already verified by #EligibleElectricBills.
    For a NULL-generalNo source bill it must remain NULL. */

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
        JOIN #EligibleElectricBills eligibleBill
          ON eligibleBill.BillsID=TRY_CONVERT(bigint,s.BillsID)
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
      
WHERE NOT EXISTS
(
    SELECT 1 FROM Housing.DeductList t
    WHERE t.deductListID=s.deductListID
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
      WHERE EXISTS
      (
        SELECT 1
        FROM KFMC.Housing.BillsDeductListDetails d
        JOIN Housing.Bills eligibleBill
          ON eligibleBill.BillsID=TRY_CONVERT(bigint,d.billsID_FK)
         AND eligibleBill.BillChargeTypeID_FK=2
        WHERE d.billDeductListID_FK=s.billDeductListID
      )
        AND NOT EXISTS(SELECT 1 FROM Housing.BillDeductList t WHERE t.billDeductListID=s.billDeductListID);
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
      JOIN KFMC.Housing.Bills sourceBill
        ON sourceBill.BillsID=d.billsID_FK
      JOIN #EligibleElectricBills eligibleBill
        ON eligibleBill.BillsID=TRY_CONVERT(bigint,sourceBill.BillsID)
      JOIN Housing.Bills migratedBill
        ON migratedBill.BillsID=TRY_CONVERT(bigint,sourceBill.BillsID)
       AND migratedBill.BillChargeTypeID_FK=2
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),s.entryData),N'')
      WHERE d.billPaid=1 AND d.paidAmount IS NOT NULL
        AND NOT EXISTS
        (
          SELECT 1 FROM Housing.DeductList t
          WHERE t.deductUID=CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'E|',s.billDeductListID,N'|',
                COALESCE(s.issueYear,YEAR(d.paidDate)),N'|',COALESCE(s.issueMonth,MONTH(d.paidDate)))))
        );
      SET @ElectricSettlementLists=@@ROWCOUNT;

      /* All historical payment rows are retained, including unknown and originally inactive
         owners. Only an identified eligible resident from #EligibleResidentScope may receive
         an active payment. The original general number remains as an audit attribute. */
      CREATE TABLE #NewMigrationPaymentIDs
      (
          PaymentID bigint NOT NULL PRIMARY KEY
      );

      SET IDENTITY_INSERT Housing.BuildingPayment ON;
      SET @PaymentIdentity=1;

      INSERT INTO Housing.BuildingPayment
      (
          paymentID, PaymentUID, buildingPaymentTypeID_FK, generalNo_FK, IDNumber,
          residentInfoID_FK, rankNameA, unitID, userName, buildingDetailsID_FK,
          amount, deductListID_FK, buildingPayementActive, BillChargeTypeID_FK,
          ExtendInsuranceID_FK, IdaraId_FK, entryDate, entryData, hostName,
          buildingPaymentLinkStatusID_FK, paymentLinkNote, disactiveReason
      )
      OUTPUT inserted.paymentID INTO #NewMigrationPaymentIDs(PaymentID)
      SELECT
          CONVERT(bigint,p.paymentID), p.PaymentUID, p.buildingPaymentTypeID_FK,
          TRY_CONVERT(bigint,p.userID_FK), p.IDNumber,
          eligible.ResidentInfoID, p.rankNameA, CONVERT(nvarchar(100),p.unitID),
          p.userName, NULL, p.amount, p.deductListID_FK,
          CONVERT(bit,CASE WHEN eligible.ResidentInfoID IS NOT NULL
                             AND ISNULL(p.buildingPayementActive,0)=1
                             AND ISNULL(d.deductActive,0)=1
                           THEN 1 ELSE 0 END),
          1, NULL, CONVERT(int,@IdaraId), d.entryDate, entryMap.MappedEntryData,
          CASE WHEN entryMap.MappedEntryData IS NULL THEN d.hostName
               ELSE CONCAT(ISNULL(d.hostName,N''),N'-',
                           NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),d.entryData))),N'')) END,
          CASE WHEN eligible.ResidentInfoID IS NULL THEN 3 ELSE 2 END,
          CASE WHEN eligible.ResidentInfoID IS NULL
               THEN N'سداد تاريخي محفوظ دون إسناد مالي لمستفيد مؤهل.'
               ELSE N'سداد إيجار تاريخي بانتظار المطابقة الزمنية مع المبنى.' END,
          NULLIF(CONCAT
          (
            CASE WHEN eligible.ResidentInfoID IS NULL THEN
                 CASE
                   WHEN NOT EXISTS
                   (SELECT 1 FROM KFMC.Housing.ResidentInfo sr
                    WHERE sr.generalNo=p.userID_FK)
                     THEN N'تم تعطيل السداد لعدم وجود ملف مستفيد مطابق للرقم العام؛ '
                   WHEN EXISTS
                   (SELECT 1 FROM KFMC.Housing.ResidentInfo sr
                    WHERE sr.generalNo=p.userID_FK AND sr.residentInfoActive=1)
                     THEN N'تم تعطيل السداد لعدم وجود مستفيد نشط مؤهل للترحيل؛ '
                   ELSE N'تم تعطيل السداد لأن ملف المستفيد غير نشط؛ '
                 END
                 ELSE N'' END,
            CASE WHEN ISNULL(p.buildingPayementActive,0)<>1
                 THEN N'حركة السداد معطلة في السجل التاريخي؛ ' ELSE N'' END,
            CASE WHEN ISNULL(d.deductActive,0)<>1
                 THEN N'المسير التاريخي غير نشط؛ ' ELSE N'' END
          ),N'')
      FROM KFMC.Housing.BuildingPayment p
      INNER JOIN KFMC.Housing.DeductList d
        ON d.deductListID=p.deductListID_FK
      LEFT JOIN #EligibleResidentScope eligible
        ON eligible.GeneralNo=TRY_CONVERT(bigint,p.userID_FK)
      INNER JOIN #EntryDataMap entryMap
        ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),d.entryData),N'')
      WHERE NOT EXISTS
      (
          SELECT 1 FROM Housing.BuildingPayment t
          WHERE t.paymentID=CONVERT(bigint,p.paymentID)
      );

      SET @RentPayments=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.BuildingPayment OFF;
      SET @PaymentIdentity=0;

      /* All source records must be present; inactive or unmatched records are NOT lost.
         Preserve the source amount, UID, original general number, deduction-list ID,
         and expected financial active state for the mapped resident. */
      IF EXISTS
      (
          SELECT 1 FROM KFMC.Housing.BuildingPayment p
          LEFT JOIN KFMC.Housing.DeductList d
            ON d.deductListID=p.deductListID_FK
          LEFT JOIN #EligibleResidentScope eligible
            ON eligible.GeneralNo=TRY_CONVERT(bigint,p.userID_FK)
          LEFT JOIN Housing.DeductList targetList
            ON targetList.deductListID=p.deductListID_FK
          LEFT JOIN Housing.BuildingPayment targetPayment
            ON targetPayment.paymentID=TRY_CONVERT(bigint,p.paymentID)
          WHERE d.deductListID IS NULL OR targetList.deductListID IS NULL
             OR targetPayment.paymentID IS NULL
             OR EXISTS
             (
                 SELECT targetPayment.PaymentUID, targetPayment.generalNo_FK,
                        targetPayment.amount, targetPayment.deductListID_FK,
                        targetPayment.residentInfoID_FK,
                        targetPayment.buildingPayementActive,
                        targetPayment.BillChargeTypeID_FK
                 EXCEPT
                 SELECT p.PaymentUID,TRY_CONVERT(bigint,p.userID_FK),
                        p.amount,p.deductListID_FK,eligible.ResidentInfoID,
                        CONVERT(bit,CASE WHEN eligible.ResidentInfoID IS NOT NULL
                            AND ISNULL(p.buildingPayementActive,0)=1
                            AND ISNULL(d.deductActive,0)=1 THEN 1 ELSE 0 END),1
             )
             OR (targetPayment.buildingPayementActive=0
                 AND NULLIF(LTRIM(RTRIM(targetPayment.disactiveReason)),N'') IS NULL)
             OR EXISTS
             (
                 SELECT targetList.deductActive EXCEPT SELECT d.deductActive
             )
      )
          THROW 56022,N'فشل مطابقة جميع حركات السداد التاريخية أو أسباب تعطيلها.',1;

      /* Full-source monetary and row-count parity. This may not be weakened to
         count only active/known owners: every historical payment must survive. */
      IF
      (
          SELECT COUNT_BIG(*) FROM KFMC.Housing.BuildingPayment
      ) <> (
          SELECT COUNT_BIG(*)
          FROM KFMC.Housing.BuildingPayment p
          JOIN Housing.BuildingPayment t
            ON t.paymentID=TRY_CONVERT(bigint,p.paymentID)
      )
      OR EXISTS
      (
          SELECT
              (SELECT SUM(CAST(ISNULL(p.amount,0) AS decimal(38,2)))
               FROM KFMC.Housing.BuildingPayment p)
          EXCEPT
          SELECT
              (SELECT SUM(CAST(ISNULL(t.amount,0) AS decimal(38,2)))
               FROM KFMC.Housing.BuildingPayment p
               JOIN Housing.BuildingPayment t
                 ON t.paymentID=TRY_CONVERT(bigint,p.paymentID))
      )
          THROW 56025,N'لم تتم مطابقة عدد ومبالغ جميع حركات السداد التاريخية.',1;

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
              CONCAT(N'HISTORICAL-EXCEL-LIST:',sourceDeduct.deductListID)
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
              CONCAT(N'HISTORICAL-EXCEL-LIST:',sourceDeduct.deductListID)
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
      JOIN Housing.BillDeductList migratedList
        ON migratedList.billDeductListID=s.billDeductListID_FK
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

JOIN Housing.BillDeductList migratedList
    ON migratedList.billDeductListID=s.billDeductListID_FK

JOIN #EntryDataMap entryMap
    ON entryMap.EntryDataKey =
       ISNULL(CONVERT(nvarchar(40), s.entryData), N'')

      WHERE NOT EXISTS(SELECT 1 FROM Housing.BillsDeductListDetails t
                       WHERE t.billsDeductListDetailsID=s.billsDeductListDetailsID);
      SET @BillDetails=@@ROWCOUNT;
      SET IDENTITY_INSERT Housing.BillsDeductListDetails OFF; SET @BillDetailIdentity=0;



      
/*
    Verify all electricity bill details for selected migrated bills:
    paid, unpaid, active and inactive.

    No source detail may be silently skipped
    or linked to a different electricity bill.
*/

IF EXISTS
(
    SELECT 1
    FROM KFMC.Housing.BillsDeductListDetails s

    JOIN KFMC.Housing.Bills sourceBill
        ON sourceBill.BillsID=s.billsID_FK
    JOIN #EligibleElectricBills eligibleBill
        ON eligibleBill.BillsID=TRY_CONVERT(bigint,sourceBill.BillsID)

    JOIN Housing.Bills targetBill
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
       BillChargeTypeID_FK,IdaraId_FK,entryDate,entryData,hostName,
       buildingPaymentLinkStatusID_FK,paymentLinkNote,disactiveReason)
      OUTPUT inserted.paymentID INTO #NewMigrationPaymentIDs(PaymentID)
      SELECT d.billsDeductListDetailsUID,COALESCE(d.paymentType,1),CONVERT(bigint,b.generalNo_FK),
       r.NationalID,
eligibleElectricResident.ResidentInfoID,
CONVERT(nvarchar(400),b.buildingDetailsID),
       d.paidAmount,targetList.deductListID,
       CONVERT(bit,CASE WHEN eligibleElectricResident.ResidentInfoID IS NOT NULL
                            AND ISNULL(sourceList.deductActive,0)=1
                         THEN 1 ELSE 0 END),
       2,CONVERT(int,@IdaraId),d.entryDate,entryMap.MappedEntryData,
       CASE WHEN entryMap.MappedEntryData IS NULL THEN d.hostName
            ELSE CONCAT(ISNULL(d.hostName,N''),N'-',NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(40),d.entryData))),N'')) END,
       CASE WHEN eligibleElectricResident.ResidentInfoID IS NULL THEN 3 WHEN b.buildingDetailsID IS NOT NULL THEN 1 ELSE 2 END,
       N'تسوية افتتاحية تاريخية لسداد فاتورة كهرباء.',
       CASE WHEN eligibleElectricResident.ResidentInfoID IS NULL
            THEN N'تم تعطيل سداد الكهرباء لعدم وجود مستفيد نشط مؤهل مرتبط بالفاتورة التاريخية.'
            WHEN ISNULL(sourceList.deductActive,0)<>1
            THEN N'تم تعطيل سداد الكهرباء لأن مسير الفواتير التاريخية غير نشط.'
            ELSE NULL END
      FROM KFMC.Housing.BillsDeductListDetails d
      
INNER JOIN KFMC.Housing.Bills b
    ON b.BillsID = d.billsID_FK

-- التحقق من هوية فاتورة الكهرباء المنقولة
INNER JOIN Housing.Bills migratedBill
    ON migratedBill.BillsID =
       CONVERT(bigint, b.BillsID)
   AND migratedBill.BillsUID = b.BillsUID
   AND migratedBill.BillChargeTypeID_FK = 2

-- NULL-generalNo electricity bills are independent; their payment remains
-- unassigned, with NULL generalNo_FK / residentInfoID_FK / IDNumber.
JOIN #EligibleElectricBills eligibleBill
    ON eligibleBill.BillsID=TRY_CONVERT(bigint,b.BillsID)
LEFT JOIN KFMC.Housing.ResidentInfo r
    ON r.residentInfoID=eligibleBill.ResidentInfoID
   AND r.residentInfoActive=1
LEFT JOIN #EligibleResidentScope eligibleElectricResident
    ON eligibleElectricResident.GeneralNo=TRY_CONVERT(bigint,b.generalNo_FK)

      JOIN KFMC.Housing.BillDeductList sourceList ON sourceList.billDeductListID=d.billDeductListID_FK
      JOIN Housing.DeductList targetList ON targetList.deductUID=
       CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'E|',sourceList.billDeductListID,N'|',
              COALESCE(sourceList.issueYear,YEAR(d.paidDate)),N'|',COALESCE(sourceList.issueMonth,MONTH(d.paidDate)))))
      JOIN #EntryDataMap entryMap ON entryMap.EntryDataKey=ISNULL(CONVERT(nvarchar(40),d.entryData),N'')
      WHERE d.billPaid=1 AND d.paidAmount IS NOT NULL
        AND NOT EXISTS(SELECT 1 FROM Housing.BuildingPayment p WHERE p.PaymentUID=d.billsDeductListDetailsUID);
      SET @ElectricPayments=@@ROWCOUNT;
      /* MIGRATION_ELECTRIC_PROVENANCE_GUARD_V1 */
      IF EXISTS (
        SELECT 1
        FROM KFMC.Housing.BillsDeductListDetails sd
        JOIN KFMC.Housing.Bills sb ON sb.BillsID=sd.billsID_FK
        JOIN Housing.BuildingPayment tp ON tp.PaymentUID=sd.billsDeductListDetailsUID
        WHERE sd.billPaid=1 AND sd.paidAmount IS NOT NULL
          AND tp.BillChargeTypeID_FK=2 AND tp.buildingPayementActive=1
          AND (tp.residentInfoID_FK IS NULL OR tp.buildingPaymentLinkStatusID_FK<>1
               OR TRY_CONVERT(bigint,tp.buildingDetailsID_FK) IS NULL
               OR TRY_CONVERT(bigint,tp.buildingDetailsID_FK)<>TRY_CONVERT(bigint,sb.buildingDetailsID))
      ) THROW 56038,N'Electricity payment did not preserve source building/status 1.',1;



      
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

    JOIN #EligibleElectricBills eligibleBill
      ON eligibleBill.BillsID=TRY_CONVERT(bigint,b.BillsID)
    LEFT JOIN Housing.ResidentInfo migratedResident
      ON migratedResident.residentInfoID=eligibleBill.ResidentInfoID
     AND migratedResident.residentInfoActive=1

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

                AND payment.buildingPayementActive = CONVERT(bit,
                      CASE WHEN migratedResident.residentInfoID IS NOT NULL
                                 AND ISNULL(sourceList.deductActive,0)=1
                           THEN 1 ELSE 0 END)
                AND (payment.buildingPayementActive=1 OR
                     NULLIF(LTRIM(RTRIM(payment.disactiveReason)),N'') IS NOT NULL)

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


      /* 56024: never allow personal invoices for excluded owners, or financially active
         payments for absent/ineligible owners. An inactive payment may retain original
         generalNo but must have NULL residentInfoID_FK and a documented reason. */
      IF EXISTS
      (
          SELECT 1 FROM Housing.Bills b
          LEFT JOIN #EligibleResidentScope e
            ON e.GeneralNo=TRY_CONVERT(bigint,b.generalNo_FK)
          WHERE b.BillChargeTypeID_FK=2 AND
            ((b.generalNo_FK IS NULL AND b.residentInfoID_FK IS NOT NULL)
             OR (b.generalNo_FK IS NOT NULL AND
                 (e.ResidentInfoID IS NULL OR b.residentInfoID_FK<>e.ResidentInfoID)))
      ) OR EXISTS
      (
          SELECT 1 FROM Housing.BuildingPayment pay
          LEFT JOIN #EligibleResidentScope e
            ON e.GeneralNo=TRY_CONVERT(bigint,pay.generalNo_FK)
          WHERE pay.BillChargeTypeID_FK IN (1,2) AND
          (
             (e.ResidentInfoID IS NULL AND
               (pay.residentInfoID_FK IS NOT NULL
                OR ISNULL(pay.buildingPayementActive,0)<>0
                OR NULLIF(LTRIM(RTRIM(pay.disactiveReason)),N'') IS NULL))
             OR
             (e.ResidentInfoID IS NOT NULL AND
                (pay.residentInfoID_FK IS NULL
                 OR pay.residentInfoID_FK<>e.ResidentInfoID))
             OR
             (ISNULL(pay.buildingPayementActive,0)=0 AND
                NULLIF(LTRIM(RTRIM(pay.disactiveReason)),N'') IS NULL)
          )
      )
          THROW 56024,N'فشل حماية أهلية الفواتير والسدادات المعطلة أو غير المسندة.',1;

      /* A permanent local audit entry for every newly imported inactive payment.
         No source database name or sensitive personal identifier is written to Notes. */
      INSERT INTO dbo.AuditLog
          (TableName,ActionType,RecordID,PerformedBy,Notes)
      SELECT N'[Housing].[BuildingPayment]',N'MIGRATION_PAYMENT_PROTECTED',
             pay.paymentID,N'MoveData',
             CONCAT(N'PaymentID=',pay.paymentID,
                    N'; DeductListID=',COALESCE(CONVERT(nvarchar(40),pay.deductListID_FK),N'NULL'),
                    N'; Reason=',COALESCE(pay.disactiveReason,N'سداد تاريخي غير نشط'))
      FROM #NewMigrationPaymentIDs imported
      JOIN Housing.BuildingPayment pay ON pay.paymentID=imported.PaymentID
      WHERE ISNULL(pay.buildingPayementActive,0)=0;


      /* MIGRATION_INTEGRATED_RENT_CLASSIFICATION_V1 */
    CREATE TABLE #ResidentMatch
    (
        generalNo bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NOT NULL
    );

    ;WITH RankedDetails AS
    (
        SELECT detailsRow.generalNo_FK,detailsRow.residentInfoID_FK,
               ROW_NUMBER() OVER(PARTITION BY detailsRow.generalNo_FK
                 ORDER BY detailsRow.residentDetailsActive DESC,detailsRow.residentDetailsID DESC) rowNumber
        FROM Housing.ResidentDetails detailsRow
        WHERE detailsRow.generalNo_FK IS NOT NULL AND detailsRow.residentInfoID_FK IS NOT NULL
    )
    INSERT #ResidentMatch(generalNo,residentInfoID)
    SELECT generalNo_FK,residentInfoID_FK FROM RankedDetails WHERE rowNumber=1;

    CREATE TABLE #PaymentBase
(
    paymentID bigint NOT NULL PRIMARY KEY,
    oldStatusID int NULL,
    residentInfoID bigint NULL,
    effectivePaymentDate date NULL,
    effectivePaymentEndDate date NULL,
    isHijriPeriod bit NOT NULL
);

    CREATE TABLE #HijriPeriodMap
(
      issueYear  int NOT NULL
    , issueMonth int NOT NULL
    , PeriodFrom date NOT NULL
    , PeriodTo   date NOT NULL
    , PRIMARY KEY (issueYear, issueMonth)
);

INSERT INTO #HijriPeriodMap
(
      issueYear
    , issueMonth
    , PeriodFrom
    , PeriodTo
)
SELECT
      g.yearH
    , g.monthH
    , MIN(CONVERT(date, g.gregorianDate))
    , MAX(CONVERT(date, g.gregorianDate))
FROM dbo._GregorianHijriDate g
WHERE g.yearH BETWEEN 1300 AND 1600
  AND g.monthH BETWEEN 1 AND 12
GROUP BY
      g.yearH
    , g.monthH;


INSERT #PaymentBase
(
      paymentID
    , oldStatusID
    , residentInfoID
    , effectivePaymentDate
    , effectivePaymentEndDate
    , isHijriPeriod
)
SELECT
      paymentRow.paymentID
    , paymentRow.buildingPaymentLinkStatusID_FK
    , COALESCE
      (
          paymentRow.residentInfoID_FK,
          residentMatch.residentInfoID
      )

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN hijri.PeriodFrom

          WHEN deductRow.issueYear BETWEEN 1900 AND 9999
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN TRY_CONVERT
                   (
                       date,
                       CONCAT
                       (
                           deductRow.issueYear,
                           N'-',
                           RIGHT
                           (
                               N'0'
                               + CONVERT
                                 (
                                     nvarchar(2),
                                     deductRow.issueMonth
                                 ),
                               2
                           ),
                           N'-01'
                       )
                   )

          ELSE CONVERT(date, deductRow.paymentDate)
      END

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN hijri.PeriodTo

          WHEN deductRow.issueYear BETWEEN 1900 AND 9999
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN EOMONTH
                   (
                       TRY_CONVERT
                       (
                           date,
                           CONCAT
                           (
                               deductRow.issueYear,
                               N'-',
                               RIGHT
                               (
                                   N'0'
                                   + CONVERT
                                     (
                                         nvarchar(2),
                                         deductRow.issueMonth
                                     ),
                                   2
                               ),
                               N'-01'
                           )
                       )
                   )

          ELSE CONVERT(date, deductRow.paymentDate)
      END

    , CASE
          WHEN deductRow.issueYear BETWEEN 1300 AND 1600
           AND deductRow.issueMonth BETWEEN 1 AND 12
              THEN CONVERT(bit, 1)

          ELSE CONVERT(bit, 0)
      END

FROM Housing.BuildingPayment paymentRow

LEFT JOIN Housing.DeductList deductRow
    ON deductRow.deductListID =
       paymentRow.deductListID_FK

LEFT JOIN #ResidentMatch residentMatch
    ON residentMatch.generalNo =
       paymentRow.generalNo_FK

LEFT JOIN #HijriPeriodMap hijri
    ON hijri.issueYear = deductRow.issueYear
   AND hijri.issueMonth = deductRow.issueMonth

WHERE
      paymentRow.BillChargeTypeID_FK = 1

  AND paymentRow.BillChargeTypeID_FK = 1

  AND paymentRow.buildingPayementActive = 1

  AND paymentRow.BillChargeTypeID_FK = 1

  AND
(
       paymentRow.buildingPaymentLinkStatusID_FK IS NULL

    OR paymentRow.buildingPaymentLinkStatusID_FK IN (2,3,4)

    OR
    (
        paymentRow.buildingPaymentLinkStatusID_FK = 1
        AND deductRow.issueYear BETWEEN 1300 AND 1600
        AND deductRow.issueMonth BETWEEN 1 AND 12
    )
)

OPTION(RECOMPILE);

    CREATE INDEX IX_PaymentBase_ResidentDates
      ON #PaymentBase(residentInfoID,effectivePaymentDate,effectivePaymentEndDate) INCLUDE(paymentID,oldStatusID);

    CREATE TABLE #OccupancyRoots
    (
        rootActionID bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        occupancyDate date NOT NULL
    );

    INSERT #OccupancyRoots(rootActionID,residentInfoID,buildingDetailsID,occupancyDate)
    SELECT actionRow.buildingActionID,actionRow.residentInfoID_FK,actionRow.buildingDetailsID_FK,
           CONVERT(date,actionRow.buildingActionDate)
    FROM Housing.BuildingAction actionRow
    WHERE actionRow.buildingActionTypeID_FK=2 AND actionRow.buildingActionActive=1
      AND actionRow.residentInfoID_FK IS NOT NULL AND actionRow.buildingDetailsID_FK IS NOT NULL
      AND actionRow.buildingActionDate IS NOT NULL;

    CREATE INDEX IX_OccupancyRoots_Resident
      ON #OccupancyRoots(residentInfoID,occupancyDate) INCLUDE(rootActionID,buildingDetailsID);

    CREATE TABLE #ActionTree
    (
        rootActionID bigint NOT NULL,
        buildingActionID bigint NOT NULL,
        buildingActionTypeID int NULL,
        buildingActionDate datetime NULL,
        treeLevel int NOT NULL
    );

    ;WITH ActionTree AS
    (
        SELECT rootRow.rootActionID,actionRow.buildingActionID,
               actionRow.buildingActionTypeID_FK,actionRow.buildingActionDate,0 treeLevel
        FROM #OccupancyRoots rootRow
        JOIN Housing.BuildingAction actionRow ON actionRow.buildingActionID=rootRow.rootActionID
        UNION ALL
        SELECT treeRow.rootActionID,childRow.buildingActionID,
               childRow.buildingActionTypeID_FK,childRow.buildingActionDate,treeRow.treeLevel+1
        FROM ActionTree treeRow
        JOIN Housing.BuildingAction childRow
          ON childRow.buildingActionParentID=treeRow.buildingActionID
         AND childRow.buildingActionActive=1
        WHERE treeRow.treeLevel<100
    )
    INSERT #ActionTree(rootActionID,buildingActionID,buildingActionTypeID,buildingActionDate,treeLevel)
    SELECT rootActionID,buildingActionID,buildingActionTypeID_FK,buildingActionDate,treeLevel
    FROM ActionTree OPTION(MAXRECURSION 0);

    CREATE INDEX IX_ActionTree_RootType
      ON #ActionTree(rootActionID,buildingActionTypeID) INCLUDE(buildingActionDate);

    CREATE TABLE #OccupancyPeriods
    (
        residentInfoID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        occupancyDate date NOT NULL,
        exitDate date NULL,
        rootActionID bigint NOT NULL PRIMARY KEY
    );

    INSERT #OccupancyPeriods(residentInfoID,buildingDetailsID,occupancyDate,exitDate,rootActionID)
    SELECT rootRow.residentInfoID,rootRow.buildingDetailsID,rootRow.occupancyDate,
           MIN(CASE WHEN treeRow.buildingActionTypeID=3 THEN CONVERT(date,treeRow.buildingActionDate) END),
           rootRow.rootActionID
    FROM #OccupancyRoots rootRow
    LEFT JOIN #ActionTree treeRow ON treeRow.rootActionID=rootRow.rootActionID
    GROUP BY rootRow.residentInfoID,rootRow.buildingDetailsID,rootRow.occupancyDate,rootRow.rootActionID;

    CREATE INDEX IX_OccupancyPeriods_ResidentDates
      ON #OccupancyPeriods(residentInfoID,occupancyDate,exitDate) INCLUDE(buildingDetailsID);

    CREATE TABLE #CandidateBuildings
    (
        paymentID bigint NOT NULL,
        buildingDetailsID bigint NOT NULL,
        CONSTRAINT PK_CandidateBuildings PRIMARY KEY(paymentID,buildingDetailsID)
    );

    INSERT #CandidateBuildings(paymentID,buildingDetailsID)
    SELECT DISTINCT paymentBase.paymentID,occupancy.buildingDetailsID
    FROM #PaymentBase paymentBase
JOIN #OccupancyPeriods occupancy
  ON occupancy.residentInfoID =
     paymentBase.residentInfoID

 AND paymentBase.isHijriPeriod = 0

 AND paymentBase.effectivePaymentEndDate >=
     occupancy.occupancyDate

 AND paymentBase.effectivePaymentDate <=
     ISNULL
     (
         occupancy.exitDate,
         CONVERT(date, GETDATE())
     )
     AND paymentBase.effectivePaymentEndDate>=occupancy.occupancyDate
     AND paymentBase.effectivePaymentDate<=ISNULL(occupancy.exitDate,CONVERT(date,GETDATE()));

    CREATE TABLE #CandidateSummary
    (
        paymentID bigint NOT NULL PRIMARY KEY,
        candidateCount int NOT NULL,
        proposedBuildingDetailsID bigint NULL
    );
    INSERT #CandidateSummary
    SELECT paymentID,COUNT(*),MIN(buildingDetailsID) FROM #CandidateBuildings GROUP BY paymentID;

    CREATE TABLE #FirstOccupancy
    (
        residentInfoID bigint NOT NULL PRIMARY KEY,
        firstOccupancyDate date NOT NULL
    );
    INSERT #FirstOccupancy
    SELECT residentInfoID,MIN(occupancyDate) FROM #OccupancyPeriods GROUP BY residentInfoID;

    CREATE TABLE #Proposal
    (
        paymentID bigint NOT NULL PRIMARY KEY,
        residentInfoID bigint NULL,
        effectivePaymentDate date NULL,
        effectivePaymentEndDate date NULL,
        firstOccupancyDate date NULL,
        candidateBuildingCount int NOT NULL,
        proposedBuildingDetailsID bigint NULL,
        oldStatusID int NULL,
        proposedStatusID int NOT NULL,
        proposalReason nvarchar(1000) NOT NULL
    );

    INSERT #Proposal
SELECT
       paymentBase.paymentID,
       paymentBase.residentInfoID,
       paymentBase.effectivePaymentDate,
       paymentBase.effectivePaymentEndDate,
       firstOccupancy.firstOccupancyDate,
       ISNULL(candidateSummary.candidateCount,0),

       CASE
            WHEN paymentBase.isHijriPeriod = 0
             AND candidateSummary.candidateCount = 1
                THEN candidateSummary.proposedBuildingDetailsID
            ELSE NULL
       END,

       paymentBase.oldStatusID,

       CASE
            WHEN paymentBase.residentInfoID IS NULL
                THEN 3

            WHEN paymentBase.isHijriPeriod = 1
             AND paymentBase.effectivePaymentEndDate IS NOT NULL
             AND firstOccupancy.firstOccupancyDate IS NOT NULL
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN 4

            WHEN paymentBase.isHijriPeriod = 1
                THEN 2

            WHEN paymentBase.effectivePaymentEndDate IS NOT NULL
             AND firstOccupancy.firstOccupancyDate IS NOT NULL
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN 4

            WHEN candidateSummary.candidateCount = 1
                THEN 1

            ELSE 2
       END,

       CASE
            WHEN paymentBase.residentInfoID IS NULL
                THEN N'لم يتم العثور على ملف المستفيد.'

            WHEN paymentBase.effectivePaymentDate IS NULL
                THEN N'تعذر تحديد تاريخ ميلادي موثوق للسداد.'

            WHEN firstOccupancy.firstOccupancyDate IS NULL
                THEN N'المستفيد معروف ولكن لا توجد له فترة سكن.'

            WHEN paymentBase.isHijriPeriod = 1
             AND paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN N'السداد الهجري يسبق أول فترة سكن معروفة.'

            WHEN paymentBase.isHijriPeriod = 1
                THEN N'سداد تاريخي بفترة هجرية؛ تم الاحتفاظ به كرصد عام للمستفيد دون ربطه بمبنى.'

            WHEN paymentBase.effectivePaymentEndDate < firstOccupancy.firstOccupancyDate
                THEN N'السداد يسبق أول فترة سكن معروفة.'

            WHEN candidateSummary.candidateCount = 1
                THEN N'تم تحديد مبنى واحد من فترة السكن في تاريخ السداد.'

            WHEN candidateSummary.candidateCount > 1
                THEN N'تاريخ السداد يقع داخل أكثر من فترة سكن؛ بقي رصيدا عاما.'

            ELSE N'السداد بعد أول سكن ولكنه خارج فترة سكن محددة؛ بقي رصيدا عاما.'
       END

FROM #PaymentBase paymentBase

LEFT JOIN #CandidateSummary candidateSummary
    ON candidateSummary.paymentID = paymentBase.paymentID

LEFT JOIN #FirstOccupancy firstOccupancy
    ON firstOccupancy.residentInfoID = paymentBase.residentInfoID;



      IF (SELECT COUNT_BIG(*) FROM #Proposal) <>
         (SELECT COUNT_BIG(*) FROM Housing.BuildingPayment WHERE BillChargeTypeID_FK=1 AND buildingPayementActive=1)
         THROW 56039,N'Rent classifier coverage mismatch.',1;
      UPDATE paymentRow
      SET paymentRow.residentInfoID_FK=proposal.residentInfoID,
          paymentRow.buildingDetailsID_FK=CASE WHEN proposal.proposedStatusID=1 THEN CONVERT(nvarchar(400),proposal.proposedBuildingDetailsID) ELSE NULL END,
          paymentRow.buildingPaymentLinkStatusID_FK=proposal.proposedStatusID,
          paymentRow.paymentLinkNote=proposal.proposalReason
      OUTPUT inserted.paymentID,deleted.buildingPaymentLinkStatusID_FK,inserted.buildingPaymentLinkStatusID_FK,
             deleted.buildingDetailsID_FK,inserted.buildingDetailsID_FK,N'AUTO_TEMPORAL',inserted.paymentLinkNote,N'MoveData',GETDATE()
      INTO Housing.BuildingPaymentLinkAudit
      (paymentID_FK,oldLinkStatusID,newLinkStatusID,oldBuildingDetailsID,newBuildingDetailsID,linkMethod,linkNote,changedBy,changedDate)
      FROM Housing.BuildingPayment paymentRow JOIN #Proposal proposal ON proposal.paymentID=paymentRow.paymentID
      WHERE ISNULL(paymentRow.residentInfoID_FK,-1)<>ISNULL(proposal.residentInfoID,-1)
         OR ISNULL(paymentRow.buildingPaymentLinkStatusID_FK,-1)<>proposal.proposedStatusID
         OR ISNULL(NULLIF(LTRIM(RTRIM(paymentRow.buildingDetailsID_FK)),N''),N'-1')<>
            ISNULL(CASE WHEN proposal.proposedStatusID=1 THEN CONVERT(nvarchar(400),proposal.proposedBuildingDetailsID) END,N'-1');

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

GO

