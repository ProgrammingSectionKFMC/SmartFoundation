CREATE TABLE [dbo].[DocumentType] (
    [documentTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [documentTypeName_A]      NVARCHAR (50)   NULL,
    [documentTypeName_E]      NVARCHAR (50)   NULL,
    [documentTypeDescription] NVARCHAR (250)  NULL,
    [documentTypeActive]      BIT             NULL,
    [documentCategoryID_FK]   INT             NULL,
    [documentTypeDisplay]     BIT             NULL,
    [documentFolderName]      NVARCHAR (1000) NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_DocumentType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  CONSTRAINT [DF_DocumentType_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DocumentType] PRIMARY KEY CLUSTERED ([documentTypeID] ASC),
    CONSTRAINT [FK_DocumentType_DocumentCategory] FOREIGN KEY ([documentCategoryID_FK]) REFERENCES [dbo].[DocumentCategory] ([documentCategoryID])
);

