
/* =========================================================
   Description:
   تقرير التأمينات التي ستنتهي خلال عدد أيام محدد (@days)،
   مع خيار تضمين المنتهي (@includeExpired) وخيار حصر النتائج على التأمينات النشطة فقط (@activeOnly).
   Type: READ (REPORT)
========================================================= */

CREATE   PROCEDURE [VIC].[Report_InsuranceExpiring_DL]
(
      @days           INT = 30
    , @includeExpired BIT = 1
    , @activeOnly     BIT = 1
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
          i.chassisNumber_FK
        , v.plateLetters
        , v.plateNumbers
        , i.EndInsurance
        , i.Amount
        , i.active
        , DATEDIFF(DAY, @Today, i.EndInsurance) AS DaysRemaining
    FROM VIC.VehicleInsurance i
    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = i.chassisNumber_FK
    WHERE i.EndInsurance IS NOT NULL
      AND (@IdaraID_BIG IS NULL OR i.IdaraID_FK = @IdaraID_BIG)
      AND (@activeOnly = 0 OR i.active = 1)
      AND (
            (@includeExpired = 1 AND i.EndInsurance <= @Cutoff)
         OR (@includeExpired = 0 AND i.EndInsurance BETWEEN @Today AND @Cutoff)
          )
    ORDER BY i.EndInsurance ASC;
END