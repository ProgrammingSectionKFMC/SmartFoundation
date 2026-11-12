CREATE   PROCEDURE [VIC].[DashboardDL]
    @ActionType              NVARCHAR(100),
    @vehicleID               INT             = NULL,
    @chassisNumber           NVARCHAR(200)   = NULL,
    @onlyHasCustody          BIT             = NULL,
    @onlyHasActiveInsurance  BIT             = NULL,
    @onlyHasDocExpiry        INT             = NULL,
    @onlyHasInsExpiry        INT             = NULL,
    @idaraID_FK              NVARCHAR(10)    = NULL,
    @daysAhead               INT             = 7
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF @IdaraID_BIG IS NULL
        THROW 50001, N'الإدارة مطلوبة', 1;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID
        FROM [VIC].[Vehicles] v
        WHERE v.vehicleID = @vehicleID
          AND v.IdaraID_FK = @IdaraID_BIG;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID
        FROM [VIC].[Vehicles] v
        WHERE v.chassisNumber = @CH
          AND v.IdaraID_FK = @IdaraID_BIG;
    END

    -- -----------------------------------------------------------------
    -- VEHICLE_STATUS
    -- -----------------------------------------------------------------
    IF @ActionType = N'VEHICLE_STATUS'
    BEGIN
        SELECT
            V.vehicleID,
            DS.chassisNumber,
            V.plateLetters,
            V.plateNumbers,
            V.vehicleStatusID_FK,
            CASE WHEN DS.CurrentUserID IS NOT NULL THEN 1 ELSE 0 END AS HasActiveCustody,
            DS.CurrentUserID AS CustodyHolder,
            CASE WHEN DS.ActiveInsuranceTypeID IS NOT NULL THEN 1 ELSE 0 END AS HasActiveInsurance,
            DS.ActiveInsuranceEndDate AS InsuranceEndDate,
            DS.NextDocEndDate AS MinDocExpiryDate,
            DS.ActiveInsuranceEndDate AS MinInsExpiryDate,
            DS.DocDaysToExpire AS DaysToDocExpiry,
            DS.InsDaysToExpire AS DaysToInsExpiry
        FROM [VIC].[V_Dashboard_VehicleStatus] DS
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = DS.chassisNumber
           AND V.IdaraID_FK = DS.IdaraID_FK
        WHERE DS.IdaraID_FK = @IdaraID_BIG
          AND (@VID IS NULL OR V.vehicleID = @VID)
          AND (@onlyHasCustody IS NULL
               OR (@onlyHasCustody = 1 AND DS.CurrentUserID IS NOT NULL)
               OR (@onlyHasCustody = 0 AND DS.CurrentUserID IS NULL))
          AND (@onlyHasActiveInsurance IS NULL
               OR (@onlyHasActiveInsurance = 1 AND DS.ActiveInsuranceTypeID IS NOT NULL)
               OR (@onlyHasActiveInsurance = 0 AND DS.ActiveInsuranceTypeID IS NULL))
          AND (@onlyHasDocExpiry IS NULL
               OR (DS.NextDocEndDate IS NOT NULL
                   AND DS.DocDaysToExpire <= @onlyHasDocExpiry))
          AND (@onlyHasInsExpiry IS NULL
               OR (DS.ActiveInsuranceEndDate IS NOT NULL
                   AND DS.InsDaysToExpire <= @onlyHasInsExpiry))
        ORDER BY
            ISNULL(DS.DocDaysToExpire, 999999) ASC,
            ISNULL(DS.InsDaysToExpire, 999999) ASC;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- MAINTENANCE_DUE
    -- -----------------------------------------------------------------
    IF @ActionType = N'MAINTENANCE_DUE'
    BEGIN
        SELECT
            MP.PlanID,
            V.vehicleID,
            V.chassisNumber,
            V.plateLetters,
            V.plateNumbers,
            MP.periodMonths,
            MP.nextDueDate,
            DATEDIFF(DAY, GETDATE(), MP.nextDueDate) AS DaysToDue,
            CASE
                WHEN MP.nextDueDate < CAST(GETDATE() AS DATE) THEN N'overdue'
                WHEN MP.nextDueDate <= DATEADD(DAY, @daysAhead, GETDATE()) THEN N'soon'
                ELSE N'ok'
            END AS DueStatus,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM [VIC].[VehicleMaintenance] VM
                    WHERE VM.chassisNumber_FK = V.chassisNumber
                      AND VM.MaintOrdTypeID_FK = 265
                      AND VM.MaintOrdActive = 1
                ) THEN 1
                ELSE 0
            END AS HasOpenOrder
        FROM [VIC].[VehicleMaintenancePlan] MP
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = MP.chassisNumber_FK
           AND V.IdaraID_FK = MP.IdaraID_FK
        WHERE MP.planActive = 1
          AND MP.nextDueDate <= DATEADD(DAY, @daysAhead, GETDATE())
          AND MP.IdaraID_FK = @IdaraID_BIG
          AND (@VID IS NULL OR V.vehicleID = @VID)
        ORDER BY MP.nextDueDate ASC;

        RETURN;
    END

    ;THROW 50001, N'نوع العملية غير معروف في DashboardDL', 1;
END;

GO

