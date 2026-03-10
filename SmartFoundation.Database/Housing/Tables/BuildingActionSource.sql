CREATE TABLE [Housing].[BuildingActionSource] (
    [buildingActionSourceID]          INT             IDENTITY (1, 1) NOT NULL,
    [buildingActionSourceName_A]      NVARCHAR (100)  NULL,
    [buildingActionSourceName_E]      NVARCHAR (100)  NULL,
    [buildingActionSourceDescription] NVARCHAR (1000) NULL,
    [buildingActionSourceActive]      BIT             NULL,
    [buildingActionSourceStartDate]   DATETIME        NULL,
    [buildingActionSourceEndDate]     DATETIME        NULL,
    [entryDate]                       DATETIME        CONSTRAINT [DF_BuildingActionSource_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                       NVARCHAR (20)   NULL,
    [hostName]                        NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingActionSource] PRIMARY KEY CLUSTERED ([buildingActionSourceID] ASC)
);

