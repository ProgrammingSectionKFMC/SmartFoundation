CREATE   PROCEDURE [VIC].[ReportDL]
    @ActionType          NVARCHAR(100),
    @vehicleID           INT             = NULL,
    @chassisNumber       NVARCHAR(200)   = NULL,
    @days                INT             = 30,
    @includeExpired      BIT             = 1,
    @activeOnly          BIT             = 1,
    @idaraID_FK          NVARCHAR(10)    = NULL,
    @fromDate            DATETIME        = NULL,
    @toDate              DATETIME        = NULL,
    @onlyActiveVehicles  BIT             = 0
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
    -- DOCUMENTS_EXPIRING
    -- -----------------------------------------------------------------
    IF @ActionType = N'DOCUMENTS_EXPIRING'
    BEGIN
        SELECT
            V.vehicleID,
            V.chassisNumber,
            VDT.vehicleDocumentTypeName_E,
            VD.vehicleDocumentNo,
            VD.vehicleDocumentEndDate,
            DATEDIFF(DAY, GETDATE(), VD.vehicleDocumentEndDate) AS DaysToExpire
        FROM [VIC].[vehicleDocument] VD
        INNER JOIN [VIC].[VehiclesDocumentType] VDT
            ON VDT.vehicleDocumentTypeID = VD.vehicleDocumentTypeID_FK
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = VD.chassisNumber_FK
        WHERE V.IdaraID_FK = @IdaraID_BIG
          AND VD.vehicleDocumentEndDate <= DATEADD(DAY, @days, GETDATE())
          AND (@includeExpired = 1 OR VD.vehicleDocumentEndDate >= CAST(GETDATE() AS DATE))
          AND (@activeOnly = 0 OR V.isActive = 1)
          AND (@VID IS NULL OR V.vehicleID = @VID)
        ORDER BY VD.vehicleDocumentEndDate ASC;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- INSURANCE_EXPIRING
    -- -----------------------------------------------------------------
    IF @ActionType = N'INSURANCE_EXPIRING'
    BEGIN
        SELECT
            V.vehicleID,
            V.chassisNumber,
            VI.Source,
            VI.StartInsurance,
            VI.EndInsurance,
            VI.Amount,
            DATEDIFF(DAY, GETDATE(), VI.EndInsurance) AS DaysToExpire
        FROM [VIC].[VehicleInsurance] VI
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = VI.chassisNumber_FK
        WHERE V.IdaraID_FK = @IdaraID_BIG
          AND VI.EndInsurance <= DATEADD(DAY, @days, GETDATE())
          AND (@includeExpired = 1 OR VI.EndInsurance >= CAST(GETDATE() AS DATE))
          AND (@activeOnly = 0 OR V.isActive = 1)
          AND (@VID IS NULL OR V.vehicleID = @VID)
        ORDER BY VI.EndInsurance ASC;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- MAINTENANCE_COST
    -- -----------------------------------------------------------------
    IF @ActionType = N'MAINTENANCE_COST'
    BEGIN
        SELECT
            V.vehicleID,
            V.chassisNumber,
            COUNT(VM.MaintOrdID) AS OrderCount,
            0 AS TotalCost
        FROM [VIC].[VehicleMaintenance] VM
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = VM.chassisNumber_FK
        WHERE V.IdaraID_FK = @IdaraID_BIG
          AND (@fromDate IS NULL OR VM.MaintOrdStartDate >= @fromDate)
          AND (@toDate IS NULL OR VM.MaintOrdStartDate < DATEADD(DAY, 1, @toDate))
          AND (@activeOnly = 0 OR V.isActive = 1)
          AND (@VID IS NULL OR V.vehicleID = @VID)
        GROUP BY V.vehicleID, V.chassisNumber
        ORDER BY OrderCount DESC;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- UNPAID_VIOLATIONS
    -- -----------------------------------------------------------------
    IF @ActionType = N'UNPAID_VIOLATIONS'
    BEGIN
        SELECT
            VL.violationID,
            V.vehicleID,
            V.chassisNumber,
            TR.typesName_E AS ViolationTypeName,
            VL.violationDate,
            VL.violationPrice,
            VL.violationLocation
        FROM [VIC].[Violations] VL
        INNER JOIN [VIC].[TypesRoot] TR
            ON TR.typesID = VL.violationTypeRoot_FK
        INNER JOIN [VIC].[Vehicles] V
            ON V.chassisNumber = VL.chassisNumber_FK
           AND V.IdaraID_FK = VL.IdaraID_FK
        WHERE VL.PaymentDate IS NULL
          AND VL.IdaraID_FK = @IdaraID_BIG
          AND (@fromDate IS NULL OR VL.violationDate >= @fromDate)
          AND (@toDate IS NULL OR VL.violationDate < DATEADD(DAY, 1, @toDate))
          AND (@activeOnly = 0 OR V.isActive = 1)
          AND (@VID IS NULL OR V.vehicleID = @VID)
        ORDER BY VL.violationDate DESC;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- VEHICLES_WITHOUT_CUSTODY
    -- -----------------------------------------------------------------
    IF @ActionType = N'VEHICLES_WITHOUT_CUSTODY'
    BEGIN
        SELECT
            V.vehicleID,
            V.chassisNumber,
            V.plateLetters,
            V.plateNumbers
        FROM [VIC].[Vehicles] V
        WHERE V.IdaraID_FK = @IdaraID_BIG
          AND NOT EXISTS (
                  SELECT 1
                  FROM [VIC].[vehicleWithUsers] vwU
                  WHERE vwU.chassisNumber_FK = V.chassisNumber
                    AND vwU.endDate IS NULL
              )
          AND (@onlyActiveVehicles = 0 OR V.isActive = 1)
        ORDER BY V.chassisNumber;

        RETURN;
    END

    -- -----------------------------------------------------------------
    -- VEHICLE_TIMELINE
    -- -----------------------------------------------------------------
    IF @ActionType = N'VEHICLE_TIMELINE'
    BEGIN
        IF @CH IS NULL
            THROW 50001, N'رقم الهيكل أو رقم المركبة مطلوب', 1;

        SELECT
            EventDate,
            EventType,
            EventDescription,
            RelatedID
        FROM
        (
            SELECT
                vwU.startDate AS EventDate,
                N'بداية العهدة' AS EventType,
                N'تم إسناد العهدة' AS EventDescription,
                vwU.vehicleWithUsersID AS RelatedID
            FROM [VIC].[vehicleWithUsers] vwU
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = vwU.chassisNumber_FK
            WHERE vwU.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND vwU.startDate IS NOT NULL

            UNION ALL

            SELECT
                vwU.endDate AS EventDate,
                N'Custody End' AS EventType,
                N'تم إنهاء العهدة' AS EventDescription,
                vwU.vehicleWithUsersID AS RelatedID
            FROM [VIC].[vehicleWithUsers] vwU
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = vwU.chassisNumber_FK
            WHERE vwU.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND vwU.endDate IS NOT NULL

            UNION ALL

            SELECT
                VM.MaintOrdStartDate AS EventDate,
                N'بداية الصيانة' AS EventType,
                N'بدأ أمر الصيانة' AS EventDescription,
                VM.MaintOrdID AS RelatedID
            FROM [VIC].[VehicleMaintenance] VM
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VM.chassisNumber_FK
            WHERE VM.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VM.MaintOrdStartDate IS NOT NULL

            UNION ALL

            SELECT
                VM.MaintOrdEndDate AS EventDate,
                N'نهاية الصيانة' AS EventType,
                N'اكتملت الصيانة' AS EventDescription,
                VM.MaintOrdID AS RelatedID
            FROM [VIC].[VehicleMaintenance] VM
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VM.chassisNumber_FK
            WHERE VM.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VM.MaintOrdEndDate IS NOT NULL

            UNION ALL

            SELECT
                VD.vehicleDocumentStartDate AS EventDate,
                N'بداية الوثيقة' AS EventType,
                N'تم إصدار الوثيقة: ' + ISNULL(VDT.vehicleDocumentTypeName_E, N'') AS EventDescription,
                VD.vehicleDocumentID AS RelatedID
            FROM [VIC].[vehicleDocument] VD
            INNER JOIN [VIC].[VehiclesDocumentType] VDT
                ON VDT.vehicleDocumentTypeID = VD.vehicleDocumentTypeID_FK
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VD.chassisNumber_FK
            WHERE VD.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VD.vehicleDocumentStartDate IS NOT NULL

            UNION ALL

            SELECT
                VD.vehicleDocumentEndDate AS EventDate,
                N'نهاية الوثيقة' AS EventType,
                N'انتهت صلاحية الوثيقة: ' + ISNULL(VDT.vehicleDocumentTypeName_E, N'') AS EventDescription,
                VD.vehicleDocumentID AS RelatedID
            FROM [VIC].[vehicleDocument] VD
            INNER JOIN [VIC].[VehiclesDocumentType] VDT
                ON VDT.vehicleDocumentTypeID = VD.vehicleDocumentTypeID_FK
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VD.chassisNumber_FK
            WHERE VD.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VD.vehicleDocumentEndDate IS NOT NULL

            UNION ALL

            SELECT
                VI.StartInsurance AS EventDate,
                N'بداية التأمين' AS EventType,
                N'بدأت وثيقة التأمين' AS EventDescription,
                VI.VehicleInsuranceID AS RelatedID
            FROM [VIC].[VehicleInsurance] VI
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VI.chassisNumber_FK
            WHERE VI.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VI.StartInsurance IS NOT NULL

            UNION ALL

            SELECT
                VI.EndInsurance AS EventDate,
                N'نهاية التأمين' AS EventType,
                N'انتهت وثيقة التأمين' AS EventDescription,
                VI.VehicleInsuranceID AS RelatedID
            FROM [VIC].[VehicleInsurance] VI
            INNER JOIN [VIC].[Vehicles] V
                ON V.chassisNumber = VI.chassisNumber_FK
            WHERE VI.chassisNumber_FK = @CH
              AND V.IdaraID_FK = @IdaraID_BIG
              AND VI.EndInsurance IS NOT NULL
        ) AS Timeline
        ORDER BY EventDate DESC;

        RETURN;
    END

    ;THROW 50001, N'نوع العملية غير معروف في إجراء بيانات التقارير', 1;
END;

GO

