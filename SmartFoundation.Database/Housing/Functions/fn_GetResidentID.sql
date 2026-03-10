CREATE FUNCTION Housing.fn_GetResidentID
(
    @generalNo_FK BIGINT = NULL,
    @NationalID   NVARCHAR(50) = NULL
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @residentID BIGINT;

    SELECT TOP 1
        @residentID = r.residentInfoID
    FROM Housing.V_GetFullResidentDetails r
    WHERE
        (
            @generalNo_FK IS NULL
            OR r.generalNo_FK = @generalNo_FK
        )
        AND
        (
            @NationalID IS NULL
            OR r.NationalID = @NationalID
        );

    RETURN @residentID;
END;
