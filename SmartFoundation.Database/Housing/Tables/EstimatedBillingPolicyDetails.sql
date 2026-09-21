CREATE TABLE [Housing].[EstimatedBillingPolicyDetails] (
    [EstimatedBillingPolicyDetailsID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [EstimatedBillingPolicyID_FK]     BIGINT          NOT NULL,
    [MeterServiceTypeID_FK]           INT             NOT NULL,
    [BuildingSpaceTypeID_FK]          INT             NOT NULL,
    [AverageDailyConsumption]         DECIMAL (18, 6) NOT NULL,
    [UsageFactor]                     DECIMAL (18, 6) CONSTRAINT [DF_EstimatedBillingPolicyDetails_UsageFactor] DEFAULT ((1)) NOT NULL,
    [UnitPrice]                       DECIMAL (18, 6) NOT NULL,
    [UnitCode]                        NVARCHAR (30)   NOT NULL,
    [EstimatedBillingPolicyDetailsActive] BIT         CONSTRAINT [DF_EstimatedBillingPolicyDetails_Active] DEFAULT ((1)) NOT NULL,
    [CanceledBy]                      NVARCHAR (20)   NULL,
    [CanceledDate]                    DATETIME        NULL,
    [entryDate]                       DATETIME        CONSTRAINT [DF_EstimatedBillingPolicyDetails_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                       NVARCHAR (20)   NULL,
    [hostName]                        NVARCHAR (200)  NULL,
    CONSTRAINT [PK_EstimatedBillingPolicyDetails] PRIMARY KEY CLUSTERED ([EstimatedBillingPolicyDetailsID] ASC),
    CONSTRAINT [FK_EstimatedBillingPolicyDetails_Policy] FOREIGN KEY ([EstimatedBillingPolicyID_FK]) REFERENCES [Housing].[EstimatedBillingPolicy] ([EstimatedBillingPolicyID]),
    CONSTRAINT [FK_EstimatedBillingPolicyDetails_ServiceType] FOREIGN KEY ([MeterServiceTypeID_FK]) REFERENCES [Housing].[MeterServiceType] ([meterServiceTypeID]),
    CONSTRAINT [FK_EstimatedBillingPolicyDetails_SpaceType] FOREIGN KEY ([BuildingSpaceTypeID_FK]) REFERENCES [Housing].[BuildingSpaceType] ([BuildingSpaceTypeID]),
    CONSTRAINT [UQ_EstimatedBillingPolicyDetails_Rule] UNIQUE NONCLUSTERED ([EstimatedBillingPolicyID_FK] ASC, [MeterServiceTypeID_FK] ASC, [BuildingSpaceTypeID_FK] ASC),
    CONSTRAINT [CK_EstimatedBillingPolicyDetails_Average] CHECK ([AverageDailyConsumption] >= (0)),
    CONSTRAINT [CK_EstimatedBillingPolicyDetails_UsageFactor] CHECK ([UsageFactor] >= (0)),
    CONSTRAINT [CK_EstimatedBillingPolicyDetails_UnitPrice] CHECK ([UnitPrice] >= (0))
);


GO
CREATE NONCLUSTERED INDEX [IX_EstimatedBillingPolicyDetails_Lookup]
    ON [Housing].[EstimatedBillingPolicyDetails]([EstimatedBillingPolicyID_FK] ASC, [MeterServiceTypeID_FK] ASC, [EstimatedBillingPolicyDetailsActive] ASC)
    INCLUDE([BuildingSpaceTypeID_FK], [AverageDailyConsumption], [UsageFactor], [UnitPrice], [UnitCode]);
