CREATE   PROCEDURE [VIC].[VehicleDL]
(
      @ActionType        NVARCHAR(100)
    , @idaraID_FK        NVARCHAR(10) = NULL

    , @vehicleID         BIGINT = NULL
    , @chassisNumber     NVARCHAR(200) = NULL
    , @ownerID_FK        NVARCHAR(200) = NULL
    , @plateLetters      NVARCHAR(200) = NULL
    , @plateNumbers      NVARCHAR(200) = NULL
    , @hasCustody        BIT = NULL
    , @q                 NVARCHAR(200) = NULL

    , @pageNumber        INT = 1
    , @pageSize          INT = 50

    , @ActiveOnly        BIT = 0
    , @InsuranceDays     INT = NULL
    , @IncludeExpired    BIT = 1
    , @active            BIT = NULL

    , @TopDocuments      INT = 20
    , @TopInsurance      INT = 20
    , @TopMaintenance    INT = 10
    , @TopViolations     INT = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @CH NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @Q_Trim NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@q)), N'');

    DECLARE @P INT = CASE WHEN ISNULL(@pageNumber, 0) < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN ISNULL(@pageSize, 0) < 1 OR @pageSize > 5000 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @TD INT = CASE WHEN @TopDocuments   IS NULL OR @TopDocuments   < 1 OR @TopDocuments   > 200 THEN 20 ELSE @TopDocuments   END;
    DECLARE @TI INT = CASE WHEN @TopInsurance   IS NULL OR @TopInsurance   < 1 OR @TopInsurance   > 200 THEN 20 ELSE @TopInsurance   END;
    DECLARE @TM INT = CASE WHEN @TopMaintenance IS NULL OR @TopMaintenance < 1 OR @TopMaintenance > 200 THEN 10 ELSE @TopMaintenance END;
    DECLARE @TV INT = CASE WHEN @TopViolations  IS NULL OR @TopViolations  < 1 OR @TopViolations  > 500 THEN 50 ELSE @TopViolations  END;

    ----------------------------------------------------------------
    -- GET
    ----------------------------------------------------------------
    IF @ActionType = 'GET'
    BEGIN
        SELECT
              v.*
            , cu.vehicleWithUsersID AS CurrentCustodyID
            , cu.vehicleUserID_FK   AS CurrentUserID
            , cu.startDate          AS CustodyStartDate
        FROM VIC.Vehicles v
        OUTER APPLY
        (
            SELECT TOP 1
                  w.vehicleWithUsersID
                , w.vehicleUserID_FK
                , w.startDate
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = v.chassisNumber
              AND w.endDate IS NULL
            ORDER BY w.startDate DESC
        ) cu
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (
                (@vehicleID IS NOT NULL AND v.vehicleID = @vehicleID)
                OR
                (@CH IS NOT NULL AND v.chassisNumber = @CH)
              );
        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST
    ----------------------------------------------------------------
    IF @ActionType = N'LIST'
    BEGIN
        SELECT
              v.vehicleID
            , v.chassisNumber
            , v.ownerID_FK
            , ownerT.typesName_A        AS ownerName
            , v.ManufacturerNameID_FK
            , manufacturerT.typesName_A AS manufacturerName
            , v.vehicleModelID_FK
            , modelT.typesName_A        AS modelName
            , v.vehicleColorID_FK
            , colorT.typesName_A        AS colorName
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.yearModel
            , v.entryDate
            , v.isActive
            , CASE WHEN ISNULL(v.isActive, 1) = 1
                   THEN N'مفعل' ELSE N'موقوف'
              END                        AS isActiveText
            , v.vehicleStatusID_FK
            , ISNULL(statusT.typesName_A, N'غير محدد') AS vehicleStatusName
            , cu.vehicleUserID_FK       AS CurrentUserID
            , cu.startDate              AS CustodyStartDate
            , CONVERT(NVARCHAR(10), cu.startDate, 23) AS CustodyStartDateText
            , cu.UserFullName_Snapshot  AS CurrentUserName
            , CASE WHEN cu.vehicleUserID_FK IS NOT NULL
                   THEN CAST(cu.vehicleUserID_FK AS NVARCHAR(20)) + N' - ' + ISNULL(cu.UserFullName_Snapshot, N'')
                   ELSE NULL END          AS CurrentUserDisplay
            , CASE WHEN cu.vehicleUserID_FK IS NOT NULL
                   THEN N'عهدة نشطة' ELSE N'بدون عهدة'
              END                        AS custodyStatusText
            , CASE
                  WHEN NOT EXISTS(SELECT 1 FROM VIC.vehicleDocument d WHERE d.chassisNumber_FK = v.chassisNumber)
                   AND NOT EXISTS(SELECT 1 FROM VIC.VehicleInsurance i WHERE i.chassisNumber_FK = v.chassisNumber)
                       THEN N'no_both'
                  WHEN NOT EXISTS(SELECT 1 FROM VIC.vehicleDocument d WHERE d.chassisNumber_FK = v.chassisNumber)
                       THEN N'no_docs'
                  WHEN NOT EXISTS(SELECT 1 FROM VIC.VehicleInsurance i WHERE i.chassisNumber_FK = v.chassisNumber)
                       THEN N'no_ins'
                  ELSE N'ok'
              END                        AS recordStatus
        FROM VIC.Vehicles v
        LEFT JOIN VIC.TypesRoot ownerT        ON ownerT.typesID = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(v.ownerID_FK)), N'')) AND ownerT.typesRoot_ParentID = 1
        LEFT JOIN VIC.TypesRoot manufacturerT ON manufacturerT.typesID = v.ManufacturerNameID_FK
        LEFT JOIN VIC.TypesRoot modelT        ON modelT.typesID = v.vehicleModelID_FK
        LEFT JOIN VIC.TypesRoot colorT        ON colorT.typesID = v.vehicleColorID_FK
        LEFT JOIN VIC.TypesRoot statusT       ON statusT.typesID = v.vehicleStatusID_FK
        OUTER APPLY (
            SELECT TOP 1
                  vw.vehicleUserID_FK
                , vw.startDate
                , vw.UserFullName_Snapshot
            FROM VIC.vehicleWithUsers vw
            WHERE vw.chassisNumber_FK = v.chassisNumber
              AND vw.endDate IS NULL
            ORDER BY vw.startDate DESC
        ) cu
        WHERE 1=1
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@vehicleID IS NULL OR v.vehicleID = @vehicleID)
          AND (@chassisNumber IS NULL OR v.chassisNumber = @chassisNumber)
          AND (@plateLetters IS NULL OR v.plateLetters LIKE '%' + @plateLetters + '%')
          AND (@plateNumbers IS NULL OR v.plateNumbers LIKE '%' + @plateNumbers + '%')
          AND (
                @hasCustody IS NULL
                OR (@hasCustody = 1 AND cu.vehicleUserID_FK IS NOT NULL)
                OR (@hasCustody = 0 AND cu.vehicleUserID_FK IS NULL)
              )
          AND (
                @q IS NULL
                OR v.chassisNumber LIKE '%' + @q + '%'
                OR v.armyNumber LIKE '%' + @q + '%'
                OR v.plateNumbers LIKE '%' + @q + '%'
                OR cu.UserFullName_Snapshot LIKE '%' + @q + '%'
              )
        ORDER BY v.vehicleID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    ----------------------------------------------------------------
    -- SEARCH
    ----------------------------------------------------------------
    IF @ActionType = 'SEARCH'
    BEGIN
        SELECT TOP (@PS)
              v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
        FROM VIC.Vehicles v
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (
                @Q_Trim IS NOT NULL
                AND (
                    v.chassisNumber LIKE N'%' + @Q_Trim + N'%'
                    OR v.armyNumber LIKE N'%' + @Q_Trim + N'%'
                    OR v.plateLetters LIKE N'%' + @Q_Trim + N'%'
                    OR v.plateNumbers LIKE N'%' + @Q_Trim + N'%'
                    )
              )
        ORDER BY v.entryDate DESC;
        RETURN;
    END

    ----------------------------------------------------------------
    -- AVAILABLE_FOR_CUSTODY
    ----------------------------------------------------------------
    IF @ActionType = 'AVAILABLE_FOR_PERIODIC'
