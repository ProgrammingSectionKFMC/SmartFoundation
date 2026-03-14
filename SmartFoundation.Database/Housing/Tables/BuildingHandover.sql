CREATE TABLE [Housing].[BuildingHandover] (
    [BuildinghandoverID]          INT             IDENTITY (1, 1) NOT NULL,
    [BuildingActionTypeID_FK]     INT             NULL,
    [NextBuildingActionTypeID_FK] INT             NULL,
    [PermissionTypeID_FK]         INT             NULL,
    [BuildinghandoverNote]        NVARCHAR (1000) NULL,
    [BuildinghandoverActive]      INT             NOT NULL,
    [IdaraID_FK]                  INT             NULL,
    [entryDate]                   DATETIME        NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL
);

