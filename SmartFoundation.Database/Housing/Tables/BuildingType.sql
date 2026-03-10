CREATE TABLE [Housing].[BuildingType] (
    [buildingTypeID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [buildingTypeCode]        NVARCHAR (100)  NULL,
    [buildingTypeName_A]      NVARCHAR (1000) NULL,
    [buildingTypeName_E]      NVARCHAR (1000) NULL,
    [buildingTypeDescription] NVARCHAR (3000) NULL,
    [buildingTypeActive]      BIT             NULL,
    [IdaraId_FK]              INT             NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_BuildingType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingType] PRIMARY KEY CLUSTERED ([buildingTypeID] ASC)
);

