CREATE   VIEW Housing.V_WaitingList_Ids
AS
SELECT b.buildingActionID AS ActionID
FROM Housing.BuildingAction b
WHERE b.buildingActionTypeID_FK = 1
  AND b.buildingActionActive = 1
  AND
  (
      -- الحالة 1: ليس Parent لأي إجراء
      NOT EXISTS (
          SELECT 1
          FROM Housing.BuildingAction c
          WHERE c.buildingActionParentID = b.buildingActionID
      )
      OR
      -- الحالة 2: لديه 32 ثم 34/35
      EXISTS (
          SELECT 1
          FROM Housing.BuildingAction a32
          WHERE a32.buildingActionParentID = b.buildingActionID
            AND a32.buildingActionTypeID_FK = 32
            AND EXISTS (
                SELECT 1
                FROM Housing.BuildingAction a3435
                WHERE a3435.buildingActionParentID = a32.buildingActionID
                  AND a3435.buildingActionTypeID_FK IN (34, 35)
            )
      )
  )
  -- الاستبعاد: وجود 32 مفتوح (بدون أبناء) أو عليه 33
  AND NOT EXISTS (
      SELECT 1
      FROM Housing.BuildingAction a32x
      WHERE a32x.buildingActionParentID = b.buildingActionID
        AND a32x.buildingActionTypeID_FK = 32
        AND
        (
            -- 32 بدون أي ابن = مفتوح
            NOT EXISTS (
                SELECT 1
                FROM Housing.BuildingAction ch
                WHERE ch.buildingActionParentID = a32x.buildingActionID
            )
            OR
            -- أو 32 عليه 33 = قبول
            EXISTS (
                SELECT 1
                FROM Housing.BuildingAction a33
                WHERE a33.buildingActionParentID = a32x.buildingActionID
                  AND a33.buildingActionTypeID_FK = 33
            )
        )
  );
