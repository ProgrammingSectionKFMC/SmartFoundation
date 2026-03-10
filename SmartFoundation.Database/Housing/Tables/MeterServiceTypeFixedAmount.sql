CREATE TABLE [Housing].[MeterServiceTypeFixedAmount] (
    [MeterServiceTypeFixedAmountID]        INT             IDENTITY (1, 1) NOT NULL,
    [MeterServiceTypeID_FK]                INT             NULL,
    [FixedAmount]                          DECIMAL (18, 2) NULL,
    [MeterServiceTypeFixedAmountStartDate] DATETIME        NULL,
    [MeterServiceTypeFixedAmountEndDate]   DATETIME        NULL,
    [MeterServiceTypeFixedAmountActive]    BIT             NULL,
    [idaraID_FK]                           BIGINT          NULL,
    [entryDate]                            DATETIME        CONSTRAINT [DF_MeterServiceTypeFixedAmount_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                            NVARCHAR (20)   NULL,
    [hostName]                             NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterServiceTypeFixedAmount] PRIMARY KEY CLUSTERED ([MeterServiceTypeFixedAmountID] ASC)
);

