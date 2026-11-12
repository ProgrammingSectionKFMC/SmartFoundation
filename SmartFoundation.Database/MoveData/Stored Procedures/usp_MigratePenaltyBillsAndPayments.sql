CREATE PROCEDURE [MoveData].[usp_MigratePenaltyBillsAndPayments]
    @IdaraId bigint,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=1)
        THROW 57990, N'إدارة الترحيل الافتراضية غير موجودة.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID=@IdaraId)
        SET @IdaraId=1;
    IF @IdaraId NOT BETWEEN 0 AND 2147483647
        THROW 56501, N'معرف الإدارة غير صالح لحقول السداد.', 1;

    /* Do not ignore malformed paid source penalties merely because the owner
       is not migrated. They must still be retained. */
    IF EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.OccupantCustodyAction c
        WHERE c.Paid=1 AND
        (
            c.occupantCustodyActionPenalty IS NULL
            OR c.occupantCustodyActionPenalty<=0
        )
    )
        THROW 56503, N'توجد غرامات مدفوعة بمبلغ غير صالح؛ يلزم تصحيح المصدر قبل ترحيلها.', 1;
    IF EXISTS
    (
        SELECT 1
        FROM KFMC.Housing.OccupantCustodyAction c
        WHERE c.Paid=1 AND
        (
            c.PaidPaymentType IS NULL
            OR TRY_CONVERT(datetime2(3),RIGHT(c.PaidBy,23),121) IS NULL
        )
    )
        THROW 56504, N'توجد غرامات مدفوعة بدون نوع سداد أو تاريخ قابل للتحويل؛ لن يتم إسقاطها.', 1;

    DECLARE @BillsInserted bigint=0,
            @SettlementListsInserted bigint=0,
            @PaymentsInserted bigint=0,
            @ProtectedPaymentsInserted bigint=0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* For billing, keep the existing eligibility rule: only an action
           belonging to an active migrated resident receives a personal bill. */
        IF EXISTS
        (
            SELECT 1
            FROM KFMC.Housing.OccupantCustodyAction c
            JOIN KFMC.Housing.BuildingAction sa
              ON sa.buildingActionID=c.buildingActionID_FK
            JOIN KFMC.Housing.ResidentInfo sr
              ON sr.generalNo=sa.generalNo_FK AND sr.residentInfoActive=1
            JOIN Housing.ResidentInfo tr
              ON tr.residentInfoID=TRY_CONVERT(bigint,sr.residentInfoID)
             AND tr.residentInfoActive=1
            LEFT JOIN Housing.BuildingAction ta
              ON ta.buildingActionID=TRY_CONVERT(bigint,c.buildingActionID_FK)
             AND ta.residentInfoID_FK=tr.residentInfoID
            WHERE ta.buildingActionID IS NULL
        )
            THROW 56502, N'إجراء الإسكان الخاص بمستفيد مؤهل غير موجود؛ يجب إتمام المرحلة السابعة.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM KFMC.Housing.OccupantCustodyAction c
            JOIN Housing.BuildingAction a
              ON a.buildingActionID=TRY_CONVERT(bigint,c.buildingActionID_FK)
            JOIN Housing.ResidentInfo r
              ON r.residentInfoID=a.residentInfoID_FK AND r.residentInfoActive=1
            WHERE c.occupantCustodyActionPenalty IS NULL
               OR c.occupantCustodyActionPenalty<=0
        )
            THROW 56505, N'غرامة شخصية لمستفيد منقول بمبلغ غير صالح.', 1;

        INSERT INTO Housing.Bills
        (
            BillsUID,BillChargeTypeID_FK,BillTypeID_FK,PeriodMonth,PeriodYear,
            buildingDetailsNo,buildingDetailsID,residentInfoID_FK,generalNo_FK,
            PRICE,PRICETAX,TotalPrice,BillsFromDate,BillsToDate,PenaltyReason,
            BillActive,CanceledBy,idaraID_FK,entryDate,entryData,hostName
        )
        SELECT
            CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-BILL|',c.occupantCustodyActionID))),
            5,3,MONTH(c.entryDate),YEAR(c.entryDate),a.buildingDetailsNo,
            CONVERT(int,a.buildingDetailsID_FK),a.residentInfoID_FK,a.generalNo_FK,
            c.occupantCustodyActionPenalty,0,c.occupantCustodyActionPenalty,
            c.entryDate,c.entryDate,c.occupantCustodyActionNote,
            c.occupantCustodyActionActive,c.canceldBy,@IdaraId,
            c.entryDate,MoveData.fn_MapEntryData(c.entryData),
            MoveData.fn_MapHostName(c.hostName,c.entryData)
        FROM KFMC.Housing.OccupantCustodyAction c
        JOIN Housing.BuildingAction a
          ON a.buildingActionID=TRY_CONVERT(bigint,c.buildingActionID_FK)
        JOIN Housing.ResidentInfo r
          ON r.residentInfoID=a.residentInfoID_FK AND r.residentInfoActive=1
        WHERE NOT EXISTS
        (
            SELECT 1 FROM Housing.Bills b
            WHERE b.BillsUID=CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-BILL|',c.occupantCustodyActionID)))
        );
        SET @BillsInserted=@@ROWCOUNT;

        /* Source paid penalties, regardless of beneficiary migration eligibility. */
        SELECT
            c.occupantCustodyActionID AS CustodyID,
            c.PaidPaymentType AS PaymentTypeID,
            TRY_CONVERT(datetime2(3),RIGHT(c.PaidBy,23),121) AS PaidDate,
            c.occupantCustodyActionPenalty AS Amount,
            c.occupantCustodyActionActive AS CustodyActive,
            c.PaidNumber AS PaidNumber,
            c.entryDate AS SourceEntryDate,
            c.entryData AS SourceEntryData,
            c.hostName AS SourceHostName,
            sa.generalNo_FK AS OriginalGeneralNo,
            ta.buildingDetailsID_FK AS BuildingID,
            eligible.residentInfoID AS EligibleResidentID,
            eligible.NationalID AS EligibleNationalID,
            CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-PAYMENT|',c.occupantCustodyActionID))) AS PaymentUID
        INTO #PaidPenalties
        FROM KFMC.Housing.OccupantCustodyAction c
        LEFT JOIN KFMC.Housing.BuildingAction sa
          ON sa.buildingActionID=c.buildingActionID_FK
        LEFT JOIN Housing.BuildingAction ta
          ON ta.buildingActionID=TRY_CONVERT(bigint,c.buildingActionID_FK)
        OUTER APPLY
        (
            SELECT TOP (1) tr.residentInfoID,tr.NationalID
            FROM KFMC.Housing.ResidentInfo sr
            JOIN Housing.ResidentInfo tr
              ON tr.residentInfoID=TRY_CONVERT(bigint,sr.residentInfoID)
             AND tr.residentInfoActive=1
            WHERE sr.generalNo=sa.generalNo_FK
              AND sr.residentInfoActive=1
              AND tr.residentInfoID=ta.residentInfoID_FK
            ORDER BY tr.residentInfoID
        ) eligible
        WHERE c.Paid=1;

        CREATE UNIQUE CLUSTERED INDEX UX_PaidPenalties_CustodyID ON #PaidPenalties(CustodyID);

        /* One settlement list for each distinct type + payment month; includes
           protected (inactive) payments so no historical payment disappears. */
        ;WITH Groups AS
        (
            SELECT p.*,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY YEAR(p.PaidDate),MONTH(p.PaidDate),p.PaymentTypeID
                       ORDER BY p.CustodyID
                   ) AS rn
            FROM #PaidPenalties p
        )
        INSERT INTO Housing.DeductList
        (
            deductTypeID_FK,deductUID,deductName,paymentTypeID_FK,
            issueMonth,issueYear,paymentDate,description,deductActive,
            BillChargeTypeID_FK,IdaraId_FK,entryDate,entryData,hostName
        )
        SELECT
            6,
            CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-LIST|',YEAR(p.PaidDate),N'|',MONTH(p.PaidDate),N'|',p.PaymentTypeID))),
            CONCAT(N'تسوية افتتاحية لسداد الغرامات - ',YEAR(p.PaidDate),N'/',
                RIGHT(N'0'+CONVERT(nvarchar(2),MONTH(p.PaidDate)),2),N' - طريقة ',p.PaymentTypeID),
            p.PaymentTypeID,MONTH(p.PaidDate),YEAR(p.PaidDate),
            DATEFROMPARTS(YEAR(p.PaidDate),MONTH(p.PaidDate),1),
            N'مسير حفظ السدادات التاريخية للغرامات',1,5,@IdaraId,
            p.SourceEntryDate,MoveData.fn_MapEntryData(p.SourceEntryData),
            MoveData.fn_MapHostName(p.SourceHostName,p.SourceEntryData)
        FROM Groups p
        WHERE p.rn=1
          AND NOT EXISTS
          (
              SELECT 1 FROM Housing.DeductList d
              WHERE d.deductUID=CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-LIST|',YEAR(p.PaidDate),N'|',MONTH(p.PaidDate),N'|',p.PaymentTypeID)))
          );
        SET @SettlementListsInserted=@@ROWCOUNT;

        DECLARE @NewPayments TABLE(PaymentID bigint PRIMARY KEY);
        INSERT INTO Housing.BuildingPayment
        (
            PaymentUID,buildingPaymentTypeID_FK,generalNo_FK,IDNumber,residentInfoID_FK,
            buildingDetailsID_FK,amount,deductListID_FK,buildingPayementActive,
            BillChargeTypeID_FK,IdaraId_FK,entryDate,entryData,hostName,
            buildingPaymentLinkStatusID_FK,paymentLinkNote,disactiveReason
        )
        OUTPUT inserted.paymentID INTO @NewPayments(PaymentID)
        SELECT
            p.PaymentUID,p.PaymentTypeID,TRY_CONVERT(bigint,p.OriginalGeneralNo),
            p.EligibleNationalID,p.EligibleResidentID,
            CONVERT(nvarchar(400),p.BuildingID),p.Amount,d.deductListID,
            CONVERT(bit,CASE WHEN p.EligibleResidentID IS NOT NULL
                                  AND ISNULL(p.CustodyActive,0)=1
                             THEN 1 ELSE 0 END),
            5,CONVERT(int,@IdaraId),p.SourceEntryDate,
            MoveData.fn_MapEntryData(p.SourceEntryData),
            MoveData.fn_MapHostName(p.SourceHostName,p.SourceEntryData),
            CASE WHEN p.EligibleResidentID IS NULL THEN 3 WHEN p.BuildingID IS NOT NULL THEN 1 ELSE 2 END,
            CONCAT(N'سداد غرامة تاريخية؛ رقم إجراء العهدة ',p.CustodyID,
                   CASE WHEN NULLIF(p.PaidNumber,N'') IS NULL
                        THEN N'' ELSE CONCAT(N'; رقم السداد ',p.PaidNumber) END),
            CASE
                WHEN p.EligibleResidentID IS NULL
                    THEN N'تم تعطيل السداد لعدم وجود مستفيد نشط مؤهل مرتبط بالحركة التاريخية.'
                WHEN ISNULL(p.CustodyActive,0)<>1
                    THEN N'تم تعطيل السداد لأن إجراء العهدة التاريخي غير نشط.'
                ELSE NULL
            END
        FROM #PaidPenalties p
        JOIN Housing.DeductList d
          ON d.deductUID=CONVERT(uniqueidentifier,HASHBYTES('MD5',CONCAT(N'PENALTY-LIST|',YEAR(p.PaidDate),N'|',MONTH(p.PaidDate),N'|',p.PaymentTypeID)))
        WHERE NOT EXISTS
        (
            SELECT 1 FROM Housing.BuildingPayment t WHERE t.PaymentUID=p.PaymentUID
        );
        SET @PaymentsInserted=@@ROWCOUNT;
        /* MIGRATION_PENALTY_PROVENANCE_GUARD_V1 */
        IF EXISTS (
           SELECT 1 FROM #PaidPenalties sp
           JOIN Housing.BuildingPayment tp ON tp.PaymentUID=sp.PaymentUID
           WHERE tp.buildingPayementActive=1
             AND (tp.buildingPaymentLinkStatusID_FK<>1 OR sp.BuildingID IS NULL
                  OR TRY_CONVERT(bigint,tp.buildingDetailsID_FK) IS NULL
                  OR TRY_CONVERT(bigint,tp.buildingDetailsID_FK)<>TRY_CONVERT(bigint,sp.BuildingID)
                  OR tp.paymentLinkNote NOT LIKE N'سداد غرامة تاريخية؛ رقم إجراء العهدة %')
        ) THROW 56507,N'Penalty payment did not preserve source building/status 1/note.',1;


        /* Every paid source row must have a corresponding preserved target row,
           whether active or protected/inactive. */
        IF EXISTS
        (
            SELECT 1
            FROM #PaidPenalties p
            LEFT JOIN Housing.BuildingPayment t ON t.PaymentUID=p.PaymentUID
            WHERE t.paymentID IS NULL
               OR EXISTS
               (
                   SELECT t.amount,t.generalNo_FK,t.residentInfoID_FK,
                          t.BillChargeTypeID_FK,t.buildingPayementActive
                   EXCEPT
                   SELECT p.Amount,TRY_CONVERT(bigint,p.OriginalGeneralNo),
                          p.EligibleResidentID,CONVERT(int,5),
                          CONVERT(bit,CASE WHEN p.EligibleResidentID IS NOT NULL
                                                AND ISNULL(p.CustodyActive,0)=1
                                           THEN 1 ELSE 0 END)
               )
               OR (t.buildingPayementActive=0 AND
                   NULLIF(LTRIM(RTRIM(t.disactiveReason)),N'') IS NULL)
        )
            THROW 56506,N'فشل التحقق: يوجد سداد غرامة تاريخي مفقود أو غير مطابق لحالته الأصلية.',1;

        INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,PerformedBy,Notes)
        SELECT N'[Housing].[BuildingPayment]',N'MIGRATION_PAYMENT_PROTECTED',
               t.paymentID,N'MoveData',
               CONCAT(N'PaymentID=',t.paymentID,
                      N'; DeductListID=',COALESCE(CONVERT(nvarchar(40),t.deductListID_FK),N'NULL'),
                      N'; Reason=',t.disactiveReason)
        FROM @NewPayments np
        JOIN Housing.BuildingPayment t ON t.paymentID=np.PaymentID
        WHERE t.buildingPayementActive=0;
        SET @ProtectedPaymentsInserted=@@ROWCOUNT;

        SELECT @RollbackAfterTest AS RollbackAfterTest,
               @BillsInserted AS PenaltyBillsInserted,
               @SettlementListsInserted AS PenaltySettlementListsInserted,
               @PaymentsInserted AS PenaltyPaymentsInserted,
               @ProtectedPaymentsInserted AS ProtectedPenaltyPaymentsInserted,
               (SELECT COUNT_BIG(*) FROM #PaidPenalties) AS SourcePaidPenaltyRows,
               (SELECT COUNT_BIG(*) FROM #PaidPenalties p
                JOIN Housing.BuildingPayment t ON t.PaymentUID=p.PaymentUID) AS MatchedPaidPenaltyRows;

        IF @RollbackAfterTest=1 ROLLBACK TRANSACTION;
        ELSE COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;