-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION dbo.GetCountAllUsers
(

)
RETURNS  int
AS
BEGIN
	DECLARE @Result  int 
	SET @Result=(
					SELECT COUNT(ud.userID_FK) CountUsers
					FROM UserDistributor AS ud 
						INNER JOIN Distributor AS d ON ud.distributorID_FK = d.distributorID
					WHERE (1=1) 
								AND (NOT (ud.UDStartDate IS NULL)) 
								AND (ud.UDEndDate IS NULL) 
								AND (ud.UDActive = 1) 
								AND (d.distributorType_FK = 1) 
								AND (NOT (d.DSDID_FK IS NULL)) 
								AND (d.roleID_FK IS NULL)
				)
				

	RETURN @Result

END
