CREATE TABLE [support].[TeamMemberRole] (
    [teamMemberRoleID]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [teamMemberID_FK]      BIGINT         NOT NULL,
    [roleID_FK]            BIGINT         NOT NULL,
    [teamMemberRoleActive] BIT            CONSTRAINT [DF_support_TeamMemberRole_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]            DATETIME       CONSTRAINT [DF_support_TeamMemberRole_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)  NULL,
    [hostName]             NVARCHAR (200) CONSTRAINT [DF_support_TeamMemberRole_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_support_TeamMemberRole] PRIMARY KEY CLUSTERED ([teamMemberRoleID] ASC),
    CONSTRAINT [FK_support_TeamMemberRole_Role] FOREIGN KEY ([roleID_FK]) REFERENCES [dbo].[Role] ([roleID]),
    CONSTRAINT [FK_support_TeamMemberRole_TeamMember] FOREIGN KEY ([teamMemberID_FK]) REFERENCES [support].[TeamMember] ([teamMemberID]),
    CONSTRAINT [UQ_support_TeamMemberRole_MemberRole] UNIQUE NONCLUSTERED ([teamMemberID_FK] ASC, [roleID_FK] ASC)
);

