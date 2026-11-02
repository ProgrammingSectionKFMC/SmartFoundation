CREATE TABLE [Housing].[AssignPeriodAllocation] (
    [AssignPeriodAllocationID] BIGINT        IDENTITY (1, 1) NOT NULL,
    [AssignPeriodMemberID_FK]  BIGINT        NOT NULL,
    [AllocationActionID_FK]    BIGINT        NOT NULL,
    [ConfirmationActionID_FK]  BIGINT        NULL,
    [OutcomeActionID_FK]       BIGINT        NULL,
    [AllocationTypeID]         INT           NOT NULL,
    [CreatedAt]                DATETIME2 (3) CONSTRAINT [DF_AssignPeriodAllocation_CreatedAt] DEFAULT (sysdatetime()) NOT NULL,
    CONSTRAINT [PK_AssignPeriodAllocation] PRIMARY KEY CLUSTERED ([AssignPeriodAllocationID] ASC),
    CONSTRAINT [CK_AssignPeriodAllocation_DifferentCopy] CHECK ([ConfirmationActionID_FK] IS NULL OR [ConfirmationActionID_FK]<>[AllocationActionID_FK]),
    CONSTRAINT [CK_AssignPeriodAllocation_DifferentOutcome] CHECK ([OutcomeActionID_FK] IS NULL OR [OutcomeActionID_FK]<>[AllocationActionID_FK] AND ([ConfirmationActionID_FK] IS NULL OR [OutcomeActionID_FK]<>[ConfirmationActionID_FK])),
    CONSTRAINT [CK_AssignPeriodAllocation_Type] CHECK ([AllocationTypeID]=(40) OR [AllocationTypeID]=(38)),
    CONSTRAINT [FK_AssignPeriodAllocation_ConfirmationAction] FOREIGN KEY ([ConfirmationActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [FK_AssignPeriodAllocation_Member] FOREIGN KEY ([AssignPeriodMemberID_FK]) REFERENCES [Housing].[AssignPeriodMember] ([AssignPeriodMemberID]),
    CONSTRAINT [FK_AssignPeriodAllocation_OriginalAction] FOREIGN KEY ([AllocationActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [FK_AssignPeriodAllocation_OutcomeAction] FOREIGN KEY ([OutcomeActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [UQ_AssignPeriodAllocation_OriginalAction] UNIQUE NONCLUSTERED ([AllocationActionID_FK] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_AssignPeriodAllocation_Member]
    ON [Housing].[AssignPeriodAllocation]([AssignPeriodMemberID_FK] ASC, [AllocationActionID_FK] ASC)
    INCLUDE([ConfirmationActionID_FK], [OutcomeActionID_FK], [AllocationTypeID]);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_AssignPeriodAllocation_Outcome]
    ON [Housing].[AssignPeriodAllocation]([OutcomeActionID_FK] ASC) WHERE ([OutcomeActionID_FK] IS NOT NULL);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_AssignPeriodAllocation_Confirmation]
    ON [Housing].[AssignPeriodAllocation]([ConfirmationActionID_FK] ASC) WHERE ([ConfirmationActionID_FK] IS NOT NULL);

