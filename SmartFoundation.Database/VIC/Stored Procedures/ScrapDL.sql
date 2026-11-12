CREATE   PROCEDURE [VIC].[ScrapDL]
    @ActionType    NVARCHAR(100) = N'LIST'
  , @scrapID       BIGINT        = NULL
  , @vehicleID     INT           = NULL
  , @chassisNumber NVARCHAR(200) = NULL
  , @Status        NVARCHAR(40)  = NULL
  , @DateFrom      DATETIME      = NULL
  , @DateTo        DATETIME      = NULL
  , @pageNumber    INT           = 1
  , @pageSize      INT           = 50
  , @idaraID_FK    NVARCHAR(10)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID_BIG BIGINT = TRY_CAST(@idaraID_FK AS BIGINT);

    DECLARE @CH  NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT @CH = v.chassisNumber,
               @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.vehicleID = @vehicleID;
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH;
    END

    ----------------------------------------------------------------
    -- GET
    ----------------------------------------------------------------
    IF @ActionType = N'GET'
    BEGIN
        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        IF @scrapID IS NOT NULL
        BEGIN
            SELECT
                vs.ScrapID,
                vs.chassisNumber_FK,
                vs.IdaraID_FK,
                vs.ScrapDate,
                vs.ScrapTypeID_FK,
                vs.RefNo,
                vs.Reason,
                vs.Note,
                vs.ApprovedByUserID,
                vs.ApprovedDate,
                vs.Status,
                vs.entryDate,
                vs.entryData,
                vs.hostName,
                v.vehicleID,
                v.chassisNumber,
                v.plateLetters,
                v.plateNumbers,
                v.armyNumber,
                v.vehicleStatusID_FK
            FROM VIC.VehicleScrap vs
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = vs.chassisNumber_FK
               AND v.IdaraID_FK = vs.IdaraID_FK
            WHERE vs.ScrapID = @scrapID
              AND vs.IdaraID_FK = @IdaraID_BIG;

            RETURN;
        END

        IF @VID IS NOT NULL
        BEGIN
            SELECT TOP 1
                vs.ScrapID,
                vs.chassisNumber_FK,
                vs.IdaraID_FK,
                vs.ScrapDate,
                vs.ScrapTypeID_FK,
                vs.RefNo,
                vs.Reason,
                vs.Note,
                vs.ApprovedByUserID,
                vs.ApprovedDate,
                vs.Status,
                vs.entryDate,
                vs.entryData,
                vs.hostName,
                v.vehicleID,
                v.chassisNumber,
                v.plateLetters,
                v.plateNumbers,
                v.armyNumber,
                v.vehicleStatusID_FK
            FROM VIC.VehicleScrap vs
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = vs.chassisNumber_FK
               AND v.IdaraID_FK = vs.IdaraID_FK
            WHERE v.vehicleID = @VID
              AND vs.IdaraID_FK = @IdaraID_BIG
            ORDER BY vs.ScrapID DESC;

            RETURN;
        END

        RETURN;
    END

    ----------------------------------------------------------------
    -- LIST
    ----------------------------------------------------------------
    IF @ActionType = N'LIST'
    BEGIN
        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @chassisFilter NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        DECLARE @offset INT = (@pageNumber - 1) * @pageSize;

        ;WITH cte AS (
            SELECT
                vs.ScrapID,
                vs.chassisNumber_FK,
                vs.IdaraID_FK,
                vs.ScrapDate,
                vs.ScrapTypeID_FK,
                vs.RefNo,
                vs.Reason,
                vs.Note,
                vs.ApprovedByUserID,
                vs.ApprovedDate,
                vs.Status,
                vs.entryDate,
                vs.entryData,
                vs.hostName,
                v.vehicleID,
                v.chassisNumber,
                v.plateLetters,
                v.plateNumbers,
                v.armyNumber,
                v.vehicleStatusID_FK,
                ROW_NUMBER() OVER (ORDER BY vs.ScrapID DESC) AS RowNum,
                COUNT(*) OVER () AS TotalRows
            FROM VIC.VehicleScrap vs
            INNER JOIN VIC.Vehicles v
                ON v.chassisNumber = vs.chassisNumber_FK
               AND v.IdaraID_FK = vs.IdaraID_FK
            WHERE vs.IdaraID_FK = @IdaraID_BIG
              AND (@Status IS NULL OR vs.Status = @Status)
              AND (@VID IS NULL OR v.vehicleID = @VID)
              AND (@chassisFilter IS NULL OR vs.chassisNumber_FK LIKE N'%' + @chassisFilter + N'%')
              AND (@DateFrom IS NULL OR vs.ScrapDate >= @DateFrom)
              AND (@DateTo IS NULL OR vs.ScrapDate < DATEADD(DAY, 1, @DateTo))
        )
        SELECT
            ScrapID,
            chassisNumber_FK,
            IdaraID_FK,
            ScrapDate,
            ScrapTypeID_FK,
            RefNo,
            Reason,
            Note,
            ApprovedByUserID,
            ApprovedDate,
            Status,
            entryDate,
            entryData,
            hostName,
            vehicleID,
            chassisNumber,
            plateLetters,
            plateNumbers,
            armyNumber,
            vehicleStatusID_FK,
            TotalRows
        FROM cte
        WHERE RowNum > @offset
          AND RowNum <= @offset + @pageSize
        ORDER BY RowNum;

        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown
    ----------------------------------------------------------------
    BEGIN
        THROW 50001, N'نوع العملية غير معروف في إجراء بيانات الإتلاف', 1;
        RETURN;
    END
END

GO