BEGIN
    SELECT v.chassisNumber, v.armyNumber, v.plateLetters, v.plateNumbers
    FROM VIC.Vehicles v
    WHERE v.vehicleStatusID_FK <> 262
      AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
      AND NOT EXISTS (SELECT 1 FROM VIC.VehicleMaintenanceGroup vmg WHERE vmg.chassisNumber_FK = v.chassisNumber AND vmg.Active = 1)
    ORDER BY v.chassisNumber;
END

IF @ActionType = 'AVAILABLE_FOR_CUSTODY'
    BEGIN
        SELECT
              v.vehicleID
            , v.chassisNumber
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
        FROM VIC.Vehicles v
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = v.chassisNumber
              AND w.endDate IS NULL
        )
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND ISNULL(v.isActive, 1) = 1
          AND v.vehicleStatusID_FK = 260
        ORDER BY v.entryDate DESC;
        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_DOCUMENT_TYPES
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_DOCUMENT_TYPES'
    BEGIN
        SELECT
              dt.vehicleDocumentTypeID
            , dt.vehicleDocumentTypeName_A
            , dt.vehicleDocumentTypeName_E
            , dt.vehicleDocumentTypeActive
        FROM VIC.VehiclesDocumentType AS dt
        WHERE (@ActiveOnly = 0 OR dt.vehicleDocumentTypeActive = 1)
        ORDER BY dt.vehicleDocumentTypeName_A;
        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_DOCUMENTS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_DOCUMENTS'
    BEGIN
        SELECT
              d.vehicleDocumentID
            , d.chassisNumber_FK
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , d.vehicleDocumentTypeID_FK
            , dt.vehicleDocumentTypeName_A
            , dt.vehicleDocumentTypeName_E
            , d.vehicleDocumentNo
            , d.vehicleDocumentStartDate
            , d.vehicleDocumentEndDate
            , CASE
                WHEN d.vehicleDocumentEndDate IS NOT NULL AND d.vehicleDocumentEndDate < CAST(GETDATE() AS DATE)
                    THEN N'منتهي'
                WHEN d.vehicleDocumentEndDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), d.vehicleDocumentEndDate) BETWEEN 0 AND 30
                    THEN N'قارب الانتهاء'
                ELSE N'ساري'
              END                    AS DocumentStatus
            , CASE
                WHEN d.vehicleDocumentEndDate IS NOT NULL AND d.vehicleDocumentEndDate < CAST(GETDATE() AS DATE)
                    THEN N'expired'
                WHEN d.vehicleDocumentEndDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), d.vehicleDocumentEndDate) BETWEEN 0 AND 30
                    THEN N'expiring'
                ELSE N'active'
              END                    AS DocumentStatusCode
            , DATEDIFF(DAY, GETDATE(), d.vehicleDocumentEndDate) AS DaysToExpire
        FROM VIC.vehicleDocument d
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = d.chassisNumber_FK
        LEFT JOIN VIC.VehiclesDocumentType dt ON dt.vehicleDocumentTypeID = d.vehicleDocumentTypeID_FK
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@CH IS NULL OR d.chassisNumber_FK = @CH)
        ORDER BY d.chassisNumber_FK, d.vehicleDocumentTypeID_FK, d.vehicleDocumentEndDate DESC;
        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_INSURANCE
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_INSURANCE'
    BEGIN
        SELECT
              ins.VehicleInsuranceID
            , ins.chassisNumber_FK
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , ins.InsuranceOpertionType_FK
            , op.typesName_A       AS InsuranceOpertionTypeName
            , ins.InsuranceTypeID_FK
            , it.typesName_A       AS InsuranceTypeName
            , ins.Source
            , ins.StartInsurance
            , ins.EndInsurance
            , ins.Amount
            , ins.Note
            , CASE
                WHEN ins.EndInsurance IS NOT NULL AND ins.EndInsurance < CAST(GETDATE() AS DATE)
                    THEN N'منتهي'
                WHEN ins.EndInsurance IS NOT NULL AND DATEDIFF(DAY, GETDATE(), ins.EndInsurance) BETWEEN 0 AND 30
                    THEN N'قارب الانتهاء'
                ELSE N'ساري'
              END                    AS InsuranceStatus
            , CASE
                WHEN ins.EndInsurance IS NOT NULL AND ins.EndInsurance < CAST(GETDATE() AS DATE)
                    THEN N'expired'
                WHEN ins.EndInsurance IS NOT NULL AND DATEDIFF(DAY, GETDATE(), ins.EndInsurance) BETWEEN 0 AND 30
                    THEN N'expiring'
                ELSE N'active'
              END                    AS InsuranceStatusCode
            , DATEDIFF(DAY, GETDATE(), ins.EndInsurance) AS DaysToExpire
        FROM VIC.VehicleInsurance ins
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = ins.chassisNumber_FK
        LEFT JOIN VIC.TypesRoot op ON op.typesID = ins.InsuranceOpertionType_FK
        LEFT JOIN VIC.TypesRoot it ON it.typesID = ins.InsuranceTypeID_FK
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@CH IS NULL OR ins.chassisNumber_FK = @CH)
          AND ins.InsuranceTypeID_FK IS NOT NULL
          AND (
                @InsuranceDays IS NULL
                OR (ins.EndInsurance IS NOT NULL AND DATEDIFF(DAY, GETDATE(), ins.EndInsurance) BETWEEN 0 AND @InsuranceDays)
              )
          AND (
                @IncludeExpired = 1
                OR ins.EndInsurance IS NULL
                OR ins.EndInsurance >= GETDATE()
              )
        ORDER BY ins.EndInsurance ASC, ins.VehicleInsuranceID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    ----------------------------------------------------------------
    -- GET_PROFILE  (multi-result-set for VehicleDetails page)
    -- Result-set order: 1=Summary  2=Documents  3=Insurance  4=Maintenance  5=Violations
    ----------------------------------------------------------------
    IF @ActionType = 'GET_PROFILE'
    BEGIN
        -- 1) Summary
        SELECT
              v.vehicleID
            , v.chassisNumber
            , v.ownerID_FK
            , ISNULL(ownerT.typesName_A, v.ownerID_FK) AS ownerName
            , v.ManufacturerNameID_FK
            , manufacturerT.typesName_A AS manufacturerName
            , v.vehicleModelID_FK
            , modelT.typesName_A        AS modelName
            , v.vehicleColorID_FK
            , colorT.typesName_A        AS colorName
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.yearModel
            , v.capacity
            , v.serialNumber
            , v.vehicleNote
            , v.entryDate
            , v.isActive
            , v.vehicleStatusID_FK
            , ISNULL(statusT.typesName_A, N'غير محدد') AS vehicleStatusName
            , cu.vehicleUserID_FK    AS CurrentUserID
            , cu.startDate           AS CustodyStartDate
            , cu.UserFullName_Snapshot  AS CurrentUserName
            , CASE WHEN cu.vehicleUserID_FK IS NOT NULL
                   THEN CAST(cu.vehicleUserID_FK AS NVARCHAR(20)) + N' - ' + ISNULL(cu.UserFullName_Snapshot, N'')
                   ELSE NULL END          AS CurrentUserDisplay
            , (SELECT COUNT(*) FROM VIC.vehicleDocument d
               WHERE d.chassisNumber_FK = v.chassisNumber
                 AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
            ) AS DocumentsCount
            , (SELECT COUNT(*) FROM VIC.VehicleInsurance i
               WHERE i.chassisNumber_FK = v.chassisNumber
                 AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)
            ) AS InsuranceCount
            , (SELECT COUNT(*) FROM VIC.VehicleMaintenance m
               WHERE m.chassisNumber_FK = v.chassisNumber
                 AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
            ) AS MaintenanceCount
            , (SELECT COUNT(*) FROM VIC.Violations vi
               WHERE vi.chassisNumber_FK = v.chassisNumber
                 AND (@IdaraID_BIG IS NULL OR vi.IdaraID_FK = @IdaraID_BIG)
            ) AS ViolationsCount
        FROM VIC.Vehicles v
        LEFT JOIN VIC.TypesRoot ownerT        ON ownerT.typesID = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(v.ownerID_FK)), N'')) AND ownerT.typesRoot_ParentID = 1
        LEFT JOIN VIC.TypesRoot manufacturerT ON manufacturerT.typesID = v.ManufacturerNameID_FK
        LEFT JOIN VIC.TypesRoot modelT        ON modelT.typesID = v.vehicleModelID_FK
        LEFT JOIN VIC.TypesRoot colorT        ON colorT.typesID = v.vehicleColorID_FK
        LEFT JOIN VIC.TypesRoot statusT       ON statusT.typesID = v.vehicleStatusID_FK
        OUTER APPLY
        (
            SELECT TOP 1 w.vehicleUserID_FK, w.startDate, w.UserFullName_Snapshot
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = v.chassisNumber
              AND w.endDate IS NULL
            ORDER BY w.startDate DESC
        ) cu
        WHERE (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (
                (@vehicleID IS NOT NULL AND v.vehicleID = @vehicleID)
                OR (@CH IS NOT NULL AND v.chassisNumber = @CH)
              );

        -- 2) Documents
        SELECT TOP (@TD)
              d.vehicleDocumentID
            , d.chassisNumber_FK
            , d.vehicleDocumentTypeID_FK
            , dt.vehicleDocumentTypeName_A
            , dt.vehicleDocumentTypeName_E
            , d.vehicleDocumentNo
            , d.vehicleDocumentStartDate
            , d.vehicleDocumentEndDate
            , d.entryDate
        FROM VIC.vehicleDocument d
        LEFT JOIN VIC.VehiclesDocumentType dt ON dt.vehicleDocumentTypeID = d.vehicleDocumentTypeID_FK
        WHERE d.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
            CASE WHEN d.vehicleDocumentEndDate IS NULL THEN 1 ELSE 0 END,
            d.vehicleDocumentEndDate ASC,
            d.entryDate DESC;

        -- 3) Insurance
        SELECT TOP (@TI)
              ins.VehicleInsuranceID
            , ins.chassisNumber_FK
            , ins.InsuranceOpertionType_FK
            , ins.InsuranceTypeID_FK
            , ins.Source
            , ins.StartInsurance
            , ins.EndInsurance
            , ins.Amount
            , ins.Note
            , ins.active
        FROM VIC.VehicleInsurance ins
        WHERE ins.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR ins.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
            CASE WHEN ISNULL(ins.active, 0) = 1 THEN 0 ELSE 1 END,
            CASE WHEN ins.EndInsurance IS NULL THEN 1 ELSE 0 END,
            ins.EndInsurance ASC,
            ins.VehicleInsuranceID DESC;

        -- 4) Maintenance Orders
        SELECT TOP (@TM)
              m.MaintOrdID
            , m.MaintOrdTypeID_FK
            , m.chassisNumber_FK
            , m.MaintOrdStartDate
            , m.MaintOrdEndDate
            , m.MaintOrdDesc
            , m.MaintOrdActive
            , m.entryDate
            , m.entryData
            , m.hostName
            , m.IdaraID_FK
            , mot.typesName_A             AS MaintOrdTypeName
            , (SELECT COUNT(*)
               FROM VIC.MaintenanceDetails md
               WHERE md.MaintOrdID_FK = m.MaintOrdID
            ) AS DetailsCount
        FROM VIC.VehicleMaintenance m
        LEFT JOIN VIC.TypesRoot mot ON mot.typesID = m.MaintOrdTypeID_FK
        WHERE m.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
            CASE WHEN ISNULL(m.MaintOrdActive, 0) = 1 THEN 0 ELSE 1 END,
            m.MaintOrdStartDate DESC,
            m.MaintOrdID DESC;

        -- 5) Violations
        SELECT TOP (@TV)
              vln.violationID
            , vln.violationTypeRoot_FK
            , vln.chassisNumber_FK
            , vln.violationDate
            , vln.violationPrice
            , vln.violationLocation
            , vln.PaymentDate
            , vln.entryPayment
            , vln.entrydata
            , vln.entrydate
            , vln.hostname
            , vln.IdaraID_FK
            , tr.typesName_A             AS ViolationTypeName
            , CASE WHEN vln.PaymentDate IS NULL THEN N'غير مسددة' ELSE N'مسددة' END AS PaymentStatusName
        FROM VIC.Violations vln
        LEFT JOIN VIC.TypesRoot tr ON tr.typesID = vln.violationTypeRoot_FK
        WHERE vln.chassisNumber_FK = @CH
          AND (@IdaraID_BIG IS NULL OR vln.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
            CASE WHEN vln.violationDate IS NULL THEN 1 ELSE 0 END,
            vln.violationDate DESC,
            vln.violationID DESC;

        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء بيانات المركبات', 1;
        RETURN;
    END
END

GO

