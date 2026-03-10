CREATE TABLE [dbo].[ChartListUsers] (
    [ChartListUsersID]        INT             IDENTITY (1, 1) NOT NULL,
    [UsersID_FK]              INT             NOT NULL,
    [ChartListID_FK]          INT             NOT NULL,
    [ChartListUsersStartDate] DATETIME        NULL,
    [ChartListUsersEndDate]   DATETIME        NULL,
    [ChartListUsersActive]    BIT             NULL,
    [ChartListUsersNote]      NVARCHAR (4000) NULL,
    [DisplayOrder]            INT             NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_ChartListUsers_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  CONSTRAINT [DF_ChartListUsers_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_ChartListUsers] PRIMARY KEY CLUSTERED ([ChartListUsersID] ASC)
);

