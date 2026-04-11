
/* =========================================================
   Description:
   قائمة وثائق المركبات مع Paging وفلاتر اختيارية.
   - وضع List العادي (القديم) يعمل بدون أي تغييرات على الاستدعاءات الحالية.
   - وضع Expiring يعمل عند تمرير @ExpireDays (مع خيار IncludeExpired).
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[VehicleDocument_List_DL]
(
      @chassisNumber          NVARCHAR(100) = NULL
    , @vehicleDocumentTypeID  INT = NULL
    , @DocumentNo             NVARCHAR(100) = NULL
    , @OnlyActiveNow          BIT = 0
    , @Page                   INT = 1
    , @PageSize               INT = 50

    /* إضافات الدمج (اختيارية) */
    , @ExpireDays             INT = NULL       -- إذا NULL: ما يطبق فلتر الانتهاء
    , @IncludeExpired         BIT = 1          -- فعال فقط إذا @ExpireDays IS NOT NULL

    , @idaraID_FK              NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @Page IS NULL OR @Page < 1 THEN 1 ELSE @Page END;
    DECLARE @PS INT = CASE WHEN @PageSize IS NULL OR @PageSize < 1 OR @PageSize > 200 THEN 50 ELSE @PageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @DN NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@DocumentNo)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @Today DATETIME = GETDATE();
    DECLARE @D INT = CASE
                        WHEN @ExpireDays IS NULL THEN NULL
                        WHEN @ExpireDays < 0 THEN 30
                        ELSE @ExpireDays
                     END;

    DECLARE @CutoffDate DATETIME = CASE
                                     WHEN @D IS NULL THEN NULL
                                     ELSE DATEADD(DAY, @D, CAST(@Today AS DATE))
                                   END;

    SELECT
          d.vehicleDocumentID
        , d.chassisNumber_FK
        , d.vehicleDocumentTypeID_FK
        , d.vehicleDocumentNo
        , d.vehicleDocumentStartDate
        , d.vehicleDocumentEndDate
        , d.entryDate
        , d.entryData

        , t.vehicleDocumentTypeName_A
        , t.vehicleDocumentTypeName_E

        , v.plateLetters
        , v.plateNumbers
        , v.yearModel
    FROM VIC.vehicleDocument AS d
    INNER JOIN VIC.VehiclesDocumentType AS t
        ON t.vehicleDocumentTypeID = d.vehicleDocumentTypeID_FK
    LEFT JOIN VIC.Vehicles AS v
        ON v.chassisNumber = d.chassisNumber_FK
    WHERE 1 = 1
      AND (@CH IS NULL OR d.chassisNumber_FK = @CH)
      AND (@vehicleDocumentTypeID IS NULL OR d.vehicleDocumentTypeID_FK = @vehicleDocumentTypeID)
      AND (@DN IS NULL OR d.vehicleDocumentNo = @DN)
      AND (@IdaraID_BIG IS NULL OR d.IdaraID_FK = @IdaraID_BIG)

      /* فلتر الساري الآن (القديم) */
      AND (
            @OnlyActiveNow = 0
            OR d.vehicleDocumentEndDate IS NULL
            OR d.vehicleDocumentEndDate >= @Today
          )

      /* فلتر Expiring (الجديد) */
      AND (
            @D IS NULL
            OR (
                 d.vehicleDocumentEndDate IS NOT NULL
                 AND (
                       (@IncludeExpired = 1 AND d.vehicleDocumentEndDate <= @CutoffDate)
                    OR (@IncludeExpired = 0 AND d.vehicleDocumentEndDate >= @Today AND d.vehicleDocumentEndDate <= @CutoffDate)
                 )
               )
          )
    ORDER BY
        d.vehicleDocumentEndDate ASC,
        d.vehicleDocumentID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END