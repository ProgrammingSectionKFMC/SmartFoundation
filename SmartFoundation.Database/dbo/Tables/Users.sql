CREATE TABLE [dbo].[Users] (
    [usersID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    [nationalID]          NVARCHAR (20)   NOT NULL,
    [nationalIDTypeID_FK] INT             NULL,
    [usersStartDate]      DATETIME        NULL,
    [usersEndDate]        DATETIME        NULL,
    [usersActive]         BIT             NULL,
    [IsAdmin]             BIT             CONSTRAINT [DF_Users_IsAdmin] DEFAULT ((0)) NULL,
    [updatedby]           NVARCHAR (2000) NULL,
    [updatedDate]         NVARCHAR (2000) NULL,
    [entryDate]           DATETIME        CONSTRAINT [DF_Users_entryDate] DEFAULT (getdate()) NULL,
    [entryData]           NVARCHAR (20)   NULL,
    [hostName]            NVARCHAR (200)  CONSTRAINT [DF_Users_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED ([usersID] ASC),
    CONSTRAINT [FK_Users_NationalIDType] FOREIGN KEY ([nationalIDTypeID_FK]) REFERENCES [dbo].[NationalIDType] ([nationalIDTypeID])
);

