
CREATE VIEW [dbo].[View_LocalAdministrations] AS
SELECT
    la.adminID          AS AdminID,
    la.adminName_A      AS AdminName_A,
    la.adminName_E      AS AdminName_E,
    la.adminStartDate   AS AdminStartDate,
    la.adminEndDate     AS AdminEndDate,
    la.adminDescription AS AdminDescription,
    la.adminActive      AS AdminActive,
    la.cityID_FK        AS CityID_FK,
    mc.cityName_A       AS CityName_A_FK
FROM LocalAdministrations la
LEFT JOIN MainCities mc ON la.cityID_FK = mc.cityID;
