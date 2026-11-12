CREATE TABLE [Housing].[MonthlyBillingRunDetails] (
    [MonthlyBillingRunDetailsID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [MonthlyBillingRunID_FK]     BIGINT          NOT NULL,
    [BillsID_FK]                 BIGINT          NULL,
    [ResidentInfoID_FK]          BIGINT          NULL,
    [GeneralNo_FK]               BIGINT          NULL,
    [BuildingDetailsID_FK]       BIGINT          NULL,
    [MeterID_FK]                 BIGINT          NULL,
    [FromDate]                   DATE            NULL,
    [ToDate]                     DATE            NULL,
    [ResultStatus]               NVARCHAR (30)   NOT NULL,
    [ReasonCode]                 NVARCHAR (100)  NULL,
    [ReasonMessage]              NVARCHAR (1000) NULL,
    [AmountBeforeTax]            DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRunDetails_Amount] DEFAULT ((0)) NOT NULL,
    [TaxAmount]                  DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRunDetails_Tax] DEFAULT ((0)) NOT NULL,
    [TotalAmount]                DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRunDetails_Total] DEFAULT ((0)) NOT NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_MonthlyBillingRunDetails_entryDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_MonthlyBillingRunDetails] PRIMARY KEY CLUSTERED ([MonthlyBillingRunDetailsID] ASC),
    CONSTRAINT [FK_MonthlyBillingRunDetails_Bill] FOREIGN KEY ([BillsID_FK]) REFERENCES [Housing].[Bills] ([BillsID]),
    CONSTRAINT [FK_MonthlyBillingRunDetails_Run] FOREIGN KEY ([MonthlyBillingRunID_FK]) REFERENCES [Housing].[MonthlyBillingRun] ([MonthlyBillingRunID])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_MonthlyBillingRunDetails_RunBill]
    ON [Housing].[MonthlyBillingRunDetails]([MonthlyBillingRunID_FK] ASC, [BillsID_FK] ASC) WHERE ([BillsID_FK] IS NOT NULL);


GO

CREATE NONCLUSTERED INDEX [IX_MonthlyBillingRunDetails_Result]
    ON [Housing].[MonthlyBillingRunDetails]([MonthlyBillingRunID_FK] ASC, [ResultStatus] ASC, [BuildingDetailsID_FK] ASC);


GO

