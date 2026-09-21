CREATE TABLE [Housing].[BillCalculationDetails] (
    [BillCalculationDetailsID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [BillCalculationID_FK]     BIGINT          NOT NULL,
    [BuildingSpaceTypeID_FK]   INT             NULL,
    [SpaceTypeCode]            NVARCHAR (50)   NULL,
    [SpaceTypeName_A]          NVARCHAR (100)  NULL,
    [SpaceCount]               INT             NOT NULL,
    [AverageDailyConsumption]  DECIMAL (18, 6) NOT NULL,
    [UsageFactor]              DECIMAL (18, 6) NOT NULL,
    [UnitPrice]                DECIMAL (18, 6) NOT NULL,
    [UnitCode]                 NVARCHAR (30)   NOT NULL,
    [BillingDays]              INT             NOT NULL,
    [AmountBeforeTax]          DECIMAL (18, 2) NOT NULL,
    [TaxAmount]                DECIMAL (18, 2) NOT NULL,
    [TotalAmount]              DECIMAL (18, 2) NOT NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_BillCalculationDetails_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillCalculationDetails] PRIMARY KEY CLUSTERED ([BillCalculationDetailsID] ASC),
    CONSTRAINT [FK_BillCalculationDetails_Calculation] FOREIGN KEY ([BillCalculationID_FK]) REFERENCES [Housing].[BillCalculation] ([BillCalculationID]),
    CONSTRAINT [FK_BillCalculationDetails_SpaceType] FOREIGN KEY ([BuildingSpaceTypeID_FK]) REFERENCES [Housing].[BuildingSpaceType] ([BuildingSpaceTypeID]),
    CONSTRAINT [CK_BillCalculationDetails_SpaceCount] CHECK ([SpaceCount] > (0)),
    CONSTRAINT [CK_BillCalculationDetails_Days] CHECK ([BillingDays] >= (1) AND [BillingDays] <= (30)),
    CONSTRAINT [CK_BillCalculationDetails_Values] CHECK ([AverageDailyConsumption] >= (0) AND [UsageFactor] >= (0) AND [UnitPrice] >= (0)),
    CONSTRAINT [CK_BillCalculationDetails_Amounts] CHECK ([AmountBeforeTax] >= (0) AND [TaxAmount] >= (0) AND [TotalAmount] >= (0))
);


GO
CREATE NONCLUSTERED INDEX [IX_BillCalculationDetails_Calculation]
    ON [Housing].[BillCalculationDetails]([BillCalculationID_FK] ASC)
    INCLUDE([BuildingSpaceTypeID_FK], [SpaceCount], [BillingDays], [AmountBeforeTax], [TaxAmount], [TotalAmount]);
