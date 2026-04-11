/* =========================================================
   Description:
   قائمة / تفاصيل / طباعة محاضر الإتلاف من VIC.VehicleScrap

   Modes:
   - List  : بدون @scrapID
   - Get   : مع @scrapID
   - Print : نفس Get (يستخدم في الطباعة)

   Filters:
   - chassisNumber
   - Status
   - Date range

   Type: READ (LIST / GET / PRINT)
========================================================= */
CREATE   PROCEDURE [VIC].[ScrapDL]
(
      @scrapID        BIGINT        = NULL
    , @chassisNumber  NVARCHAR(100) = NULL
    , @Status         NVARCHAR(40)  = NULL
    , @DateFrom       DATETIME      = NULL
    , @DateTo         DATETIME      = NULL
    , @pageNumber     INT           = 1
    , @pageSize       INT           = 50
    , @idaraID_FK     NVARCHAR(10)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @CH NVARCHAR(100) =
        NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @ST NVARCHAR(40) =
        NULLIF(LTRIM(RTRIM(@Status)), N'');

    IF ISNULL(@pageNumber,0) <= 0 SET @pageNumber = 1;
    IF ISNULL(@pageSize,0) <= 0 SET @pageSize = 50;

    /* =====================================================
       1) GET / PRINT
    ===================================================== */
    IF @scrapID IS NOT NULL
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleScrap s
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = s.chassisNumber_FK
            WHERE s.ScrapID = @scrapID
              AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        )
        BEGIN
            ;THROW 50001, N'محضر الإتلاف غير موجود', 1;
        END;

        SELECT
              s.ScrapID
            , s.chassisNumber_FK
            , s.IdaraID_FK
            , s.ScrapDate
            , s.ScrapTypeID_FK
            , s.RefNo
            , s.Reason
            , s.Note
            , s.Notes
            , s.Status
            , s.ApprovedByUserID
            , s.ApprovedDate
            , s.entryDate
            , s.entryData
            , s.hostName

            -- بيانات المركبة
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.vehicleStatusID_FK

        FROM VIC.VehicleScrap s
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = s.chassisNumber_FK
        WHERE s.ScrapID = @scrapID
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG);

        RETURN;
    END;

    /* =====================================================
       2) LIST
    ===================================================== */
    ;WITH Q AS
    (
        SELECT
              s.ScrapID
            , s.chassisNumber_FK
            , s.IdaraID_FK
            , s.ScrapDate
            , s.ScrapTypeID_FK
            , s.RefNo
            , s.Reason
            , s.Status
            , s.ApprovedDate

            -- بيانات المركبة
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.vehicleStatusID_FK

            , ROW_NUMBER() OVER (ORDER BY s.ScrapID DESC) AS RN
            , COUNT(*) OVER () AS TotalRows

        FROM VIC.VehicleScrap s
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = s.chassisNumber_FK

        WHERE
            (@CH IS NULL OR s.chassisNumber_FK LIKE N'%' + @CH + N'%')
        AND (@ST IS NULL OR s.Status = @ST)
        AND (@DateFrom IS NULL OR s.ScrapDate >= @DateFrom)
        AND (@DateTo IS NULL OR s.ScrapDate <= @DateTo)
        AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
    )
    SELECT *
    FROM Q
    WHERE RN BETWEEN ((@pageNumber - 1) * @pageSize) + 1
                 AND (@pageNumber * @pageSize)
    ORDER BY RN;
END