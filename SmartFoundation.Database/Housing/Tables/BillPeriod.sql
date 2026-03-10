CREATE TABLE [Housing].[BillPeriod] (
    [billPeriodID]        INT            IDENTITY (1, 1) NOT NULL,
    [billPeriodTypeID_FK] INT            NULL,
    [billPeriodName_A]    NVARCHAR (100) NULL,
    [billPeriodName_E]    NVARCHAR (100) NULL,
    [billPeriodStartDate] DATETIME       NULL,
    [billPeriodEndDate]   DATETIME       NULL,
    [billPeriodActive]    BIT            NULL,
    [ClosedBy]            NVARCHAR (500) NULL,
    [IdaraId_FK]          BIGINT         NULL,
    [entryDate]           DATETIME       CONSTRAINT [DF_BillPeriod_entryDate] DEFAULT (getdate()) NULL,
    [entryData]           NVARCHAR (20)  NULL,
    [hostName]            NVARCHAR (200) NULL,
    CONSTRAINT [PK_BillPeriod] PRIMARY KEY CLUSTERED ([billPeriodID] ASC),
    CONSTRAINT [FK_BillPeriod_BillPeriodType] FOREIGN KEY ([billPeriodTypeID_FK]) REFERENCES [Housing].[BillPeriodType] ([billPeriodTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BillPeriod_Idara_Active_Type_PeriodID]
    ON [Housing].[BillPeriod]([IdaraId_FK] ASC, [billPeriodActive] ASC, [billPeriodTypeID_FK] ASC, [billPeriodID] ASC);

