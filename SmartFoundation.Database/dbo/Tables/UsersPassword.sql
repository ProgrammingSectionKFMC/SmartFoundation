CREATE TABLE [dbo].[UsersPassword] (
    [usersPasswordID]       BIGINT         IDENTITY (1, 1) NOT NULL,
    [usersID_FK]            BIGINT         NOT NULL,
    [PasswordHash]          VARBINARY (64) NOT NULL,
    [PasswordSalt]          VARBINARY (32) NOT NULL,
    [HashAlgorithm]         NVARCHAR (20)  CONSTRAINT [DF_UsersPassword_HashAlgorithm] DEFAULT ('SHA2_256') NULL,
    [userPasswordStartDate] DATETIME       NULL,
    [userPasswordEndDate]   DATETIME       NULL,
    [userPasswordActive]    BIT            NULL,
    [ChangedPassword]       BIT            CONSTRAINT [DF_UsersPassword_CahngedPassword] DEFAULT ((0)) NULL,
    [entryDate]             DATETIME       CONSTRAINT [DF_UsersPassword_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)  NULL,
    [hostName]              NVARCHAR (200) CONSTRAINT [DF_UsersPassword_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_UsersPassword] PRIMARY KEY CLUSTERED ([usersPasswordID] ASC),
    CONSTRAINT [FK_UsersPassword_Users1] FOREIGN KEY ([usersID_FK]) REFERENCES [dbo].[Users] ([usersID])
);

