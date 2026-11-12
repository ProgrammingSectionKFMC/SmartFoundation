/*
  نفس نمط WaitingListDL / OtherWaitingListDL / HousingResidentDL.
  نوع الفئة مستنتج من Housing.WaitingClass.idara_FK ولا يُرسل من الواجهة.
  Masters_DataLoad يرجع جدول الصلاحيات أولا، ثم يرجع هذا الإجراء:
  dt1 = المستفيدون (WAITING + المراحل التاريخية 45/46/47/2)
  dt2 = الفئات الرئيسية والجانبية المسموحة للمستخدم
  dt3 = المنازل المرشحة (وتعاد أهلية المنزل داخل PageSP)
  يتطلب العمود HistoricalOccupentDate الوارد في ملف متطلبات الجداول.
*/
CREATE   PROCEDURE [Housing].[HousingHistoricalResidentDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entrydata INT
    , @hostname NVARCHAR(400)
    , @WaitingClassID_nvar NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WaitingClassID INT = TRY_CAST(@WaitingClassID_nvar AS INT);

    -- dt1: سجلات الانتظار والمراحل الاستثنائية الحالية لنفس الفئة.
    SELECT
          w.ActionID
        , ROW_NUMBER() OVER (
              ORDER BY w.ActionDecisionDate, w.ActionDecisionNo, w.GeneralNo
          ) AS WaitingListOrder
        , rd.FullName_A
        , rd.rankNameA
        , w.NationalID
        , w.GeneralNo
        , w.ActionDecisionNo
        , CONVERT(NVARCHAR(10), w.ActionDecisionDate, 23) AS ActionDecisionDate
        , w.WaitingClassID
        , w.WaitingClassName
        , CASE WHEN c.idara_FK IS NULL THEN N'رئيسية' ELSE N'جانبية' END AS OccupentType
        , w.WaitingOrderTypeID
        , w.WaitingOrderTypeName
        , w.waitingClassSequence
        , w.residentInfoID
        , w.LastActionTypeID
        , w.LastActionID
        , bat.buildingActionTypeResidentAlias
        , w.buildingDetailsID
        , w.buildingDetailsNo
        , CONVERT(NVARCHAR(10), w.OccupentDate, 23) AS OccupentDate
        , ISNULL(w.LastActionNote, w.ActionNote) AS ActionNote
        , w.IdaraId
        , w.AssignPeriodID
        , (SELECT COUNT(*)
             FROM Housing.MeterForBuilding m
            WHERE m.buildingDetailsID_FK = w.buildingDetailsID
              AND m.IdaraID_FK = w.IdaraId
              AND m.meterForBuildingActive = 1) AS meterscount
        , w.ActionTypeID
        , w.CustdyRecord
    FROM Housing.V_WaitingList w
    INNER JOIN Housing.V_GetFullResidentDetails rd
        ON rd.residentInfoID = w.residentInfoID
    INNER JOIN Housing.WaitingClass c
        ON c.waitingClassID = w.WaitingClassID
    LEFT JOIN Housing.BuildingActionType bat
        ON bat.buildingActionTypeID = w.LastActionTypeID
    WHERE w.WaitingClassID = @WaitingClassID
      AND w.IdaraId = @idaraID
      AND c.waitingClassActive = 1
      AND (c.idara_FK IS NULL OR c.idara_FK = @idaraID)
      AND
      (
          w.LastActionTypeID IS NULL
          OR w.LastActionTypeID IN (34, 35)
          OR
          (
              w.LastActionTypeID IN (45, 46, 47, 2)
              AND EXISTS
              (
                  SELECT 1
                  FROM Housing.BuildingAction a45
                  LEFT JOIN Housing.BuildingAction a38
                      ON a38.buildingActionID = a45.buildingActionParentID
                     AND a38.buildingActionTypeID_FK = 38
                  LEFT JOIN Housing.BuildingAction a27
                      ON a27.buildingActionID = a38.buildingActionParentID
                     AND a27.buildingActionTypeID_FK = 27
                  WHERE a45.buildingActionTypeID_FK = 45
                    AND a45.buildingActionActive = 1
                    AND a45.HistoricalOccupentDate IS NOT NULL
                    AND a45.residentInfoID_FK = w.residentInfoID
                    AND a45.IdaraId_FK = @idaraID
                    AND (
                         a45.buildingActionParentID = w.ActionID
                         OR a27.buildingActionParentID = w.ActionID
                    )
              )
          )
      )
    ORDER BY w.ActionDecisionDate, w.ActionDecisionNo, w.GeneralNo;

    -- dt2: القائمة الثانية، مع نوع الفئة لاستخدامه في تصفية خيارات الواجهة.
    SELECT
          c.waitingClassID
        , c.waitingClassName_A
        , c.waitingClassSequence
        , CASE WHEN c.idara_FK IS NULL THEN N'MAIN' ELSE N'SIDE' END AS ListType
    FROM Housing.WaitingClass c
    WHERE c.waitingClassActive = 1
      AND (c.idara_FK IS NULL OR c.idara_FK = @idaraID)
    ORDER BY CASE WHEN c.idara_FK IS NULL THEN 0 ELSE 1 END,
             c.waitingClassSequence,
             c.waitingClassID;

    -- dt3: نفس منطق اختيار المنازل في OtherWaitingListDL الذي أرسلته،
    -- مع حجب كل منزل يظهر في V_Occupant (حتى 57/58؛ ليس إخلاء مكتملًا).
    SELECT
          b.buildingDetailsID
        , b.buildingDetailsNo
    FROM Housing.V_GetGeneralListForBuilding b
    WHERE b.BuildingIdaraID = @idaraID
      AND b.buildingDetailsActive = 1
      AND b.LastActionTypeID = 5
      AND EXISTS
      (
          SELECT 1
          FROM Housing.BuildingSpace bs
          INNER JOIN Housing.BuildingSpaceType bst
              ON bst.BuildingSpaceTypeID = bs.BuildingSpaceTypeID_FK
          WHERE bs.BuildingDetailsID_FK = b.buildingDetailsID
            AND bs.BuildingSpaceActive = 1
            AND bs.BuildingSpaceTypeID_FK = 1
            AND bst.BuildingSpaceTypeCode = N'BEDROOM'
            AND bst.BuildingSpaceTypeActive = 1
            AND (bs.BuildingSpaceStartDate IS NULL OR bs.BuildingSpaceStartDate <= CAST(GETDATE() AS DATE))
            AND (bs.BuildingSpaceEndDate IS NULL OR bs.BuildingSpaceEndDate >= CAST(GETDATE() AS DATE))
            AND (bst.BuildingSpaceTypeStartDate IS NULL OR bst.BuildingSpaceTypeStartDate <= CAST(GETDATE() AS DATE))
            AND (bst.BuildingSpaceTypeEndDate IS NULL OR bst.BuildingSpaceTypeEndDate >= CAST(GETDATE() AS DATE))
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.V_Occupant o
          WHERE o.buildingDetailsID = b.buildingDetailsID
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM Housing.V_WaitingList holding
          WHERE holding.buildingDetailsID = b.buildingDetailsID
            AND holding.LastActionTypeID IN (38, 40, 45, 46, 47)
      )
    ORDER BY b.buildingDetailsNo;
END;