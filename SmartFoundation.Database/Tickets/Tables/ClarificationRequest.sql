CREATE TABLE [Tickets].[ClarificationRequest] (
    [clarificationRequestID]   BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]              BIGINT          NOT NULL,
    [idaraID_FK]               INT             NOT NULL,
    [requestedByUserID]        INT             NULL,
    [requestedFromUserID]      INT             NULL,
    [requestedFromDSDID_FK]    INT             NULL,
    [clarificationReasonID_FK] INT             NULL,
    [requestNotes]             NVARCHAR (2000) NULL,
    [responseNotes]            NVARCHAR (2000) NULL,
    [requestDate]              DATETIME        CONSTRAINT [DF_Tickets_ClarificationRequest_requestDate] DEFAULT (getdate()) NOT NULL,
    [responseDate]             DATETIME        NULL,
    [clarificationStatus]      NVARCHAR (50)   NOT NULL,
    [clarificationActive]      BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_Tickets_ClarificationRequest_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    [requestNotes_A]           NVARCHAR (2000) NULL,
    [responseNotes_A]          NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_ClarificationRequest] PRIMARY KEY CLUSTERED ([clarificationRequestID] ASC)
);


GO

