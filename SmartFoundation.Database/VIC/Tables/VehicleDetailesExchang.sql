CREATE TABLE [VIC].[VehicleDetailesExchang] (
    [VehicleDetailesExchangID] INT            IDENTITY (1, 1) NOT NULL,
    [VehicleHandoverID_FK]     INT            NULL,
    [DetailesNote]             NVARCHAR (500) NULL,
    [entryDate]                DATETIME       CONSTRAINT [DF_VehicleDetailesExchang_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)  NULL,
    [hostName]                 NVARCHAR (200) NULL,
    CONSTRAINT [PK_VehicleDetailesExchang] PRIMARY KEY CLUSTERED ([VehicleDetailesExchangID] ASC)
);

