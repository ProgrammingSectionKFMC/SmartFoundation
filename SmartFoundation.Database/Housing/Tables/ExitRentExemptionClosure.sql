CREATE TABLE [Housing].[ExitRentExemptionClosure] (
    [ExitRentExemptionClosureID] BIGINT         IDENTITY (1, 1) NOT NULL,
    [ExitRequestActionID_FK]     BIGINT         NOT NULL,
    [ResidentRentExemptionID_FK] BIGINT         NOT NULL,
    [OriginalEndDate]            DATETIME       NULL,
    [AppliedExitEndDate]         DATETIME       NOT NULL,
    [ClosureReason]              NVARCHAR (30)  CONSTRAINT [DF_ExitExemptionClosure_Reason] DEFAULT (N'EXIT_REQUEST') NOT NULL,
    [ClosedAt]                   DATETIME2 (3)  CONSTRAINT [DF_ExitExemptionClosure_ClosedAt] DEFAULT (sysdatetime()) NOT NULL,
    [ClosedBy]                   NVARCHAR (20)  NULL,
    [CloseHostName]              NVARCHAR (200) NULL,
    [RestoredAt]                 DATETIME2 (3)  NULL,
    [RestoredBy]                 NVARCHAR (20)  NULL,
    [RestoreHostName]            NVARCHAR (200) NULL,
    CONSTRAINT [PK_ExitRentExemptionClosure] PRIMARY KEY CLUSTERED ([ExitRentExemptionClosureID] ASC),
    CONSTRAINT [CK_ExitExemptionClosure_Dates] CHECK ([OriginalEndDate] IS NULL OR CONVERT([date],[OriginalEndDate])>CONVERT([date],[AppliedExitEndDate])),
    CONSTRAINT [CK_ExitExemptionClosure_Reason] CHECK ([ClosureReason]=N'EXIT_REQUEST'),
    CONSTRAINT [FK_ExitExemptionClosure_Cycle] FOREIGN KEY ([ExitRequestActionID_FK]) REFERENCES [Housing].[ExitFinancialProcessingCycle] ([ExitRequestActionID_FK]),
    CONSTRAINT [FK_ExitExemptionClosure_Exemption] FOREIGN KEY ([ResidentRentExemptionID_FK]) REFERENCES [Housing].[ResidentRentExemption] ([residentRentExemptionID])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitExemptionClosure_Open]
    ON [Housing].[ExitRentExemptionClosure]([ResidentRentExemptionID_FK] ASC) WHERE ([RestoredAt] IS NULL);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitExemptionClosure_Cycle_Open]
    ON [Housing].[ExitRentExemptionClosure]([ExitRequestActionID_FK] ASC, [ResidentRentExemptionID_FK] ASC) WHERE ([RestoredAt] IS NULL);

