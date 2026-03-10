
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[GetCountUserFromDSD] 
(
	@DSDID int
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result  int = 0
	SET @Result=(
					SELECT COUNT(ud.userID_FK) CountUsers
					FROM UserDistributor AS ud 
					INNER JOIN dbo.[Users] u ON ud.userID_FK=u.usersID AND u.usersActive=1
						INNER JOIN Distributor AS d ON ud.distributorID_FK = d.distributorID
					WHERE (1=1) 
								AND (NOT (ud.UDStartDate IS NULL)) 
								AND (ud.UDEndDate IS NULL) 
								AND (ud.UDActive = 1) 
								AND (d.distributorType_FK = 1) 
								AND (NOT (d.DSDID_FK IS NULL)) 
								AND (d.roleID_FK IS NULL)
								AND (d.DSDID_FK=@DSDID)
	)
	
	RETURN @Result

END
