-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[HousingHandoverDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	, @LastActionTypeID  INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Buildinghandover Data

          select distinct
		  b.buildingDetailsID,
		  b.buildingDetailsNo,
		  b.militaryLocationName_A,
		  b.militaryAreaCityName_A,
		  b.militaryAreaName_A,
		  b.buildingUtilityTypeName_A,
		  b.LastActionTypeID,
		  b.LastActionTypeName,
		  b.LastActionTypeBuildingAlias,
		  b.LastActionID,
		  b.LastActionNote,
		  convert(nvarchar(10),b.LastActionEntryDate,23) +N'  '+ convert(nvarchar(10),b.LastActionEntryDate,8) as LastActionEntryDatestring,
		  b.LastActionEntryDate
		  
		  
		  from [Housing].[V_GetGeneralListForBuilding] b
		  left join housing.Buildinghandover h on h.BuildingActionTypeID_FK = b.LastActionTypeID
		  where h.BuildinghandoverActive = 1
		  and b.buildingDetailsActive = 1
		  and b.LastActionTypeID = @LastActionTypeID
		  and b.BuildingIdaraID = @idaraID
		  and h.PermissionTypeID_FK 
		  in (select distinct d.permissionTypeID from dbo.V_GetListUserPermission d where d.permissionTypeRoleID = 20 and d.userID = @entrydata)
		  order by b.LastActionEntryDate desc

		  --------------------------

		   select distinct
		  
		  h.BuildingActionTypeID_FK,
		  t.buildingActionTypeBuildingAlias
		
		  
		  from 
		  housing.Buildinghandover h 
		  inner join Housing.BuildingActionType t on t.BuildingActionTypeID = h.BuildingActionTypeID_FK
		  where h.BuildinghandoverActive = 1
		  and h.IdaraID_FK = @idaraID
		  and h.PermissionTypeID_FK 
		  in (select distinct d.permissionTypeID from dbo.V_GetListUserPermission d where d.permissionTypeRoleID = 20 and d.userID = @entrydata)

		  
		  order by h.BuildingActionTypeID_FK asc

		  ----------------------------------

		  select distinct 
		  h.NextBuildingActionTypeID_FK,
		  t.buildingActionTypeName_A,
		  h.BuildingActionTypeID_FK
		  from [Housing].[Buildinghandover] h
		  inner join Housing.BuildingActionType t on t.BuildingActionTypeID = h.NextBuildingActionTypeID_FK
		  where h.BuildinghandoverActive = 1
		  and h.BuildingActionTypeID_FK = @LastActionTypeID
		  and h.IdaraID_FK = @idaraID

		  order by h.NextBuildingActionTypeID_FK asc

		

   
END