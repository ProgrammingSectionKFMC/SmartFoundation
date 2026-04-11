
/* =========================================================
   Description:
   إرجاع قائمة المركبات من VIC.Vehicles مع Paging وفلاتر اختيارية:
   - ownerID_FK
   - plateLetters
   - plateNumbers
   - HasCustody (هل عليها عهدة حالية أم لا)
   ويُرجع كذلك:
   - CurrentUserID / CustodyStartDate
   - vehicleStatusID_FK / VehicleStatusName
   Type: READ (LIST)
========================================================= */

CREATE PROCEDURE [VIC].[Vehicle_List_DL]
(
      @ownerID_FK    NVARCHAR(100) = NULL
    , @plateLetters  NVARCHAR(100) = NULL
    , @plateNumbers  INT = NULL
    , @hasCustody    BIT = NULL
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PN INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@PN - 1) * @PS;

    DECLARE @Owner_Trim   NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@ownerID_FK)), N'');
    DECLARE @Letters_Trim NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@plateLetters)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, @IdaraID_BIG);

    ;WITH Base AS
    (
        SELECT
              v.chassisNumber
            , v.vehicleID
            , v.ownerID_FK
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.yearModel
            , v.entryDate
            , v.isActive
            , v.vehicleStatusID_FK
            , CASE 
                  WHEN v.vehicleStatusID_FK = 262 THEN N'تالف'
                  WHEN v.vehicleStatusID_FK = 261 THEN N'غير نشط'
                  WHEN v.vehicleStatusID_FK = 260 THEN N'نشط'
                  ELSE N'غير محدد'
              END AS VehicleStatusName
        FROM VIC.Vehicles v
        WHERE 1 = 1
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@Owner_Trim   IS NULL OR v.ownerID_FK = @Owner_Trim)
          AND (@Letters_Trim IS NULL OR v.plateLetters = @Letters_Trim)
          AND (@plateNumbers IS NULL OR v.plateNumbers = @plateNumbers)
    ),
    WithCustody AS
    (
        SELECT
              b.*
            , cu.userID_FK AS CurrentUserID
            , cu.startDate AS CustodyStartDate
        FROM Base b
        OUTER APPLY
        (
            SELECT TOP (1)
                  w.userID_FK
                , w.startDate
            FROM VIC.vehicleWithUsers w
            WHERE w.chassisNumber_FK = b.chassisNumber
              AND w.endDate IS NULL
              AND (@IdaraID_INT IS NULL OR w.IdaraID_Snapshot = @IdaraID_INT)
            ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC
        ) cu
    )
    SELECT *
    FROM WithCustody
    WHERE
    (
           @hasCustody IS NULL
        OR (@hasCustody = 1 AND CurrentUserID IS NOT NULL)
        OR (@hasCustody = 0 AND CurrentUserID IS NULL)
    )
    ORDER BY entryDate DESC, chassisNumber
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END