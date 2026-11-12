
CREATE PROCEDURE [Housing].[HousingHandoverDL]
      @pageName_         NVARCHAR(400)
    , @idaraID           INT
    , @entrydata         INT
    , @hostname          NVARCHAR(400)
    , @LastActionTypeID  INT
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- تحديد مصدر الإجراءات المعتمد للإدارة
    --
    -- إذا وجد أي سجل نشط خاص بالإدارة:
    --   استخدام سجلات الإدارة فقط.
    --
    -- إذا لم يوجد أي سجل نشط خاص بالإدارة:
    --   استخدام السجلات الافتراضية IdaraID_FK IS NULL.
    --
    -- القرار على مستوى الإدارة بالكامل، وليس لكل صلاحية.
    ------------------------------------------------------------

    DECLARE @UseDepartmentActions BIT = 0;

    IF EXISTS
    (
        SELECT 1
        FROM Housing.Buildinghandover h
        WHERE h.IdaraID_FK = @idaraID
          AND h.BuildinghandoverActive = 1
    )
    BEGIN
        SET @UseDepartmentActions = 1;
    END;

    ------------------------------------------------------------
-- 1. Buildinghandover Data
-- Materialize the complete view before applying filters
------------------------------------------------------------

DROP TABLE IF EXISTS #HandoverBuildings;

SELECT
      b.buildingDetailsID
    , b.buildingDetailsNo
    , b.BuildingIdaraID
    , b.buildingDetailsActive
    , b.militaryLocationName_A
    , b.militaryAreaCityName_A
    , b.militaryAreaName_A
    , b.buildingUtilityTypeName_A
    , b.LastActionTypeID
    , b.LastActionTypeName
    , b.LastActionTypeBuildingAlias
    , b.LastActionID
    , b.LastActionNote
    , b.LastActionEntryDate
INTO #HandoverBuildings
FROM Housing.V_GetGeneralListForBuilding b


------------------------------------------------------------
-- Apply department, status and permission filters
-- only after the view result is materialized
------------------------------------------------------------

SELECT DISTINCT
      b.buildingDetailsID
    , b.buildingDetailsNo
    , b.militaryLocationName_A
    , b.militaryAreaCityName_A
    , b.militaryAreaName_A
    , b.buildingUtilityTypeName_A
    , b.LastActionTypeID
    , b.LastActionTypeName
    , CASE
          WHEN b.LastActionTypeID = 57
          THEN N'المبنى خالٍ بانتظار اتخاذ إجراء'
          ELSE b.LastActionTypeBuildingAlias
      END AS LastActionTypeBuildingAlias
    , b.LastActionID
    , b.LastActionNote
    , CONVERT(
          NVARCHAR(10),
          b.LastActionEntryDate,
          23
      )
      + N'  '
      + CONVERT(
          NVARCHAR(10),
          b.LastActionEntryDate,
          8
      ) AS LastActionEntryDatestring
    , b.LastActionEntryDate

FROM #HandoverBuildings b

WHERE b.buildingDetailsActive = 1
  AND b.LastActionTypeID = @LastActionTypeID
  AND b.BuildingIdaraID = @idaraID

  AND EXISTS
  (
      SELECT 1
      FROM Housing.Buildinghandover h
      WHERE h.BuildingActionTypeID_FK =
            b.LastActionTypeID
        AND h.BuildinghandoverActive = 1

        AND
        (
            (
                @UseDepartmentActions = 1
                AND h.IdaraID_FK = @idaraID
            )
            OR
            (
                @UseDepartmentActions = 0
                AND h.IdaraID_FK IS NULL
            )
        )

        AND EXISTS
        (
            SELECT 1
            FROM dbo.V_GetListUserPermission d
            WHERE d.permissionTypeRoleID = 20
              AND d.userID = @entrydata
              AND d.permissionTypeID =
                  h.PermissionTypeID_FK
        )
  )

ORDER BY b.LastActionEntryDate DESC;


    ------------------------------------------------------------
    -- 2. DDLValues
    -- الحالات المتاحة في القائمة المنسدلة
    ------------------------------------------------------------

    SELECT DISTINCT
          h.BuildingActionTypeID_FK
        , CASE
              WHEN h.BuildingActionTypeID_FK = 57
                  THEN N'المبنى خالٍ بانتظار اتخاذ إجراء'
              ELSE t.buildingActionTypeBuildingAlias
          END AS buildingActionTypeBuildingAlias

    FROM Housing.Buildinghandover h

    INNER JOIN Housing.BuildingActionType t
        ON t.BuildingActionTypeID =
           h.BuildingActionTypeID_FK

    WHERE h.BuildinghandoverActive = 1

      AND
      (
          (
              @UseDepartmentActions = 1
              AND h.IdaraID_FK = @idaraID
          )
          OR
          (
              @UseDepartmentActions = 0
              AND h.IdaraID_FK IS NULL
          )
      )

      AND EXISTS
      (
          SELECT 1
          FROM dbo.V_GetListUserPermission d
          WHERE d.permissionTypeRoleID = 20
            AND d.userID = @entrydata
            AND d.permissionTypeID = h.PermissionTypeID_FK
      )

    ORDER BY h.BuildingActionTypeID_FK ASC;


    ------------------------------------------------------------
    -- 3. DDLValues With Extra Params
    -- الإجراءات التالية للحالة المختارة
    ------------------------------------------------------------

    SELECT DISTINCT
      h.NextBuildingActionTypeID_FK
    , CASE
          WHEN h.NextBuildingActionTypeID_FK = 57
              THEN N'المبنى خالٍ بانتظار اتخاذ إجراء'
          ELSE t.buildingActionTypeName_A
      END AS buildingActionTypeName_A
    , h.BuildingActionTypeID_FK

    FROM Housing.Buildinghandover h

    INNER JOIN Housing.BuildingActionType t
        ON t.BuildingActionTypeID =
           h.NextBuildingActionTypeID_FK

    WHERE h.BuildinghandoverActive = 1

      AND h.BuildingActionTypeID_FK = @LastActionTypeID

      AND
      (
          (
              @UseDepartmentActions = 1
              AND h.IdaraID_FK = @idaraID
          )
          OR
          (
              @UseDepartmentActions = 0
              AND h.IdaraID_FK IS NULL
          )
      )

      AND EXISTS
      (
          SELECT 1
          FROM dbo.V_GetListUserPermission d
          WHERE d.permissionTypeRoleID = 20
            AND d.userID = @entrydata
            AND d.permissionTypeID = h.PermissionTypeID_FK
      )

    ORDER BY h.NextBuildingActionTypeID_FK ASC;

END;

GO

