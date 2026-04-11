
CREATE   PROCEDURE [VIC].[Dashboard_Get_DL]
(
      @onlyHasCustody         BIT = NULL
    , @onlyHasActiveInsurance BIT = NULL
    , @onlyHasDocExpiry       INT = NULL
    , @onlyHasInsExpiry       INT = NULL
    , @idaraID_FK             NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    SELECT
        d.*
    FROM VIC.V_Dashboard_VehicleStatus d
    WHERE 1 = 1
      AND (
            @onlyHasCustody IS NULL
            OR (@onlyHasCustody = 1 AND d.CurrentUserID IS NOT NULL)
            OR (@onlyHasCustody = 0 AND d.CurrentUserID IS NULL)
          )
      AND (
            @onlyHasActiveInsurance IS NULL
            OR (@onlyHasActiveInsurance = 1 AND d.ActiveInsuranceTypeID IS NOT NULL)
            OR (@onlyHasActiveInsurance = 0 AND d.ActiveInsuranceTypeID IS NULL)
          )
      AND (
            @onlyHasDocExpiry IS NULL
            OR (d.NextDocEndDate IS NOT NULL AND d.DocDaysToExpire BETWEEN 0 AND @onlyHasDocExpiry)
          )
      AND (
            @onlyHasInsExpiry IS NULL
            OR (d.ActiveInsuranceEndDate IS NOT NULL AND d.InsDaysToExpire BETWEEN 0 AND @onlyHasInsExpiry)
          )
      AND (
            @IdaraID_BIG IS NULL
            OR d.IdaraID_FK = @IdaraID_BIG
          )
    ORDER BY
        ISNULL(d.DocDaysToExpire, 999999),
        ISNULL(d.InsDaysToExpire, 999999),
        d.chassisNumber;
END