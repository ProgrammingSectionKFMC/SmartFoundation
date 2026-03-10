CREATE TABLE [Housing].[BuildingRent] (
    [buildingRentID]          INT             IDENTITY (1, 1) NOT NULL,
    [buildingRentTypeID_FK]   INT             NULL,
    [buildingDetailsID_FK]    BIGINT          NULL,
    [buildingRentAmount]      DECIMAL (10, 2) NULL,
    [buildingRentStartDate]   DATETIME        NULL,
    [buildingRentEndDate]     DATETIME        NULL,
    [buildingRentDescription] NVARCHAR (1000) NULL,
    [buildingRentActive]      BIT             NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_BuildingRent_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (2000) NULL,
    [hostName]                NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingRent] PRIMARY KEY CLUSTERED ([buildingRentID] ASC),
    CONSTRAINT [FK_BuildingRent_BuildingDetails] FOREIGN KEY ([buildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_BuildingRent_BuildingRentType] FOREIGN KEY ([buildingRentTypeID_FK]) REFERENCES [Housing].[BuildingRentType] ([buildingRentTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingRent_Details_Dates]
    ON [Housing].[BuildingRent]([buildingDetailsID_FK] ASC, [buildingRentStartDate] ASC, [buildingRentEndDate] ASC)
    INCLUDE([buildingRentAmount]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingRent_Building_Start]
    ON [Housing].[BuildingRent]([buildingDetailsID_FK] ASC, [buildingRentStartDate] ASC)
    INCLUDE([buildingRentEndDate], [buildingRentAmount], [buildingRentID]);

