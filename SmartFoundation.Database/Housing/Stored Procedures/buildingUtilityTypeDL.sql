-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[buildingUtilityTypeDL] 
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
                  t.buildingUtilityTypeID
                , t.buildingUtilityTypeName_A
                , t.buildingUtilityTypeName_E
                , t.buildingUtilityTypeDescription
                , t.buildingUtilityTypeActive
                , convert(nvarchar(10),t.buildingUtilityTypeStartDate,23) buildingUtilityTypeStartDate
                , convert(nvarchar(10),t.buildingUtilityTypeEndDate,23) buildingUtilityTypeEndDate
                , CASE 
                    WHEN t.buildingUtilityIsRent = 0 THEN N'0'
                    WHEN t.buildingUtilityIsRent = 1 THEN N'1'
                    ELSE N''
                  END AS buildingUtilityIsRent
            FROM  Housing.buildingUtilityType t
            WHERE t.buildingUtilityTypeActive = 1 and (t.IdaraId_FK is null or t.IdaraId_FK = @idaraID)
            ORDER BY t.buildingUtilityTypeID asc;
    -- Insert statements for procedure here
END