-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [WH].[WarehouseLocationsDL] 
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
	   

  -- warehouse

     SELECT 
       [warehouseID]
      ,[warehouseName]
      ,[warehousePartName_A]
      ,[warehousePartOldParentID_FK]
      ,[warehouseActive]
      ,case when warehouseActive = 1 then N'نشط' 
      else N'غير نشط' end 
      as warehouseStatus
  FROM [DATACORE].[WH].[V_warehouse] w
  where w.IdaraID_FK = @idaraID

   -- building

    SELECT 
       [warehouseID]
      ,wh.warehouseName
      ,wh.warehousePartName_A
      ,[buildingID]
      ,[buildingName]
      ,[buildingPartName_A]
      ,[buildingActive]
      ,case when buildingActive = 1 then N'نشط' 
      else N'غير نشط' end 
      as buildingStatus
      
  FROM [DATACORE].[WH].[V_building] w
  inner join [DATACORE].[WH].[V_warehouse] wh on w.buildingParentID_FK = wh.warehouseID
  where w.IdaraID_FK = @idaraID 

  -- shelf

    SELECT 
       wh.[warehouseID]
      ,wh.warehouseName
      ,wh.warehousePartName_A
      ,[buildingID]
      ,[buildingName]
      ,[buildingPartName_A]
      ,[shelfID]
      ,[shelfName]
      ,[shelfName_A]
      ,[shelfActive]
      ,case when shelfActive = 1 then N'نشط' 
      else N'غير نشط' end 
      as shelfStatus

  FROM [DATACORE].[WH].[V_shelf] w
  inner join [DATACORE].[WH].[V_building] b on b.buildingID = w.shelfParentID_FK
  inner join [DATACORE].[WH].[V_warehouse] wh on b.buildingParentID_FK = wh.warehouseID
  where w.IdaraID_FK = @idaraID 

   -- column

  
    SELECT 
       wh.[warehouseID]
      ,wh.warehouseName
      ,wh.warehousePartName_A
      ,[buildingID]
      ,[buildingName]
      ,[buildingPartName_A]
      ,[shelfID]
      ,[shelfName]
      ,[shelfName_A]
      ,[columnID]
      ,[columnName]
      ,[columnName_A]
      ,[columnActive]
      ,case when columnActive = 1 then N'نشط' 
      else N'غير نشط' end 
      as columnStatus


  FROM [DATACORE].[WH].[V_column] c
  inner join [DATACORE].[WH].[V_shelf] w on c.columnParentID_FK = w.shelfID
  inner join [DATACORE].[WH].[V_building] b on b.buildingID = w.shelfParentID_FK
  inner join [DATACORE].[WH].[V_warehouse] wh on b.buildingParentID_FK = wh.warehouseID
  where w.IdaraID_FK = @idaraID


  -- row

  
    SELECT 
       wh.[warehouseID]
      ,wh.warehouseName
      ,wh.warehousePartName_A
      ,[buildingID]
      ,[buildingName]
      ,[buildingPartName_A]
      ,[shelfID]
      ,[shelfName]
      ,[shelfName_A]
      ,[columnID]
      ,[columnName]
      ,[columnName_A]
      ,[rowID]
      ,[rowName]
      ,[rowName_A]
      ,[rowActive]
      ,case when rowActive = 1 then N'نشط' 
      else N'غير نشط' end 
      as rowStatus


  FROM [DATACORE].[WH].[V_row] r
  inner join [DATACORE].[WH].[V_column] c on r.rowParentID_FK = c.columnID
  inner join [DATACORE].[WH].[V_shelf] w on c.columnParentID_FK = w.shelfID
  inner join [DATACORE].[WH].[V_building] b on b.buildingID = w.shelfParentID_FK
  inner join [DATACORE].[WH].[V_warehouse] wh on b.buildingParentID_FK = wh.warehouseID
  where w.IdaraID_FK = @idaraID
           
END