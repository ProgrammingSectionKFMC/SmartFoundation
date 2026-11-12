
/*
    Old entryData stores the employee general number.
    New entryData stores dbo.Users.usersID.
    If the old value cannot be matched, return NULL.
*/
CREATE   FUNCTION [MoveData].[fn_MapEntryData]
(
    @SourceEntryData nvarchar(4000)
)
RETURNS nvarchar(4000)
AS
BEGIN
    DECLARE @MappedUsersID bigint;

    SELECT TOP (1)
        @MappedUsersID = userDetails.[usersID_FK]
    FROM [dbo].[UsersDetails] AS userDetails
    JOIN [dbo].[Users] AS usersRow
      ON usersRow.[usersID] = userDetails.[usersID_FK]
    WHERE userDetails.[GeneralNo] =
          TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(@SourceEntryData)), N''))
    ORDER BY
        CASE
            WHEN ISNULL(usersRow.[usersActive], 0) = 1
             AND ISNULL(userDetails.[userActive], 0) = 1 THEN 0
            ELSE 1
        END,
        userDetails.[usersID_FK];

    RETURN CONVERT(nvarchar(4000), @MappedUsersID);
END;

GO

