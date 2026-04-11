-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [WH].[GetParentByPartID]
(
	-- Add the parameters for the function here
	@partID bigint
)
RETURNS nvarchar(50)
AS
BEGIN
	-- Declare the return variable here


	-- Add the T-SQL statements to compute the return value here
	DECLARE  @Result  nvarchar(50)

Declare @parentID bigint
Declare @parentName nvarchar(20) 




set @parentID = (
select w.warehousePartParentID_FK 
from wh.WarehousePart w
where w.warehousePartID = @partID)



set @parentName = ''




WHILE( @parentID is not null )
BEGIN


set @parentName =  (
select w.warehousePartName_E 
from wh.WarehousePart w
where w.warehousePartID = @parentID) + @parentName


set @parentID = (
select w.warehousePartParentID_FK 
from wh.WarehousePart w
where w.warehousePartID = @parentID)



END


set @Result = (select @parentName)




	-- Return the result of the function
	RETURN  @Result

END