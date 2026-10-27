CREATE TABLE [Housing].[ExitFinancialProcessingCycle] (
    [ExitRequestActionID_FK] BIGINT         NOT NULL,
    [ProcessingVersion]      TINYINT        CONSTRAINT [DF_ExitFinancialCycle_Version] DEFAULT ((1)) NOT NULL,
    [CreatedAt]              DATETIME2 (3)  CONSTRAINT [DF_ExitFinancialCycle_CreatedAt] DEFAULT (sysdatetime()) NOT NULL,
    [entryData]              NVARCHAR (20)  NULL,
    [hostName]               NVARCHAR (200) NULL,
    CONSTRAINT [PK_ExitFinancialProcessingCycle] PRIMARY KEY CLUSTERED ([ExitRequestActionID_FK] ASC),
    CONSTRAINT [CK_ExitFinancialCycle_Version] CHECK ([ProcessingVersion]=(1)),
    CONSTRAINT [FK_ExitFinancialCycle_BuildingAction] FOREIGN KEY ([ExitRequestActionID_FK]) REFERENCES [Housing].[BuildingAction] ([buildingActionID])
);

