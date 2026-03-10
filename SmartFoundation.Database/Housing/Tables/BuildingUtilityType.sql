CREATE TABLE [Housing].[BuildingUtilityType] (
    [buildingUtilityTypeID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [buildingUtilityTypeName_A]      NVARCHAR (100)  NULL,
    [buildingUtilityTypeName_E]      NVARCHAR (100)  NULL,
    [buildingUtilityTypeDescription] NVARCHAR (1000) NULL,
    [buildingUtilityTypeActive]      BIT             NULL,
    [buildingUtilityTypeStartDate]   DATETIME        NULL,
    [buildingUtilityTypeEndDate]     DATETIME        NULL,
    [buildingUtilityIsRent]          BIT             NULL,
    [IdaraId_FK]                     INT             NULL,
    [entryDate]                      DATETIME        CONSTRAINT [DF_BuildingUtilityType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (2000) NULL,
    [hostName]                       NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingUtilityType] PRIMARY KEY CLUSTERED ([buildingUtilityTypeID] ASC)
);

