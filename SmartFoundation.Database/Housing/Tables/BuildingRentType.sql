CREATE TABLE [Housing].[BuildingRentType] (
    [buildingRentTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [buildingRentTypeDays]        INT             NULL,
    [buildingRentTypeName_A]      NVARCHAR (100)  NULL,
    [buildingRentTypeName_E]      NVARCHAR (100)  NULL,
    [buildingRentTypeDescription] NVARCHAR (1000) NULL,
    [buildingRentTypeActive]      BIT             NULL,
    [entryDate]                   DATETIME        CONSTRAINT [DF_BuildingRentType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingRentType] PRIMARY KEY CLUSTERED ([buildingRentTypeID] ASC)
);

