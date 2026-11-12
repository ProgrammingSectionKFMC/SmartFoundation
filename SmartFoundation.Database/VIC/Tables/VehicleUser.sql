CREATE TABLE [VIC].[VehicleUser] (
    [vehicleUserID] INT            IDENTITY (1, 1) NOT NULL,
    [generalNo]     BIGINT         NULL,
    [nationalID]    NVARCHAR (20)  NULL,
    [mobileNo]      NVARCHAR (20)  NULL,
    [IdaraID_FK]    BIGINT         NOT NULL,
    [userActive]    BIT            DEFAULT ((1)) NOT NULL,
    [entryDate]     DATETIME       DEFAULT (getdate()) NOT NULL,
    [entryData]     NVARCHAR (40)  NULL,
    [hostName]      NVARCHAR (400) NULL,
    CONSTRAINT [PK_VehicleUser] PRIMARY KEY CLUSTERED ([vehicleUserID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_VehicleUser_Idara]
    ON [VIC].[VehicleUser]([IdaraID_FK] ASC, [userActive] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_VehicleUser_NationalID]
    ON [VIC].[VehicleUser]([nationalID] ASC) WHERE ([nationalID] IS NOT NULL);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_VehicleUser_GeneralNo]
    ON [VIC].[VehicleUser]([generalNo] ASC) WHERE ([generalNo] IS NOT NULL);


GO

