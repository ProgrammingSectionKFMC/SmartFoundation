CREATE TABLE [Tickets].[ArbitrationCase] (
    [arbitrationCaseID]       BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]             BIGINT          NOT NULL,
    [idaraID_FK]              INT             NOT NULL,
    [raisedByUserID]          INT             NOT NULL,
    [raisedFromDSDID_FK]      INT             NOT NULL,
    [arbitrationReasonID_FK]  INT             NULL,
    [arbitratorDistributorID] INT             NULL,
    [arbitrationStatus]       NVARCHAR (50)   NOT NULL,
    [decisionType]            NVARCHAR (50)   NULL,
    [decisionTargetDSDID_FK]  INT             NULL,
    [decisionNotes]           NVARCHAR (2000) NULL,
    [decisionDate]            DATETIME        NULL,
    [arbitrationCaseActive]   BIT             NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_Tickets_ArbitrationCase_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  NULL,
    [decisionNotes_A]         NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_ArbitrationCase] PRIMARY KEY CLUSTERED ([arbitrationCaseID] ASC)
);


GO

