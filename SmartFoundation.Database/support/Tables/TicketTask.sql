CREATE TABLE [support].[TicketTask] (
    [ticketTaskID]              BIGINT         IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]               BIGINT         NOT NULL,
    [taskNo]                    NVARCHAR (40)  NOT NULL,
    [taskTitle]                 NVARCHAR (300) NOT NULL,
    [taskDescription]           NVARCHAR (MAX) NULL,
    [statusID_FK]               TINYINT        CONSTRAINT [DF_support_TicketTask_statusID] DEFAULT ((1)) NOT NULL,
    [priorityID_FK]             TINYINT        CONSTRAINT [DF_support_TicketTask_priorityID] DEFAULT ((2)) NOT NULL,
    [assignedToTeamMemberID_FK] BIGINT         NOT NULL,
    [assignedByUserID_FK]       BIGINT         NOT NULL,
    [assignedDate]              DATETIME       CONSTRAINT [DF_support_TicketTask_assignedDate] DEFAULT (getdate()) NOT NULL,
    [dueDate]                   DATETIME       NULL,
    [completedDate]             DATETIME       NULL,
    [taskOrder]                 INT            NULL,
    [isRequired]                BIT            CONSTRAINT [DF_support_TicketTask_isRequired] DEFAULT ((1)) NOT NULL,
    [taskActive]                BIT            CONSTRAINT [DF_support_TicketTask_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]                 DATETIME       CONSTRAINT [DF_support_TicketTask_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)  NULL,
    [hostName]                  NVARCHAR (200) CONSTRAINT [DF_support_TicketTask_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TicketTask] PRIMARY KEY CLUSTERED ([ticketTaskID] ASC),
    CONSTRAINT [CK_support_TicketTask_CompletedDate] CHECK ([completedDate] IS NULL OR [completedDate]>=[assignedDate]),
    CONSTRAINT [FK_support_TicketTask_AssignedByUser] FOREIGN KEY ([assignedByUserID_FK]) REFERENCES [dbo].[Users] ([usersID]),
    CONSTRAINT [FK_support_TicketTask_AssignedToMember] FOREIGN KEY ([assignedToTeamMemberID_FK]) REFERENCES [support].[TeamMember] ([teamMemberID]),
    CONSTRAINT [FK_support_TicketTask_Priority] FOREIGN KEY ([priorityID_FK]) REFERENCES [support].[TicketPriority] ([priorityID]),
    CONSTRAINT [FK_support_TicketTask_Status] FOREIGN KEY ([statusID_FK]) REFERENCES [support].[TicketStatus] ([statusID]),
    CONSTRAINT [FK_support_TicketTask_Ticket] FOREIGN KEY ([ticketID_FK]) REFERENCES [support].[Ticket] ([ticketID]),
    CONSTRAINT [UQ_support_TicketTask_taskNo] UNIQUE NONCLUSTERED ([taskNo] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_support_TicketTask_Ticket_Order]
    ON [support].[TicketTask]([ticketID_FK] ASC, [taskOrder] ASC, [assignedDate] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_support_TicketTask_Assignee_Status]
    ON [support].[TicketTask]([assignedToTeamMemberID_FK] ASC, [statusID_FK] ASC, [assignedDate] DESC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_support_TicketTask_Ticket_Assignee_Active]
    ON [support].[TicketTask]([ticketID_FK] ASC, [assignedToTeamMemberID_FK] ASC) WHERE ([taskActive]=(1));

