
/* =========================================================
   4) Stored Procedure (ترجع DataSet  )
========================================================= */
CREATE   PROCEDURE Demo.usp_Demo_Pie3D_Units
(
    @PageName NVARCHAR(100),
    @IdaraId  INT,
    @UserId   INT,
    @HostName NVARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;

    /* ---------- Table (0): Permissions ---------- */
    SELECT permissionTypeName_E
    FROM (VALUES
        (N'INSERT'),
        (N'UPDATE'),
        (N'DELETE')
    ) AS P(permissionTypeName_E);

    /* ---------- Table (1): Pie3D Data ---------- */
    SELECT
        SegmentKey     AS [Key],
        SegmentLabel_A AS [Label],
        SegmentValue   AS [Value],
        SegmentHref    AS [Href],
        SegmentHint    AS [Hint]
    FROM Demo.Demo_Pie3D_UnitDistribution
    WHERE IsActive = 1
      AND (@IdaraId IS NULL OR IdaraId_FK IS NULL OR IdaraId_FK = @IdaraId)
    ORDER BY SortOrder;
END
