CREATE TABLE [Housing].[BuildingSpace] (
    [BuildingSpaceID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [BuildingDetailsID_FK]   BIGINT          NOT NULL,
    [BuildingSpaceTypeID_FK] INT             NOT NULL,
    [BuildingSpaceSequence]  INT             NOT NULL,
    [BuildingSpaceName]      NVARCHAR (200)  NULL,
    [BuildingSpaceLength]    DECIMAL (10, 2) NULL,
    [BuildingSpaceWidth]     DECIMAL (10, 2) NULL,
    [BuildingSpaceArea]      DECIMAL (10, 2) NULL,
    [BuildingSpaceStartDate] DATE            NULL,
    [BuildingSpaceEndDate]   DATE            NULL,
    [BuildingSpaceActive]    BIT             CONSTRAINT [DF_BuildingSpace_Active] DEFAULT ((1)) NOT NULL,
    [BuildingSpaceRemark]    NVARCHAR (1000) NULL,
    [CanceledBy]             NVARCHAR (20)   NULL,
    [CanceledDate]           DATETIME        NULL,
    [entryDate]              DATETIME        CONSTRAINT [DF_BuildingSpace_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]              NVARCHAR (20)   NULL,
    [hostName]               NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingSpace] PRIMARY KEY CLUSTERED ([BuildingSpaceID] ASC),
    CONSTRAINT [FK_BuildingSpace_BuildingDetails] FOREIGN KEY ([BuildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_BuildingSpace_BuildingSpaceType] FOREIGN KEY ([BuildingSpaceTypeID_FK]) REFERENCES [Housing].[BuildingSpaceType] ([BuildingSpaceTypeID]),
    CONSTRAINT [CK_BuildingSpace_Sequence] CHECK ([BuildingSpaceSequence] > (0)),
    CONSTRAINT [CK_BuildingSpace_Length] CHECK ([BuildingSpaceLength] IS NULL OR [BuildingSpaceLength] > (0)),
    CONSTRAINT [CK_BuildingSpace_Width] CHECK ([BuildingSpaceWidth] IS NULL OR [BuildingSpaceWidth] > (0)),
    CONSTRAINT [CK_BuildingSpace_Area] CHECK ([BuildingSpaceArea] IS NULL OR [BuildingSpaceArea] > (0)),
    CONSTRAINT [CK_BuildingSpace_Dates] CHECK ([BuildingSpaceEndDate] IS NULL OR [BuildingSpaceStartDate] IS NULL OR [BuildingSpaceEndDate] >= [BuildingSpaceStartDate])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_BuildingSpace_ActiveSequence]
    ON [Housing].[BuildingSpace]([BuildingDetailsID_FK] ASC, [BuildingSpaceTypeID_FK] ASC, [BuildingSpaceSequence] ASC)
    WHERE [BuildingSpaceActive] = (1);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingSpace_BillingLookup]
    ON [Housing].[BuildingSpace]([BuildingDetailsID_FK] ASC, [BuildingSpaceActive] ASC, [BuildingSpaceStartDate] ASC, [BuildingSpaceEndDate] ASC)
    INCLUDE([BuildingSpaceTypeID_FK], [BuildingSpaceSequence]);
