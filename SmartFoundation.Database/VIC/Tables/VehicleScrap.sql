CREATE TABLE [VIC].[VehicleScrap] (
    [ScrapID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [chassisNumber_FK] NVARCHAR (100)  NOT NULL,
    [IdaraID_FK]       BIGINT          NULL,
    [ScrapDate]        DATETIME        NULL,
    [ScrapTypeID_FK]   INT             NULL,
    [RefNo]            NVARCHAR (100)  NULL,
    [Reason]           NVARCHAR (400)  NULL,
    [Note]             NVARCHAR (1000) NULL,
    [ApprovedByUserID] BIGINT          NULL,
    [ApprovedDate]     DATETIME        NULL,
    [Status]           NVARCHAR (20)   NOT NULL,
    [entryDate]        DATETIME        NULL,
    [entryData]        NVARCHAR (40)   NULL,
    [hostName]         NVARCHAR (400)  NULL,
    [Notes]            NVARCHAR (1000) NULL,
    CONSTRAINT [PK_VehicleScrap] PRIMARY KEY CLUSTERED ([ScrapID] ASC),
    CONSTRAINT [CK_VehicleScrap_Status] CHECK ([Status]=N'Cancelled' OR [Status]=N'Approved' OR [Status]=N'Draft'),
    CONSTRAINT [FK_VehicleScrap_TypesRoot_ScrapType] FOREIGN KEY ([ScrapTypeID_FK]) REFERENCES [VIC].[TypesRoot] ([typesID]),
    CONSTRAINT [FK_VehicleScrap_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

