CREATE TABLE [Housing].[AssignNote] (
    [AssignNoteID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [AssignPeriodID_FK]   BIGINT          NULL,
    [residentInfoID_FK]   BIGINT          NULL,
    [buildingActionID_FK] BIGINT          NULL,
    [AssignNote]          NVARCHAR (4000) NULL,
    [AssignNoteActive]    BIT             NULL,
    [IdaraID_FK]          BIGINT          NULL,
    [entryDate]           DATETIME        CONSTRAINT [DF_AssignNote_entryDate] DEFAULT (getdate()) NULL,
    [entryData]           NVARCHAR (20)   NULL,
    [hostName]            NVARCHAR (200)  NULL,
    CONSTRAINT [PK_AssignNote] PRIMARY KEY CLUSTERED ([AssignNoteID] ASC)
);

