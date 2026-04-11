
/* =========================================================
   Description:
   قائمة تأمينات المركبات من جدول VIC.VehicleInsurance مع دعم:
   - فلاتر عامة (نوع التأمين/نوع العملية/نشط/تواريخ البداية/شاصي)
   - (اختياري) فلتر الانتهاء خلال X يوم مع خيار IncludeExpired
   
   Type: READ (LIST)
========================================================= */
CREATE   PROCEDURE [VIC].[VehicleInsurance_List_DL]
(
      @chassisNumber     NVARCHAR(100) = NULL
    , @InsuranceTypeID   INT = NULL
    , @OperationTypeID   INT = NULL
    , @Active            BIT = NULL
    , @FromDate          DATETIME = NULL
    , @ToDate            DATETIME = NULL
    , @Page              INT = 1
    , @PageSize          INT = 50

    -- Expiring filter (دمج VehicleInsurance_Expiring_List)
    , @Days              INT = NULL          -- إذا NULL: لا يطبق فلتر الانتهاء
    , @IncludeExpired    BIT = 1             -- يستخدم فقط إذا @Days ليست NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P    INT = CASE WHEN @Page IS NULL OR @Page < 1 THEN 1 ELSE @Page END;
    DECLARE @PS   INT = CASE WHEN @PageSize IS NULL OR @PageSize < 1 OR @PageSize > 200 THEN 50 ELSE @PageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @D INT = CASE
                        WHEN @Days IS NULL THEN NULL
                        WHEN @Days < 0 THEN 30
                        ELSE @Days
                     END;

    DECLARE @Today DATETIME = GETDATE();
    DECLARE @CutoffDate DATETIME = CASE
                                      WHEN @D IS NULL THEN NULL
                                      ELSE DATEADD(DAY, @D, CAST(@Today AS DATE))
                                   END;

    SELECT
          i.VehicleInsuranceID
        , i.chassisNumber_FK
        , i.InsuranceOpertionType_FK
        , i.InsuranceTypeID_FK
        , i.Source
        , i.StartInsurance
        , i.EndInsurance
        , i.Amount
        , i.Note
        , i.active
        , i.entryDate
        , i.entryData

        , v.plateLetters
        , v.plateNumbers
        , v.yearModel
    FROM VIC.VehicleInsurance AS i
    LEFT JOIN VIC.Vehicles AS v
        ON v.chassisNumber = i.chassisNumber_FK
    WHERE 1=1
      AND (@CH IS NULL OR i.chassisNumber_FK = @CH)
      AND (@InsuranceTypeID IS NULL OR i.InsuranceTypeID_FK = @InsuranceTypeID)
      AND (@OperationTypeID IS NULL OR i.InsuranceOpertionType_FK = @OperationTypeID)
      AND (@Active IS NULL OR i.active = @Active)
      AND (@FromDate IS NULL OR i.StartInsurance >= @FromDate)
      AND (@ToDate   IS NULL OR i.StartInsurance <  DATEADD(DAY, 1, @ToDate))
      AND
      (
            @D IS NULL
            OR
            (
                i.EndInsurance IS NOT NULL
                AND
                (
                    (@IncludeExpired = 1 AND i.EndInsurance <= @CutoffDate)
                    OR
                    (@IncludeExpired = 0 AND i.EndInsurance >= @Today AND i.EndInsurance <= @CutoffDate)
                )
            )
      )
    ORDER BY
        CASE WHEN @D IS NULL THEN i.EndInsurance END DESC,
        CASE WHEN @D IS NOT NULL THEN i.EndInsurance END ASC,
        i.VehicleInsuranceID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END