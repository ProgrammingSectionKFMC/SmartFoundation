CREATE TABLE [Housing].[BuildingActionField] (
    [buildingActionFieldID]        INT            IDENTITY (1, 1) NOT NULL,
    [buildingActionTypeID_FK]      INT            NULL,
    [buildingActionFieldName_A]    NVARCHAR (100) NULL,
    [buildingActionFieldName_E]    NVARCHAR (100) NULL,
    [buildingActionFieldControlID] NVARCHAR (100) NULL,
    [buildingActionFieldLabelText] NVARCHAR (100) NULL,
    [buildingActionFieldSerial]    INT            NULL,
    [buildingActionFieldActive]    BIT            NULL,
    [entryDate]                    DATETIME       CONSTRAINT [DF_BuildingActionField_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)  NULL,
    [hostName]                     NVARCHAR (200) NULL,
    CONSTRAINT [PK_BuildingActionField] PRIMARY KEY CLUSTERED ([buildingActionFieldID] ASC),
    CONSTRAINT [FK_BuildingActionField_BuildingActionType] FOREIGN KEY ([buildingActionTypeID_FK]) REFERENCES [Housing].[BuildingActionType] ([buildingActionTypeID])
);

