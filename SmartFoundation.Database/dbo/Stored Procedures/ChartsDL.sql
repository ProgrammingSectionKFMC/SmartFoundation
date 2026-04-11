-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[ChartsDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @UsersID 	      NVARCHAR(400) = NULL
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

           select c.ChartListName_E from dbo.ChartList c
           inner join dbo.ChartListUsers cl on c.ChartListID = cl.ChartListID_FK

           where c.ChartListActive = 1 and c.ChartListStartDate is not null and (c.ChartListEndDate is null or cast(c.ChartListEndDate as date) < cast(GETDATE() as date))
           AND
           cl.ChartListUsersActive = 1 and cl.ChartListUsersStartDate is not null and (cl.ChartListUsersEndDate is null or cast(cl.ChartListUsersEndDate as date) < cast(GETDATE() as date))
           AND
           cl.UsersID_FK = @UsersID

           order by cl.DisplayOrder asc



           ----------------

IF OBJECT_ID('tempdb..#building') IS NOT NULL
    DROP TABLE #building;

SELECT
    gf.buildingDetailsNo      AS BuildingNo,
    gf.buildingTypeID_FK      AS BuildingTypeID,
    gf.buildingClassID_FK     AS BuildingClassID,
    gf.buildingClassName_A    AS BuildingClassName,
    ISNULL(gf.LastActionTypeID, 8) AS LastAction
INTO #building
FROM Housing.V_GetGeneralListForBuilding gf
LEFT JOIN Housing.V_LastActionForBuilding v
    ON gf.LastActionID = v.buildingActionID
WHERE gf.buildingUtilityTypeID_FK IN (1,11)
and gf.BuildingIdaraID = 1
;

CREATE CLUSTERED INDEX IX_building_LastAction
    ON #building (LastAction);

DECLARE
    @allbuildings       DECIMAL(18,2),
    @Occbuildings       DECIMAL(18,2),
    @Emptybuildings     DECIMAL(18,2),
    @Unknownbuildings   DECIMAL(18,2),
    @Maintancebuildings DECIMAL(18,2),
    @Jawdahbuildings    DECIMAL(18,2),
    @Servicebuildings   DECIMAL(18,2),
    @Readybuildings     DECIMAL(18,2);

SELECT
    @allbuildings       = SUM(CASE WHEN LastAction IN (2,24,3,4,5,15,16,17,9,10,8,11,12,13,14,5) THEN 1 ELSE 0 END), --COUNT(*),
    @Occbuildings       = SUM(CASE WHEN LastAction IN (2,24) THEN 1 ELSE 0 END),
    @Emptybuildings     = SUM(CASE WHEN LastAction IN (3,4,15,16,17) THEN 1 ELSE 0 END),
  --  @Unknownbuildings   = SUM(CASE WHEN LastAction = 8 THEN 1 ELSE 0 END),
    @Maintancebuildings = SUM(CASE WHEN LastAction IN (9,10,8) THEN 1 ELSE 0 END),
    @Jawdahbuildings    = SUM(CASE WHEN LastAction IN (11,12) THEN 1 ELSE 0 END),
    @Servicebuildings   = SUM(CASE WHEN LastAction IN (13,14) THEN 1 ELSE 0 END),
    @Readybuildings     = SUM(CASE WHEN LastAction = 5 THEN 1 ELSE 0 END)
FROM #building;

DECLARE @OccPercentge       DECIMAL(18,2) = (@Occbuildings       / NULLIF(@allbuildings,0)) * 100;
DECLARE @EmptyPercentge     DECIMAL(18,2) = (@Emptybuildings     / NULLIF(@allbuildings,0)) * 100;
DECLARE @MaintancePercentge DECIMAL(18,2) = (@Maintancebuildings / NULLIF(@allbuildings,0)) * 100;
DECLARE @JawdahPercentge    DECIMAL(18,2) = (@Jawdahbuildings    / NULLIF(@allbuildings,0)) * 100;
DECLARE @ServicePercentge   DECIMAL(18,2) = (@Servicebuildings   / NULLIF(@allbuildings,0)) * 100;
DECLARE @ReadyPercentge     DECIMAL(18,2) = (@Readybuildings     / NULLIF(@allbuildings,0)) * 100;

SELECT 1 AS #, N'المشغولة'           AS N'النوع', CAST(@OccPercentge       AS DECIMAL(18,2)) AS Percentages, cast(@Occbuildings as int)      AS N'العدد'
UNION ALL
SELECT 2 AS #, N'المساكن الخالية'    AS N'النوع', CAST(@EmptyPercentge     AS DECIMAL(18,2)) AS Percentages, cast(@Emptybuildings as int)     AS N'العدد'
--UNION ALL
--SELECT 3 AS #, N'المساكن الغير معروفة' AS N'النوع', CAST(@UnknownPercentge   AS DECIMAL(18,2)) AS Percentages, cast(@Unknownbuildings as int)   AS N'العدد'
UNION ALL
SELECT 4 AS #, N'تحت الصيانة'        AS N'النوع', CAST(@MaintancePercentge AS DECIMAL(18,2)) AS Percentages, cast(@Maintancebuildings as int) AS N'العدد'
UNION ALL
SELECT 5 AS #, N'الجودة'             AS N'النوع', CAST(@JawdahPercentge    AS DECIMAL(18,2)) AS Percentages, cast(@Jawdahbuildings as int)    AS N'العدد'
UNION ALL
SELECT 6 AS #, N'الخدمات'            AS N'النوع', CAST(@ServicePercentge   AS DECIMAL(18,2)) AS Percentages, cast(@Servicebuildings as int)   AS N'العدد'
UNION ALL
SELECT 7 AS #, N'جاهزة للتسكين'      AS N'النوع', CAST(@ReadyPercentge     AS DECIMAL(18,2)) AS Percentages, cast(@Readybuildings as int)     AS N'العدد'
UNION ALL
SELECT 8 AS #, N'الاجمالي'           AS N'النوع', CAST(100 AS DECIMAL(18,2))                 AS Percentages, cast(@allbuildings  as int)      AS N'العدد';
			   ---------------------------------------------------
  


   
END