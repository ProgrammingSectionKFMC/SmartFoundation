CREATE VIEW [dbo].[View_Countries] AS
SELECT
    c.countryID        AS CountryID,
    c.countryName_A    AS CountryName_A,
    c.countryName_E    AS CountryName_E,
    c.countryStartDate AS CountryStartDate,
    c.countryEndDate   AS CountryEndDate,
    c.countryDescription AS CountryDescription,
    c.countryActive    AS CountryActive,
    c.continentID_FK   AS ContinentID_FK,
    ct.continentName_A AS ContinentName_A_FK
FROM Countries c
LEFT JOIN Continents ct ON c.continentID_FK = ct.continentID;
