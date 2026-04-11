
/* =========================================================
   Description:
   تقرير وثائق المركبات التي ستنتهي خلال عدد أيام محدد (@days)،
   مع خيار تضمين الوثائق المنتهية بالفعل (@includeExpired=1) أو استبعادها.
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_DocumentsExpiring_DL]
(
      @days           INT = 30
    , @includeExpired BIT = 1
    , @idaraID_FK     NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @days IS NULL OR @days < 0
        THROW 50001, N'days غير صحيح', 1;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @Today  DATE = CAST(GETDATE() AS DATE);
    DECLARE @Cutoff DATE = DATEADD(DAY, @days, @Today);

    SELECT
          d.chassisNumber_FK
        , v.plateLetters
        , v.plateNumbers
        , t.vehicleDocumentTypeName_A
        , d.vehicleDocumentNo
        , d.vehicleDocumentEndDate
        , DATEDIFF(DAY, @Today, d.vehicleDocumentEndDate) AS DaysRemaining
    FROM VIC.vehicleDocument d
    INNER JOIN VIC.VehiclesDocumentType t
        ON t.vehicleDocumentTypeID = d.vehicleDocumentTypeID_FK
    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = d.chassisNumber_FK
    WHERE d.vehicleDocumentEndDate IS NOT NULL
      AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)
      AND (
            (@includeExpired = 1 AND d.vehicleDocumentEndDate <= @Cutoff)
         OR (@includeExpired = 0 AND d.vehicleDocumentEndDate BETWEEN @Today AND @Cutoff)
          )
    ORDER BY d.vehicleDocumentEndDate ASC;
END