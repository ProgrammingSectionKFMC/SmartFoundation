

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [WH].[GetWarehousePartIDByLocation]
(
	-- Add the parameters for the function here
	@location NVARCHAR(10)
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	--DECLARE @Result INT 
	Declare @NewName NVARCHAR(10)
    DECLARE @PartTypeID INT

	-- Add the T-SQL statements to compute the return value here
	--  SET @Result = 
	-- 				(
IF(LEN(@location) = 1)
BEGIN 
    SET @NewName = @location
    SET @PartTypeID = 1
    IF EXISTS(SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartID = @PartTypeID AND wp.warehousePartActive = 1)
    BEGIN 
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartID = @PartTypeID AND wp.warehousePartActive = 1)
    END
    ELSE
    BEGIN 
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)
    END
    
END
ELSE IF(LEN(@location) = 2)
BEGIN 
    SET @NewName = SUBSTRING(@location, 2, 1)
    SET @PartTypeID = 2
    IF EXISTS(SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
    AND wp.warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1))
    BEGIN 
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
    AND wp.warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1))
    END
    ELSE
    BEGIN 
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)
    END
END
ELSE IF(LEN(@location) = 4)
BEGIN 
    SET @NewName = SUBSTRING(@location, 3, 2)
    SET @PartTypeID = 3
    IF EXISTS(SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
    AND wp.warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1)))
    BEGIN 
    
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
        AND wp.warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1)))
    END
    ELSE
    BEGIN 
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)
    END
END
ELSE IF(LEN(@location) = 6)
BEGIN 
    SET @NewName = SUBSTRING(@location, 5, 2)
    SET @PartTypeID = 4
    IF EXISTS(SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
    AND wp.warehousePartParentID_FK = 
    (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 3,2) AND warehousePartTypeID_FK = 3 AND warehousePartParentID_FK =
    (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1))))
    BEGIN
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
        AND wp.warehousePartParentID_FK = 
        (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 3,2) AND warehousePartTypeID_FK = 3 AND warehousePartParentID_FK =
        (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1))))
    END
    ELSE
    BEGIN
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)
    END
END
ELSE IF(LEN(@location) = 8)
BEGIN 
    SET @NewName = SUBSTRING(@location, 7, 2)
    SET @PartTypeID = 5
 
 if EXISTS(SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
    AND wp.warehousePartParentID_FK = 
    (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 5,2) AND warehousePartTypeID_FK = 4 AND warehousePartParentID_FK =
    (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 3,2) AND warehousePartTypeID_FK = 3 AND warehousePartParentID_FK =
    (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1)))))
    BEGIN
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartName = @NewName AND wp.warehousePartTypeID_FK = @PartTypeID AND wp.warehousePartActive = 1
        AND wp.warehousePartParentID_FK = 
        (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 5,2) AND warehousePartTypeID_FK = 4 AND warehousePartParentID_FK =
        (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 3,2) AND warehousePartTypeID_FK = 3 AND warehousePartParentID_FK =
        (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 2,1) AND warehousePartTypeID_FK = 2 AND warehousePartParentID_FK = (SELECT warehousePartID FROM KFMC.WH.WarehousePart WHERE warehousePartName = SUBSTRING(@location, 1,1) AND warehousePartTypeID_FK = 1)))))
    END
    ELSE
    BEGIN
        RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)
    end
END

    RETURN (SELECT wp.warehousePartID FROM KFMC.WH.WarehousePart wp WHERE wp.warehousePartTypeID_FK = 6)


					

	-- Return the result of the function
	--RETURN @Result

END