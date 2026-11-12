CREATE TABLE [Tickets].[TicketSLAHistory] (
    [ticketSLAHistoryID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketSLAID_FK]     BIGINT          NOT NULL,
    [idaraID_FK]         INT             NOT NULL,
    [slaEventType]       NVARCHAR (50)   NOT NULL,
    [eventDate]          DATETIME        CONSTRAINT [DF_Tickets_TicketSLAHistory_eventDate] DEFAULT (getdate()) NOT NULL,
    [notes]              NVARCHAR (2000) NULL,
    [performerUserID]    INT             NULL,
    [entryDate]          DATETIME        CONSTRAINT [DF_Tickets_TicketSLAHistory_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)   NULL,
    [hostName]           NVARCHAR (200)  NULL,
    [notes_A]            NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_TicketSLAHistory] PRIMARY KEY CLUSTERED ([ticketSLAHistoryID] ASC)
);


GO

