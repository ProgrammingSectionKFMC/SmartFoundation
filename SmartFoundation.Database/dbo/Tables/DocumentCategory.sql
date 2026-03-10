CREATE TABLE [dbo].[DocumentCategory] (
    [documentCategoryID]     INT            IDENTITY (1, 1) NOT NULL,
    [documentCatName_A]      NVARCHAR (50)  NULL,
    [documentCatName_E]      NVARCHAR (50)  NULL,
    [documentCatDescription] NVARCHAR (250) NULL,
    [documentCatActive]      BIT            NULL,
    [documentCatForDept_FK]  BIGINT         NULL,
    [entryDate]              DATETIME       CONSTRAINT [DF_DocumentCategory_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)  NULL,
    [hostName]               NVARCHAR (200) CONSTRAINT [DF_DocumentCategory_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DocumentCategory] PRIMARY KEY CLUSTERED ([documentCategoryID] ASC),
    CONSTRAINT [FK_DocumentCategory_Department] FOREIGN KEY ([documentCatForDept_FK]) REFERENCES [dbo].[Department] ([deptID])
);

