CREATE TABLE [VIC].[Vehicles] (
    [vehicleID]             INT             IDENTITY (1, 1) NOT NULL,
    [ownerID_FK]            NVARCHAR (50)   NULL,
    [ManufacturerNameID_FK] INT             NULL,
    [vehicleModelID_FK]     INT             NULL,
    [vehicleClassID_FK]     INT             NULL,
    [TypeOfUseID_FK]        INT             NULL,
    [vehicleColorID_FK]     INT             NULL,
    [countryMadeID_FK]      INT             NULL,
    [regstritionTypeID_FK]  INT             NULL,
    [regionID_FK]           INT             NULL,
    [fuelTypeID_FK]         INT             NULL,
    [vehicleTypeID_FK]      INT             NULL,
    [yearModel]             INT             NULL,
    [capacity]              INT             NULL,
    [chassisNumber]         NVARCHAR (100)  NOT NULL,
    [serialNumber]          NVARCHAR (50)   NULL,
    [plateLetters]          NVARCHAR (50)   NULL,
    [plateNumbers]          INT             NULL,
    [armyNumber]            NVARCHAR (50)   NULL,
    [vehicleNote]           NVARCHAR (400)  NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_Vehicles_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    [isActive]              BIT             CONSTRAINT [DF_Vehicles_isActive] DEFAULT ((1)) NOT NULL,
    [IdaraID_FK]            BIGINT          NOT NULL,
    [vehicleStatusID_FK]    INT             NULL,
    [scrapDate]             DATETIME        NULL,
    [scrapRefNo]            NVARCHAR (100)  NULL,
    [scrapReason]           NVARCHAR (400)  NULL,
    [scrapNote]             NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Vehicles] PRIMARY KEY CLUSTERED ([chassisNumber] ASC),
    CONSTRAINT [FK_Vehicles_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID])
);


GO

CREATE   TRIGGER VIC.tr_Vehicles_Scrap_MaintenanceCleanup
ON VIC.Vehicles
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- PeriodicMaintenance START - cancel maintenance cycle when vehicle becomes scrapped (262)
    UPDATE p SET p.planActive = 0
    FROM VIC.VehicleMaintenancePlan p
    INNER JOIN inserted i ON p.chassisNumber_FK = i.chassisNumber
    INNER JOIN deleted d ON i.chassisNumber = d.chassisNumber
    WHERE i.vehicleStatusID_FK = 262 AND ISNULL(d.vehicleStatusID_FK,0) <> 262 AND p.planActive = 1;

    UPDATE vmg SET vmg.Active = 0
    FROM VIC.VehicleMaintenanceGroup vmg
    INNER JOIN inserted i ON vmg.chassisNumber_FK = i.chassisNumber
    INNER JOIN deleted d ON i.chassisNumber = d.chassisNumber
    WHERE i.vehicleStatusID_FK = 262 AND ISNULL(d.vehicleStatusID_FK,0) <> 262 AND vmg.Active = 1;

    UPDATE m SET m.Cancelled = 1,
        m.CancelReason = NCHAR(1575)+NCHAR(1604)+NCHAR(1605)+NCHAR(1585)+NCHAR(1603)+NCHAR(1576)+NCHAR(1577)+NCHAR(32)+NCHAR(1578)+NCHAR(1575)+NCHAR(1604)+NCHAR(1601)+NCHAR(1577),
        m.CancelDate = GETDATE(),
        m.MaintOrdActive = 0
    FROM VIC.VehicleMaintenance m
    INNER JOIN inserted i ON m.chassisNumber_FK = i.chassisNumber
    INNER JOIN deleted d ON i.chassisNumber = d.chassisNumber
    WHERE i.vehicleStatusID_FK = 262 AND ISNULL(d.vehicleStatusID_FK,0) <> 262
      AND m.MaintOrdTypeID_FK = 265 AND m.MaintOrdActive = 1;
    -- PeriodicMaintenance END
END

GO

