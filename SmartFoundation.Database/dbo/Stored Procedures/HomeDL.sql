-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
create PROCEDURE [dbo].[HomeDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @UsersID 	      NVARCHAR(400) = NULL
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

           select c.ChartListName_E from dbo.ChartList c
           inner join dbo.ChartListUsers cl on c.ChartListID = cl.ChartListID_FK

           where c.ChartListActive = 1 and c.ChartListStartDate is not null and (c.ChartListEndDate is null or cast(c.ChartListEndDate as date) < cast(GETDATE() as date))
           AND
           cl.ChartListUsersActive = 1 and cl.ChartListUsersStartDate is not null and (cl.ChartListUsersEndDate is null or cast(cl.ChartListUsersEndDate as date) < cast(GETDATE() as date))
           AND
           cl.UsersID_FK = @UsersID
  


   
END