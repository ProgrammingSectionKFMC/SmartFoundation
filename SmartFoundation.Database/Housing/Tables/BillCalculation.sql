CREATE TABLE [Housing].[BillCalculation] (
    [BillCalculationID]           BIGINT          IDENTITY (1, 1) NOT NULL,
    [BillsID_FK]                  BIGINT          NOT NULL,
    [CalculationMethod]           NVARCHAR (40)   NOT NULL,
    [EstimatedBillingPolicyID_FK] BIGINT          NULL,
    [BillingDays]                 INT             NOT NULL,
    [TaxApplicable]               BIT             NOT NULL,
    [TaxInclusive]                BIT             NOT NULL,
    [TaxID_FK]                    INT             NULL,
    [TaxRate]                     DECIMAL (9, 6)  NOT NULL,
    [AmountBeforeTax]             DECIMAL (18, 2) NOT NULL,
    [TaxAmount]                   DECIMAL (18, 2) NOT NULL,
    [TotalAmount]                 DECIMAL (18, 2) NOT NULL,
    [CalculationReason]           NVARCHAR (1000) NULL,
    [entryDate]                   DATETIME        CONSTRAINT [DF_BillCalculation_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                   NVARCHAR (20)   NULL,
    [hostName]                    NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillCalculation] PRIMARY KEY CLUSTERED ([BillCalculationID] ASC),
    CONSTRAINT [FK_BillCalculation_Bill] FOREIGN KEY ([BillsID_FK]) REFERENCES [Housing].[Bills] ([BillsID]),
    CONSTRAINT [FK_BillCalculation_Policy] FOREIGN KEY ([EstimatedBillingPolicyID_FK]) REFERENCES [Housing].[EstimatedBillingPolicy] ([EstimatedBillingPolicyID]),
    CONSTRAINT [FK_BillCalculation_Tax] FOREIGN KEY ([TaxID_FK]) REFERENCES [dbo].[Tax] ([taxID]),
    CONSTRAINT [UQ_BillCalculation_Bill] UNIQUE NONCLUSTERED ([BillsID_FK] ASC),
    CONSTRAINT [CK_BillCalculation_Method] CHECK ([CalculationMethod] IN (N'METER_READING', N'SPACE_ESTIMATED', N'METER_FIXED', N'SERVICE_FIXED_FALLBACK')),
    CONSTRAINT [CK_BillCalculation_Days] CHECK ([BillingDays] >= (1) AND [BillingDays] <= (30)),
    CONSTRAINT [CK_BillCalculation_TaxRate] CHECK ([TaxRate] >= (0) AND [TaxRate] <= (1)),
    CONSTRAINT [CK_BillCalculation_Amounts] CHECK ([AmountBeforeTax] >= (0) AND [TaxAmount] >= (0) AND [TotalAmount] >= (0))
);


GO
CREATE NONCLUSTERED INDEX [IX_BillCalculation_MethodPolicy]
    ON [Housing].[BillCalculation]([CalculationMethod] ASC, [EstimatedBillingPolicyID_FK] ASC)
    INCLUDE([BillsID_FK], [BillingDays], [AmountBeforeTax], [TaxAmount], [TotalAmount]);
