CREATE PROCEDURE [Housing].[GenerateMissingResidentFixedServiceBills]
(
      @ResidentInfoID BIGINT
    , @GeneralNo BIGINT
    , @BuildingDetailsID BIGINT
    , @OccupentDate DATE
    , @IdaraID BIGINT
    , @EntryData NVARCHAR(20)
    , @HostName NVARCHAR(200)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LastBillDate DATE = EOMONTH(DATEADD(MONTH, -1, GETDATE()));

    IF @OccupentDate IS NULL OR @OccupentDate > @LastBillDate
        RETURN;

    EXEC Housing.GenerateFixedServiceBillsForResidentPeriod
          @ResidentInfoID = @ResidentInfoID
        , @GeneralNo = @GeneralNo
        , @BuildingDetailsID = @BuildingDetailsID
        , @FromDate = @OccupentDate
        , @ToDate = @LastBillDate
        , @IdaraID = @IdaraID
        , @EntryData = @EntryData
        , @HostName = @HostName;
END;

GO

