CREATE TABLE [VIC].[VehiclesDocumentType] (
    [vehicleDocumentTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [vehicleDocumentTypeName_A] NVARCHAR (50)  NULL,
    [vehicleDocumentTypeName_E] NVARCHAR (50)  NULL,
    [vehicleDocumentTypeActive] BIT            NULL,
    [entryDate]                 DATETIME       CONSTRAINT [DF_VehiclesDocumentType_ed] DEFAULT (getdate()) NOT NULL,
    [entryData]                 NVARCHAR (40)  NULL,
    [hostName]                  NVARCHAR (400) NULL,
    CONSTRAINT [PK_VehiclesDocumentType] PRIMARY KEY CLUSTERED ([vehicleDocumentTypeID] ASC)
);

