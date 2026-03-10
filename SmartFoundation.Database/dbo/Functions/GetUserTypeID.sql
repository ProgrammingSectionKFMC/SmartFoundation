create FUNCTION [dbo].[GetUserTypeID]
(
	-- Add the parameters for the function here
	@userID int 
)
RETURNS  int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	SET	@Result=(	SELECT 
					CASE 
					WHEN ( US_UserID LIKE ('600%') ) OR ( US_UserID LIKE ('650%') ) THEN 1
					WHEN ( US_UserID LIKE ('100%') ) THEN 2
					WHEN ( US_UserID LIKE ('900%') ) THEN 4
					else 3
					END N'userTypeID_FK'
					FROM TBS_BAWSE2.dbo.TBST_Users 
					WHERE cast(US_UserID as int)=@userID)
	RETURN  @Result

END
