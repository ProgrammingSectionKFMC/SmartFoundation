CREATE TABLE [Housing].[BuildingActionType] (
    [buildingActionTypeID]            INT             IDENTITY (1, 1) NOT NULL,
    [buildingActionTypeOrder]         INT             NULL,
    [buildingStatusID_FK]             INT             NULL,
    [buildingActionTypeName_A]        NVARCHAR (100)  NULL,
    [buildingActionTypeName_E]        NVARCHAR (100)  NULL,
    [buildingActionTypeDescriptoin]   NVARCHAR (1000) NULL,
    [buildingActionTypeActive]        BIT             NULL,
    [buildingActionTypeStartDate]     DATETIME        NULL,
    [buildingActionTypeEndDate]       DATETIME        NULL,
    [buildingActionTypeResidentAlias] NVARCHAR (1000) NULL,
    [buildingActionTypeBuildingAlias] NVARCHAR (1000) NULL,
    [buildingActionRoot]              INT             NULL,
    [IsResident]                      BIT             CONSTRAINT [DF_BuildingActionType_IsResident] DEFAULT ((0)) NULL,
    [entryDate]                       DATETIME        CONSTRAINT [DF_BuildingActionType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                       NVARCHAR (20)   NULL,
    [hostName]                        NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingActionType] PRIMARY KEY CLUSTERED ([buildingActionTypeID] ASC)
);




GO
CREATE NONCLUSTERED INDEX [IX_BuildingActionType_ID]
    ON [Housing].[BuildingActionType]([buildingActionTypeID] ASC)
    INCLUDE([buildingActionTypeName_A], [IsResident]);

