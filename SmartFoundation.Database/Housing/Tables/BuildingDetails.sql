CREATE TABLE [Housing].[BuildingDetails] (
    [buildingDetailsID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [buildingDetailsNo]          NVARCHAR (20)   NOT NULL,
    [buildingDetailsRooms]       INT             NULL,
    [buildingLevelsCount]        INT             CONSTRAINT [DF_BuildingDetails_buildingLevelsCount] DEFAULT ((1)) NULL,
    [buildingDetailsArea]        DECIMAL (10, 2) NULL,
    [buildingDetailsCoordinates] NVARCHAR (50)   NULL,
    [buildingTypeID_FK]          BIGINT          NULL,
    [buildingUtilityTypeID_FK]   BIGINT          NULL,
    [militaryLocationID_FK]      INT             NULL,
    [buildingClassID_FK]         BIGINT          NULL,
    [buildingDetailsTel_1]       NVARCHAR (15)   NULL,
    [buildingDetailsTel_2]       NVARCHAR (15)   NULL,
    [buildingDetailsRemark]      NVARCHAR (1000) NULL,
    [buildingDetailsStartDate]   DATETIME        NULL,
    [buildingDetailsEndDate]     DATETIME        NULL,
    [buildingDetailsActive]      BIT             NULL,
    [IdaraId_FK]                 BIGINT          NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_BuildingDetails_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (2000) NULL,
    [hostName]                   NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingDetails] PRIMARY KEY CLUSTERED ([buildingDetailsID] ASC),
    CONSTRAINT [FK_BuildingDetails_BuildingClass] FOREIGN KEY ([buildingClassID_FK]) REFERENCES [Housing].[BuildingClass] ([buildingClassID]),
    CONSTRAINT [FK_BuildingDetails_BuildingType] FOREIGN KEY ([buildingTypeID_FK]) REFERENCES [Housing].[BuildingType] ([buildingTypeID]),
    CONSTRAINT [FK_BuildingDetails_BuildingUtilityType] FOREIGN KEY ([buildingUtilityTypeID_FK]) REFERENCES [Housing].[BuildingUtilityType] ([buildingUtilityTypeID]),
    CONSTRAINT [FK_BuildingDetails_MilitaryLocation] FOREIGN KEY ([militaryLocationID_FK]) REFERENCES [Housing].[MilitaryLocation] ([militaryLocationID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingDetails_Active_Start_End]
    ON [Housing].[BuildingDetails]([buildingDetailsActive] ASC, [buildingDetailsStartDate] ASC, [buildingDetailsEndDate] ASC)
    INCLUDE([buildingTypeID_FK], [buildingUtilityTypeID_FK], [militaryLocationID_FK], [buildingClassID_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingDetails_ActiveDates]
    ON [Housing].[BuildingDetails]([buildingDetailsActive] ASC, [buildingDetailsEndDate] ASC, [buildingDetailsStartDate] ASC)
    INCLUDE([buildingDetailsID], [buildingTypeID_FK], [buildingUtilityTypeID_FK], [militaryLocationID_FK], [buildingClassID_FK]);

