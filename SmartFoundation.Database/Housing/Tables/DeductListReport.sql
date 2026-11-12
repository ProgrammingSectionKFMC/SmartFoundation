CREATE TABLE [Housing].[DeductListReport] (
    [DeductListReportID]    BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraID_FK]            BIGINT          NOT NULL,
    [PeriodYear]            INT             NOT NULL,
    [PeriodMonth]           INT             NOT NULL,
    [BillingType]           NVARCHAR (20)   NOT NULL,
    [MeterServiceTypeID_FK] INT             NULL,
    [CalculationMethod]     NVARCHAR (30)   NOT NULL,
    [ReportNo]              NVARCHAR (50)   NOT NULL,
    [RevisionNo]            INT             CONSTRAINT [DF_DeductListReport_Revision] DEFAULT ((1)) NOT NULL,
    [ReportStatus]          NVARCHAR (20)   CONSTRAINT [DF_DeductListReport_Status] DEFAULT (N'DRAFT') NOT NULL,
    [IsCurrent]             BIT             CONSTRAINT [DF_DeductListReport_Current] DEFAULT ((1)) NOT NULL,
    [InvoiceCount]          INT             CONSTRAINT [DF_DeductListReport_Count] DEFAULT ((0)) NOT NULL,
    [AmountBeforeTax]       DECIMAL (18, 2) CONSTRAINT [DF_DeductListReport_Amount] DEFAULT ((0)) NOT NULL,
    [TaxAmount]             DECIMAL (18, 2) CONSTRAINT [DF_DeductListReport_Tax] DEFAULT ((0)) NOT NULL,
    [TotalAmount]           DECIMAL (18, 2) CONSTRAINT [DF_DeductListReport_Total] DEFAULT ((0)) NOT NULL,
    [ApprovedDate]          DATETIME        NULL,
    [ApprovedBy]            NVARCHAR (20)   NULL,
    [SentDate]              DATETIME        NULL,
    [SentBy]                NVARCHAR (20)   NULL,
    [ExternalReferenceNo]   NVARCHAR (100)  NULL,
    [Notes]                 NVARCHAR (1000) NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_DeductListReport_EntryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    [ExternalReferenceDate] DATE            NULL,
    CONSTRAINT [PK_DeductListReport] PRIMARY KEY CLUSTERED ([DeductListReportID] ASC),
    CONSTRAINT [CK_DeductListReport_Period] CHECK ([PeriodMonth]>=(1) AND [PeriodMonth]<=(12)),
    CONSTRAINT [CK_DeductListReport_Status] CHECK ([ReportStatus]=N'CANCELLED' OR [ReportStatus]=N'SENT' OR [ReportStatus]=N'APPROVED' OR [ReportStatus]=N'DRAFT'),
    CONSTRAINT [CK_DeductListReport_Type] CHECK ([BillingType]=N'SERVICE' OR [BillingType]=N'RENT'),
    CONSTRAINT [FK_DeductListReport_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DeductListReport_CurrentScope]
    ON [Housing].[DeductListReport]([IdaraID_FK] ASC, [PeriodYear] ASC, [PeriodMonth] ASC, [BillingType] ASC, [MeterServiceTypeID_FK] ASC, [CalculationMethod] ASC) WHERE ([IsCurrent]=(1));


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DeductListReport_ReportNo]
    ON [Housing].[DeductListReport]([ReportNo] ASC);


GO

