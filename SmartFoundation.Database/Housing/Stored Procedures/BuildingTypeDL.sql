-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[BuildingTypeDL] 
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
	   

            -- BuildingType Data
            SELECT 
                  t.buildingTypeID
                , t.buildingTypeCode
                , t.buildingTypeName_A
                , t.buildingTypeName_E
                , t.buildingTypeDescription
            FROM  Housing.BuildingType t
            WHERE t.buildingTypeActive = 1 and (t.IdaraId_FK is null or t.IdaraId_FK = @idaraID)
            ORDER BY t.buildingTypeID desc;

            -- Cities DDL
            SELECT c.cityID, c.cityName_A
            FROM  dbo.City c
            WHERE c.cityActive = 1;
    -- Insert statements for procedure here
END
