CREATE TABLE [Housing].[MeterTypeFixedAmount] (
    [MeterTypeFixedAmountID]        INT             IDENTITY (1, 1) NOT NULL,
    [MeterTypeID_FK]                INT             NULL,
    [FixedAmount]                   DECIMAL (18, 2) NULL,
    [MeterTypeFixedAmountStartDate] DATETIME        NULL,
    [MeterTypeFixedAmountEndDate]   DATETIME        NULL,
    [MeterTypeFixedAmountActive]    BIT             NULL,
    [idaraID_FK]                    BIGINT          NULL,
    [entryDate]                     DATETIME        CONSTRAINT [DF_MeterTypeFixedAmount_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                     NVARCHAR (20)   NULL,
    [hostName]                      NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterTypeFixedAmount] PRIMARY KEY CLUSTERED ([MeterTypeFixedAmountID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_MeterTypeFixedAmount_Search]
    ON [Housing].[MeterTypeFixedAmount]([idaraID_FK] ASC, [MeterTypeFixedAmountActive] ASC, [MeterTypeID_FK] ASC, [MeterTypeFixedAmountID] DESC)
    INCLUDE([FixedAmount]);


GO

