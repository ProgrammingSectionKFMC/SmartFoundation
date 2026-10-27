CREATE TABLE [Housing].[GeneralBalanceBuildingAllocation] (
    [AllocationID]               BIGINT           IDENTITY (1, 1) NOT NULL,
    [SourcePaymentID_FK]         BIGINT           NOT NULL,
    [TargetBuildingID_FK]        BIGINT           NOT NULL,
    [ResidentInfoID_FK]          BIGINT           NOT NULL,
    [BillChargeTypeID_FK]        INT              NOT NULL,
    [IdaraID_FK]                 INT              NOT NULL,
    [AllocatedAmount]            DECIMAL (18, 2)  NOT NULL,
    [AllocationReference]        NVARCHAR (200)   NOT NULL,
    [AllocationDetails]          NVARCHAR (1000)  NULL,
    [RequestKey]                 UNIQUEIDENTIFIER NOT NULL,
    [AllocationStatus]           TINYINT          CONSTRAINT [DF_GBBA_Status] DEFAULT ((1)) NOT NULL,
    [SourceMovementPaymentID_FK] BIGINT           NOT NULL,
    [TargetMovementPaymentID_FK] BIGINT           NOT NULL,
    [DeductListID_FK]            INT              NOT NULL,
    [EntryDate]                  DATETIME2 (3)    CONSTRAINT [DF_GBBA_EntryDate] DEFAULT (sysdatetime()) NOT NULL,
    [EntryData]                  NVARCHAR (40)    NOT NULL,
    [HostName]                   NVARCHAR (400)   NULL,
    [CancellationReason]         NVARCHAR (1000)  NULL,
    [CancellationDate]           DATETIME2 (3)    NULL,
    [CancellationEntryData]      NVARCHAR (40)    NULL,
    CONSTRAINT [PK_GBBA] PRIMARY KEY CLUSTERED ([AllocationID] ASC),
    CONSTRAINT [CK_GBBA_Amount] CHECK ([AllocatedAmount]>(0)),
    CONSTRAINT [CK_GBBA_Movements] CHECK ([SourcePaymentID_FK]<>[SourceMovementPaymentID_FK] AND [SourcePaymentID_FK]<>[TargetMovementPaymentID_FK] AND [SourceMovementPaymentID_FK]<>[TargetMovementPaymentID_FK]),
    CONSTRAINT [CK_GBBA_Status] CHECK ([AllocationStatus]=(2) OR [AllocationStatus]=(1)),
    CONSTRAINT [FK_GBBA_Deduct] FOREIGN KEY ([DeductListID_FK]) REFERENCES [Housing].[DeductList] ([deductListID]),
    CONSTRAINT [FK_GBBA_Resident] FOREIGN KEY ([ResidentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID]),
    CONSTRAINT [FK_GBBA_Service] FOREIGN KEY ([BillChargeTypeID_FK]) REFERENCES [Housing].[BillChargeType] ([BillChargeTypeID]),
    CONSTRAINT [FK_GBBA_SourceMovement] FOREIGN KEY ([SourceMovementPaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [FK_GBBA_SourcePayment] FOREIGN KEY ([SourcePaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [FK_GBBA_TargetBuilding] FOREIGN KEY ([TargetBuildingID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_GBBA_TargetMovement] FOREIGN KEY ([TargetMovementPaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [UQ_GBBA_RequestKey] UNIQUE NONCLUSTERED ([RequestKey] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_GBBA_TargetMovement]
    ON [Housing].[GeneralBalanceBuildingAllocation]([TargetMovementPaymentID_FK] ASC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_GBBA_SourceMovement]
    ON [Housing].[GeneralBalanceBuildingAllocation]([SourceMovementPaymentID_FK] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_GBBA_TargetBuilding]
    ON [Housing].[GeneralBalanceBuildingAllocation]([TargetBuildingID_FK] ASC, [AllocationStatus] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_GBBA_SourceStatus]
    ON [Housing].[GeneralBalanceBuildingAllocation]([SourcePaymentID_FK] ASC, [AllocationStatus] ASC)
    INCLUDE([AllocatedAmount], [ResidentInfoID_FK], [BillChargeTypeID_FK], [IdaraID_FK]);

