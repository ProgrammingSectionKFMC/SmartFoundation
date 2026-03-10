CREATE TABLE [Housing].[BuildingStatus] (
    [buildingStatusID]          INT             IDENTITY (1, 1) NOT NULL,
    [buildigStatusName_A]       NVARCHAR (100)  NULL,
    [buildingStatusName_E]      NVARCHAR (100)  NULL,
    [buildingStatusDescription] NVARCHAR (1000) NULL,
    [buildingStatusActive]      BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_BuildingStatus_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingStatus] PRIMARY KEY CLUSTERED ([buildingStatusID] ASC)
);

