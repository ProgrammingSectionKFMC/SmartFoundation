-- REVIEW ONLY. Before deployment verify the live hash and review the delta.
-- ALTER, not CREATE, because the procedure is already present in DATACORE.
-- Do NOT run without verifying the live definition and transaction tests.
CREATE  PROCEDURE [Housing].[GenerateHistoricalServiceBillsForExitRequest]
      @Action NVARCHAR(12)
    , @ExitRequestActionID BIGINT
    , @EntryData NVARCHAR(20) = NULL
    , @HostName NVARCHAR(200) = NULL
    , @PreviewFrom DATE = NULL
    , @PreviewTo DATE = NULL, @ReturnResult BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Action NOT IN (N'PREVIEW',N'GENERATE') OR @Action IS NULL
        THROW 50001, N'العملية المسموحة PREVIEW أو GENERATE فقط.', 1;
    IF @ExitRequestActionID IS NULL
        THROW 50001, N'رقم دورة الإخلاء مطلوب.', 1;
    IF @Action=N'GENERATE' AND (@PreviewFrom IS NOT NULL OR @PreviewTo IS NOT NULL)
        THROW 50001, N'يمنع تحديد فترة جزئية عند الإصدار؛ يجب فحص كامل تاريخ الإشغال.', 1;

    DECLARE @ResidentInfoID BIGINT,@GeneralNo BIGINT,@BuildingDetailsID BIGINT,
            @IdaraID BIGINT,@OccupentDate DATE,@ExitDate DATE,
            @HistoryFrom DATE,@HistoryTo DATE,@CurrentStage60 BIGINT,
            @InitialTransactionCount INT=@@TRANCOUNT,
            @AppLockResult INT;

    BEGIN TRY
        IF @Action=N'GENERATE' AND @InitialTransactionCount=0 BEGIN TRANSACTION;
        IF @Action=N'GENERATE'
        BEGIN
            IF NULLIF(LTRIM(RTRIM(@EntryData)),N'') IS NULL
                THROW 50001,N'هوية منفذ إصدار الخدمات مطلوبة.',1;
        END;

        SELECT @ResidentInfoID=a.residentInfoID_FK,
               @GeneralNo=a.generalNo_FK,
               @BuildingDetailsID=a.buildingDetailsID_FK,
               @IdaraID=a.IdaraId_FK,
               @OccupentDate=TRY_CONVERT(DATE,a.OccupentDate),
               @ExitDate=TRY_CONVERT(DATE,a.ExitDate)
        FROM Housing.ExitFinancialProcessingCycle c
        JOIN Housing.BuildingAction a ON a.buildingActionID=c.ExitRequestActionID_FK
        WHERE c.ExitRequestActionID_FK=@ExitRequestActionID
          AND c.ProcessingVersion=1
          AND a.buildingActionTypeID_FK=54 AND a.buildingActionActive=1;
        IF @ResidentInfoID IS NULL OR @GeneralNo IS NULL OR @BuildingDetailsID IS NULL
           OR @IdaraID IS NULL OR @OccupentDate IS NULL OR @ExitDate IS NULL
           OR @ExitDate<@OccupentDate
            THROW 50001,N'دورة الإخلاء غير مسجلة أو بياناتها غير مكتملة.',1;

        IF @Action=N'GENERATE'
        BEGIN
            -- Same resource name as Housing.GenerateExitServiceBillsForRequest.

                    declare @msg nvarchar(max) = CONCAT(N'ExitServiceCycle:',@IdaraID,N':',@ResidentInfoID,N':',@BuildingDetailsID);

            EXEC @AppLockResult=sys.sp_getapplock
              @Resource=@msg,
              @LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=15000;
            IF @AppLockResult<0 THROW 50001,N'تعذر حجز معالجة الخدمات التاريخية.',1;
        END;

        SELECT TOP (1) @CurrentStage60=a60.buildingActionID
        FROM Housing.V_WaitingList w
        JOIN Housing.BuildingAction a60
          ON a60.buildingActionID=TRY_CONVERT(BIGINT,w.LastActionID)
         AND a60.buildingActionTypeID_FK=60 AND a60.buildingActionActive=1
        JOIN Housing.BuildingAction prev
          ON prev.buildingActionID=a60.buildingActionParentID
         AND prev.buildingActionTypeID_FK IN (54,59) AND prev.buildingActionActive=1
        WHERE w.LastActionTypeID=60 AND w.residentInfoID=@ResidentInfoID
          AND w.buildingDetailsID=@BuildingDetailsID AND w.IdaraId=@IdaraID
          AND w.GeneralNo=@GeneralNo
          AND (CASE WHEN prev.buildingActionTypeID_FK=59
                    THEN prev.buildingActionParentID ELSE prev.buildingActionID END)
              =@ExitRequestActionID
          AND a60.residentInfoID_FK=@ResidentInfoID
          AND a60.generalNo_FK=@GeneralNo
          AND a60.buildingDetailsID_FK=@BuildingDetailsID
          AND a60.IdaraId_FK=@IdaraID;
        IF @CurrentStage60 IS NULL
            THROW 50001,N'المرحلة الحالية ليست 60 للدورة المحددة.',1;

        SET @HistoryFrom=@OccupentDate;
        SET @HistoryTo=DATEADD(DAY,-1,DATEFROMPARTS(YEAR(@ExitDate),MONTH(@ExitDate),1));
        IF @Action=N'PREVIEW'
        BEGIN
            IF @PreviewFrom IS NOT NULL AND @PreviewFrom>@HistoryFrom SET @HistoryFrom=@PreviewFrom;
            IF @PreviewTo IS NOT NULL AND @PreviewTo<@HistoryTo SET @HistoryTo=@PreviewTo;
            IF @PreviewFrom IS NOT NULL AND @PreviewTo IS NOT NULL AND @PreviewFrom>@PreviewTo
                THROW 50001,N'نطاق المعاينة غير صحيح.',1;
            IF @HistoryFrom<=@HistoryTo AND DATEDIFF(DAY,@HistoryFrom,@HistoryTo)>400
                THROW 50001,N'معاينة أكثر من 400 يوم غير مسموحة؛ حدد فترة أقصر.',1;
        END;
        IF @HistoryFrom>@HistoryTo
        BEGIN
            IF @ReturnResult=1 SELECT @ExitRequestActionID AS Exit54,0 AS HistoricalDays,
                   N'NO_COMPLETED_HISTORICAL_MONTH' AS Status;
            IF @Action=N'GENERATE' AND @InitialTransactionCount=0 COMMIT TRANSACTION;
            RETURN;
        END;

        -- Protect the resident/home billing range against concurrent inserts
        -- while collecting coverage and generating missing bills. The same
        -- lock resource above serializes this engine with the exit-month engine.
        IF @Action=N'GENERATE'
        BEGIN
            DECLARE @LockedInvoiceCount BIGINT;
            SELECT @LockedInvoiceCount=COUNT_BIG(*)
            FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
            WHERE b.residentInfoID_FK=@ResidentInfoID
              AND b.buildingDetailsID=@BuildingDetailsID
              AND b.idaraID_FK=@IdaraID
              AND b.BillChargeTypeID_FK IN (2,3,4);
        END;

        ---------------------------------------------------------------------------
        -- RETRO_UNASSIGNED_INVOICE_SPLIT_V1 [REVIEW ONLY]
        -- Eligible monthly service invoices (no resident), issued before a backdated
        -- occupancy was registered, are replaced by a resident share and, when
        -- needed, a no-resident share. Never look at payments in this feature.
        -- PREVIEW builds the virtual replacement coverage but DOES NOT write.
        ---------------------------------------------------------------------------
        CREATE TABLE #RetroSplitPlan
        (
            SourceBillsID BIGINT NOT NULL PRIMARY KEY,
            BillFrom DATE NOT NULL,
            BillTo DATE NOT NULL,
            AssignedFrom DATE NOT NULL,
            AssignedTo DATE NOT NULL,
            TotalDays360 INT NOT NULL,
            AssignedDays360 INT NOT NULL,
            AssignedFactor DECIMAL(18,10) NOT NULL,
            AssignedTotal DECIMAL(18,2) NOT NULL,
            UnassignedTotal DECIMAL(18,2) NOT NULL,
            AssignedBillsID BIGINT NULL,
            UnassignedBillsID BIGINT NULL
        );

        INSERT INTO #RetroSplitPlan
            (SourceBillsID,BillFrom,BillTo,AssignedFrom,AssignedTo,
             TotalDays360,AssignedDays360,AssignedFactor,AssignedTotal,UnassignedTotal)
        SELECT
            b.BillsID,
            CONVERT(DATE,b.BillsFromDate),CONVERT(DATE,b.BillsToDate),
            CASE WHEN CONVERT(DATE,b.BillsFromDate)<@OccupentDate
                 THEN @OccupentDate ELSE CONVERT(DATE,b.BillsFromDate) END,
            CONVERT(DATE,b.BillsToDate),
            days.TotalDays360,days.AssignedDays360,
            CONVERT(DECIMAL(18,10),days.AssignedDays360*1.0/NULLIF(days.TotalDays360,0)),
            CAST(ROUND(b.TotalPrice*days.AssignedDays360*1.0/NULLIF(days.TotalDays360,0),2) AS DECIMAL(18,2)),
            CONVERT(DECIMAL(18,2),b.TotalPrice-
                CAST(ROUND(b.TotalPrice*days.AssignedDays360*1.0/NULLIF(days.TotalDays360,0),2) AS DECIMAL(18,2)))
        FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
        JOIN Housing.MeterRead mr ON mr.meterReadID=b.meterReadID
        LEFT JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=b.BillChargeTypeID_FK
        CROSS APPLY (SELECT CONVERT(DATE,b.BillsFromDate) AS BillFrom,
                            CONVERT(DATE,b.BillsToDate) AS BillTo,
                            CASE WHEN CONVERT(DATE,b.BillsFromDate)<@OccupentDate
                                 THEN @OccupentDate ELSE CONVERT(DATE,b.BillsFromDate) END AS AssignedFrom) dates
        CROSS APPLY
        (
            SELECT
              (YEAR(dates.BillTo)-YEAR(dates.BillFrom))*360
              +(MONTH(dates.BillTo)-MONTH(dates.BillFrom))*30
              +(CASE WHEN dates.BillTo=EOMONTH(dates.BillTo) AND DAY(dates.BillTo)<30 THEN 30
                     WHEN DAY(dates.BillTo)>30 THEN 30 ELSE DAY(dates.BillTo) END)
              -(CASE WHEN dates.BillFrom=EOMONTH(dates.BillFrom) AND DAY(dates.BillFrom)<30 THEN 30
                     WHEN DAY(dates.BillFrom)>30 THEN 30 ELSE DAY(dates.BillFrom) END)+1 AS TotalDays360,
              (YEAR(dates.BillTo)-YEAR(dates.AssignedFrom))*360
              +(MONTH(dates.BillTo)-MONTH(dates.AssignedFrom))*30
              +(CASE WHEN dates.BillTo=EOMONTH(dates.BillTo) AND DAY(dates.BillTo)<30 THEN 30
                     WHEN DAY(dates.BillTo)>30 THEN 30 ELSE DAY(dates.BillTo) END)
              -(CASE WHEN dates.AssignedFrom=EOMONTH(dates.AssignedFrom) AND DAY(dates.AssignedFrom)<30 THEN 30
                     WHEN DAY(dates.AssignedFrom)>30 THEN 30 ELSE DAY(dates.AssignedFrom) END)+1 AS AssignedDays360
        ) days
        WHERE b.residentInfoID_FK IS NULL
          AND b.buildingDetailsID=@BuildingDetailsID
          AND b.idaraID_FK=@IdaraID
          AND b.BillTypeID_FK=2 AND b.BillChargeTypeID_FK IN (2,3,4)
          AND b.BillActive=1 AND b.ParentBillsID_FK IS NULL
          AND b.TotalPrice>0
          AND b.BillsFromDate IS NOT NULL AND b.BillsToDate IS NOT NULL
          AND dates.BillFrom<=dates.BillTo
          AND dates.BillTo>=@HistoryFrom AND dates.BillTo<=@HistoryTo
          AND YEAR(dates.BillFrom)=YEAR(dates.BillTo)
          AND MONTH(dates.BillFrom)=MONTH(dates.BillTo)
          AND b.PeriodYear=YEAR(dates.BillFrom)
          AND b.PeriodMonth=MONTH(dates.BillFrom)
          AND days.TotalDays360>0
          AND days.AssignedDays360 BETWEEN 1 AND days.TotalDays360
          AND COALESCE(b.meterServiceTypeID,ct.MeterServiceTypeID_FK) IS NOT NULL
          AND mr.meterReadActive=1 AND mr.meterReadTypeID_FK=2
          AND mr.residentInfoID_FK IS NULL
          AND (mr.buildingDetailsID IS NULL OR mr.buildingDetailsID=@BuildingDetailsID)
          AND mr.IdaraID_FK=@IdaraID
          AND (b.meterID IS NULL OR b.meterID=mr.meterID_FK)
          AND NOT EXISTS
          (SELECT 1 FROM Housing.Bills child
           WHERE child.ParentBillsID_FK=b.BillsID);

        -- Rounding must not create a zero-value active replacement bill.
        IF EXISTS
        (
            SELECT 1 FROM #RetroSplitPlan p
            WHERE p.AssignedTotal<=0 OR p.UnassignedTotal<0
               OR (p.BillFrom<p.AssignedFrom AND p.UnassignedTotal<=0)
        )
            THROW 50001,N'مبلغ الفاتورة لا يسمح بتقسيم موثوق بعد التقريب إلى هللتين.',1;

        -- Refuse ambiguous overlapping invoices rather than silently duplicating
        -- charges. All historical service overlaps for the same service are included.
        IF EXISTS
        (
            SELECT 1
            FROM #RetroSplitPlan p
            JOIN Housing.Bills sourceBill ON sourceBill.BillsID=p.SourceBillsID
            LEFT JOIN Housing.BillChargeType sourceCharge ON sourceCharge.BillChargeTypeID=sourceBill.BillChargeTypeID_FK
            JOIN Housing.Bills otherBill WITH (UPDLOCK,HOLDLOCK)
              ON otherBill.buildingDetailsID=@BuildingDetailsID
             AND otherBill.idaraID_FK=@IdaraID
             AND otherBill.BillActive=1
             AND otherBill.BillChargeTypeID_FK IN (2,3,4)
             AND otherBill.BillsID<>p.SourceBillsID
             AND CONVERT(DATE,otherBill.BillsFromDate)<=p.AssignedTo
             AND CONVERT(DATE,otherBill.BillsToDate)>=p.AssignedFrom
            LEFT JOIN Housing.BillChargeType otherCharge ON otherCharge.BillChargeTypeID=otherBill.BillChargeTypeID_FK
            WHERE COALESCE(sourceBill.meterServiceTypeID,sourceCharge.MeterServiceTypeID_FK)
                = COALESCE(otherBill.meterServiceTypeID,otherCharge.MeterServiceTypeID_FK)
        )
            THROW 50001,N'توجد فاتورة خدمات متداخلة؛ تعذر تقسيم الفاتورة غير المسندة بأمان.',1;

        IF @Action=N'GENERATE'
        BEGIN
          DECLARE @RetroSourceID BIGINT,@RetroAssignedID BIGINT,@RetroUnassignedID BIGINT;
          DECLARE @RetroFrom DATE,@RetroTo DATE,@RetroAssignedFrom DATE,@RetroAssignedTo DATE;
          DECLARE @RetroFactor DECIMAL(18,10),@RetroAssignedTotal DECIMAL(18,2),@RetroUnassignedTotal DECIMAL(18,2);

          WHILE EXISTS (SELECT 1 FROM #RetroSplitPlan WHERE AssignedBillsID IS NULL)
          BEGIN
            SELECT TOP(1) @RetroSourceID=SourceBillsID,@RetroFrom=BillFrom,@RetroTo=BillTo,
                   @RetroAssignedFrom=AssignedFrom,@RetroAssignedTo=AssignedTo,
                   @RetroFactor=AssignedFactor,@RetroAssignedTotal=AssignedTotal,
                   @RetroUnassignedTotal=UnassignedTotal
            FROM #RetroSplitPlan WHERE AssignedBillsID IS NULL ORDER BY SourceBillsID;

            -- Soft cancel the historical original; all replacement rows below are
            -- within the caller's transaction (stage 60 -> 57).
            UPDATE b SET b.BillActive=0,b.CanceledBy=@EntryData,b.CanceledDate=SYSDATETIME()
            FROM Housing.Bills b WHERE b.BillsID=@RetroSourceID
              AND b.BillActive=1 AND b.residentInfoID_FK IS NULL;
            IF @@ROWCOUNT<>1
                THROW 50001,N'تغيرت الفاتورة التاريخية قبل تقسيمها؛ ألغيت المعالجة.',1;

            -- Recreate resident share from same historic bill metadata, retaining
            -- source invoice as parent; proportionalize amount fields, not rates.
            INSERT INTO Housing.Bills
            (BillsUID,BillChargeTypeID_FK,BillTypeID_FK,CurrentPeriodID,PeriodMonth,PeriodYear,
             CurrentPeriodTax,meterNo,meterID,meterName_A,buildingDetailsNo,buildingUtilityTypeID,
             buildingDetailsID,meterTypeID,meterServiceTypeID,residentInfoID_FK,generalNo_FK,
             CurrentRead,LastRead,ReadDiff,PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,
             TotalPrice,BillsFromDate,BillsToDate,BillActive,idaraID_FK,entryData,hostName,
             ExitRequestActionID_FK,ParentBillsID_FK,meterReadID)
            SELECT NEWID(),b.BillChargeTypeID_FK,b.BillTypeID_FK,b.CurrentPeriodID,b.PeriodMonth,b.PeriodYear,
                   b.CurrentPeriodTax,b.meterNo,b.meterID,b.meterName_A,b.buildingDetailsNo,b.buildingUtilityTypeID,
                   b.buildingDetailsID,b.meterTypeID,b.meterServiceTypeID,@ResidentInfoID,@GeneralNo,
                   CASE WHEN @RetroFrom<@RetroAssignedFrom THEN 0 ELSE b.CurrentRead END,
                   CASE WHEN @RetroFrom<@RetroAssignedFrom THEN 0 ELSE b.LastRead END,
                   CASE WHEN @RetroFrom<@RetroAssignedFrom THEN 0 ELSE b.ReadDiff END,
                   CAST(ROUND(b.PRICE*@RetroFactor,2) AS DECIMAL(18,2)),
                   CAST(ROUND(b.PRICETAX*@RetroFactor,2) AS DECIMAL(18,2)),
                   CAST(ROUND(b.meterServicePrice*@RetroFactor,2) AS DECIMAL(18,2)),
                   CAST(ROUND(b.meterServicePriceTAX*@RetroFactor,2) AS DECIMAL(18,2)),
                   @RetroAssignedTotal,@RetroAssignedFrom,@RetroAssignedTo,1,@IdaraID,@EntryData,@HostName,
                   NULL,@RetroSourceID,b.meterReadID
            FROM Housing.Bills b WHERE b.BillsID=@RetroSourceID;
            IF @@ROWCOUNT<>1 THROW 50001,N'فشل إنشاء نصيب المستفيد من الفاتورة التاريخية.',1;
            SET @RetroAssignedID=SCOPE_IDENTITY();

            SET @RetroUnassignedID=NULL;
            IF @RetroFrom<@RetroAssignedFrom
            BEGIN
              -- Unassigned historical remainder exactly balances original invoice.
              INSERT INTO Housing.Bills
              (BillsUID,BillChargeTypeID_FK,BillTypeID_FK,CurrentPeriodID,PeriodMonth,PeriodYear,
               CurrentPeriodTax,meterNo,meterID,meterName_A,buildingDetailsNo,buildingUtilityTypeID,
               buildingDetailsID,meterTypeID,meterServiceTypeID,residentInfoID_FK,generalNo_FK,
               CurrentRead,LastRead,ReadDiff,PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,
               TotalPrice,BillsFromDate,BillsToDate,BillActive,idaraID_FK,entryData,hostName,
               ExitRequestActionID_FK,ParentBillsID_FK,meterReadID)
              SELECT NEWID(),b.BillChargeTypeID_FK,b.BillTypeID_FK,b.CurrentPeriodID,b.PeriodMonth,b.PeriodYear,
                     b.CurrentPeriodTax,b.meterNo,b.meterID,b.meterName_A,b.buildingDetailsNo,b.buildingUtilityTypeID,
                     b.buildingDetailsID,b.meterTypeID,b.meterServiceTypeID,NULL,NULL,
                     0,0,0, -- derived allocation; physical reads retained on canceled original
                     b.PRICE - CAST(ROUND(b.PRICE*@RetroFactor,2) AS DECIMAL(18,2)),
                     b.PRICETAX - CAST(ROUND(b.PRICETAX*@RetroFactor,2) AS DECIMAL(18,2)),
                     b.meterServicePrice - CAST(ROUND(b.meterServicePrice*@RetroFactor,2) AS DECIMAL(18,2)),
                     b.meterServicePriceTAX - CAST(ROUND(b.meterServicePriceTAX*@RetroFactor,2) AS DECIMAL(18,2)),
                     @RetroUnassignedTotal,@RetroFrom,DATEADD(DAY,-1,@RetroAssignedFrom),1,@IdaraID,@EntryData,@HostName,
                     NULL,@RetroSourceID,b.meterReadID
              FROM Housing.Bills b WHERE b.BillsID=@RetroSourceID;
              IF @@ROWCOUNT<>1 THROW 50001,N'فشل إنشاء الجزء غير المسند من الفاتورة التاريخية.',1;
              SET @RetroUnassignedID=SCOPE_IDENTITY();
            END;

            UPDATE #RetroSplitPlan
              SET AssignedBillsID=@RetroAssignedID,UnassignedBillsID=@RetroUnassignedID
            WHERE SourceBillsID=@RetroSourceID;

            INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,PerformedBy,Notes)
            VALUES(N'[Housing].[Bills]',N'SPLITUNASSIGNEDHISTORICALBILL',@RetroSourceID,@EntryData,
                   CONCAT(N'Exit54=',@ExitRequestActionID,N'; AssignedBill=',@RetroAssignedID,
                          N'; UnassignedBill=',COALESCE(CONVERT(NVARCHAR(30),@RetroUnassignedID),N'NULL'),
                          N'; AssignedAmount=',@RetroAssignedTotal,
                          N'; UnassignedAmount=',@RetroUnassignedTotal));
          END;
        END;

        -- Day/method classification copied from the tested current exit-month engine;
        -- history-specific change: space validity is checked against EACH BillDay.
    ;WITH Days AS
    (
        SELECT @HistoryFrom AS BillDay
        UNION ALL
        SELECT DATEADD(DAY,1,BillDay) FROM Days WHERE BillDay < @HistoryTo
    )
    SELECT
          d.BillDay
        , st.meterServiceTypeID AS ServiceID
        , st.meterServiceTypeName_A AS ServiceName
        , CONVERT(INT,CASE WHEN dept.HasLink=1 THEN 1 ELSE 0 END) AS LinkedToIdara
        , CONVERT(INT,CASE WHEN service.HasLink=1 THEN 1 ELSE 0 END) AS LinkedToBuilding
        , ISNULL(reading.CountMeters,0) AS ReadingMeters
        , ISNULL(fixed.CountMeters,0) AS FixedMeters
        , selectedPolicy.EstimatedBillingPolicyID AS SelectedPolicyID
        , ISNULL(spaces.MatchedSpaces,0) AS EligibleSpaces
        , ISNULL(fallback.CountRates,0) AS FixedFallbackRates
        , ISNULL(existingBill.CountBills,0) AS ExistingActiveBillsForDay
        , CONVERT(VARCHAR(25),CASE
            WHEN dept.HasLink IS NULL THEN 'NOT_LINKED_TO_IDARA'
            WHEN reading.CountMeters > 0 THEN 'READING_METER'
            WHEN fixed.CountMeters > 0 THEN 'FIXED_METER'
            WHEN service.HasLink IS NULL THEN 'NOT_LINKED_TO_BUILDING'
            WHEN spaces.MatchedSpaces > 0 THEN 'SPACE_ESTIMATED'
            WHEN fallback.CountRates > 0 THEN 'SERVICE_FIXED_FALLBACK'
            ELSE 'NO_ELIGIBLE_RATE' END) AS ProposedMethod
    INTO #HistoryDays
    FROM Days d
    CROSS JOIN Housing.MeterServiceType st
    OUTER APPLY
    (
        SELECT TOP (1) 1 AS HasLink
        FROM Housing.MeterServiceTypeLinkedWithIdara il
        WHERE il.MeterServiceTypeID_FK=st.meterServiceTypeID
          AND (il.Idara_FK=@IdaraID OR il.Idara_FK IS NULL)
          AND (il.MeterServiceTypeLinkedWithIdaraActive=1 OR il.MeterServiceTypeLinkedWithIdaraEndDate IS NOT NULL)
          AND (il.MeterServiceTypeLinkedWithIdaraStartDate IS NULL OR CONVERT(date,il.MeterServiceTypeLinkedWithIdaraStartDate)<=d.BillDay)
          AND (il.MeterServiceTypeLinkedWithIdaraEndDate IS NULL OR CONVERT(date,il.MeterServiceTypeLinkedWithIdaraEndDate)>=d.BillDay)
    ) dept
    OUTER APPLY
    (
        SELECT TOP(1) 1 AS HasLink
        FROM Housing.BuildingDetailsMeterServices s
        WHERE s.BuildingDetailsID_FK=@BuildingDetailsID
          AND s.IdaraId_FK=@IdaraID
          AND s.MeterServicesTypeID_FK=st.meterServiceTypeID
          AND (s.BuildingDetailsMeterServicesActive=1 OR s.BuildingDetailsMeterServicesEndDate IS NOT NULL)
          AND (s.BuildingDetailsMeterServicesStartDate IS NULL OR CONVERT(date,s.BuildingDetailsMeterServicesStartDate)<=d.BillDay)
          AND (s.BuildingDetailsMeterServicesEndDate IS NULL OR CONVERT(date,s.BuildingDetailsMeterServicesEndDate)>=d.BillDay)
    ) service
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountMeters
        FROM Housing.MeterForBuilding link
        JOIN Housing.Meter m ON m.meterID=link.meterID_FK
        JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
        WHERE link.buildingDetailsID_FK=@BuildingDetailsID
          AND link.IdaraID_FK=@IdaraID
          AND link.meterForBuildingActive=1 AND m.meterActive=1 AND mt.meterTypeActive=1
          AND mt.IdaraId_FK=@IdaraID
          AND mt.meterServiceTypeID_FK=st.meterServiceTypeID
          AND mt.MeterCalculateTypeID_FK=1
          AND (link.meterForBuildingStartDate IS NULL OR CONVERT(date,link.meterForBuildingStartDate)<=d.BillDay)
          AND (link.meterForBuildingEndDate IS NULL OR CONVERT(date,link.meterForBuildingEndDate)>=d.BillDay)
          AND (m.meterStartDate IS NULL OR CONVERT(date,m.meterStartDate)<=d.BillDay)
          AND (m.meterEndDate IS NULL OR CONVERT(date,m.meterEndDate)>=d.BillDay)
    ) reading
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountMeters
        FROM Housing.MeterForBuilding link
        JOIN Housing.Meter m ON m.meterID=link.meterID_FK
        JOIN Housing.MeterType mt ON mt.meterTypeID=m.meterTypeID_FK
        WHERE link.buildingDetailsID_FK=@BuildingDetailsID
          AND link.IdaraID_FK=@IdaraID
          AND link.meterForBuildingActive=1 AND m.meterActive=1 AND mt.meterTypeActive=1
          AND mt.IdaraId_FK=@IdaraID
          AND mt.meterServiceTypeID_FK=st.meterServiceTypeID
          AND mt.MeterCalculateTypeID_FK=2
          AND (link.meterForBuildingStartDate IS NULL OR CONVERT(date,link.meterForBuildingStartDate)<=d.BillDay)
          AND (link.meterForBuildingEndDate IS NULL OR CONVERT(date,link.meterForBuildingEndDate)>=d.BillDay)
          AND (m.meterStartDate IS NULL OR CONVERT(date,m.meterStartDate)<=d.BillDay)
          AND (m.meterEndDate IS NULL OR CONVERT(date,m.meterEndDate)>=d.BillDay)
    ) fixed
    OUTER APPLY
    (
        SELECT TOP(1) p.EstimatedBillingPolicyID
        FROM Housing.EstimatedBillingPolicy p
        WHERE p.EstimatedBillingPolicyActive=1
          AND (p.IdaraID_FK=@IdaraID OR p.IdaraID_FK IS NULL)
          AND p.EffectiveFrom<=d.BillDay
          AND (p.EffectiveTo IS NULL OR p.EffectiveTo>=d.BillDay)
        ORDER BY CASE WHEN p.IdaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                 p.EffectiveFrom DESC,p.EstimatedBillingPolicyID DESC
    ) selectedPolicy
    OUTER APPLY
    (
        /* An eligible space overlapping ANY part of this period qualifies as an input.
           The future billing engine must preserve the user's whole-period rule. */
        SELECT COUNT(*) AS MatchedSpaces
        FROM Housing.BuildingSpace sp
        JOIN Housing.EstimatedBillingPolicyDetails policyRule
          ON policyRule.BuildingSpaceTypeID_FK=sp.BuildingSpaceTypeID_FK
         AND policyRule.MeterServiceTypeID_FK=st.meterServiceTypeID
         AND policyRule.EstimatedBillingPolicyID_FK=selectedPolicy.EstimatedBillingPolicyID
         AND policyRule.EstimatedBillingPolicyDetailsActive=1
        WHERE sp.BuildingDetailsID_FK=@BuildingDetailsID AND sp.BuildingSpaceActive=1
          AND (sp.BuildingSpaceStartDate IS NULL OR CONVERT(date,sp.BuildingSpaceStartDate)<=d.BillDay)
          AND (sp.BuildingSpaceEndDate IS NULL OR CONVERT(date,sp.BuildingSpaceEndDate)>=d.BillDay)
    ) spaces
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountRates
        FROM Housing.MeterServiceTypeFixedAmount amount
        WHERE amount.MeterServiceTypeID_FK=st.meterServiceTypeID
          AND (amount.idaraID_FK=@IdaraID OR amount.idaraID_FK IS NULL)
          AND amount.FixedAmount>0
          AND (amount.MeterServiceTypeFixedAmountActive=1 OR amount.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
          AND (amount.MeterServiceTypeFixedAmountStartDate IS NULL OR CONVERT(date,amount.MeterServiceTypeFixedAmountStartDate)<=d.BillDay)
          AND (amount.MeterServiceTypeFixedAmountEndDate IS NULL OR CONVERT(date,amount.MeterServiceTypeFixedAmountEndDate)>=d.BillDay)
    ) fallback
    OUTER APPLY
    (
        SELECT COUNT(*) AS CountBills
        FROM Housing.Bills b
        LEFT JOIN Housing.BillChargeType chargeType
          ON chargeType.BillChargeTypeID=b.BillChargeTypeID_FK
        WHERE (b.residentInfoID_FK=@ResidentInfoID
          OR (@Action=N'PREVIEW' AND b.residentInfoID_FK IS NULL
              AND EXISTS (SELECT 1 FROM #RetroSplitPlan p
                          WHERE p.SourceBillsID=b.BillsID
                            AND d.BillDay BETWEEN p.AssignedFrom AND p.AssignedTo)))
          AND b.buildingDetailsID=@BuildingDetailsID
          AND b.idaraID_FK=@IdaraID
          AND (b.meterServiceTypeID=st.meterServiceTypeID
               OR (b.meterServiceTypeID IS NULL AND chargeType.MeterServiceTypeID_FK=st.meterServiceTypeID))
          AND b.BillActive=1
          AND b.BillChargeTypeID_FK IN (2,3,4)
          AND COALESCE(CONVERT(date,b.BillsFromDate),
                CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                THEN DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1) END) <=d.BillDay
          AND COALESCE(CONVERT(date,b.BillsToDate),
                CASE WHEN b.PeriodYear BETWEEN 1753 AND 9999 AND b.PeriodMonth BETWEEN 1 AND 12
                THEN EOMONTH(DATEFROMPARTS(b.PeriodYear,b.PeriodMonth,1)) END) >=d.BillDay
    ) existingBill
    WHERE st.meterServiceTypeActive=1
      AND (st.meterServiceTypeStartDate IS NULL OR CONVERT(date,st.meterServiceTypeStartDate)<=d.BillDay)
      AND (st.meterServiceTypeEndDate IS NULL OR CONVERT(date,st.meterServiceTypeEndDate)>=d.BillDay)
    OPTION (MAXRECURSION 0);


        CREATE CLUSTERED INDEX IX_HistoryDays ON #HistoryDays(ServiceID,BillDay);

        -- Do not trust a month-only date as exact partial-month coverage.
        -- Existing bills contribute to coverage; they do NOT prove their own correctness.
        CREATE TABLE #Issues
        (
          IssueType NVARCHAR(60) NOT NULL,
          ServiceID INT NULL,
          BillsID BIGINT NULL,
          FromDate DATE NULL, ToDate DATE NULL,
          Explanation NVARCHAR(300) NOT NULL,
          IsBlocking BIT NOT NULL DEFAULT (1)
        );
        -- Do not treat the obsolete bill-to-payment mapping as proof of collection.
        -- An existing active invoice covers its period in the ledger; when its
        -- meter link was retroactively shortened, surface a nonblocking warning.
        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation,IsBlocking)
        SELECT N'METER_ASSIGNMENT_HISTORY_WARNING',b.meterServiceTypeID,b.BillsID,
               MIN(d.BillDay),MAX(d.BillDay),
               N'فاتورة نشطة تغطي فترة خارج تاريخ ربط العداد الحالي؛ تحقق من السجل التاريخي عند الحاجة دون افتراض سداد أو إعادة فوترة.',
               CONVERT(BIT,0)
        FROM Housing.Bills b
        JOIN #HistoryDays d ON d.ServiceID=b.meterServiceTypeID
         AND d.BillDay BETWEEN CONVERT(DATE,b.BillsFromDate) AND CONVERT(DATE,b.BillsToDate)
        WHERE b.residentInfoID_FK=@ResidentInfoID AND b.buildingDetailsID=@BuildingDetailsID
          AND b.idaraID_FK=@IdaraID AND b.BillActive=1
          AND b.BillChargeTypeID_FK IN (2,3,4)
          AND b.meterID IS NOT NULL
          AND NOT EXISTS
          (
            SELECT 1 FROM Housing.MeterForBuilding link
            WHERE link.meterID_FK=b.meterID
              AND link.buildingDetailsID_FK=@BuildingDetailsID AND link.IdaraID_FK=@IdaraID
              AND (link.meterForBuildingActive=1 OR link.meterForBuildingEndDate IS NOT NULL)
              AND (link.meterForBuildingStartDate IS NULL OR CONVERT(DATE,link.meterForBuildingStartDate)<=d.BillDay)
              AND (link.meterForBuildingEndDate IS NULL OR CONVERT(DATE,link.meterForBuildingEndDate)>=d.BillDay)
          )
        GROUP BY b.meterServiceTypeID,b.BillsID;

        IF @Action=N'PREVIEW'
          INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation,IsBlocking)
          SELECT N'AUTO_SPLIT_UNASSIGNED_BILL',ct.MeterServiceTypeID_FK,p.SourceBillsID,
                 p.AssignedFrom,p.AssignedTo,
                 N'فاتورة غير مسندة ستقسم تلقائيًا قبل الإرسال إذا استوفت شروط الأهلية.',
                 CONVERT(BIT,0)
          FROM #RetroSplitPlan p
          JOIN Housing.Bills b ON b.BillsID=p.SourceBillsID
          JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=b.BillChargeTypeID_FK;

        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation)
        SELECT N'DUPLICATE_ACTIVE_BILLS',d.ServiceID,NULL,MIN(d.BillDay),MAX(d.BillDay),
               N'تغطية متداخلة لفواتير خدمات نشطة؛ يمنع إعادة إصدار الفترة.'
        FROM #HistoryDays d WHERE d.ExistingActiveBillsForDay>1
        GROUP BY d.ServiceID;

        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation)
        SELECT N'MISSING_READING_INVOICE',d.ServiceID,NULL,MIN(d.BillDay),MAX(d.BillDay),
               N'توجد أيام قراءة عداد غير مفوترة؛ لا يجوز تحويلها تلقائيًا إلى تقدير.'
        FROM #HistoryDays d
        WHERE d.ExistingActiveBillsForDay=0 AND d.ProposedMethod='READING_METER'
        GROUP BY d.ServiceID;

        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation)
        SELECT N'UNSUPPORTED_FIXED_METER',d.ServiceID,NULL,MIN(d.BillDay),MAX(d.BillDay),
               N'استكمال العداد الثابت المتعدد يحتاج إصدارًا لكل عداد؛ إصدار هذه الفترات موقوف في V0.1.'
        FROM #HistoryDays d
        WHERE d.ExistingActiveBillsForDay=0 AND d.ProposedMethod='FIXED_METER'
        GROUP BY d.ServiceID;

        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation)
        SELECT N'NO_EFFECTIVE_RATE',d.ServiceID,NULL,MIN(d.BillDay),MAX(d.BillDay),
               N'فترة خدمة غير مفوترة بدون تعرفة سارية؛ لا يجوز تطبيق سياسة لاحقة بأثر رجعي.'
        FROM #HistoryDays d
        WHERE d.ExistingActiveBillsForDay=0 AND d.ProposedMethod='NO_ELIGIBLE_RATE'
        GROUP BY d.ServiceID;

        -- Missing contiguous spans by service/method/policy and month.
        ;WITH Candidates AS
        (
          SELECT d.ServiceID,d.ServiceName,d.BillDay,d.ProposedMethod,d.SelectedPolicyID,
                 DATEFROMPARTS(YEAR(d.BillDay),MONTH(d.BillDay),1) AS CalendarMonth,
                 DATEDIFF(DAY,'20000101',d.BillDay)-
                  ROW_NUMBER() OVER(PARTITION BY d.ServiceID,YEAR(d.BillDay),MONTH(d.BillDay),
                                                d.ProposedMethod,ISNULL(d.SelectedPolicyID,-1)
                                    ORDER BY d.BillDay) AS IslandKey
          FROM #HistoryDays d
          WHERE d.ExistingActiveBillsForDay=0
            AND d.ProposedMethod IN ('SPACE_ESTIMATED','SERVICE_FIXED_FALLBACK')
        )
        , Grouped AS
        (
          SELECT ServiceID,MAX(ServiceName) AS ServiceName,
                 MIN(BillDay) AS SegmentStart,MAX(BillDay) AS SegmentEnd,
                 ProposedMethod,SelectedPolicyID,COUNT(*) AS CalendarDays
          FROM Candidates
          GROUP BY ServiceID,CalendarMonth,ProposedMethod,SelectedPolicyID,IslandKey
        )
        SELECT CONVERT(INT,ROW_NUMBER() OVER(ORDER BY SegmentStart,ServiceID)) AS SegmentID,
               ServiceID,ServiceName,SegmentStart,SegmentEnd,ProposedMethod,SelectedPolicyID,CalendarDays
        INTO #Segments FROM Grouped;

        -- A non-null active invoice using only PeriodYear/Month blocks a new partial
        -- invoice for that month regardless of the generic daily-preview classification.
        INSERT INTO #Issues(IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation)
        SELECT DISTINCT N'WEAK_MONTH_OVERLAP',s.ServiceID,b.BillsID,s.SegmentStart,s.SegmentEnd,
               N'فاتورة قائمة بتاريخ فترة ناقص في الشهر نفسه؛ لا يجوز إصدار جزئي بجانبها.'
        FROM #Segments s
        JOIN Housing.Bills b ON b.residentInfoID_FK=@ResidentInfoID
          AND b.buildingDetailsID=@BuildingDetailsID AND b.idaraID_FK=@IdaraID
          AND b.BillActive=1 AND b.BillChargeTypeID_FK IN (2,3,4)
          AND b.PeriodYear=YEAR(s.SegmentStart) AND b.PeriodMonth=MONTH(s.SegmentStart)
          AND (b.BillsFromDate IS NULL OR b.BillsToDate IS NULL)
        LEFT JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=b.BillChargeTypeID_FK
        WHERE COALESCE(b.meterServiceTypeID,ct.MeterServiceTypeID_FK)=s.ServiceID;

        IF @Action=N'PREVIEW'
        BEGIN
          SELECT @ExitRequestActionID AS Exit54,@ResidentInfoID AS ResidentInfoID,
                 @BuildingDetailsID AS BuildingDetailsID,@IdaraID AS IdaraID,
                 @HistoryFrom AS PeriodFrom,@HistoryTo AS PeriodTo,
                 @CurrentStage60 AS Stage60;
          SELECT IssueType,ServiceID,BillsID,FromDate,ToDate,Explanation,IsBlocking FROM #Issues
          ORDER BY IssueType,ServiceID,BillsID;
          SELECT SegmentID,ServiceID,ServiceName,SegmentStart,SegmentEnd,ProposedMethod,
                 SelectedPolicyID,CalendarDays FROM #Segments ORDER BY SegmentStart,ServiceID;
          SELECT d.ServiceID,MAX(d.ServiceName) AS ServiceName,
                 COUNT(*) AS TotalDays,
                 SUM(CASE WHEN d.ExistingActiveBillsForDay=0
                                AND d.ProposedMethod NOT IN ('NOT_LINKED_TO_IDARA','NOT_LINKED_TO_BUILDING')
                           THEN 1 ELSE 0 END) AS UnbilledDays,
                 SUM(CASE WHEN d.ExistingActiveBillsForDay>1 THEN 1 ELSE 0 END) AS DuplicateDays
          FROM #HistoryDays d GROUP BY d.ServiceID ORDER BY d.ServiceID;
          SELECT CASE WHEN EXISTS(SELECT 1 FROM #Issues WHERE IsBlocking=1) THEN 'BLOCKED'
                      ELSE 'ELIGIBLE_FOR_LIMITED_GENERATE' END AS PreviewDecision,
                 (SELECT COUNT(*) FROM #Issues WHERE IsBlocking=1) AS IssueCount,
                 (SELECT COUNT(*) FROM #Issues WHERE IsBlocking=0) AS WarningCount,
                 (SELECT COUNT(*) FROM #Segments) AS MissingSegments;
          RETURN;
        END;

        IF EXISTS (SELECT 1 FROM #Issues WHERE IsBlocking=1)
            THROW 50001,N'الفوترة التاريخية غير مؤهلة: توجد فجوات قراءة أو تعرفة/تغطية غير موثوقة؛ نفذ PREVIEW.',1;

        -- Safe subset only: homogeneous estimation/fallback within a gap.
        -- We fail closed if the financial configuration changes inside a segment.
        CREATE TABLE #NewBills(BillsID BIGINT PRIMARY KEY,ServiceID INT,SegmentStart DATE,SegmentEnd DATE,Method NVARCHAR(25));
        DECLARE @SegmentID INT=0,@SegmentMax INT=(SELECT ISNULL(MAX(SegmentID),0) FROM #Segments);
        DECLARE @ServiceID INT,@SegmentStart DATE,@SegmentEnd DATE,@Method NVARCHAR(25),
                @PolicyID BIGINT,@BillingDays INT,@ChargeTypeID INT,@TaxID INT,
                @TaxRatePercent DECIMAL(18,6),@TaxApplicable BIT,@TaxInclusive BIT,
                @BeforeTax DECIMAL(18,2),@TaxAmount DECIMAL(18,2),@TotalPrice DECIMAL(18,2),
                @FixedAmount DECIMAL(18,2),@PeriodID INT,@BuildingNo NVARCHAR(200),
                @UtilityTypeID INT,@BillID BIGINT,@CalculationID BIGINT;
        SELECT @BuildingNo=bd.buildingDetailsNo,@UtilityTypeID=bd.buildingUtilityTypeID_FK
        FROM Housing.BuildingDetails bd
        WHERE bd.buildingDetailsID=@BuildingDetailsID AND bd.IdaraId_FK=@IdaraID;

        CREATE TABLE #SpaceAmounts
        (
          BuildingSpaceTypeID INT,SpaceCode NVARCHAR(50),SpaceName NVARCHAR(100),
          SpaceCount INT,AverageConsumption DECIMAL(18,6),UsageFactor DECIMAL(18,6),
          UnitPrice DECIMAL(18,6),UnitCode NVARCHAR(30),
          BeforeTax DECIMAL(18,2),Tax DECIMAL(18,2),Total DECIMAL(18,2)
        );
        WHILE @SegmentID<@SegmentMax
        BEGIN
          SET @SegmentID=@SegmentID+1;
          SELECT @ServiceID=ServiceID,@SegmentStart=SegmentStart,@SegmentEnd=SegmentEnd,
                 @Method=ProposedMethod,@PolicyID=SelectedPolicyID
          FROM #Segments WHERE SegmentID=@SegmentID;
          SET @ChargeTypeID=NULL; SET @TaxID=NULL; SET @TaxRatePercent=NULL;
          SET @FixedAmount=NULL; SET @TaxApplicable=1; SET @TaxInclusive=0;
          SET @BeforeTax=NULL; SET @TaxAmount=NULL; SET @TotalPrice=NULL;

          -- Count 30/360 billable days, preserving current exit-service convention.
          SET @BillingDays=(YEAR(@SegmentEnd)-YEAR(@SegmentStart))*360
             +(MONTH(@SegmentEnd)-MONTH(@SegmentStart))*30
             +CASE WHEN @SegmentEnd=EOMONTH(@SegmentEnd) AND DAY(@SegmentEnd)<30 THEN 30
                   WHEN DAY(@SegmentEnd)>30 THEN 30 ELSE DAY(@SegmentEnd) END
             -CASE WHEN @SegmentStart=EOMONTH(@SegmentStart) AND DAY(@SegmentStart)<30 THEN 30
                   WHEN DAY(@SegmentStart)>30 THEN 30 ELSE DAY(@SegmentStart) END +1;
          IF @BillingDays<1 OR @BillingDays>30
             THROW 50001,N'عدد أيام الفوترة التاريخية غير صحيح وفق 30/360.',1;

          -- Configuration must not change inside this segment: tax, space applicability,
          -- fallback rate, and estimation inputs must remain stable day-by-day.
          IF @Method=N'SPACE_ESTIMATED'
          BEGIN
            SELECT @TaxApplicable=p.TaxApplicable,@TaxInclusive=p.TaxInclusive
            FROM Housing.EstimatedBillingPolicy p
            WHERE p.EstimatedBillingPolicyID=@PolicyID AND p.EstimatedBillingPolicyActive=1
              AND p.EffectiveFrom<=@SegmentStart
              AND (p.EffectiveTo IS NULL OR p.EffectiveTo>=@SegmentEnd);
            IF @@ROWCOUNT<>1
                THROW 50001,N'سياسة التقدير غير متاحة طوال الفترة.',1;
            IF EXISTS
            (
              SELECT 1 FROM Housing.BuildingSpace sp
              JOIN Housing.EstimatedBillingPolicyDetails pd
                ON pd.BuildingSpaceTypeID_FK=sp.BuildingSpaceTypeID_FK
               AND pd.MeterServiceTypeID_FK=@ServiceID
               AND pd.EstimatedBillingPolicyID_FK=@PolicyID
               AND pd.EstimatedBillingPolicyDetailsActive=1
              WHERE sp.BuildingDetailsID_FK=@BuildingDetailsID AND sp.BuildingSpaceActive=1
                AND ((sp.BuildingSpaceStartDate>@SegmentStart AND sp.BuildingSpaceStartDate<=@SegmentEnd)
                   OR (sp.BuildingSpaceEndDate>=@SegmentStart AND sp.BuildingSpaceEndDate<@SegmentEnd))
            ) THROW 50001,N'تغيرت الفراغات المؤهلة خلال الفترة؛ يلزم تقسيم أكثر دقة.',1;
          END
          ELSE
          BEGIN
            SELECT TOP (1) @FixedAmount=r.FixedAmount
            FROM Housing.MeterServiceTypeFixedAmount r
            WHERE r.MeterServiceTypeID_FK=@ServiceID AND r.FixedAmount>0
              AND (r.idaraID_FK=@IdaraID OR r.idaraID_FK IS NULL)
              AND (r.MeterServiceTypeFixedAmountActive=1 OR r.MeterServiceTypeFixedAmountEndDate IS NOT NULL)
              AND (r.MeterServiceTypeFixedAmountStartDate IS NULL OR CONVERT(DATE,r.MeterServiceTypeFixedAmountStartDate)<=@SegmentStart)
              AND (r.MeterServiceTypeFixedAmountEndDate IS NULL OR CONVERT(DATE,r.MeterServiceTypeFixedAmountEndDate)>=@SegmentEnd)
            ORDER BY CASE WHEN r.idaraID_FK=@IdaraID THEN 0 ELSE 1 END,
                     r.MeterServiceTypeFixedAmountStartDate DESC,r.MeterServiceTypeFixedAmountID DESC;
            IF @FixedAmount IS NULL THROW 50001,N'التعرفة الثابتة غير صالحة طوال الفترة.',1;
            IF EXISTS
            (
              SELECT 1 FROM Housing.MeterServiceTypeFixedAmount r
              WHERE r.MeterServiceTypeID_FK=@ServiceID
                AND (r.idaraID_FK=@IdaraID OR r.idaraID_FK IS NULL)
                AND r.FixedAmount>0
                AND r.MeterServiceTypeFixedAmountStartDate>@SegmentStart
                AND r.MeterServiceTypeFixedAmountStartDate<=@SegmentEnd
            ) THROW 50001,N'تغيرت التعرفة الثابتة خلال الفترة؛ يلزم التقسيم.',1;
          END;

          SELECT TOP(1) @TaxID=t.taxID,@TaxRatePercent=t.taxRate
          FROM dbo.Tax t
          WHERE t.taxActive=1 AND CONVERT(DATE,t.taxStartDate)<=@SegmentStart
            AND (t.taxEndDate IS NULL OR CONVERT(DATE,t.taxEndDate)>=@SegmentEnd)
          ORDER BY t.taxStartDate DESC,t.taxID DESC;
          IF @TaxApplicable=1 AND @TaxRatePercent IS NULL
              THROW 50001,N'ضريبة الخدمات غير متاحة طوال فترة الفاتورة.',1;
          IF EXISTS
          (
            SELECT 1 FROM dbo.Tax t WHERE t.taxStartDate>@SegmentStart AND t.taxStartDate<=@SegmentEnd
              AND t.taxActive=1
          ) THROW 50001,N'تغيرت الضريبة خلال الفترة؛ يلزم تقسيمها.',1;

          SELECT TOP (1) @ChargeTypeID=ct.BillChargeTypeID
          FROM Housing.BillChargeType ct
          WHERE ct.MeterServiceTypeID_FK=@ServiceID AND ct.BillChargeTypeActive=1
            AND ct.BillChargeTypeID IN (2,3,4)
          ORDER BY ct.BillChargeTypeID;
          IF @ChargeTypeID IS NULL
              THROW 50001,N'نوع رسم الخدمة غير متاح.',1;

          DELETE FROM #SpaceAmounts;
          IF @Method=N'SPACE_ESTIMATED'
          BEGIN
            ;WITH SpaceCounts AS
            (
              SELECT sp.BuildingSpaceTypeID_FK,COUNT(*) AS SpaceCount
              FROM Housing.BuildingSpace sp
              WHERE sp.BuildingDetailsID_FK=@BuildingDetailsID AND sp.BuildingSpaceActive=1
                AND (sp.BuildingSpaceStartDate IS NULL OR CONVERT(DATE,sp.BuildingSpaceStartDate)<=@SegmentStart)
                AND (sp.BuildingSpaceEndDate IS NULL OR CONVERT(DATE,sp.BuildingSpaceEndDate)>=@SegmentEnd)
              GROUP BY sp.BuildingSpaceTypeID_FK
            )
            INSERT INTO #SpaceAmounts
            SELECT typ.BuildingSpaceTypeID,typ.BuildingSpaceTypeCode,typ.BuildingSpaceTypeName_A,
                   sc.SpaceCount,rule_.AverageDailyConsumption,rule_.UsageFactor,rule_.UnitPrice,rule_.UnitCode,
                   CAST(CASE WHEN @TaxApplicable=1 AND @TaxInclusive=1
                           THEN raw_.RawAmount/(1+ISNULL(@TaxRatePercent,0)/100.0)
                           ELSE raw_.RawAmount END AS DECIMAL(18,2)),
                   CAST(CASE WHEN @TaxApplicable=0 THEN 0
                           WHEN @TaxInclusive=1 THEN raw_.RawAmount-raw_.RawAmount/(1+ISNULL(@TaxRatePercent,0)/100.0)
                           ELSE raw_.RawAmount*@TaxRatePercent/100.0 END AS DECIMAL(18,2)),
                   CAST(CASE WHEN @TaxApplicable=1 AND @TaxInclusive=0
                           THEN raw_.RawAmount*(1+@TaxRatePercent/100.0)
                           ELSE raw_.RawAmount END AS DECIMAL(18,2))
            FROM SpaceCounts sc
            JOIN Housing.BuildingSpaceType typ
              ON typ.BuildingSpaceTypeID=sc.BuildingSpaceTypeID_FK AND typ.BuildingSpaceTypeActive=1
            JOIN Housing.EstimatedBillingPolicyDetails rule_
              ON rule_.EstimatedBillingPolicyID_FK=@PolicyID
             AND rule_.MeterServiceTypeID_FK=@ServiceID
             AND rule_.BuildingSpaceTypeID_FK=sc.BuildingSpaceTypeID_FK
             AND rule_.EstimatedBillingPolicyDetailsActive=1
            CROSS APPLY
            (SELECT CAST(sc.SpaceCount*rule_.AverageDailyConsumption*rule_.UsageFactor
                        *rule_.UnitPrice*@BillingDays AS DECIMAL(18,6)) AS RawAmount) raw_;
            IF NOT EXISTS(SELECT 1 FROM #SpaceAmounts)
               THROW 50001,N'لا توجد فراغات مؤهلة للفاتورة التاريخية.',1;
            SELECT @BeforeTax=SUM(BeforeTax),@TaxAmount=SUM(Tax),@TotalPrice=SUM(Total)
            FROM #SpaceAmounts;
          END
          ELSE
          BEGIN
            SET @BeforeTax=CAST(@FixedAmount*@BillingDays/30.0 AS DECIMAL(18,2));
            SET @TaxAmount=CASE WHEN @TaxApplicable=1 THEN
                          CAST(@BeforeTax*@TaxRatePercent/100.0 AS DECIMAL(18,2)) ELSE 0 END;
            SET @TotalPrice=@BeforeTax+@TaxAmount;
          END;
          IF @TotalPrice IS NULL OR @TotalPrice<=0
              THROW 50001,N'مبلغ الفاتورة التاريخية غير صالح.',1;
          SET @PeriodID=NULL;
          SELECT TOP(1) @PeriodID=p.billPeriodID
          FROM Housing.BillPeriodType bt JOIN Housing.BillPeriod p
            ON p.billPeriodTypeID_FK=bt.billPeriodTypeID AND p.IdaraId_FK=@IdaraID
          WHERE bt.meterServiceTypeID_FK=@ServiceID
            AND p.billPeriodStartDate<=@SegmentStart AND p.billPeriodEndDate>=@SegmentEnd
          ORDER BY p.billPeriodID DESC;

          -- Idempotency with shared row-range locks: no duplicate for any day.
          IF EXISTS
          (
            SELECT 1 FROM Housing.Bills b WITH (UPDLOCK,HOLDLOCK)
            LEFT JOIN Housing.BillChargeType ct ON ct.BillChargeTypeID=b.BillChargeTypeID_FK
            WHERE b.residentInfoID_FK=@ResidentInfoID AND b.buildingDetailsID=@BuildingDetailsID
              AND b.idaraID_FK=@IdaraID AND b.BillActive=1
              AND b.BillChargeTypeID_FK IN (2,3,4)
              AND COALESCE(b.meterServiceTypeID,ct.MeterServiceTypeID_FK)=@ServiceID
              AND CONVERT(DATE,b.BillsFromDate)<=@SegmentEnd
              AND CONVERT(DATE,b.BillsToDate)>=@SegmentStart
          ) THROW 50001,N'توجد فاتورة متداخلة مع الفترة المستهدفة؛ تم إيقاف الإصدار.',1;

          INSERT INTO Housing.Bills
          (BillsUID,BillChargeTypeID_FK,BillTypeID_FK,CurrentPeriodID,PeriodMonth,PeriodYear,
           CurrentPeriodTax,meterNo,meterID,meterName_A,buildingDetailsNo,buildingUtilityTypeID,
           buildingDetailsID,meterTypeID,meterServiceTypeID,residentInfoID_FK,generalNo_FK,
           CurrentRead,LastRead,ReadDiff,PRICE,PRICETAX,meterServicePrice,meterServicePriceTAX,
           TotalPrice,BillsFromDate,BillsToDate,BillActive,idaraID_FK,entryData,hostName,ExitRequestActionID_FK)
          VALUES
          (NEWID(),@ChargeTypeID,2,@PeriodID,MONTH(@SegmentStart),YEAR(@SegmentStart),
           ISNULL(@TaxRatePercent,0),NULL,NULL,NULL,@BuildingNo,@UtilityTypeID,
           @BuildingDetailsID,NULL,@ServiceID,@ResidentInfoID,@GeneralNo,
           0,0,0,@BeforeTax,@TaxAmount,0,0,@TotalPrice,@SegmentStart,@SegmentEnd,
           1,@IdaraID,@EntryData,@HostName,NULL);
          SET @BillID=SCOPE_IDENTITY();
          INSERT INTO Housing.BillCalculation
          (BillsID_FK,CalculationMethod,EstimatedBillingPolicyID_FK,BillingDays,TaxApplicable,TaxInclusive,
           TaxID_FK,TaxRate,AmountBeforeTax,TaxAmount,TotalAmount,CalculationReason,entryData,hostName)
          VALUES
          (@BillID,@Method,@PolicyID,@BillingDays,@TaxApplicable,@TaxInclusive,
           CASE WHEN @TaxApplicable=1 THEN @TaxID ELSE NULL END,
           CASE WHEN @TaxApplicable=1 THEN @TaxRatePercent/100.0 ELSE 0 END,
           @BeforeTax,@TaxAmount,@TotalPrice,
           CONCAT(N'استكمال فاتورة خدمة تاريخية قبل الإخلاء؛ الدورة ',@ExitRequestActionID),@EntryData,@HostName);
          SET @CalculationID=SCOPE_IDENTITY();
          IF @Method=N'SPACE_ESTIMATED'
          BEGIN
            INSERT INTO Housing.BillCalculationDetails
            (BillCalculationID_FK,BuildingSpaceTypeID_FK,SpaceTypeCode,SpaceTypeName_A,SpaceCount,
             AverageDailyConsumption,UsageFactor,UnitPrice,UnitCode,BillingDays,
             AmountBeforeTax,TaxAmount,TotalAmount,entryData,hostName)
            SELECT @CalculationID,BuildingSpaceTypeID,SpaceCode,SpaceName,SpaceCount,
                   AverageConsumption,UsageFactor,UnitPrice,UnitCode,@BillingDays,
                   BeforeTax,Tax,Total,@EntryData,@HostName FROM #SpaceAmounts;
          END;
          INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,PerformedBy,Notes)
          VALUES (N'[Housing].[Bills]',N'GENERATEHISTORICALSERVICEBILL',@BillID,@EntryData,
                  CONCAT(N'Exit54=',@ExitRequestActionID,N'; Service=',@ServiceID,
                         N'; From=',CONVERT(NVARCHAR(10),@SegmentStart,23),
                         N'; To=',CONVERT(NVARCHAR(10),@SegmentEnd,23)));
          INSERT INTO #NewBills VALUES(@BillID,@ServiceID,@SegmentStart,@SegmentEnd,@Method);
        END;
        IF @ReturnResult=1 SELECT BillsID,ServiceID,SegmentStart,SegmentEnd,Method FROM #NewBills ORDER BY SegmentStart,ServiceID;
        IF @InitialTransactionCount=0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @InitialTransactionCount=0 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;