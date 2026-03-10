CREATE TABLE [dbo].[DocumentPermission] (
    [documentPermissionID] INT            IDENTITY (1, 1) NOT NULL,
    [distributorID_FK]     INT            NULL,
    [documentTypeID_FK]    INT            NULL,
    [entryDate]            DATETIME       CONSTRAINT [DF_DocumentPermission_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)  NULL,
    [hostName]             NVARCHAR (200) NULL,
    CONSTRAINT [PK_DocumentPermission] PRIMARY KEY CLUSTERED ([documentPermissionID] ASC)
);

