CREATE TABLE [Housing].[BuildingUtilityTypeLinkToBillDeductType] (
    [buildingUtilityTypeLinkToBillDeductTypeID]     INT    IDENTITY (1, 1) NOT NULL,
    [billDeductTypeID_FK]                           INT    NULL,
    [buildingUtilityTypeID_FK]                      BIGINT NULL,
    [buildingUtilityTypeLinkToBillDeductTypeActive] BIT    NULL,
    CONSTRAINT [PK_BuildingUtilityTypeLinkToBillDeductType_1] PRIMARY KEY CLUSTERED ([buildingUtilityTypeLinkToBillDeductTypeID] ASC),
    CONSTRAINT [FK_BuildingUtilityTypeLinkToBillDeductType_BillDeductType] FOREIGN KEY ([billDeductTypeID_FK]) REFERENCES [Housing].[BillDeductType] ([billDeductTypeID]),
    CONSTRAINT [FK_BuildingUtilityTypeLinkToBillDeductType_BuildingUtilityType] FOREIGN KEY ([buildingUtilityTypeID_FK]) REFERENCES [Housing].[BuildingUtilityType] ([buildingUtilityTypeID])
);

