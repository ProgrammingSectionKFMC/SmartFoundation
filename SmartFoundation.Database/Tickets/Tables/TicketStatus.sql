CREATE TABLE [Tickets].[TicketStatus] (
    [ticketStatusID]     INT             IDENTITY (1, 1) NOT NULL,
    [ticketStatusCode]   NVARCHAR (50)   NOT NULL,
    [ticketStatusName_A] NVARCHAR (200)  NULL,
    [ticketStatusName_E] NVARCHAR (200)  NULL,
    [ticketStatusDesc]   NVARCHAR (1000) NULL,
    [ticketStatusActive] BIT             NULL,
    [entryDate]          DATETIME        CONSTRAINT [DF_Tickets_TicketStatus_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)   NULL,
    [hostName]           NVARCHAR (200)  NULL,
    [ticketStatusDesc_A] NVARCHAR (1000) NULL,
    [ticketStatusColor]  NVARCHAR (20)   NULL,
    CONSTRAINT [PK_Tickets_TicketStatus] PRIMARY KEY CLUSTERED ([ticketStatusID] ASC)
);


GO

