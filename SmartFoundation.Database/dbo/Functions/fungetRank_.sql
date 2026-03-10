-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[fungetRank_]
(@userID int)
RETURNS nvarchar (100)
AS
BEGIN
	declare @rankName_A nvarchar (100)
 set @rankName_A=
	(SELECT top (1)  d.distributorName_A
	FROM UserDistributor AS ud 
	INNER JOIN Distributor AS d ON ud.distributorID_FK = d.distributorID 
	INNER JOIN UserType AS ut ON d.groupID_FK = ut.userTypeID
	WHERE 1=1
	AND (ud.userID_FK=@userID)
	AND(d.distributorType_FK=3)
	AND (d.groupID_FK IS NOT NULL)
	AND (d.distributorActive = 1) 
	AND (ud.UDEndDate IS NULL OR ud.UDEndDate='') 
	AND (ud.UDActive = 1)

order by ud.UDID desc
)

	-- Return the result of the function
	RETURN @rankName_A

END
