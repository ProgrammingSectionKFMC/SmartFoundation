CREATE TABLE [Housing].[BuildingAssignType] (
    [BuildingAssignTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [BuildingAssignTypeName_A] NCHAR (300)    NULL,
    [BuildingAssignTypeName_E] NVARCHAR (300) NULL,
    [Active]                   BIT            NULL,
    CONSTRAINT [PK_BuildingAssignType] PRIMARY KEY CLUSTERED ([BuildingAssignTypeID] ASC)
);

