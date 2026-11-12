CREATE TABLE [Housing].[BuildingDetailsMeterServices] (
    [BuildingDetailsMeterServicesID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [BuildingDetailsID_FK]                  BIGINT          NULL,
    [MeterServicesTypeID_FK]                INT             NULL,
    [BuildingDetailsMeterServicesStartDate] DATETIME        NULL,
    [BuildingDetailsMeterServicesEndDate]   DATETIME        NULL,
    [BuildingDetailsMeterServicesActive]    BIT             NULL,
    [IdaraId_FK]                            BIGINT          NULL,
    [entryDate]                             DATETIME        CONSTRAINT [DF_BuildingDetailsMeterServices_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                             NVARCHAR (2000) NULL,
    [hostName]                              NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingDetailsMeterServices] PRIMARY KEY CLUSTERED ([BuildingDetailsMeterServicesID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_BuildingDetailsMeterServices_HistoricalBilling]
    ON [Housing].[BuildingDetailsMeterServices]([BuildingDetailsID_FK] ASC, [IdaraId_FK] ASC, [MeterServicesTypeID_FK] ASC)
    INCLUDE([BuildingDetailsMeterServicesActive], [BuildingDetailsMeterServicesStartDate], [BuildingDetailsMeterServicesEndDate]);


GO

