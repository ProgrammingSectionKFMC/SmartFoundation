-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[BuildingDetailsDL] 
	-- Add the parameters for the stored procedure here
	
       @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @buildingUtilityTypeID_FK INT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   

            -- MilitaryLocation Data
            SELECT 
                 bd.buildingDetailsID
                ,bd.buildingDetailsNo
                ,bd.buildingDetailsRooms
                ,bd.buildingLevelsCount
                ,bd.buildingDetailsArea
                ,bd.buildingDetailsCoordinates
                ,bd.buildingTypeID_FK
                ,bt.buildingTypeName_A
                ,bd.buildingUtilityTypeID_FK
                ,but.buildingUtilityTypeName_A
                ,bd.militaryLocationID_FK
                ,m.militaryLocationName_A
                ,bd.buildingClassID_FK
                ,bc.buildingClassName_A
                ,bd.buildingDetailsTel_1
                ,bd.buildingDetailsTel_2
                ,brt.buildingRentTypeID
                ,brt.buildingRentTypeName_A
                ,br.buildingRentAmount
                ,bd.buildingDetailsRemark
                ,bd.buildingDetailsStartDate
                ,bd.buildingDetailsEndDate
                ,bd.buildingDetailsActive
                ,br.buildingRentStartDate
                ,br.buildingRentEndDate
                ,bd.IdaraId_FK

           FROM [DATACORE].[Housing].[BuildingDetails] bd
            inner join [DATACORE].[Housing].[BuildingType] bt on bd.buildingTypeID_FK = bt.buildingTypeID
            inner join [DATACORE].[Housing].[BuildingUtilityType] but on bd.buildingUtilityTypeID_FK = but.buildingUtilityTypeID
            inner join [DATACORE].[Housing].[MilitaryLocation] m on bd.militaryLocationID_FK = m.militaryLocationID
            inner join [DATACORE].[Housing].[BuildingClass] bc on bd.buildingClassID_FK = bc.buildingClassID
            left  join [DATACORE].[Housing].[BuildingRent] br on bd.buildingDetailsID = br.buildingDetailsID_FK and br.buildingRentActive = 1 
            left join [DATACORE].[Housing].[BuildingRentType] brt on br.buildingRentTypeID_FK = brt.buildingRentTypeID and brt.buildingRentTypeActive =1
            WHERE bd.buildingDetailsActive = 1 and m.militaryLocationActive = 1 and bt.buildingTypeActive = 1 
            and but.buildingUtilityTypeActive = 1 and m.militaryLocationActive = 1 
            and bc.buildingClassActive = 1 
            and bd.buildingUtilityTypeID_FK = @buildingUtilityTypeID_FK
            and bd.IdaraId_FK = @idaraID
            ORDER BY bd.buildingDetailsID desc;


             -- BuildingUtilityType DDL
            SELECT bu.buildingUtilityTypeID, bu.buildingUtilityTypeName_A,bu.buildingUtilityIsRent
            FROM [DATACORE].[Housing].[BuildingUtilityType] bu
            WHERE bu.buildingUtilityTypeActive = 1 and (bu.IdaraId_FK = @idaraID or bu.IdaraId_FK is null);


            -- BuildingRentType DDL
            SELECT r.buildingRentTypeID, r.buildingRentTypeName_A
            FROM [DATACORE].[Housing].[BuildingRentType] r
            WHERE r.buildingRentTypeActive = 1 and r.buildingRentTypeID = 1;

            

            -- BuildingType DDL
            SELECT r.buildingTypeID, r.buildingTypeName_A
            FROM [DATACORE].[Housing].[BuildingType] r
            WHERE r.buildingTypeActive = 1 and (r.IdaraId_FK = @idaraID or r.IdaraId_FK is null);


            

            -- MilitaryLocation DDL
            SELECT r.militaryLocationID, r.militaryLocationName_A
            FROM [DATACORE].[Housing].[MilitaryLocation] r
            WHERE r.militaryLocationActive = 1 --and (r.IdaraId_FK = @idaraID or r.IdaraId_FK is null);


            

            -- BuildingClass DDL
            SELECT r.buildingClassID, r.buildingClassName_A
            FROM [DATACORE].[Housing].[BuildingClass] r
            WHERE r.buildingClassActive = 1 and (r.IdaraId_FK = @idaraID or r.IdaraId_FK is null);



           
END
