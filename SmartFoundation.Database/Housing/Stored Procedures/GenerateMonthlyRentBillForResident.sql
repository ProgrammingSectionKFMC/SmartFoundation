CREATE   PROCEDURE [Housing].[GenerateMonthlyRentBillForResident]
(
      @ResidentInfoID    BIGINT
    , @GeneralNo         BIGINT
    , @BuildingDetailsID BIGINT
    , @OccupentDate      DATE
    , @Month             INT
    , @Year              INT
    , @IdaraID           BIGINT
    , @EntryData         NVARCHAR(20)
    , @HostName          NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionCount INT = @@TRANCOUNT;
    DECLARE @MonthStart DATE;
    DECLARE @MonthEnd DATE;
    DECLARE @BillingFromDate DATE;
    DECLARE @UnbilledRanges TABLE
(
    GapFrom DATE NOT NULL,
    GapTo   DATE NOT NULL,
    PRIMARY KEY (GapFrom, GapTo)
);

    BEGIN TRY
        IF @TransactionCount = 0
            BEGIN TRANSACTION;

        IF @ResidentInfoID IS NULL
           OR @BuildingDetailsID IS NULL
           OR @OccupentDate IS NULL
           OR @IdaraID IS NULL
           OR @Month NOT BETWEEN 1 AND 12
           OR @Year NOT BETWEEN 1900 AND 9999
        BEGIN
            ;THROW 50001, N'بيانات رصد فاتورة الإيجار غير صحيحة', 1;
        END;

        SET @MonthStart = DATEFROMPARTS(@Year, @Month, 1);
        SET @MonthEnd = EOMONTH(@MonthStart);

        SET @BillingFromDate =
    CASE
        WHEN @OccupentDate > @MonthStart
            THEN @OccupentDate
        ELSE @MonthStart
    END;

IF @BillingFromDate <= @MonthEnd
BEGIN

    /* تحديد جميع الأيام غير المفوترة داخل الشهر */
    ;WITH DayNumbers AS
    (
        SELECT 0 AS DayNumber

        UNION ALL

        SELECT DayNumber + 1
        FROM DayNumbers
        WHERE DayNumber <
              DATEDIFF(DAY, @BillingFromDate, @MonthEnd)
    ),
    UnbilledDays AS
    (
        SELECT
            DATEADD(DAY, n.DayNumber, @BillingFromDate)
                AS MissingDay
        FROM DayNumbers n
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Housing.Bills b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.residentInfoID_FK = @ResidentInfoID
              AND b.buildingDetailsID = @BuildingDetailsID
              AND b.idaraID_FK = @IdaraID
              AND b.BillChargeTypeID_FK = 1
              AND b.BillActive = 1
              AND CAST(b.BillsFromDate AS DATE)
                  <= DATEADD(DAY, n.DayNumber, @BillingFromDate)
              AND CAST(b.BillsToDate AS DATE)
                  >= DATEADD(DAY, n.DayNumber, @BillingFromDate)
        )
    ),
    GroupedDays AS
    (
        SELECT
            MissingDay,
            DATEADD
            (
                DAY,
                -CONVERT
                (
                    INT,
                    ROW_NUMBER() OVER (ORDER BY MissingDay)
                ),
                MissingDay
            ) AS GroupKey
        FROM UnbilledDays
    )
    INSERT INTO @UnbilledRanges
    (
        GapFrom,
        GapTo
    )
    SELECT
        MIN(MissingDay),
        MAX(MissingDay)
    FROM GroupedDays
    GROUP BY GroupKey
    OPTION (MAXRECURSION 32);

    /*
إذا لم توجد فجوات، لن تُنشأ فواتير جديدة لأن
@UnbilledRanges فارغ، لكن يجب الاستمرار
لمزامنة سدادات الإعفاء للفواتير الموجودة.
*/

    /* رفض الفترات التي لا يوجد لها تعريف إيجار */
    IF EXISTS
    (
        SELECT 1
        FROM @UnbilledRanges g
        OUTER APPLY Housing.fn_CalcBuildingRent_ForOneMonth
        (
            @BuildingDetailsID,
            g.GapFrom,
            @Year,
            @Month,
            g.GapTo
        ) rent
        WHERE rent.buildingDetailsID IS NULL
    )
    BEGIN
        THROW 50001,
              N'توجد فترة إيجار غير مفوترة ولا يمكن تحديد قيمتها؛ يرجى مراجعة تعريف الإيجار.',
              1;
    END;

       
            ;WITH CalculatedRent AS
            (
                SELECT
                      rent.CalcFromDate
                    , rent.CalcToDate
                    , RentAmount = CAST(rent.RentForMonth AS DECIMAL(18,2))
                FROM @UnbilledRanges g

CROSS APPLY Housing.fn_CalcBuildingRent_ForOneMonth
(
      @BuildingDetailsID
    , g.GapFrom
    , @Year
    , @Month
    , g.GapTo
) rent
                OUTER APPLY
                (
                    SELECT
                        ExemptionAmount =
                            CAST
                            (
                                (rent.RentForMonth / NULLIF(rent.Days30InMonth, 0))
                                * SUM(x.ExemptDays30)
                                AS DECIMAL(18,2)
                            )
                    FROM
                    (
                        SELECT
                            ExemptDays30 =
                            (
                                (YEAR(d.ExemptEnd) - YEAR(d.ExemptStart)) * 360
                              + (MONTH(d.ExemptEnd) - MONTH(d.ExemptStart)) * 30
                              + (
                                    CASE
                                        WHEN d.ExemptEnd = EOMONTH(d.ExemptEnd) AND DAY(d.ExemptEnd) < 30 THEN 30
                                        WHEN DAY(d.ExemptEnd) > 30 THEN 30
                                        ELSE DAY(d.ExemptEnd)
                                    END
                                    -
                                    CASE
                                        WHEN d.ExemptStart = EOMONTH(d.ExemptStart) AND DAY(d.ExemptStart) < 30 THEN 30
                                        WHEN DAY(d.ExemptStart) > 30 THEN 30
                                        ELSE DAY(d.ExemptStart)
                                    END
                                )
                              + 1
                            )
                        FROM
                        (
                            SELECT
                                  ExemptStart =
                                      CASE
                                          WHEN CAST(ex.residentRentExemptionStartDate AS date) < rent.CalcFromDate
                                              THEN rent.CalcFromDate
                                          ELSE CAST(ex.residentRentExemptionStartDate AS date)
                                      END
                                , ExemptEnd =
                                      CASE
                                          WHEN ex.residentRentExemptionEndDate IS NULL
                                               OR CAST(ex.residentRentExemptionEndDate AS date) > rent.CalcToDate
                                              THEN rent.CalcToDate
                                          ELSE CAST(ex.residentRentExemptionEndDate AS date)
                                      END
                            FROM Housing.ResidentRentExemption ex
                            WHERE ex.residentInfoID_FK = @ResidentInfoID
                              AND ex.buildingDetailsID_FK = @BuildingDetailsID
                              AND ISNULL(ex.residentRentExemptionActive, 0) = 1
                              AND CAST(ex.residentRentExemptionStartDate AS date) <= rent.CalcToDate
                              AND
                                  (
                                      ex.residentRentExemptionEndDate IS NULL
                                      OR CAST(ex.residentRentExemptionEndDate AS date) >= rent.CalcFromDate
                                  )
                        ) d
                        WHERE d.ExemptStart <= d.ExemptEnd
                    ) x
                ) exm
            )
            INSERT INTO Housing.Bills
            (
                  BillsUID
                , BillChargeTypeID_FK
                , BillTypeID_FK
                , PeriodMonth
                , PeriodYear
                , buildingDetailsID
                , residentInfoID_FK
                , generalNo_FK
                , PRICE
                , PRICETAX
                , TotalPrice
                , buildingRentTypeID_FK
                , BillsFromDate
                , BillsToDate
                , BillActive
                , idaraID_FK
                , entryDate
                , entryData
                , hostName
            )
            SELECT
                  NEWID()
                , 1
                , 2
                , @Month
                , @Year
                , @BuildingDetailsID
                , @ResidentInfoID
                , @GeneralNo
                , rent.RentAmount
                , 0
                , rent.RentAmount
                , 1
                , rent.CalcFromDate
                , rent.CalcToDate
                , 1
                , @IdaraID
                , GETDATE()
                , @EntryData
                , @HostName
            FROM CalculatedRent rent
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.Bills existingBill WITH (UPDLOCK, HOLDLOCK)
                WHERE existingBill.residentInfoID_FK = @ResidentInfoID
                  AND existingBill.buildingDetailsID = @BuildingDetailsID
                  AND existingBill.idaraID_FK = @IdaraID
                  AND existingBill.BillChargeTypeID_FK = 1
                  AND existingBill.BillActive = 1
                  AND CAST(existingBill.BillsFromDate AS date) <= rent.CalcToDate
                  AND CAST(existingBill.BillsToDate AS date) >= rent.CalcFromDate
            );

            DECLARE @ResidentRentExemptionID BIGINT;
            DECLARE exemptionCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT exemption.residentRentExemptionID
            FROM Housing.ResidentRentExemption exemption
            WHERE exemption.residentInfoID_FK = @ResidentInfoID
              AND exemption.buildingDetailsID_FK = @BuildingDetailsID
              AND exemption.idaraID_FK = @IdaraID
              AND exemption.residentRentExemptionActive = 1
              AND CAST(exemption.residentRentExemptionStartDate AS date) <= @MonthEnd
              AND
              (
                  exemption.residentRentExemptionEndDate IS NULL
                  OR CAST(exemption.residentRentExemptionEndDate AS date) >= @MonthStart
              );

            OPEN exemptionCursor;
            FETCH NEXT FROM exemptionCursor INTO @ResidentRentExemptionID;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC Housing.SyncRentExemptionPayments
                      @Action = N'GENERATE'
                    , @ResidentRentExemptionID = @ResidentRentExemptionID
                    , @ThroughDate = @MonthEnd
                    , @SourceType = N'RESIDENT_MONTHLY'
                    , @EntryData = @EntryData
                    , @HostName = @HostName;

                FETCH NEXT FROM exemptionCursor INTO @ResidentRentExemptionID;
            END;

            CLOSE exemptionCursor;
            DEALLOCATE exemptionCursor;
        END;

        IF @TransactionCount = 0
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @TransactionCount = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;