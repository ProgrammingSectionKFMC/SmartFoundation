CREATE TABLE [VIC].[MaintenanceGroup] (
    [GroupID]     INT            IDENTITY (1, 1) NOT NULL,
    [GroupCode]   NVARCHAR (10)  NOT NULL,
    [GroupName_A] NVARCHAR (100) NOT NULL,
    [GroupActive] BIT            DEFAULT ((1)) NOT NULL,
    PRIMARY KEY CLUSTERED ([GroupID] ASC)
);


GO

