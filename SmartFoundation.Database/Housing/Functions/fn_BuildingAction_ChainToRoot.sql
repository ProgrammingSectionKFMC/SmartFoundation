CREATE   FUNCTION Housing.fn_BuildingAction_ChainToRoot
(
    @buildingActionID BIGINT
)
RETURNS TABLE
AS
RETURN
(
    WITH chain AS
    (
        SELECT
            b.*,
            0 AS Lvl,
            CAST(N'|' + CAST(b.buildingActionID AS NVARCHAR(50)) + N'|' AS NVARCHAR(MAX)) AS PathIds
        FROM Housing.BuildingAction b
        WHERE b.buildingActionID = @buildingActionID

        UNION ALL

        SELECT
            p.*,
            c.Lvl + 1 AS Lvl,
            CAST(c.PathIds + CAST(p.buildingActionID AS NVARCHAR(50)) + N'|' AS NVARCHAR(MAX)) AS PathIds
        FROM chain c
        INNER JOIN Housing.BuildingAction p
            ON p.buildingActionID = c.buildingActionParentID
        WHERE CHARINDEX(
                N'|' + CAST(p.buildingActionID AS NVARCHAR(50)) + N'|',
                c.PathIds
              ) = 0
    ),
    mx AS
    (
        SELECT MAX(Lvl) AS MaxLvl FROM chain
    )
    SELECT
        -- جميع الأعمدة
        buildingActionID,
        buildingActionUDID,
        buildingActionTypeID_FK,
        buildingStatusID_FK,
        residentInfoID_FK,
        generalNo_FK,
        buildingPaymentTypeID_FK,
        buildingDetailsID_FK,
        buildingDetailsNo,
        buildingActionFromDate,
        buildingActionToDate,
        buildingActionDate,
        buildingActionDate2,
        buildingActionDecisionNo,
        buildingActionDecisionDate,
        fromDSD_FK,
        toDSD_FK,
        buildingActionFromSourceID_FK,
        buildingActionToSourceID_FK,
        buildingActionNote,
        buildingActionExtraText1,
        buildingActionExtraText2,
        buildingActionExtraText3,
        buildingActionExtraText4,
        buildingActionExtraDate1,
        buildingActionExtraDate2,
        buildingActionExtraDate3,
        buildingActionExtraFloat1,
        buildingActionExtraFloat2,
        buildingActionExtraInt1,
        buildingActionExtraInt2,
        buildingActionExtraInt3,
        buildingActionExtraInt4,
        buildingActionExtraType1,
        buildingActionExtraType2,
        buildingActionExtraType3,
        buildingActionActive,
        buildingActionParentID,
        CustdyRecord,
        AssignPeriodID_FK,
        IdaraId_FK,
        entryDate,
        entryData,
        hostName,

        -- ✅ لفل جديد يبدأ من الجذر
        (mx.MaxLvl - c.Lvl) AS Lvl
    FROM chain c
    CROSS JOIN mx
);
