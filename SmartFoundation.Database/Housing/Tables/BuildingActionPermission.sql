CREATE TABLE [Housing].[BuildingActionPermission] (
    [buildingActionPermissionID]   INT             IDENTITY (1, 1) NOT NULL,
    [buildingActionTypeID_FK]      INT             NULL,
    [perviosActionTypeID_FK]       INT             NULL,
    [distributorID_FK]             INT             NULL,
    [buildingActionPermissionNote] NVARCHAR (1000) NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_BuildingActionPermission_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BuildingActionPermission] PRIMARY KEY CLUSTERED ([buildingActionPermissionID] ASC),
    CONSTRAINT [FK_BuildingActionPermission_BuildingActionType] FOREIGN KEY ([buildingActionTypeID_FK]) REFERENCES [Housing].[BuildingActionType] ([buildingActionTypeID])
);

