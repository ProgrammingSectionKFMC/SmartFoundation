
/*
    When entryData is resolved to a target usersID, keep the old executor
    general number visible in hostName as: oldHostName-oldEntryData.
    If entryData is not resolved, preserve the old hostName only.
*/
CREATE   FUNCTION [MoveData].[fn_MapHostName]
(
    @SourceHostName nvarchar(4000),
    @SourceEntryData nvarchar(4000)
)
RETURNS nvarchar(4000)
AS
BEGIN
    DECLARE @MappedEntryData nvarchar(4000) = [MoveData].[fn_MapEntryData](@SourceEntryData);

    IF @MappedEntryData IS NULL
        RETURN @SourceHostName;

    RETURN CONCAT(ISNULL(@SourceHostName, N''), N'-', NULLIF(LTRIM(RTRIM(@SourceEntryData)), N''));
END;

GO

