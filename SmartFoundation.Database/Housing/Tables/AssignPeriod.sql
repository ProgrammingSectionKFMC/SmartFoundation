CREATE TABLE [Housing].[AssignPeriod] (
    [AssignPeriodID]           BIGINT          IDENTITY (1, 1) NOT NULL,
    [AssignPeriodDescrption]   NVARCHAR (4000) NULL,
    [AssignPeriodStartdate]    DATETIME        NULL,
    [AssignPeriodEnddate]      DATETIME        NULL,
    [AssignPeriodActive]       BIT             NULL,
    [AssignPeriodClose]        BIT             NULL,
    [AssignPeriodCloseNote]    NVARCHAR (4000) NULL,
    [AssignPeriodCloseBy]      NVARCHAR (20)   NULL,
    [AssignPeriodFinalEND]     BIT             NULL,
    [AssignPeriodFinalENDNote] NVARCHAR (4000) NULL,
    [AssignPeriodFinalENDBy]   NVARCHAR (20)   NULL,
    [AssignPeriodFinalEnddate] DATETIME        NULL,
    [IdaraId_FK]               INT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_AssignPeriod_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_AssignPeriod] PRIMARY KEY CLUSTERED ([AssignPeriodID] ASC)
);

