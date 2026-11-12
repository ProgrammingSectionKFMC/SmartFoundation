CREATE   PROCEDURE [VIC].[ViolationDL]
(
      @ActionType        NVARCHAR(100)
    , @violationID       INT = NULL
    , @vehicleID         INT = NULL
    , @chassisNumber     NVARCHAR(200) = NULL
    , @violationTypeID   INT = NULL
    , @Paid              BIT = NULL
    , @FromDate          DATE = NULL
    , @ToDate            DATE = NULL
    , @Page              INT = 1
    , @PageSize          INT = 50
    , @idaraID_FK        NVARCHAR(10) = NULL
    , @ActiveOnly        BIT = 1
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

    DECLARE @P INT = CASE WHEN @Page < 1 THEN 1 ELSE @Page END;
    DECLARE @PS INT = CASE WHEN @PageSize < 1 OR @PageSize > 200 THEN 50 ELSE @PageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    ----------------------------------------------------------------
    -- GET
    ----------------------------------------------------------------
    IF @ActionType = N'GET'
    BEGIN
        SELECT *
        FROM VIC.Violations
        WHERE violationID = @violationID
          AND IdaraID_FK = @IdaraID_BIG;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST
    ----------------------------------------------------------------
    IF @ActionType = N'LIST'
    BEGIN
        SELECT
              v.violationID
            , v.violationTypeRoot_FK
            , v.chassisNumber_FK
            , v.violationDate
            , v.violationPrice
            , v.violationLocation
            , v.PaymentDate
            , v.IdaraID_FK
            , vh.vehicleID
            , vh.plateLetters
            , vh.plateNumbers
            , CASE WHEN v.PaymentDate IS NOT NULL THEN 1 ELSE 0 END AS IsPaid
            , CASE WHEN v.PaymentDate IS NOT NULL THEN N'مدفوعة' ELSE N'غير مدفوعة' END AS PaymentStatus
        FROM VIC.Violations v
        LEFT JOIN VIC.Vehicles vh ON vh.chassisNumber = v.chassisNumber_FK
        WHERE v.IdaraID_FK = @IdaraID_BIG
          AND (@CH IS NULL OR v.chassisNumber_FK = @CH)
          AND (@violationTypeID IS NULL OR v.violationTypeRoot_FK = @violationTypeID)
          AND (@Paid IS NULL OR (@Paid = 1 AND v.PaymentDate IS NOT NULL) OR (@Paid = 0 AND v.PaymentDate IS NULL))
          AND (@FromDate IS NULL OR v.violationDate >= @FromDate)
          AND (@ToDate IS NULL OR v.violationDate < DATEADD(DAY,1,@ToDate))
        ORDER BY v.violationDate DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- LOOKUPS
    ----------------------------------------------------------------
    IF @ActionType = N'LOOKUPS'
    BEGIN
        SELECT typesID, typesName_A, typesName_E
        FROM VIC.TypesRoot
        WHERE typesRoot_ParentID = 257
          AND (@ActiveOnly = 0 OR typesActive = 1);

        RETURN;
    END

    ;THROW 50001, N'نوع العملية غير معروف في إجراء بيانات المخالفات', 1;
END

GO

