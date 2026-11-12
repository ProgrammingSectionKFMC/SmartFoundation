CREATE PROCEDURE [MoveData].[usp_MigrateBuildingFixedServices]
    @IdaraId bigint,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    /* Normalize migration administration: preserve a valid supplied value, otherwise use Idara 1. */
    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = 1)
        THROW 57990, N'Default migration Idara 1 does not exist.', 1;
    IF @IdaraId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        SET @IdaraId = 1;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Idara WHERE idaraID = @IdaraId)
        THROW 56600, N'The supplied IdaraId does not exist.', 1;

    /*
       Historical service bills may have been imported before the house-service
       configuration was introduced.  Resolve the service through BillChargeType
       so this applies to every configured fixed service, not water only.
       A service must already be active, linked to the administration, and have
       a fixed amount; migration never invents a tariff or an administration link.
    */
    DECLARE @BillServicesUpdated bigint = 0,
            @BuildingServicesInserted bigint = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH HistoricalFixedBills AS
        (
            SELECT
                bill.BillsID,
                bill.buildingDetailsID,
                charge.MeterServiceTypeID_FK AS MeterServiceTypeID,
                CAST
                (
                    COALESCE
                    (
                        bill.BillsFromDate,
                        DATEFROMPARTS(bill.PeriodYear, bill.PeriodMonth, 1)
                    )
                    AS date
                ) AS ServiceStartDate
            FROM Housing.Bills bill
            JOIN Housing.BillChargeType charge
              ON charge.BillChargeTypeID = bill.BillChargeTypeID_FK
            JOIN Housing.MeterServiceType serviceType
              ON serviceType.meterServiceTypeID = charge.MeterServiceTypeID_FK
             AND serviceType.meterServiceTypeActive = 1
            WHERE bill.idaraID_FK = @IdaraId
              AND bill.BillActive = 1
              AND bill.buildingDetailsID IS NOT NULL
              /* Metered legacy bills are migrated by their dedicated path;
                 this procedure owns only no-meter fixed-service bills. */
              AND bill.meterID IS NULL
              AND bill.meterReadID IS NULL
              AND charge.MeterServiceTypeID_FK IS NOT NULL
              AND EXISTS
              (
                  SELECT 1
                  FROM Housing.MeterServiceTypeLinkedWithIdara serviceLink
                  WHERE serviceLink.MeterServiceTypeID_FK = charge.MeterServiceTypeID_FK
                    AND serviceLink.Idara_FK = @IdaraId
                    AND serviceLink.MeterServiceTypeLinkedWithIdaraActive = 1
              )
        )
        UPDATE bill
           SET meterServiceTypeID = source.MeterServiceTypeID
        FROM Housing.Bills bill
        JOIN HistoricalFixedBills source
          ON source.BillsID = bill.BillsID
        WHERE bill.meterServiceTypeID IS NULL;
        SET @BillServicesUpdated = @@ROWCOUNT;

        ;WITH HistoricalServiceStart AS
        (
            SELECT
                bill.buildingDetailsID,
                charge.MeterServiceTypeID_FK AS MeterServiceTypeID,
                MIN
                (
                    CAST
                    (
                        COALESCE
                        (
                            bill.BillsFromDate,
                            DATEFROMPARTS(bill.PeriodYear, bill.PeriodMonth, 1)
                        )
                        AS date
                    )
                ) AS ServiceStartDate
            FROM Housing.Bills bill
            JOIN Housing.BillChargeType charge
              ON charge.BillChargeTypeID = bill.BillChargeTypeID_FK
            JOIN Housing.MeterServiceType serviceType
              ON serviceType.meterServiceTypeID = charge.MeterServiceTypeID_FK
             AND serviceType.meterServiceTypeActive = 1
            WHERE bill.idaraID_FK = @IdaraId
              AND bill.BillActive = 1
              AND bill.buildingDetailsID IS NOT NULL
              AND bill.meterID IS NULL
              AND bill.meterReadID IS NULL
              AND charge.MeterServiceTypeID_FK IS NOT NULL
              AND EXISTS
              (
                  SELECT 1
                  FROM Housing.MeterServiceTypeLinkedWithIdara serviceLink
                  WHERE serviceLink.MeterServiceTypeID_FK = charge.MeterServiceTypeID_FK
                    AND serviceLink.Idara_FK = @IdaraId
                    AND serviceLink.MeterServiceTypeLinkedWithIdaraActive = 1
              )
            GROUP BY bill.buildingDetailsID, charge.MeterServiceTypeID_FK
        )
        INSERT INTO Housing.BuildingDetailsMeterServices
        (
            BuildingDetailsID_FK,
            MeterServicesTypeID_FK,
            BuildingDetailsMeterServicesStartDate,
            BuildingDetailsMeterServicesActive,
            IdaraId_FK,
            entryDate,
            entryData,
            hostName
        )
        SELECT
            source.buildingDetailsID,
            source.MeterServiceTypeID,
            source.ServiceStartDate,
            1,
            @IdaraId,
            GETDATE(),
            N'MIGRATION',
            N'usp_MigrateBuildingFixedServices'
        FROM HistoricalServiceStart source
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Housing.BuildingDetailsMeterServices buildingService
            WHERE buildingService.BuildingDetailsID_FK = source.buildingDetailsID
              AND buildingService.MeterServicesTypeID_FK = source.MeterServiceTypeID
              AND buildingService.IdaraId_FK = @IdaraId
              AND buildingService.BuildingDetailsMeterServicesActive = 1
        );
        SET @BuildingServicesInserted = @@ROWCOUNT;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            @BillServicesUpdated AS FixedServiceBillsUpdated,
            @BuildingServicesInserted AS BuildingFixedServicesInserted;

        IF @RollbackAfterTest = 1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

