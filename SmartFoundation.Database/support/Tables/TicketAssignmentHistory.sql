CREATE TABLE [support].[TicketAssignmentHistory] (
    [ticketAssignmentHistoryID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]               BIGINT          NOT NULL,
    [fromTeamMemberID_FK]       BIGINT          NULL,
    [toTeamMemberID_FK]         BIGINT          NOT NULL,
    [actionByUserID_FK]         BIGINT          NOT NULL,
    [assignmentNote]            NVARCHAR (1000) NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_support_TicketAssignmentHistory_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  CONSTRAINT [DF_support_TicketAssignmentHistory_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TicketAssignmentHistory] PRIMARY KEY CLUSTERED ([ticketAssignmentHistoryID] ASC),
    CONSTRAINT [FK_support_TicketAssignmentHistory_ActionByUser] FOREIGN KEY ([actionByUserID_FK]) REFERENCES [dbo].[Users] ([usersID]),
    CONSTRAINT [FK_support_TicketAssignmentHistory_FromMember] FOREIGN KEY ([fromTeamMemberID_FK]) REFERENCES [support].[TeamMember] ([teamMemberID]),
    CONSTRAINT [FK_support_TicketAssignmentHistory_Ticket] FOREIGN KEY ([ticketID_FK]) REFERENCES [support].[Ticket] ([ticketID]),
    CONSTRAINT [FK_support_TicketAssignmentHistory_ToMember] FOREIGN KEY ([toTeamMemberID_FK]) REFERENCES [support].[TeamMember] ([teamMemberID])
);

