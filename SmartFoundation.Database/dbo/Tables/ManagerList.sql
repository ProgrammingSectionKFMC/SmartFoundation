CREATE TABLE [dbo].[ManagerList] (
    [ManagerListID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [ManagerListTypeID_FK]   BIGINT          NULL,
    [ManagerListName]        NVARCHAR (2000) NULL,
    [ManagerListRank]        NVARCHAR (2000) NULL,
    [ManagerListPosition]    NVARCHAR (4000) NULL,
    [ManagerListStartDate]   DATETIME        NULL,
    [ManagerListEndDate]     DATETIME        NULL,
    [ManagerListDescription] NVARCHAR (2000) NULL,
    [ManagerListActive]      BIT             NULL,
    [IdaraID_FK]             BIGINT          NULL,
    [entryDate]              DATETIME        CONSTRAINT [DF_ManagerList_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)   NULL,
    [hostName]               NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ManagerList] PRIMARY KEY CLUSTERED ([ManagerListID] ASC)
);

