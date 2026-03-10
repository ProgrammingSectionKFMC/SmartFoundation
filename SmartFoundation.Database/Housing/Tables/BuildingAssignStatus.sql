CREATE TABLE [Housing].[BuildingAssignStatus] (
    [BuildingAssignStatusID]     INT             IDENTITY (1, 1) NOT NULL,
    [BuildingAssignStatusName_A] NVARCHAR (1000) NULL,
    [BuildingAssignStatusName_E] NVARCHAR (1000) NULL,
    [Active]                     BIT             NULL,
    CONSTRAINT [PK_BuildingAssignStatus] PRIMARY KEY CLUSTERED ([BuildingAssignStatusID] ASC)
);

