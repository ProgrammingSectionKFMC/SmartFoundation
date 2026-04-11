
/* =========================================================
   Description:
   قائمة خطط الصيانة الدورية مع فلاتر اختيارية + Paging
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenancePlan_List_DL]
(
      @chassisNumber NVARCHAR(100) = NULL
    , @active        BIT = NULL
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    SELECT
          p.PlanID
        , p.chassisNumber_FK
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
      AND (@CH IS NULL OR p.chassisNumber_FK = @CH)
      AND (@active IS NULL OR p.planActive = @active)
    ORDER BY
        p.PlanID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END