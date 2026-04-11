
/* =========================================================
   Description:
   إرجاع قائمة بنود أمر الصيانة (Maintenance Details) المرتبطة بـ MaintOrdID،
   مرتبة حسب تاريخ البند ثم رقم البند.
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[MaintenanceDetails_List_DL]
(
      @maintOrdID   INT
    , @idaraID_FK   NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @maintOrdID IS NULL OR @maintOrdID <= 0
        THROW 50001, N'maintOrdID مطلوب', 1;

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- تحقق وجود أمر الصيانة + (فلترة الإدارة إن تم تمريرها)
    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.VehicleMaintenance AS m
        WHERE m.MaintOrdID = @maintOrdID
          AND (@IdaraID_BIG IS NULL OR m.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'أمر الصيانة غير موجود أو لا يطابق الإدارة', 1;

    SELECT
          d.MaintDetailesID
        , d.MaintOrdID_FK
        , d.typesID_FK
        , d.SupportID_FK
        , d.CheckStatus_FK
        , d.ActionState
        , d.CorrectiveAction
        , d.FSN
        , d.MaintLevel
        , d.CurrentDate
        , d.Notes
        , d.entryDate
        , d.entryData
        , d.hostName
    FROM VIC.MaintenanceDetails AS d
    WHERE d.MaintOrdID_FK = @maintOrdID
    ORDER BY
        d.CurrentDate ASC,
        d.MaintDetailesID ASC;
END