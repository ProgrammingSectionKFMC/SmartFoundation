CREATE TABLE [Tickets].[TicketDescriptionTemplate] (
    [templateID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [templateCode]      NVARCHAR (50)   NOT NULL,
    [templateName_A]    NVARCHAR (500)  NOT NULL,
    [templateName_E]    NVARCHAR (500)  NULL,
    [templateContent_A] NVARCHAR (4000) NOT NULL,
    [templateContent_E] NVARCHAR (4000) NULL,
    [templateDesc]      NVARCHAR (2000) NULL,
    [serviceID_FK]      BIGINT          NULL,
    [ticketClassID_FK]  INT             NULL,
    [displayOrder]      INT             CONSTRAINT [DF_TicketDescriptionTemplate_displayOrder] DEFAULT ((0)) NULL,
    [templateActive]    BIT             CONSTRAINT [DF_TicketDescriptionTemplate_templateActive] DEFAULT ((1)) NULL,
    [idaraID_FK]        INT             NULL,
    [entryDate]         DATETIME        CONSTRAINT [DF_TicketDescriptionTemplate_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)   NULL,
    [hostName]          NVARCHAR (200)  NULL,
    CONSTRAINT [PK_TicketDescriptionTemplate] PRIMARY KEY CLUSTERED ([templateID] ASC),
    CONSTRAINT [FK_TicketDescriptionTemplate_Service] FOREIGN KEY ([serviceID_FK]) REFERENCES [Tickets].[Service] ([serviceID]),
    CONSTRAINT [FK_TicketDescriptionTemplate_TicketClass] FOREIGN KEY ([ticketClassID_FK]) REFERENCES [Tickets].[TicketClass] ([ticketClassID])
);




GO




GO




GO




GO

