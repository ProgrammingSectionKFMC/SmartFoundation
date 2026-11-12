CREATE   PROCEDURE [VIC].[MaintenancePlanDL]
(
      @ActionType        NVARCHAR(100)
    , @vehicleID         INT           = NULL
    , @idaraID_FK        NVARCHAR(10)  = NULL
    , @planID            INT           = NULL
    , @chassisNumber     NVARCHAR(200) = NULL
    , @active            BIT           = NULL
    , @pageNumber        INT           = 1
    , @pageSize          INT           = 50
    , @maintOrdTypeID_FK INT           = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @DL_CH NVARCHAR(200);
    DECLARE @DL_VID INT;
    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @DL_CH = v.chassisNumber, @DL_VID = v.vehicleID FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @DL_CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @DL_VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @DL_CH;
    END

    ----------------------------------------------------------------
    -- GET_PLAN
    ----------------------------------------------------------------
    IF @ActionType = 'GET_PLAN'
    BEGIN
        IF @planID IS NULL OR @planID <= 0
        BEGIN
            THROW 50001, N'معرف خطة الصيانة مطلوب', 1;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleMaintenancePlan p
            WHERE p.PlanID = @planID
              AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
        )
        BEGIN
            THROW 50001, N'خطة الصيانة غير موجودة', 1;
            RETURN;
        END

        SELECT
              p.PlanID
            , p.chassisNumber_FK
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , p.periodMonths
            , p.nextDueDate
            , p.planActive
            , p.entryDate
            , p.entryData
            , p.hostName
        FROM VIC.VehicleMaintenancePlan p
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = p.chassisNumber_FK
        WHERE p.PlanID = @planID
          AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG);

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_PLANS
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_PLANS'
    BEGIN
        SELECT
              p.PlanID
            , p.chassisNumber_FK
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , p.periodMonths
            , p.nextDueDate
            , p.planActive
            , p.entryDate
            , p.entryData
            , p.hostName
        FROM VIC.VehicleMaintenancePlan p
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = p.chassisNumber_FK
        WHERE 1 = 1
          AND (@IdaraID_BIG IS NULL OR p.IdaraID_FK = @IdaraID_BIG)
          AND (@DL_CH IS NULL OR p.chassisNumber_FK = @DL_CH)
          AND (@active IS NULL OR p.planActive = @active)
        ORDER BY
            p.PlanID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST_TEMPLATES
    ----------------------------------------------------------------
    IF @ActionType = 'LIST_TEMPLATES'
    BEGIN
        SELECT
              mt.TemplateID
            , mt.MaintOrdTypeID_FK
            , mot.typesName_A AS MaintOrdTypeName_A
            , mot.typesName_E AS MaintOrdTypeName_E
            , mt.typesID_FK
            , t.typesName_A   AS TemplateItemName_A
            , t.typesName_E   AS TemplateItemName_E
            , mt.TemplateOrder
            , mt.templateActive
            , mt.entryDate
            , mt.entryData
            , mt.hostName
        FROM VIC.MaintenanceTemplate mt
        LEFT JOIN VIC.TypesRoot mot
            ON mot.typesID = mt.MaintOrdTypeID_FK
        LEFT JOIN VIC.TypesRoot t
            ON t.typesID = mt.typesID_FK
        WHERE (@maintOrdTypeID_FK IS NULL OR mt.MaintOrdTypeID_FK = @maintOrdTypeID_FK)
          AND (@active IS NULL OR mt.templateActive = @active)
        ORDER BY
              mt.MaintOrdTypeID_FK
            , mt.TemplateOrder
            , mt.TemplateID;

        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء بيانات خطط الصيانة', 1;
        RETURN;
    END
END

GO

