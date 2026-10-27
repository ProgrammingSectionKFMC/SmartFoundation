CREATE   PROCEDURE [Housing].[ExitMeterBillProrationSP]
      @Action                  NVARCHAR(20)
    , @ExitRequestActionID     BIGINT
    , @OriginalBillsID         BIGINT
    , @ExitDate                DATE = NULL
    , @EntryData               NVARCHAR(20) = NULL
    , @HostName                NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartingTranCount INT = @@TRANCOUNT;
    DECLARE @OwnTran BIT = CASE WHEN @StartingTranCount = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        IF @Action NOT IN (N'PREVIEW', N'GENERATE', N'REGENERATE', N'CANCEL')
            OR @Action IS NULL
            THROW 50001, N'عملية توزيع فاتورة الإخلاء غير صحيحة.', 1;

        IF @ExitRequestActionID IS NULL OR @OriginalBillsID IS NULL
            THROW 50001, N'يجب تحديد دورة الإخلاء والفاتورة الأصلية.', 1;

        IF @Action <> N'CANCEL' AND @ExitDate IS NULL
            THROW 50001, N'تاريخ الإخلاء مطلوب.', 1;

        IF @ExitDate IS NOT NULL AND @ExitDate > CONVERT(DATE, GETDATE())
            THROW 50001, N'لا يمكن تصحيح فاتورة بإخلاء مستقبلي.', 1;

        IF @Action <> N'PREVIEW'
           AND NULLIF(LTRIM(RTRIM(@EntryData)),N'') IS NULL
            THROW 50001, N'هوية منفذ التصحيح مطلوبة.', 1;

        IF @OwnTran = 1 BEGIN TRANSACTION;

        DECLARE
              @ResidentInfoID BIGINT
            , @GeneralNo BIGINT
            , @BuildingDetailsID BIGINT
            , @IdaraID BIGINT
            , @MeterID BIGINT
            , @MeterReadID INT
            , @MeterServiceTypeID INT
            , @BillTypeID INT
            , @BillChargeTypeID INT
            , @OriginalActive BIT
            , @OriginalCanceledBy NVARCHAR(200)
            , @PeriodFrom DATE
            , @PeriodTo DATE
            , @OriginalTotal DECIMAL(18,2)
            , @Price DECIMAL(18,2)
            , @PriceTax DECIMAL(18,2)
            , @ServicePrice DECIMAL(18,2)
            , @ServicePriceTax DECIMAL(18,2);

        -- Consistent lock order with HousingExitSP: occupancy lock BEFORE bill rows.
        DECLARE @LockIdara BIGINT, @LockBuilding BIGINT;
        SELECT @LockIdara = b.idaraID_FK, @LockBuilding = b.buildingDetailsID
        FROM Housing.Bills b
        WHERE b.BillsID = @OriginalBillsID;
        IF @LockIdara IS NULL OR @LockBuilding IS NULL
            THROW 50001, N'الفاتورة الأصلية أو نطاقها غير موجود.', 1;

        DECLARE @LockResult INT, @LockResource NVARCHAR(255) =
            CONCAT(N'Housing.Occupancy:', @LockIdara, N':', @LockBuilding);
        EXEC @LockResult = sys.sp_getapplock
              @Resource = @LockResource
            , @LockMode = N'Exclusive'
            , @LockOwner = N'Transaction'
            , @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 50001, N'تعذر حجز المسكن لتصحيح الفاتورة.', 1;

        DECLARE @RegisteredOccupentDate DATE = NULL;

        SELECT
              @ResidentInfoID = b.residentInfoID_FK
            , @GeneralNo = b.generalNo_FK
            , @BuildingDetailsID = b.buildingDetailsID
            , @IdaraID = b.idaraID_FK
            , @MeterID = b.meterID
            , @MeterReadID = b.meterReadID
            , @MeterServiceTypeID = b.meterServiceTypeID
            , @BillTypeID = b.BillTypeID_FK
            , @BillChargeTypeID = b.BillChargeTypeID_FK
            , @OriginalActive = b.BillActive
            , @OriginalCanceledBy = b.CanceledBy
            , @PeriodFrom = TRY_CONVERT(DATE, b.BillsFromDate)
            , @PeriodTo = TRY_CONVERT(DATE, b.BillsToDate)
            , @OriginalTotal = TRY_CONVERT(DECIMAL(18,2), b.TotalPrice)
            , @Price = TRY_CONVERT(DECIMAL(18,2), b.PRICE)
            , @PriceTax = TRY_CONVERT(DECIMAL(18,2), b.PRICETAX)
            , @ServicePrice = TRY_CONVERT(DECIMAL(18,2), b.meterServicePrice)
            , @ServicePriceTax = TRY_CONVERT(DECIMAL(18,2), b.meterServicePriceTAX)
        FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.BillsID = @OriginalBillsID
          AND b.ParentBillsID_FK IS NULL;

        IF @IdaraID <> @LockIdara OR @BuildingDetailsID <> @LockBuilding
            THROW 50001, N'نطاق الفاتورة تغير أثناء طلب التصحيح.', 1;

        IF @ResidentInfoID IS NULL OR @GeneralNo IS NULL
           OR @BuildingDetailsID IS NULL OR @IdaraID IS NULL
           OR @MeterID IS NULL OR @MeterReadID IS NULL
           OR @MeterServiceTypeID IS NULL
           OR @BillTypeID <> 2 OR @BillChargeTypeID <> 2
           OR @PeriodFrom IS NULL OR @PeriodTo IS NULL
           OR @PeriodFrom > @PeriodTo OR @OriginalTotal IS NULL
            THROW 50001, N'الفاتورة ليست فاتورة عداد شهرية أصلية مؤهلة للتصحيح.', 1;

        IF @OriginalTotal < 0 OR @Price IS NULL OR @PriceTax IS NULL
           OR @ServicePrice IS NULL OR @ServicePriceTax IS NULL
           OR @Price < 0 OR @PriceTax < 0 OR @ServicePrice < 0 OR @ServicePriceTax < 0
           OR @OriginalTotal <> @Price + @PriceTax + @ServicePrice + @ServicePriceTax
            THROW 50001, N'مكونات المبلغ الأصلي غير متطابقة؛ يلزم مراجعة الفاتورة قبل تقسيمها.', 1;

        IF NOT EXISTS
        (
            SELECT 1 FROM Housing.MeterRead r
            WHERE r.meterReadID = @MeterReadID AND r.meterID_FK = @MeterID
              AND r.meterReadActive = 1
        )
            THROW 50001, N'القراءة الأصلية غير نشطة أو لا تطابق العداد.', 1;

        -- Only enrolled exit cycles; never touch legacy exits outside the registered scope.
        SELECT @RegisteredOccupentDate = CONVERT(DATE,a.OccupentDate)
        FROM Housing.ExitFinancialProcessingCycle c WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN Housing.BuildingAction a WITH (UPDLOCK, HOLDLOCK)
            ON a.buildingActionID = c.ExitRequestActionID_FK
        WHERE c.ExitRequestActionID_FK = @ExitRequestActionID
          AND c.ProcessingVersion = 1
          AND a.buildingActionTypeID_FK = 54
          AND a.buildingActionActive = 1
          AND a.residentInfoID_FK = @ResidentInfoID
          AND a.generalNo_FK = @GeneralNo
          AND a.buildingDetailsID_FK = @BuildingDetailsID
          AND a.IdaraId_FK = @IdaraID;
        -- A monthly invoice may include days before the original occupancy.
        -- Those days are NOT assigned to the tenant (three-way proration).
        IF @RegisteredOccupentDate IS NULL OR @PeriodTo < @RegisteredOccupentDate
            THROW 50001, N'تاريخ سكن المستفيد لا يتداخل مع فترة الفاتورة الأصلية.', 1;
        IF @Action <> N'CANCEL' AND @ExitDate < @RegisteredOccupentDate
            THROW 50001, N'لا يمكن أن يسبق تاريخ الإخلاء تاريخ السكن.', 1;

        -- Match BOTH the current effective exit date and the exact request-54
        -- ancestor. A caller cannot bypass the approved date using raw EXEC.
        IF NOT EXISTS
        (
            SELECT 1
            FROM Housing.V_WaitingList w
            WHERE w.residentInfoID = @ResidentInfoID
              AND w.buildingDetailsID = @BuildingDetailsID
              AND w.IdaraId = @IdaraID
              AND w.LastActionTypeID IN (54, 59, 60, 57, 58)
              AND (@Action = N'CANCEL' OR CONVERT(DATE,w.ExitDate) = @ExitDate)
              AND EXISTS
              (
                  SELECT 1 FROM Housing.fn_BuildingAction_ChainToRoot(
                      TRY_CONVERT(BIGINT,w.LastActionID)) chain
                  WHERE chain.buildingActionID = @ExitRequestActionID
                    AND chain.buildingActionTypeID_FK = 54
                    AND chain.buildingActionActive = 1
              )
        )
            THROW 50001, N'الدورة أو تاريخ الإخلاء لا يطابقان الحالة التشغيلية الحالية.', 1;

        DECLARE @ActiveProrationID BIGINT = NULL,
                @OldResidentBillID BIGINT = NULL,
                @OldVacantBillID BIGINT = NULL,
                @OldPreBillID BIGINT = NULL;

        SELECT
              @ActiveProrationID = p.ProrationID
            , @OldResidentBillID = p.ResidentBillsID_FK
            , @OldVacantBillID = p.VacantBillsID_FK
            , @OldPreBillID = p.PreOccupancyBillsID_FK
        FROM Housing.ExitMeterBillProration p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.OriginalBillsID_FK = @OriginalBillsID
          AND p.ExitRequestActionID_FK = @ExitRequestActionID
          AND p.CorrectionStatus = 1;

        IF EXISTS
        (
            SELECT 1 FROM Housing.ExitMeterBillProration p WITH (UPDLOCK, HOLDLOCK)
            WHERE p.OriginalBillsID_FK = @OriginalBillsID
              AND p.CorrectionStatus = 1
              AND p.ExitRequestActionID_FK <> @ExitRequestActionID
        )
            THROW 50001, N'الفاتورة الأصلية مرتبطة بتصحيح نشط لدورة إخلاء أخرى.', 1;

        IF @Action IN (N'PREVIEW', N'GENERATE', N'REGENERATE')
        BEGIN
            -- Do not allocate a subsequent tenant's occupancy as vacant days.
            IF @ExitDate < @PeriodTo AND EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction laterOccupancy
                WHERE laterOccupancy.buildingActionActive = 1
                  AND laterOccupancy.buildingActionTypeID_FK = 2
                  AND laterOccupancy.buildingDetailsID_FK = @BuildingDetailsID
                  AND laterOccupancy.IdaraId_FK = @IdaraID
                  AND laterOccupancy.residentInfoID_FK <> @ResidentInfoID
                  AND TRY_CONVERT(DATE, laterOccupancy.OccupentDate) > @ExitDate
                  AND TRY_CONVERT(DATE, laterOccupancy.OccupentDate) <= @PeriodTo
            )
                THROW 50001, N'يوجد إشغال آخر أثناء الفترة؛ لا يمكن نسبتها بالكامل إلى الشغور.', 1;
        END;

        DECLARE @TotalDays INT = DATEDIFF(DAY, @PeriodFrom, @PeriodTo) + 1;
        DECLARE @PreDays INT = CASE
            WHEN @PeriodFrom < @RegisteredOccupentDate
              THEN DATEDIFF(DAY,@PeriodFrom,@RegisteredOccupentDate)
            ELSE 0 END;
        DECLARE @ResidentStart DATE = CASE
            WHEN @PeriodFrom > @RegisteredOccupentDate THEN @PeriodFrom
            ELSE @RegisteredOccupentDate END;
        DECLARE @ResidentEnd DATE = CASE
            WHEN @ExitDate IS NULL OR @ExitDate > @PeriodTo THEN @PeriodTo
            ELSE @ExitDate END;
        DECLARE @ResidentDays INT = CASE
            WHEN @Action = N'CANCEL' THEN 0
            WHEN @ResidentEnd < @ResidentStart THEN 0
            ELSE DATEDIFF(DAY,@ResidentStart,@ResidentEnd)+1 END;
        DECLARE @PostDays INT = @TotalDays-@PreDays-@ResidentDays;
        DECLARE @VacantDays INT = @TotalDays-@ResidentDays;
        IF @PreDays<0 OR @ResidentDays<0 OR @PostDays<0
            THROW 50001,N'توزيع الأيام غير صحيح.',1;

        IF @Action = N'PREVIEW'
        BEGIN
            SELECT
                  @OriginalBillsID AS OriginalBillsID
                , @OriginalTotal AS OriginalAmount
                , @PeriodFrom AS PeriodFrom
                , @PeriodTo AS PeriodTo
                , @ExitDate AS ExitDate
                , @TotalDays AS TotalDays
                , @PreDays AS PreOccupancyDays
                , @ResidentDays AS ResidentDays
                , @PostDays AS PostExitDays
                , @VacantDays AS VacantDays
                , CAST(ROUND(@OriginalTotal * @ResidentDays /
                       CONVERT(DECIMAL(18,6), @TotalDays), 2) AS DECIMAL(18,2)) AS ResidentAmount
                , CAST(@OriginalTotal - CAST(ROUND(@OriginalTotal * @ResidentDays /
                       CONVERT(DECIMAL(18,6), @TotalDays), 2) AS DECIMAL(18,2)) AS DECIMAL(18,2)) AS VacantAmount
                , CASE WHEN @PostDays=0 THEN
                        @OriginalTotal-CAST(ROUND(@OriginalTotal*@ResidentDays/
                             CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2))
                       ELSE CAST(ROUND(@OriginalTotal*@PreDays/
                             CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2))
                  END AS PreOccupancyAmount
                , @ActiveProrationID AS ActiveProrationID;
            IF @OwnTran = 1 COMMIT TRANSACTION;
            RETURN;
        END;

        IF @ActiveProrationID IS NULL AND @OriginalActive <> 1
            THROW 50001, N'الفاتورة الأصلية غير نشطة ولم نعثر على تصحيح نشط تابع للدورة.', 1;

        IF @ActiveProrationID IS NOT NULL
        BEGIN
            IF @OriginalActive <> 0 OR ISNULL(@OriginalCanceledBy,N'') <> N'EXIT_PRORATION'
                THROW 50001, N'حالة الفاتورة الأصلية تغيرت خارج محرك التصحيح.', 1;

            IF EXISTS
            (
                SELECT 1 FROM Housing.ExitMeterBillProration p
                LEFT JOIN Housing.Bills residentBill
                    ON residentBill.BillsID = p.ResidentBillsID_FK
                LEFT JOIN Housing.Bills vacantBill
                    ON vacantBill.BillsID = p.VacantBillsID_FK
                WHERE p.ProrationID = @ActiveProrationID
                  AND (
                       (p.ResidentBillsID_FK IS NOT NULL AND
                        (residentBill.BillsID IS NULL OR residentBill.BillActive <> 1
                         OR residentBill.ParentBillsID_FK <> @OriginalBillsID
                         OR residentBill.ExitRequestActionID_FK <> @ExitRequestActionID
                         OR residentBill.SplitType <> N'EXIT_RESIDENT'))
                    OR (p.VacantBillsID_FK IS NOT NULL AND
                        (vacantBill.BillsID IS NULL OR vacantBill.BillActive <> 1
                         OR vacantBill.ParentBillsID_FK <> @OriginalBillsID
                         OR vacantBill.ExitRequestActionID_FK <> @ExitRequestActionID
                         OR vacantBill.SplitType <> N'EXIT_VACANT'))
                    OR (p.PreOccupancyBillsID_FK IS NOT NULL AND NOT EXISTS
                        (SELECT 1 FROM Housing.Bills pre
                         WHERE pre.BillsID=p.PreOccupancyBillsID_FK
                           AND pre.BillActive=1
                           AND pre.ParentBillsID_FK=@OriginalBillsID
                           AND pre.ExitRequestActionID_FK=@ExitRequestActionID
                           AND pre.SplitType=N'EXIT_VACANT_BEFORE'))
                  )
            )
                THROW 50001, N'فواتير التصحيح السابقة تغيرت؛ يلزم مراجعتها.', 1;
        END;

        IF @Action = N'GENERATE' AND @ActiveProrationID IS NOT NULL
            THROW 50001, N'يوجد تصحيح نشط؛ استخدم REGENERATE بعد تعديل التاريخ.', 1;
        IF @Action = N'REGENERATE' AND @ActiveProrationID IS NULL
            THROW 50001,N'لا يوجد تصحيح نشط لإعادة إصداره؛ استخدم GENERATE.',1;
        -- Cancellation is idempotent: no correction means no invoice mutation.
        IF @Action = N'CANCEL' AND @ActiveProrationID IS NULL
        BEGIN
            IF @OriginalActive <> 1
                THROW 50001,N'الفاتورة الأصلية غير نشطة، ولا يوجد تصحيح لاستعادته.',1;
            IF @OwnTran = 1 COMMIT TRANSACTION;
            RETURN;
        END;

        -- Verify that no other active replacement / administrative bill overlaps the target gap.
        IF @Action <> N'CANCEL' AND @VacantDays > 0
        BEGIN
            DECLARE @VacantFrom DATE =
                CASE WHEN @ExitDate < @PeriodFrom THEN @PeriodFrom
                     ELSE DATEADD(DAY, 1, @ExitDate) END;
            DECLARE @PreTo DATE = DATEADD(DAY,-1,@RegisteredOccupentDate);
            IF EXISTS
            (
                SELECT 1 FROM Housing.Bills otherBill WITH (UPDLOCK, HOLDLOCK)
                WHERE otherBill.BillActive = 1
                  AND otherBill.BillsID <> @OriginalBillsID
                  AND otherBill.BillsID NOT IN
                      (ISNULL(@OldResidentBillID,-1), ISNULL(@OldVacantBillID,-1),ISNULL(@OldPreBillID,-1))
                  AND otherBill.meterID = @MeterID
                  AND otherBill.buildingDetailsID = @BuildingDetailsID
                  AND otherBill.idaraID_FK = @IdaraID
                  AND otherBill.BillChargeTypeID_FK = 2
                  AND otherBill.residentInfoID_FK IS NULL
                  AND
                  (
                      (otherBill.BillsFromDate IS NOT NULL AND otherBill.BillsToDate IS NOT NULL
                       AND (
                           (@PostDays>0 AND CONVERT(DATE,otherBill.BillsFromDate) <= @PeriodTo
                                    AND CONVERT(DATE,otherBill.BillsToDate) >= @VacantFrom)
                           OR (@PreDays>0 AND CONVERT(DATE,otherBill.BillsFromDate) <= @PreTo
                                    AND CONVERT(DATE,otherBill.BillsToDate) >= @PeriodFrom)))
                      OR (otherBill.PeriodYear = YEAR(@PeriodFrom)
                          AND otherBill.PeriodMonth = MONTH(@PeriodFrom)
                          AND (otherBill.BillsFromDate IS NULL OR otherBill.BillsToDate IS NULL))
                  )
            )
                THROW 50001, N'توجد فاتورة عداد للإدارة متداخلة مع فترة الشغور المقترحة.', 1;
        END;

        IF @Action IN (N'REGENERATE', N'CANCEL') AND @ActiveProrationID IS NOT NULL
        BEGIN
            UPDATE Housing.Bills
               SET BillActive = 0, CanceledBy = @EntryData,
                   CanceledDate = GETDATE()
            WHERE BillsID IN (ISNULL(@OldResidentBillID,-1), ISNULL(@OldVacantBillID,-1), ISNULL(@OldPreBillID,-1))
              AND BillActive = 1;

            UPDATE Housing.ExitMeterBillProration
               SET CorrectionStatus = CASE WHEN @Action = N'CANCEL' THEN 3 ELSE 2 END,
                   ClosedDate = SYSDATETIME(), ClosedBy = @EntryData
            WHERE ProrationID = @ActiveProrationID
              AND CorrectionStatus = 1;
            IF @@ROWCOUNT <> 1
                THROW 50001, N'فشل إغلاق إصدار التصحيح السابق.', 1;

            INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
            VALUES
            (
                N'[Housing].[ExitMeterBillProration]',
                CASE WHEN @Action = N'CANCEL' THEN N'CANCEL' ELSE N'SUPERSEDE' END,
                @ActiveProrationID, @EntryData,
                CONCAT(N'ExitRequestActionID=',@ExitRequestActionID,
                       N'; OriginalBill=',@OriginalBillsID)
            );
        END;

        IF @Action = N'CANCEL' OR @ResidentDays = @TotalDays
        BEGIN
            -- Restore only when no independently active reading bill overlaps
            -- this meter and monthly period; never duplicate a new tenant's charge.
            IF EXISTS
            (
                SELECT 1 FROM Housing.Bills otherBill WITH (UPDLOCK,HOLDLOCK)
                WHERE otherBill.BillActive = 1
                  AND otherBill.BillsID <> @OriginalBillsID
                  AND otherBill.meterID = @MeterID
                  AND otherBill.buildingDetailsID = @BuildingDetailsID
                  AND otherBill.idaraID_FK = @IdaraID
                  AND otherBill.BillChargeTypeID_FK = 2
                  AND otherBill.BillTypeID_FK = 2
                  AND (
                        (otherBill.BillsFromDate IS NOT NULL AND otherBill.BillsToDate IS NOT NULL
                         AND CONVERT(DATE,otherBill.BillsFromDate) <= @PeriodTo
                         AND CONVERT(DATE,otherBill.BillsToDate) >= @PeriodFrom)
                        OR (otherBill.PeriodYear = YEAR(@PeriodFrom)
                            AND otherBill.PeriodMonth = MONTH(@PeriodFrom)
                            AND (otherBill.BillsFromDate IS NULL OR otherBill.BillsToDate IS NULL))
                  )
            )
                THROW 50001, N'توجد فاتورة شهرية أخرى متداخلة؛ لا يمكن استعادة الأصلية.', 1;

            -- Before reactivating the original invoice, refuse unknown active derived bills.
            IF EXISTS
            (
                SELECT 1 FROM Housing.Bills child WITH (UPDLOCK, HOLDLOCK)
                WHERE child.ParentBillsID_FK = @OriginalBillsID
                  AND child.BillActive = 1
            )
                THROW 50001, N'لا يمكن إعادة الفاتورة الأصلية مع وجود فواتير فرعية نشطة.', 1;

            UPDATE Housing.Bills
               SET BillActive = 1, CanceledBy = NULL, CanceledDate = NULL
            WHERE BillsID = @OriginalBillsID
              AND (BillActive = 0 AND CanceledBy = N'EXIT_PRORATION' OR BillActive = 1);
            IF @@ROWCOUNT <> 1
                THROW 50001, N'تعذر استعادة الفاتورة الأصلية.', 1;

            IF @OwnTran = 1 COMMIT TRANSACTION;
            RETURN;
        END;

        -- Recheck for any unexpected active children before new issue.
        IF EXISTS
        (
            SELECT 1 FROM Housing.Bills child WITH (UPDLOCK,HOLDLOCK)
            WHERE child.ParentBillsID_FK = @OriginalBillsID
              AND child.BillActive = 1
        )
            THROW 50001, N'توجد فواتير مشتقة نشطة أخرى للفترة الأصلية.', 1;

        DECLARE @ResidentTotal DECIMAL(18,2) = CAST(ROUND(
            @OriginalTotal * @ResidentDays / CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @VacantTotal DECIMAL(18,2) = @OriginalTotal - @ResidentTotal;
        DECLARE @PreTotal DECIMAL(18,2) = CASE
            WHEN @PostDays=0 THEN @OriginalTotal-@ResidentTotal
            ELSE CAST(ROUND(@OriginalTotal*@PreDays/CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2))
        END;
        DECLARE @PostTotal DECIMAL(18,2) = @VacantTotal - @PreTotal;
        IF @PostTotal < 0 THROW 50001,N'قيمة الشغور بعد الإخلاء سالبة.',1;

        -- Distribute all monetary components, including meter service fees/taxes.
        -- The final consumption PRICE is the rounding residual, preserving exactly
        -- the approved gross amount and the original total of each component.
        DECLARE @RPriceTax DECIMAL(18,2) = CAST(ROUND(
            @PriceTax * @ResidentDays / CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @RServicePrice DECIMAL(18,2) = CAST(ROUND(
            @ServicePrice * @ResidentDays / CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @RServicePriceTax DECIMAL(18,2) = CAST(ROUND(
            @ServicePriceTax * @ResidentDays / CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @RPrice DECIMAL(18,2) = @ResidentTotal - @RPriceTax - @RServicePrice - @RServicePriceTax;

        DECLARE @PPriceTax DECIMAL(18,2)=CAST(ROUND(@PriceTax*@PreDays/CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @PServicePrice DECIMAL(18,2)=CAST(ROUND(@ServicePrice*@PreDays/CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        DECLARE @PServicePriceTax DECIMAL(18,2)=CAST(ROUND(@ServicePriceTax*@PreDays/CONVERT(DECIMAL(18,6),@TotalDays),2) AS DECIMAL(18,2));
        IF @PostDays=0
        BEGIN
            -- No post-exit row exists. Allocate the entire rounding residual
            -- to pre-occupancy components rather than inventing a zero-day bill.
            SET @PPriceTax=@PriceTax-@RPriceTax;
            SET @PServicePrice=@ServicePrice-@RServicePrice;
            SET @PServicePriceTax=@ServicePriceTax-@RServicePriceTax;
        END;
        DECLARE @PPrice DECIMAL(18,2)=@PreTotal-@PPriceTax-@PServicePrice-@PServicePriceTax;
        DECLARE @QPrice DECIMAL(18,2)=@Price-@RPrice-@PPrice;
        DECLARE @QPriceTax DECIMAL(18,2)=@PriceTax-@RPriceTax-@PPriceTax;
        DECLARE @QServicePrice DECIMAL(18,2)=@ServicePrice-@RServicePrice-@PServicePrice;
        DECLARE @QServicePriceTax DECIMAL(18,2)=@ServicePriceTax-@RServicePriceTax-@PServicePriceTax;
        IF @PPrice<0 OR @QPrice<0 OR @QPriceTax<0 OR @QServicePrice<0 OR @QServicePriceTax<0
           OR @PreTotal<>@PPrice+@PPriceTax+@PServicePrice+@PServicePriceTax
           OR @PostTotal<>@QPrice+@QPriceTax+@QServicePrice+@QServicePriceTax
            THROW 50001,N'تعذر توزيع مكونات الفاتورة بين ثلاث فترات بأمان.',1;

        IF @RPrice < 0 OR @RPrice > @Price
           OR @RPriceTax > @PriceTax
           OR @RServicePrice > @ServicePrice
           OR @RServicePriceTax > @ServicePriceTax
            THROW 50001, N'تعذر توزيع مكونات الفاتورة دون الإخلال بالقيم؛ يلزم مراجعة.', 1;

        -- Parent remains a historical invoice, no longer included in active totals.
        IF @OriginalActive = 1
        BEGIN
            UPDATE Housing.Bills
               SET BillActive = 0, CanceledBy = N'EXIT_PRORATION',
                   CanceledDate = GETDATE()
            WHERE BillsID = @OriginalBillsID AND BillActive = 1;
            IF @@ROWCOUNT <> 1
                THROW 50001, N'فشل تعطيل الفاتورة الأصلية.', 1;
        END;

        DECLARE @NewResidentBillID BIGINT = NULL, @NewVacantBillID BIGINT = NULL,
                @NewPreBillID BIGINT = NULL;

        -- Derived invoices deliberately have NULL meterReadID; the physical read
        -- remains on the (inactive) parent. Never duplicate a real meter reading.
        IF @ResidentTotal > 0
        BEGIN
            INSERT INTO Housing.Bills
            (
                  BillsUID, BillChargeTypeID_FK, BillTypeID_FK, ParentBillsID_FK
                , ExitRequestActionID_FK, SplitType, SplitDate, SplitBy
                , PeriodMonth, PeriodYear, PerviosPeriodID, CurrentPeriodID
                , CurrentPeriodTax, meterNo, meterID, meterName_A, meterName_E
                , meterDescription, buildingDetailsNo, buildingUtilityTypeID
                , buildingDetailsID, meterTypeID, meterServiceTypeID
                , residentInfoID_FK, generalNo_FK
                , PRICE, PRICETAX, meterServicePrice, meterServicePriceTAX, TotalPrice
                , BillsFromDate, BillsToDate, BillActive, idaraID_FK
                , entryDate, entryData, hostName
            )
            SELECT
                  NEWID(), b.BillChargeTypeID_FK, 2, @OriginalBillsID
                , @ExitRequestActionID, N'EXIT_RESIDENT', GETDATE(), @EntryData
                , b.PeriodMonth, b.PeriodYear, b.PerviosPeriodID, b.CurrentPeriodID
                , b.CurrentPeriodTax, b.meterNo, b.meterID, b.meterName_A, b.meterName_E
                , b.meterDescription, b.buildingDetailsNo, b.buildingUtilityTypeID
                , b.buildingDetailsID, b.meterTypeID, b.meterServiceTypeID
                , b.residentInfoID_FK, b.generalNo_FK
                , @RPrice, @RPriceTax, @RServicePrice, @RServicePriceTax, @ResidentTotal
                , @ResidentStart, @ResidentEnd, 1, b.idaraID_FK
                , GETDATE(), @EntryData, @HostName
            FROM Housing.Bills b
            WHERE b.BillsID = @OriginalBillsID;
            IF @@ROWCOUNT <> 1 THROW 50001, N'فشل إنشاء مطالبة المستفيد المصححة.', 1;
            SET @NewResidentBillID = CONVERT(BIGINT, SCOPE_IDENTITY());
        END;

        IF @PostTotal > 0
        BEGIN
            DECLARE @VacantBillFrom DATE =
                CASE WHEN @ExitDate < @PeriodFrom THEN @PeriodFrom
                     ELSE DATEADD(DAY,1,@ExitDate) END;

            INSERT INTO Housing.Bills
            (
                  BillsUID, BillChargeTypeID_FK, BillTypeID_FK, ParentBillsID_FK
                , ExitRequestActionID_FK, SplitType, SplitDate, SplitBy
                , PeriodMonth, PeriodYear, PerviosPeriodID, CurrentPeriodID
                , CurrentPeriodTax, meterNo, meterID, meterName_A, meterName_E
                , meterDescription, buildingDetailsNo, buildingUtilityTypeID
                , buildingDetailsID, meterTypeID, meterServiceTypeID
                , residentInfoID_FK, generalNo_FK
                , PRICE, PRICETAX, meterServicePrice, meterServicePriceTAX, TotalPrice
                , BillsFromDate, BillsToDate, BillActive, idaraID_FK
                , entryDate, entryData, hostName
            )
            SELECT
                  NEWID(), b.BillChargeTypeID_FK, 2, @OriginalBillsID
                , @ExitRequestActionID, N'EXIT_VACANT', GETDATE(), @EntryData
                , b.PeriodMonth, b.PeriodYear, b.PerviosPeriodID, b.CurrentPeriodID
                , b.CurrentPeriodTax, b.meterNo, b.meterID, b.meterName_A, b.meterName_E
                , b.meterDescription, b.buildingDetailsNo, b.buildingUtilityTypeID
                , b.buildingDetailsID, b.meterTypeID, b.meterServiceTypeID
                , NULL, NULL
                , @QPrice, @QPriceTax
                , @QServicePrice, @QServicePriceTax
                , @PostTotal
                , @VacantBillFrom, @PeriodTo, 1, b.idaraID_FK
                , GETDATE(), @EntryData, @HostName
            FROM Housing.Bills b
            WHERE b.BillsID = @OriginalBillsID;
            IF @@ROWCOUNT <> 1 THROW 50001, N'فشل إنشاء فاتورة فترة الشغور.', 1;
            SET @NewVacantBillID = CONVERT(BIGINT, SCOPE_IDENTITY());
        END;

        -- Separate administrative bill for the earlier (pre-occupancy) segment.
        IF @PreTotal > 0
        BEGIN
            INSERT INTO Housing.Bills
            (
                  BillsUID, BillChargeTypeID_FK, BillTypeID_FK, ParentBillsID_FK
                , ExitRequestActionID_FK, SplitType, SplitDate, SplitBy
                , PeriodMonth, PeriodYear, PerviosPeriodID, CurrentPeriodID
                , CurrentPeriodTax, meterNo, meterID, meterName_A, meterName_E
                , meterDescription, buildingDetailsNo, buildingUtilityTypeID
                , buildingDetailsID, meterTypeID, meterServiceTypeID
                , residentInfoID_FK, generalNo_FK
                , PRICE, PRICETAX, meterServicePrice, meterServicePriceTAX, TotalPrice
                , BillsFromDate, BillsToDate, BillActive, idaraID_FK
                , entryDate, entryData, hostName
            )
            SELECT NEWID(),b.BillChargeTypeID_FK,2,@OriginalBillsID,
                   @ExitRequestActionID,N'EXIT_VACANT_BEFORE',GETDATE(),@EntryData,
                   b.PeriodMonth,b.PeriodYear,b.PerviosPeriodID,b.CurrentPeriodID,
                   b.CurrentPeriodTax,b.meterNo,b.meterID,b.meterName_A,b.meterName_E,
                   b.meterDescription,b.buildingDetailsNo,b.buildingUtilityTypeID,
                   b.buildingDetailsID,b.meterTypeID,b.meterServiceTypeID,
                   NULL,NULL,
                   @PPrice,@PPriceTax,@PServicePrice,@PServicePriceTax,@PreTotal,
                   @PeriodFrom,DATEADD(DAY,-1,@RegisteredOccupentDate),1,b.idaraID_FK,
                   GETDATE(),@EntryData,@HostName
            FROM Housing.Bills b WHERE b.BillsID=@OriginalBillsID;
            IF @@ROWCOUNT<>1 THROW 50001,N'فشل إنشاء فاتورة شغور ما قبل التسكين.',1;
            SET @NewPreBillID=CONVERT(BIGINT,SCOPE_IDENTITY());
        END;

        DECLARE @NextRevisionNo INT;
        SELECT @NextRevisionNo = ISNULL(MAX(p.RevisionNo),0)+1
        FROM Housing.ExitMeterBillProration p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.ExitRequestActionID_FK = @ExitRequestActionID
          AND p.OriginalBillsID_FK = @OriginalBillsID;

        INSERT INTO Housing.ExitMeterBillProration
        (
              ExitRequestActionID_FK, OriginalBillsID_FK
            , ResidentBillsID_FK, VacantBillsID_FK, PreOccupancyBillsID_FK
            , PreOccupancyAmount
            , RevisionNo, ExitDate, BillsFromDate, BillsToDate
            , OriginalAmount, ResidentAmount, VacantAmount
            , CorrectionStatus, CreatedBy
        )
        VALUES
        (
              @ExitRequestActionID, @OriginalBillsID
            , @NewResidentBillID, @NewVacantBillID, @NewPreBillID
            , @PreTotal
            , @NextRevisionNo, @ExitDate, @PeriodFrom, @PeriodTo
            , @OriginalTotal, @ResidentTotal, @VacantTotal
            , 1, @EntryData
        );
        DECLARE @NewProrationID BIGINT = CONVERT(BIGINT,SCOPE_IDENTITY());

        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
        VALUES
        (
              N'[Housing].[ExitMeterBillProration]'
            , CASE WHEN @Action = N'REGENERATE' THEN N'REGENERATE' ELSE N'GENERATE' END
            , @NewProrationID, @EntryData
            , CONCAT(N'ExitRequestActionID=', @ExitRequestActionID,
                     N'; OriginalBill=',@OriginalBillsID,
                     N'; ResidentBill=',COALESCE(CONVERT(NVARCHAR(30),@NewResidentBillID),N'NULL'),
                     N'; VacantBill=',COALESCE(CONVERT(NVARCHAR(30),@NewVacantBillID),N'NULL'),
                     N'; BeforeBill=',COALESCE(CONVERT(NVARCHAR(30),@NewPreBillID),N'NULL'))
        );

        IF @OwnTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @OwnTran = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;