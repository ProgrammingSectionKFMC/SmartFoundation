CREATE TABLE [Housing].[MonthlyBillingRun] (
    [MonthlyBillingRunID]   BIGINT          IDENTITY (1, 1) NOT NULL,
    [IdaraID_FK]            BIGINT          NOT NULL,
    [PeriodYear]            INT             NOT NULL,
    [PeriodMonth]           INT             NOT NULL,
    [BillingType]           NVARCHAR (20)   NOT NULL,
    [MeterServiceTypeID_FK] INT             CONSTRAINT [DF_MonthlyBillingRun_Service] DEFAULT ((0)) NOT NULL,
    [CalculationMethod]     NVARCHAR (30)   NOT NULL,
    [RunStatus]             NVARCHAR (30)   NOT NULL,
    [ProposedCount]         INT             CONSTRAINT [DF_MonthlyBillingRun_Proposed] DEFAULT ((0)) NOT NULL,
    [CreatedCount]          INT             CONSTRAINT [DF_MonthlyBillingRun_Created] DEFAULT ((0)) NOT NULL,
    [ExistingCount]         INT             CONSTRAINT [DF_MonthlyBillingRun_Existing] DEFAULT ((0)) NOT NULL,
    [SkippedCount]          INT             CONSTRAINT [DF_MonthlyBillingRun_Skipped] DEFAULT ((0)) NOT NULL,
    [FailedCount]           INT             CONSTRAINT [DF_MonthlyBillingRun_Failed] DEFAULT ((0)) NOT NULL,
    [AmountBeforeTax]       DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRun_Amount] DEFAULT ((0)) NOT NULL,
    [TaxAmount]             DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRun_Tax] DEFAULT ((0)) NOT NULL,
    [TotalAmount]           DECIMAL (18, 2) CONSTRAINT [DF_MonthlyBillingRun_Total] DEFAULT ((0)) NOT NULL,
    [StartedAt]             DATETIME2 (0)   NULL,
    [LastHeartbeatAt]       DATETIME2 (0)   NULL,
    [FinishedAt]            DATETIME2 (0)   NULL,
    [AttemptCount]          INT             CONSTRAINT [DF_MonthlyBillingRun_Attempt] DEFAULT ((0)) NOT NULL,
    [LastError]             NVARCHAR (4000) NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_MonthlyBillingRun_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MonthlyBillingRun] PRIMARY KEY CLUSTERED ([MonthlyBillingRunID] ASC),
    CONSTRAINT [CK_MonthlyBillingRun_Month] CHECK ([PeriodMonth]>=(1) AND [PeriodMonth]<=(12)),
    CONSTRAINT [UQ_MonthlyBillingRun_Scope] UNIQUE NONCLUSTERED ([IdaraID_FK] ASC, [PeriodYear] ASC, [PeriodMonth] ASC, [BillingType] ASC, [MeterServiceTypeID_FK] ASC, [CalculationMethod] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_MonthlyBillingRun_Status]
    ON [Housing].[MonthlyBillingRun]([RunStatus] ASC, [PeriodYear] ASC, [PeriodMonth] ASC, [IdaraID_FK] ASC);


GO

