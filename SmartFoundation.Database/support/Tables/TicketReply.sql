CREATE TABLE [support].[TicketReply] (
    [ticketReplyID]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]       BIGINT         NOT NULL,
    [replyText]         NVARCHAR (MAX) NOT NULL,
    [replyByUserID_FK]  BIGINT         NOT NULL,
    [isInternal]        BIT            CONSTRAINT [DF_support_TicketReply_isInternal] DEFAULT ((0)) NOT NULL,
    [ticketReplyActive] BIT            CONSTRAINT [DF_support_TicketReply_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_support_TicketReply_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) CONSTRAINT [DF_support_TicketReply_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TicketReply] PRIMARY KEY CLUSTERED ([ticketReplyID] ASC),
    CONSTRAINT [FK_support_TicketReply_Ticket] FOREIGN KEY ([ticketID_FK]) REFERENCES [support].[Ticket] ([ticketID]),
    CONSTRAINT [FK_support_TicketReply_User] FOREIGN KEY ([replyByUserID_FK]) REFERENCES [dbo].[Users] ([usersID])
);

