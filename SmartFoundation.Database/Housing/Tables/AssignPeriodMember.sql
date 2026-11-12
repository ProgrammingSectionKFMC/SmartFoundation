CREATE TABLE [Housing].[AssignPeriodMember] (
    [AssignPeriodMemberID]   BIGINT        IDENTITY (1, 1) NOT NULL,
    [AssignPeriodID_FK]      BIGINT        NOT NULL,
    [WaitingRootActionID_FK] BIGINT        NOT NULL,
    [ResidentInfoID_FK]      BIGINT        NOT NULL,
    [FirstPeriodActionID_FK] BIGINT        NOT NULL,
    [DataOrigin]             NVARCHAR (30) NOT NULL,
    [CreatedAt]              DATETIME2 (3) CONSTRAINT [DF_AssignPeriodMember_CreatedAt] DEFAULT (sysdatetime()) NOT NULL,
    CONSTRAINT [PK_AssignPeriodMember] PRIMARY KEY CLUSTERED ([AssignPeriodMemberID] ASC),
    CONSTRAINT [CK_AssignPeriodMember_DataOrigin] CHECK ([DataOrigin]=N'LEGACY_RECONSTRUCTED' OR [DataOrigin]=N'OPERATIONAL'),
    CONSTRAINT [FK_AssignPeriodMember_FirstAction] FOREIGN KEY ([FirstPeriodActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [FK_AssignPeriodMember_Period] FOREIGN KEY ([AssignPeriodID_FK]) REFERENCES [Housing].[AssignPeriod] ([AssignPeriodID]),
    CONSTRAINT [FK_AssignPeriodMember_Resident] FOREIGN KEY ([ResidentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID]),
    CONSTRAINT [FK_AssignPeriodMember_RootAction] FOREIGN KEY ([WaitingRootActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID]),
    CONSTRAINT [UQ_AssignPeriodMember_Period_Root] UNIQUE NONCLUSTERED ([AssignPeriodID_FK] ASC, [WaitingRootActionID_FK] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_AssignPeriodMember_Resident]
    ON [Housing].[AssignPeriodMember]([ResidentInfoID_FK] ASC, [AssignPeriodID_FK] ASC)
    INCLUDE([WaitingRootActionID_FK]);


GO

