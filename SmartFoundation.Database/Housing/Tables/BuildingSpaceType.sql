CREATE TABLE [Housing].[BuildingSpaceType] (
    [BuildingSpaceTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [BuildingSpaceTypeCode]        NVARCHAR (50)   NOT NULL,
    [BuildingSpaceTypeName_A]      NVARCHAR (100)  NOT NULL,
    [BuildingSpaceTypeName_E]      NVARCHAR (100)  NULL,
    [BuildingSpaceTypeDescription] NVARCHAR (1000) NULL,
    [BuildingSpaceTypeStartDate]   DATE            NULL,
    [BuildingSpaceTypeEndDate]     DATE            NULL,
    [BuildingSpaceTypeActive]      BIT             CONSTRAINT [DF_BuildingSpaceType_Active] DEFAULT ((1)) NOT NULL,
    [CanceledBy]                   NVARCHAR (20)   NULL,
    [CanceledDate]                 DATETIME        NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_BuildingSpaceType_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingSpaceType] PRIMARY KEY CLUSTERED ([BuildingSpaceTypeID] ASC),
    CONSTRAINT [UQ_BuildingSpaceType_Code] UNIQUE NONCLUSTERED ([BuildingSpaceTypeCode] ASC),
    CONSTRAINT [CK_BuildingSpaceType_Dates] CHECK ([BuildingSpaceTypeEndDate] IS NULL OR [BuildingSpaceTypeStartDate] IS NULL OR [BuildingSpaceTypeEndDate] >= [BuildingSpaceTypeStartDate])
);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingSpaceType_Active_Dates]
    ON [Housing].[BuildingSpaceType]([BuildingSpaceTypeActive] ASC, [BuildingSpaceTypeStartDate] ASC, [BuildingSpaceTypeEndDate] ASC);
