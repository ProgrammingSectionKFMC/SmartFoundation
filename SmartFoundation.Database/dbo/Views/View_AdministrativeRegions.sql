
CREATE VIEW [dbo].[View_AdministrativeRegions] AS
SELECT
    r.regionID         AS RegionID,
    r.regionName_A     AS RegionName_A,
    r.regionName_E     AS RegionName_E,
    r.regionStartDate  AS RegionStartDate,
    r.regionEndDate    AS RegionEndDate,
    r.regionDescription AS RegionDescription,
    r.regionActive     AS RegionActive,
    r.countryID_FK     AS CountryID_FK,
    c.countryName_A    AS CountryName_A_FK
FROM AdministrativeRegions r
LEFT JOIN Countries c ON r.countryID_FK = c.countryID;
