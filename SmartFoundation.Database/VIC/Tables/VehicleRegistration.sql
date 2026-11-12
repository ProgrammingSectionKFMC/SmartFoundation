CREATE TABLE [VIC].[VehicleRegistration] (
    [ID]          INT            NOT NULL,
    [VehicleCode] NVARCHAR (50)  NOT NULL,
    [VehicleType] NVARCHAR (200) NOT NULL,
    [ArmyNumber]  NVARCHAR (50)  NOT NULL,
    [Note]        NVARCHAR (200) NULL,
    [entryDate]   DATETIME       NULL,
    [entryData]   NVARCHAR (200) NULL,
    [hostName]    NVARCHAR (200) NULL,
    CONSTRAINT [PK_VehicleRegistration] PRIMARY KEY CLUSTERED ([ID] ASC)
);


GO

