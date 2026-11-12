CREATE TABLE [Tickets].[TicketPauseSession] (
    [ticketPauseSessionID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]                      BIGINT          NOT NULL,
    [idaraID_FK]                       INT             NOT NULL,
    [pauseReasonID_FK]                 INT             NULL,
    [relatedChildTicketID_FK]          BIGINT          NULL,
    [relatedArbitrationCaseID_FK]      BIGINT          NULL,
    [relatedClarificationRequestID_FK] BIGINT          NULL,
    [pauseStart]                       DATETIME        NOT NULL,
    [pauseEnd]                         DATETIME        NULL,
    [slaPauseFlag]                     BIT             NULL,
    [pauseNotes]                       NVARCHAR (2000) NULL,
    [ticketPauseSessionActive]         BIT             NULL,
    [entryDate]                        DATETIME        CONSTRAINT [DF_Tickets_TicketPauseSession_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                        NVARCHAR (20)   NULL,
    [hostName]                         NVARCHAR (200)  NULL,
    [pauseNotes_A]                     NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_TicketPauseSession] PRIMARY KEY CLUSTERED ([ticketPauseSessionID] ASC)
);


GO

