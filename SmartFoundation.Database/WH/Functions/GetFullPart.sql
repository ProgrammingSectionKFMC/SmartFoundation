-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE FUNCTION [WH].[GetFullPart] 
(	
	-- Add the parameters for the function here
	
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT 
    isnull(p1.warehousePartName_A,'') + isnull(p2.warehousePartName_A,'') + isnull(p3.warehousePartName_A,'') + isnull(p4.warehousePartName_A,'') + isnull(p5.warehousePartName_A,'') AS 'PartSequence', p5.warehousePartID, p5.warehousePartParentID_FK
    
    FROM WH.WarehousePart p1 
    INNER JOIN WH.WarehousePart p2 ON p1.warehousePartID = p2.warehousePartParentID_FK
    INNER JOIN WH.WarehousePart p3 ON p2.warehousePartID = p3.warehousePartParentID_FK
    INNER JOIN WH.WarehousePart p4 ON p3.warehousePartID = p4.warehousePartParentID_FK
    INNER JOIN WH.WarehousePart p5 ON p4.warehousePartID = p5.warehousePartParentID_FK

)