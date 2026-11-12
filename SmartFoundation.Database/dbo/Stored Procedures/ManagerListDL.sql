-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[ManagerListDL] 
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
	   
	   Select 
	   m.ManagerListID
	  ,m.ManagerListTypeID_FK
	  ,t.ManagerListTypeName_A
	  ,m.ManagerListName
      ,m.ManagerListRank
      ,m.ManagerListPosition
      ,convert(nvarchar(10),m.ManagerListStartDate,23) ManagerListStartDate
      ,convert(nvarchar(10),m.ManagerListEndDate,23) ManagerListEndDate
      ,m.ManagerListActive
      ,m.IdaraID_FK
      ,convert(nvarchar(10),m.entryDate,23) entryDate
      ,m.entryData
      ,m.hostName
	   From dbo.ManagerList m
	   inner join dbo.ManagerListType t on m.ManagerListTypeID_FK = t.ManagerListTypeID
	   where m.ManagerListActive =1 


	   --

	   SELECT 
       t.[ManagerListTypeID]
      ,t.[ManagerListTypeName_A]
      ,t.[ManagerListTypeName_E]
      ,t.[ManagerListTypeActive]
      ,t.[IdaraIs_FK]
      FROM [DATACORE].[dbo].[ManagerListType] t
      where t.ManagerListTypeActive = 1 
      and (t.IdaraIs_FK is null or t.IdaraIs_FK = @idaraID)


            
END