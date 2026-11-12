CREATE TABLE [VIC].[GeneralMaintenanceFault] (
    [FaultID]          INT            IDENTITY (1, 1) NOT NULL,
    [MaintOrdID_FK]    INT            NOT NULL,
    [LineNo]           INT            NOT NULL,
    [FaultDescription] NVARCHAR (500) NOT NULL,
    [CorrectiveAction] NVARCHAR (500) NULL,
    [Active]           BIT            DEFAULT ((1)) NULL,
    [entryDate]        DATETIME       DEFAULT (getdate()) NULL,
    [entryData]        NVARCHAR (40)  NULL,
    [hostName]         NVARCHAR (400) NULL,
    PRIMARY KEY CLUSTERED ([FaultID] ASC)
);


GO

