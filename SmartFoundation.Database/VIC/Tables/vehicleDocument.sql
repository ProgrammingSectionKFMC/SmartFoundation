CREATE TABLE [VIC].[vehicleDocument] (
    [vehicleDocumentID]        INT            IDENTITY (1, 1) NOT NULL,
    [vehicleDocumentTypeID_FK] INT            NULL,
    [chassisNumber_FK]         NVARCHAR (100) NULL,
    [vehicleDocumentNo]        NVARCHAR (50)  NULL,
    [vehicleDocumentStartDate] DATETIME       NULL,
    [vehicleDocumentEndDate]   DATETIME       NULL,
    [entryDate]                DATETIME       CONSTRAINT [DF_vehicleDocument_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)  NULL,
    [hostName]                 NVARCHAR (200) NULL,
    [IdaraID_FK]               BIGINT         NULL,
    CONSTRAINT [PK_vehicleDocument] PRIMARY KEY CLUSTERED ([vehicleDocumentID] ASC),
    CONSTRAINT [CK_vehicleDocument_DateRange] CHECK ([vehicleDocumentStartDate] IS NULL OR [vehicleDocumentEndDate] IS NULL OR [vehicleDocumentStartDate]<=[vehicleDocumentEndDate]),
    CONSTRAINT [FK_vehicleDocument_DocType] FOREIGN KEY ([vehicleDocumentTypeID_FK]) REFERENCES [VIC].[VehiclesDocumentType] ([vehicleDocumentTypeID]),
    CONSTRAINT [FK_vehicleDocument_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_vehicleDocument_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

