CREATE TABLE [Tickets].[TicketReason] (
    [ticketReasonID]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketReasonCode]   NVARCHAR (50)   NOT NULL,
    [ticketReasonName_A] NVARCHAR (500)  NOT NULL,
    [ticketReasonName_E] NVARCHAR (500)  NULL,
    [ticketReasonDesc]   NVARCHAR (2000) NULL,
    [serviceID_FK]       BIGINT          NULL,
    [ticketClassID_FK]   INT             NULL,
    [priorityID_FK]      INT             NULL,
    [displayOrder]       INT             CONSTRAINT [DF_TicketReason_displayOrder] DEFAULT ((0)) NULL,
    [ticketReasonActive] BIT             CONSTRAINT [DF_TicketReason_ticketReasonActive] DEFAULT ((1)) NULL,
    [idaraID_FK]         INT             NULL,
    [entryDate]          DATETIME        CONSTRAINT [DF_TicketReason_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)   NULL,
    [hostName]           NVARCHAR (200)  NULL,
    CONSTRAINT [PK_TicketReason] PRIMARY KEY CLUSTERED ([ticketReasonID] ASC),
    CONSTRAINT [FK_TicketReason_Priority] FOREIGN KEY ([priorityID_FK]) REFERENCES [Tickets].[Priority] ([priorityID]),
    CONSTRAINT [FK_TicketReason_Service] FOREIGN KEY ([serviceID_FK]) REFERENCES [Tickets].[Service] ([serviceID]),
    CONSTRAINT [FK_TicketReason_TicketClass] FOREIGN KEY ([ticketClassID_FK]) REFERENCES [Tickets].[TicketClass] ([ticketClassID])
);


GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Active_Order]
    ON [Tickets].[TicketReason]([ticketReasonActive] ASC, [displayOrder] ASC, [ticketReasonID] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Class]
    ON [Tickets].[TicketReason]([ticketClassID_FK] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Priority]
    ON [Tickets].[TicketReason]([priorityID_FK] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_TicketReason_Service]
    ON [Tickets].[TicketReason]([serviceID_FK] ASC);


GO

