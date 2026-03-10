CREATE TABLE [Housing].[BuildingClass] (
    [buildingClassID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [buildingClassName_A]      NVARCHAR (100)  NULL,
    [buildingClassName_E]      NVARCHAR (100)  NULL,
    [buildingClassDescription] NVARCHAR (1000) NULL,
    [buildingClassOrder]       INT             NULL,
    [buildingClassActive]      BIT             NULL,
    [IdaraId_FK]               INT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_BuildingClass_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (2000) NULL,
    [hostName]                 NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingClass] PRIMARY KEY CLUSTERED ([buildingClassID] ASC)
);

