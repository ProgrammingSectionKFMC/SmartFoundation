
/* =========================================================
   Description:
   إرجاع بيانات القوائم المساعدة (Lookups) اللازمة لشاشة/وحدة المركبات:
   - TypesRoot (مع فلترة اختيارية حسب ParentID)
   - VehicleTransferRequestType (النشط فقط)
   - HandoverType (النشط فقط)
   - VehiclesDocumentType (النشط فقط)
   يتضمن خيار التحقق من صلاحية القائمة عبر fn_UserHasMenuPermission عند SkipPermission=0.
   Type: READ (LOOKUP_LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_GetLookups_DL]
(
      @UsersID            INT = NULL
    , @MenuLink           NVARCHAR(1000) = NULL
    , @SkipPermission     BIT = 1
    , @TypesRoot_ParentID INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MenuLink_Trim NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@MenuLink)), N'');

    IF ISNULL(@SkipPermission, 1) = 0 AND @MenuLink_Trim IS NOT NULL
    BEGIN
        IF dbo.fn_UserHasMenuPermission(@UsersID, @MenuLink_Trim) = 0
            THROW 50001, N'عفواً لا تملك صلاحية', 1;
    END

    /* 1) TypesRoot */
    SELECT
          t.typesID
        , t.typesName_A
        , t.typesName_E
        , t.typesDesc
        , t.typesActive
        , t.typesStartDate
        , t.typesEndDate
        , t.typesRoot_ParentID
    FROM VIC.TypesRoot t
    WHERE ISNULL(t.typesActive, 1) = 1
      AND (@TypesRoot_ParentID IS NULL OR t.typesRoot_ParentID = @TypesRoot_ParentID)
    ORDER BY ISNULL(t.typesRoot_ParentID, -1), t.typesID;

    /* 2) VehicleTransferRequestType */
    SELECT
          x.VehicleTransferRequestTypeID
        , x.VehicleTransferRequestTypeNameA
        , x.VehicleTransferRequestTypeNameE
        , x.Active
    FROM VIC.VehicleTransferRequestType x
    WHERE ISNULL(x.Active, 1) = 1
    ORDER BY x.VehicleTransferRequestTypeID;

    /* 3) HandoverType */
    SELECT
          h.handOverTypeID
        , h.handOverTypeName_A
        , h.handOverTypeName_E
        , h.active
    FROM VIC.HandoverType h
    WHERE ISNULL(h.active, 1) = 1
    ORDER BY h.handOverTypeID;

    /* 4) VehiclesDocumentType */
    SELECT
          d.vehicleDocumentTypeID
        , d.vehicleDocumentTypeName_A
        , d.vehicleDocumentTypeName_E
        , d.vehicleDocumentTypeActive
    FROM VIC.VehiclesDocumentType d
    WHERE ISNULL(d.vehicleDocumentTypeActive, 1) = 1
    ORDER BY d.vehicleDocumentTypeID;
END