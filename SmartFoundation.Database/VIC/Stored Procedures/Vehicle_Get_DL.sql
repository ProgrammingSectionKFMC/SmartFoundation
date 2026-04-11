
/* =========================================================
   Description:
   جلب بيانات مركبة واحدة من VIC.Vehicles حسب رقم الهيكل (chassisNumber).
   يتضمن خيار التحقق من صلاحية القائمة عبر fn_UserHasMenuPermission عند SkipPermission=0.
   Type: READ (GET)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_Get_DL]
(
      @UsersID        INT = NULL
    , @MenuLink       NVARCHAR(1000) = NULL
    , @SkipPermission BIT = 1
    , @chassisNumber  NVARCHAR(100)
    , @idaraID_FK     NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MenuLink_Trim NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@MenuLink)), N'');
    DECLARE @CH_Trim       NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    IF ISNULL(@SkipPermission, 1) = 0 AND @MenuLink_Trim IS NOT NULL
    BEGIN
        IF dbo.fn_UserHasMenuPermission(@UsersID, @MenuLink_Trim) = 0
            THROW 50001, N'عفواً لا تملك صلاحية', 1;
    END

    IF @CH_Trim IS NULL
        THROW 50001, N'chassisNumber مطلوب', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH_Trim
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
    )
        THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

    SELECT v.*
    FROM VIC.Vehicles v
    WHERE v.chassisNumber = @CH_Trim
      AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG);
END