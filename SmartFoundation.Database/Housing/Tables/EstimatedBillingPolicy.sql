CREATE TABLE [Housing].[EstimatedBillingPolicy] (
    [EstimatedBillingPolicyID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [EstimatedBillingPolicyName_A]      NVARCHAR (200)  NOT NULL,
    [EstimatedBillingPolicyName_E]      NVARCHAR (200)  NULL,
    [IdaraID_FK]                        BIGINT          NULL,
    [EffectiveFrom]                     DATE            NOT NULL,
    [EffectiveTo]                       DATE            NULL,
    [TaxApplicable]                     BIT             CONSTRAINT [DF_EstimatedBillingPolicy_TaxApplicable] DEFAULT ((1)) NOT NULL,
    [TaxInclusive]                      BIT             CONSTRAINT [DF_EstimatedBillingPolicy_TaxInclusive] DEFAULT ((1)) NOT NULL,
    [EstimatedBillingPolicyActive]      BIT             CONSTRAINT [DF_EstimatedBillingPolicy_Active] DEFAULT ((1)) NOT NULL,
    [EstimatedBillingPolicyDescription] NVARCHAR (1000) NULL,
    [CanceledBy]                        NVARCHAR (20)   NULL,
    [CanceledDate]                      DATETIME        NULL,
    [entryDate]                         DATETIME        CONSTRAINT [DF_EstimatedBillingPolicy_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                         NVARCHAR (20)   NULL,
    [hostName]                          NVARCHAR (200)  NULL,
    CONSTRAINT [PK_EstimatedBillingPolicy] PRIMARY KEY CLUSTERED ([EstimatedBillingPolicyID] ASC),
    CONSTRAINT [FK_EstimatedBillingPolicy_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [CK_EstimatedBillingPolicy_Dates] CHECK ([EffectiveTo] IS NULL OR [EffectiveTo] >= [EffectiveFrom]),
    CONSTRAINT [CK_EstimatedBillingPolicy_TaxFlags] CHECK ([TaxApplicable] = (1) OR [TaxInclusive] = (0))
);


GO
CREATE NONCLUSTERED INDEX [IX_EstimatedBillingPolicy_Resolution]
    ON [Housing].[EstimatedBillingPolicy]([IdaraID_FK] ASC, [EstimatedBillingPolicyActive] ASC, [EffectiveFrom] DESC, [EffectiveTo] ASC)
    INCLUDE([TaxApplicable], [TaxInclusive]);
