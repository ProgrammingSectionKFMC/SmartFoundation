CREATE TABLE [VIC].[VehicleRank] (
    [rankID]     INT            IDENTITY (1, 1) NOT NULL,
    [rankName_A] NVARCHAR (100) NULL,
    [rankName_E] NVARCHAR (100) NULL,
    [rankActive] BIT            NULL,
    CONSTRAINT [PK_VehicleRank] PRIMARY KEY CLUSTERED ([rankID] ASC)
);


GO

