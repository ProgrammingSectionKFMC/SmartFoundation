CREATE TABLE [VIC].[VehicleTransferRequestType] (
    [VehicleTransferRequestTypeID]    INT            IDENTITY (1, 1) NOT NULL,
    [VehicleTransferRequestTypeNameA] NVARCHAR (50)  NULL,
    [VehicleTransferRequestTypeNameE] NVARCHAR (50)  NULL,
    [Active]                          BIT            NULL,
    [entryDate]                       DATETIME       CONSTRAINT [DF_VehicleTransferRequestType_ed] DEFAULT (getdate()) NOT NULL,
    [entryData]                       NVARCHAR (40)  NULL,
    [hostName]                        NVARCHAR (400) NULL,
    CONSTRAINT [PK_VehicleTransferRequestType] PRIMARY KEY CLUSTERED ([VehicleTransferRequestTypeID] ASC)
);

