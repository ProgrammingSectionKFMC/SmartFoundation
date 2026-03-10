-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[MilitaryLocationDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   

         -- MilitaryLocation Data
            SELECT 
                  m.militaryLocationID
                , m.militaryLocationCode
                , m.militaryAreaCityID_FK
                , m.militaryLocationName_A
                , m.militaryLocationName_E
                , m.militaryLocationCoordinates
                , m.militaryLocationDescription
                , m.militaryLocationActive
                , m.IdaraId_FK
                , mc.militaryAreaCityName_A
                
            FROM [DATACORE].[Housing].[MilitaryLocation] m
            inner join [DATACORE].[Housing].[MilitaryAreaCity] mc on m.militaryAreaCityID_FK = mc.militaryAreaCityID
            WHERE m.militaryLocationActive = 1 and (m.IdaraId_FK is null or m.IdaraId_FK = @idaraID)
            ORDER BY m.militaryLocationID desc;

            -- Cities DDL
            SELECT c.militaryAreaCityID, c.militaryAreaCityName_A
            FROM  Housing.MilitaryAreaCity c
            WHERE c.militaryAreaCityActive = 1;
    -- Insert statements for procedure here
END
