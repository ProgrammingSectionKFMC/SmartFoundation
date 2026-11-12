CREATE   PROCEDURE [VIC].[MaintenanceDL]
(
      @ActionType        NVARCHAR(100)
    , @vehicleID         INT            = NULL
    , @idaraID_FK        BIGINT          = NULL
    , @maintOrdID        INT            = NULL
    , @maintOrdTypeID_FK INT            = NULL
    , @chassisNumber     NVARCHAR(200)  = NULL
    , @active            BIT            = NULL
    , @fromDate          DATETIME       = NULL
    , @toDate            DATETIME       = NULL
    , @pageNumber        INT            = 1
    , @pageSize          INT            = 50
    , @maintDetailesID   INT            = NULL
    , @groupID           INT            = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID
        FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    DECLARE @P INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    ----------------------------------------------------------------
    -- GET_ORDER
    ----------------------------------------------------------------
    IF @ActionType = 'GET_ORDER'
    BEGIN
        IF @maintOrdID IS NULL OR @maintOrdID <= 0
        BEGIN
            THROW 50001, N'معرف أمر الصيانة مطلوب', 1;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance m
            WHERE m.MaintOrdID = @maintOrdID
              AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
        )
        BEGIN
            THROW 50001, N'أمر الصيانة غير موجود', 1;
            RETURN;
        END

        SELECT
              m.MaintOrdID
            , m.MaintOrdTypeID_FK
            , m.chassisNumber_FK
            , v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , m.MaintOrdStartDate
            , m.MaintOrdEndDate
            , m.MaintOrdDesc
            , m.MaintOrdActive
            , m.odometer
            , m.jobOrderNumber
            , m.closeNote
            , m.entryDate
            , m.entryData
            , m.hostName
        FROM VIC.VehicleMaintenance m
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = m.chassisNumber_FK
        WHERE m.MaintOrdID = @maintOrdID
          AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK);

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_ORDERS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_ORDERS'
    BEGIN
        SELECT
              m.MaintOrdID
            , m.MaintOrdTypeID_FK
            , m.chassisNumber_FK
            , v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , m.MaintOrdStartDate
            , m.MaintOrdEndDate
            , m.MaintOrdDesc
            , m.MaintOrdActive
            , m.odometer
            , m.jobOrderNumber
            , m.closeNote
            , m.workshopIDs
            , m.entryDate
            , m.entryData
            , m.hostName
            , pln.nextDueDate
            , CASE
                WHEN pln.nextDueDate IS NOT NULL
                     AND pln.nextDueDate < CAST(GETDATE() AS DATE)
                THEN N'متأخر'
                WHEN pln.nextDueDate IS NOT NULL
                THEN N'في الموعد'
                ELSE NULL
              END AS overdueStatus
            , STUFF((
                SELECT N'، ' + gf.FaultDescription
                FROM VIC.GeneralMaintenanceFault gf
                WHERE gf.MaintOrdID_FK = m.MaintOrdID
                  AND ISNULL(gf.[Active], 1) = 1
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'), 1, 2, N'') AS faultSummary
            , STUFF((
                SELECT N'، ' + gf.CorrectiveAction
                FROM VIC.GeneralMaintenanceFault gf
                WHERE gf.MaintOrdID_FK = m.MaintOrdID
                  AND ISNULL(gf.[Active], 1) = 1
                  AND gf.CorrectiveAction IS NOT NULL
                  AND LEN(LTRIM(RTRIM(gf.CorrectiveAction))) > 0
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'), 1, 2, N'') AS correctiveSummary
        FROM VIC.VehicleMaintenance m
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = m.chassisNumber_FK
        OUTER APPLY (
            SELECT TOP 1 p2.nextDueDate
            FROM VIC.VehicleMaintenancePlan p2
            WHERE p2.chassisNumber_FK = m.chassisNumber_FK
              AND p2.planActive = 1
            ORDER BY p2.nextDueDate ASC
        ) pln
        WHERE 1 = 1
          AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
          AND (@CH IS NULL OR m.chassisNumber_FK = @CH)
          AND (@maintOrdTypeID_FK IS NULL OR m.MaintOrdTypeID_FK = @maintOrdTypeID_FK)
          AND (@active IS NULL OR m.MaintOrdActive = @active)
          AND (@fromDate IS NULL OR m.MaintOrdStartDate >= @fromDate)
          AND (@toDate IS NULL OR m.MaintOrdStartDate < DATEADD(DAY, 1, @toDate))
        ORDER BY m.MaintOrdID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_MONTHLY_REPORT  (Comprehensive Maintenance Report)
    ----------------------------------------------------------------
    IF @ActionType = N'LIST_MONTHLY_REPORT'
    BEGIN
        SELECT
              m.MaintOrdID
            , m.MaintOrdTypeID_FK
            , m.chassisNumber_FK
            , v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , CONVERT(NVARCHAR(200), v.plateNumbers) AS plateNumbers
            , v.armyNumber
            , m.MaintOrdStartDate
            , m.MaintOrdEndDate
            , m.MaintOrdDesc
            , m.MaintOrdActive
            , m.odometer
            , m.jobOrderNumber
            , m.closeNote
            , m.workshopIDs
            , m.entryDate
            , STUFF((
                SELECT N'، ' + gf.FaultDescription
                FROM VIC.GeneralMaintenanceFault gf
                WHERE gf.MaintOrdID_FK = m.MaintOrdID
                  AND ISNULL(gf.[Active], 1) = 1
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS faultSummary
            , STUFF((
                SELECT N'، ' + gf.CorrectiveAction
                FROM VIC.GeneralMaintenanceFault gf
                WHERE gf.MaintOrdID_FK = m.MaintOrdID
                  AND ISNULL(gf.[Active], 1) = 1
                  AND gf.CorrectiveAction IS NOT NULL
                  AND LEN(LTRIM(RTRIM(gf.CorrectiveAction))) > 0
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS correctiveSummary
        FROM VIC.VehicleMaintenance m
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = m.chassisNumber_FK
        WHERE 1 = 1
          AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
          AND (@fromDate IS NULL OR m.MaintOrdStartDate >= @fromDate)
          AND (@toDate IS NULL OR m.MaintOrdStartDate < DATEADD(DAY, 1, @toDate))
        ORDER BY m.MaintOrdStartDate ASC, m.MaintOrdID ASC;

        SELECT 1 AS MonthNum, N'01' AS MonthName UNION ALL
        SELECT 2, N'02' UNION ALL
        SELECT 3, N'03' UNION ALL
        SELECT 4, N'04' UNION ALL
        SELECT 5, N'05' UNION ALL
        SELECT 6, N'06' UNION ALL
        SELECT 7, N'07' UNION ALL
        SELECT 8, N'08' UNION ALL
        SELECT 9, N'09' UNION ALL
        SELECT 10, N'10' UNION ALL
        SELECT 11, N'11' UNION ALL
        SELECT 12, N'12';

        SELECT YEAR(GETDATE()) - 5 AS YearNum UNION ALL
        SELECT YEAR(GETDATE()) - 4 UNION ALL
        SELECT YEAR(GETDATE()) - 3 UNION ALL
        SELECT YEAR(GETDATE()) - 2 UNION ALL
        SELECT YEAR(GETDATE()) - 1 UNION ALL
        SELECT YEAR(GETDATE()) UNION ALL
        SELECT YEAR(GETDATE()) + 1;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_MONITORING
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_MONITORING'
BEGIN
    DECLARE @CurrentMonth INT = MONTH(GETDATE());
    DECLARE @CurrentYear  INT = YEAR(GETDATE());
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    ;WITH AllVehicles AS
    (
        SELECT v.chassisNumber, v.armyNumber, v.plateLetters, v.plateNumbers,
               CONCAT(v.chassisNumber, N' ', v.plateLetters, N' ', v.plateNumbers) AS vehicleDesc,
               vmg.GroupID_FK AS GroupID, mg.GroupCode, mg.GroupName_A
        FROM VIC.Vehicles v
        LEFT JOIN VIC.VehicleMaintenanceGroup vmg ON vmg.chassisNumber_FK = v.chassisNumber AND vmg.Active = 1
        LEFT JOIN VIC.MaintenanceGroup mg ON mg.GroupID = vmg.GroupID_FK
        WHERE v.vehicleStatusID_FK <> 262
          AND (@idaraID_FK IS NULL OR v.IdaraID_FK = @idaraID_FK)
          AND (@groupID IS NULL OR (@groupID = 0 AND vmg.GroupID_FK IS NULL) OR (@groupID > 0 AND vmg.GroupID_FK = @groupID))
    ),
    OpenOrders AS
    (
        SELECT m.chassisNumber_FK, m.MaintOrdID AS openOrderID, m.jobOrderNumber AS openJobOrderNumber
        FROM VIC.VehicleMaintenance m
        WHERE m.MaintOrdActive = 1 AND m.MaintOrdTypeID_FK = 265 AND ISNULL(m.Cancelled,0) = 0
    ),
    LastCompleted AS
    (
        SELECT m.chassisNumber_FK, MAX(m.MaintOrdEndDate) AS lastMaintenanceDate, MAX(m.jobOrderNumber) AS lastJobOrderNumber
        FROM VIC.VehicleMaintenance m
        WHERE m.MaintOrdActive = 0 AND m.MaintOrdTypeID_FK = 265 AND ISNULL(m.Cancelled,0) = 0
        GROUP BY m.chassisNumber_FK
    ),
    CompletedThisPeriod AS
    (
        SELECT DISTINCT m.chassisNumber_FK
        FROM VIC.VehicleMaintenance m
        WHERE m.MaintOrdActive = 0 AND m.MaintOrdTypeID_FK = 265 AND ISNULL(m.Cancelled,0) = 0
          AND MONTH(m.MaintOrdEndDate) = @CurrentMonth AND YEAR(m.MaintOrdEndDate) = @CurrentYear
    ),
    VehicleStatus AS
    (
        SELECT av.chassisNumber, av.armyNumber, av.vehicleDesc, av.GroupID, av.GroupCode, av.GroupName_A,
               oo.openOrderID, oo.openJobOrderNumber, lc.lastMaintenanceDate, lc.lastJobOrderNumber, p.nextDueDate,
               CASE
                 WHEN oo.openOrderID IS NOT NULL AND @Today <= DATEADD(day,7,ISNULL(p.nextDueDate,@Today)) THEN N'جاري'
                 WHEN oo.openOrderID IS NOT NULL                                                       THEN N'متأخر'
                 WHEN oo.openOrderID IS NULL AND ctp.chassisNumber_FK IS NOT NULL                       THEN N'مكتمل'
                 WHEN oo.openOrderID IS NULL AND p.nextDueDate IS NOT NULL
                      AND CAST(p.nextDueDate AS DATE) >= @Today
                      AND CAST(p.nextDueDate AS DATE) <= DATEADD(day,7,@Today)                          THEN N'في الموعد'
                 ELSE N'لم يبدأ'
               END AS statusName
        FROM AllVehicles av
        LEFT JOIN OpenOrders oo ON oo.chassisNumber_FK = av.chassisNumber
        LEFT JOIN LastCompleted lc ON lc.chassisNumber_FK = av.chassisNumber
        LEFT JOIN CompletedThisPeriod ctp ON ctp.chassisNumber_FK = av.chassisNumber
        LEFT JOIN VIC.VehicleMaintenancePlan p ON p.chassisNumber_FK = av.chassisNumber AND p.planActive = 1
    )
    SELECT vs.chassisNumber, vs.armyNumber, vs.vehicleDesc, vs.GroupID, vs.GroupCode, vs.GroupName_A,
           vs.lastMaintenanceDate, ISNULL(vs.openJobOrderNumber, vs.lastJobOrderNumber) AS lastJobOrderNumber,
           vs.openOrderID, vs.statusName,
           CASE vs.statusName
             WHEN N'جاري' THEN 1
             WHEN N'متأخر' THEN 2
             WHEN N'مكتمل' THEN 3
             WHEN N'في الموعد' THEN 4
             WHEN N'لم يبدأ' THEN 5
             ELSE 9
           END AS statusOrder
    FROM VehicleStatus vs
    ORDER BY
      CASE vs.statusName
        WHEN N'جاري' THEN 1
        WHEN N'متأخر' THEN 2
        WHEN N'مكتمل' THEN 3
        WHEN N'في الموعد' THEN 4
        WHEN N'لم يبدأ' THEN 5
        ELSE 9
      END ASC, vs.chassisNumber ASC;

    RETURN;
END

    ----------------------------------------------------------------
    -- LIST_GROUPS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_GROUPS'
    BEGIN
        SELECT
              GroupID
            , GroupCode
            , GroupName_A
        FROM VIC.MaintenanceGroup
        WHERE GroupActive = 1
        ORDER BY GroupCode;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_HISTORY
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_HISTORY'
    BEGIN
        SELECT
              m.MaintOrdID
            , m.MaintOrdTypeID_FK
            , m.chassisNumber_FK
            , v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , m.MaintOrdStartDate
            , m.MaintOrdEndDate
            , m.MaintOrdDesc
            , m.MaintOrdActive
            , m.odometer
            , m.jobOrderNumber
            , m.closeNote
            , m.entryDate
            , m.entryData
            , m.hostName
            , ISNULL(grp.GroupCode, N'') AS GroupCode
            , ISNULL(grp.GroupName_A, N'') AS GroupName_A
        FROM VIC.VehicleMaintenance m
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = m.chassisNumber_FK
        OUTER APPLY (
            SELECT TOP 1 mg.GroupCode, mg.GroupName_A
            FROM VIC.VehicleMaintenanceGroup vmg
            INNER JOIN VIC.MaintenanceGroup mg
                ON mg.GroupID = vmg.GroupID_FK
            WHERE LTRIM(RTRIM(vmg.chassisNumber_FK)) = LTRIM(RTRIM(m.chassisNumber_FK))
              AND vmg.Active = 1
        ) grp
        WHERE m.MaintOrdTypeID_FK = 265
          AND m.MaintOrdActive = 0
          AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
          AND (@CH IS NULL OR m.chassisNumber_FK = @CH)
          AND (@fromDate IS NULL OR m.MaintOrdStartDate >= @fromDate)
          AND (@toDate IS NULL OR m.MaintOrdStartDate < DATEADD(DAY, 1, @toDate))
        ORDER BY m.MaintOrdID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- GET_DETAIL
    ----------------------------------------------------------------
    IF @ActionType = 'GET_DETAIL'
    BEGIN
        IF @maintDetailesID IS NULL OR @maintDetailesID <= 0
        BEGIN
            THROW 50001, N'معرف بند الصيانة مطلوب', 1;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.MaintenanceDetails d
            INNER JOIN VIC.VehicleMaintenance m
                ON m.MaintOrdID = d.MaintOrdID_FK
            WHERE d.MaintDetailesID = @maintDetailesID
              AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
        )
        BEGIN
            THROW 50001, N'بند الصيانة غير موجود', 1;
            RETURN;
        END

        SELECT
              d.MaintDetailesID
            , d.MaintOrdID_FK
            , d.typesID_FK
            , ISNULL(tr.typesName_A, N'') AS itemName
            , ISNULL(tr.typesName_E, N'') AS itemName_E
            , d.SupportID_FK
            , d.CheckStatus_FK
            , d.ActionState
            , d.CorrectiveAction
            , d.FSN
            , d.MaintLevel
            , d.CurrentDate
            , d.Notes
            , d.MaintDetailActive
            , d.entryDate
            , d.entryData
            , d.hostName
            , v.vehicleID
            , v.chassisNumber
        FROM VIC.MaintenanceDetails d
        INNER JOIN VIC.VehicleMaintenance m
            ON m.MaintOrdID = d.MaintOrdID_FK
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = m.chassisNumber_FK
        LEFT JOIN VIC.TypesRoot tr ON tr.typesID = d.typesID_FK
        WHERE d.MaintDetailesID = @maintDetailesID
          AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK);

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_FAULTS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_FAULTS'
    BEGIN
        IF @maintOrdID IS NULL OR @maintOrdID <= 0
        BEGIN
            THROW 50001, N'معرف أمر الصيانة مطلوب', 1;
            RETURN;
        END

        SELECT
              FaultID
            , MaintOrdID_FK
            , [LineNo]
            , FaultDescription
            , CorrectiveAction
        FROM VIC.GeneralMaintenanceFault
        WHERE MaintOrdID_FK = @maintOrdID
          AND ISNULL([Active], 1) = 1
        ORDER BY [LineNo];

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_WORKSHOPS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_WORKSHOPS'
    BEGIN
        SELECT
              t.typesID
            , t.typesName_A
            , t.typesName_E
        FROM VIC.TypesRoot t
        WHERE t.typesRoot_ParentID = 288
          AND t.typesID BETWEEN 291 AND 296
          AND ISNULL(t.typesActive, 1) = 1
        ORDER BY t.typesID;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_DETAILS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_DETAILS'
    BEGIN
        IF @maintOrdID IS NULL OR @maintOrdID <= 0
        BEGIN
            THROW 50001, N'معرف أمر الصيانة مطلوب', 1;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenance m
            WHERE m.MaintOrdID = @maintOrdID
              AND (@idaraID_FK IS NULL OR m.IdaraID_FK = @idaraID_FK)
        )
        BEGIN
            THROW 50001, N'أمر الصيانة غير موجود', 1;
            RETURN;
        END

        SELECT
              ISNULL(d.MaintDetailesID, 0) AS MaintDetailesID
            , @maintOrdID AS MaintOrdID_FK
            , tr.typesID AS typesID_FK
            , ISNULL(tr.typesName_A, N'') AS itemName
            , ISNULL(tr.typesName_E, N'') AS itemName_E
            , d.SupportID_FK
            , d.CheckStatus_FK
            , d.ActionState
            , d.CorrectiveAction
            , d.FSN
            , d.MaintLevel
            , d.CurrentDate
            , ISNULL(d.Notes, N'') AS Notes
            , ISNULL(d.MaintDetailActive, 1) AS MaintDetailActive
            , d.entryDate
            , d.entryData
            , d.hostName
            , v.vehicleID
            , v.chassisNumber
        FROM VIC.TypesRoot tr
        INNER JOIN VIC.VehicleMaintenance m
            ON m.MaintOrdID = @maintOrdID
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = m.chassisNumber_FK
        LEFT JOIN VIC.MaintenanceDetails d
            ON d.typesID_FK = tr.typesID
            AND d.MaintOrdID_FK = @maintOrdID
        WHERE tr.typesRoot_ParentID = 179
          AND ISNULL(tr.typesActive, 1) = 1
        ORDER BY tr.typesID ASC;

        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء بيانات الصيانة', 1;
        RETURN;
    END
END

GO

