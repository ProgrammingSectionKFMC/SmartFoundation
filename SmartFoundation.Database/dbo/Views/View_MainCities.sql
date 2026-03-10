
CREATE VIEW [dbo].[View_MainCities] AS
SELECT
    mc.cityID          AS CityID,
    mc.cityName_A      AS CityName_A,
    mc.cityName_E      AS CityName_E,
    mc.cityStartDate   AS CityStartDate,
    mc.cityEndDate     AS CityEndDate,
    mc.cityDescription AS CityDescription,
    mc.cityActive      AS CityActive,
    mc.regionID_FK     AS RegionID_FK,
    r.regionName_A     AS RegionName_A_FK
FROM MainCities mc
LEFT JOIN AdministrativeRegions r ON mc.regionID_FK = r.regionID;
