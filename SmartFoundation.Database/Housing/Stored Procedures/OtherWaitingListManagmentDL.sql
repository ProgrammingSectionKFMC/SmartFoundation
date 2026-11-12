-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[OtherWaitingListManagmentDL] 
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
            c.waitingClassID,
            c.waitingClassName_A,
            c.waitingClassName_E,
            c.waitingClassRoot,
            c.waitingClassDescription,
            c.idara_FK
            FROM [DATACORE].[Housing].[WaitingClass] c
            where (c.WaitingClassID not in(1,2,3,4,11)) and (c.idara_FK = @idaraID)
            and c.waitingClassActive =1
            order by c.waitingClassSequence asc
    -- Insert statements for procedure here
END

GO

