CREATE TABLE [support].[TeamMember] (
    [teamMemberID]      BIGINT         IDENTITY (1, 1) NOT NULL,
    [userID_FK]         BIGINT         NOT NULL,
    [canReceiveTickets] BIT            CONSTRAINT [DF_support_TeamMember_canReceive] DEFAULT ((1)) NOT NULL,
    [canAssignTickets]  BIT            CONSTRAINT [DF_support_TeamMember_canAssign] DEFAULT ((0)) NOT NULL,
    [teamMemberActive]  BIT            CONSTRAINT [DF_support_TeamMember_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_support_TeamMember_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) CONSTRAINT [DF_support_TeamMember_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TeamMember] PRIMARY KEY CLUSTERED ([teamMemberID] ASC),
    CONSTRAINT [FK_support_TeamMember_Users] FOREIGN KEY ([userID_FK]) REFERENCES [dbo].[Users] ([usersID]),
    CONSTRAINT [UQ_support_TeamMember_User] UNIQUE NONCLUSTERED ([userID_FK] ASC)
);

