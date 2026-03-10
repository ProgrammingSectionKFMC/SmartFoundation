-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[BuildingClassDL] 
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
                  c.buildingClassID
                , c.buildingClassName_A
                , c.buildingClassName_E
                , c.buildingClassDescription
                , c.buildingClassOrder
                , c.buildingClassActive
            FROM  Housing.BuildingClass c
            WHERE c.buildingClassActive = 1 and (c.IdaraId_FK is null or c.IdaraId_FK = @idaraID)
            order by c.buildingClassID desc;
    -- Insert statements for procedure here
END
