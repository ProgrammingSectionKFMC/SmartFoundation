CREATE TABLE [Tickets].[TicketClass] (
    [ticketClassID]     INT             IDENTITY (1, 1) NOT NULL,
    [ticketClassCode]   NVARCHAR (50)   NOT NULL,
    [ticketClassName_A] NVARCHAR (200)  NULL,
    [ticketClassName_E] NVARCHAR (200)  NULL,
    [ticketClassDesc]   NVARCHAR (1000) NULL,
    [ticketClassActive] BIT             NULL,
    [entryDate]         DATETIME        CONSTRAINT [DF_Tickets_TicketClass_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)   NULL,
    [hostName]          NVARCHAR (200)  NULL,
    [ticketClassDesc_A] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_TicketClass] PRIMARY KEY CLUSTERED ([ticketClassID] ASC)
);


GO

