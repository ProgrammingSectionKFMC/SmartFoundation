CREATE TABLE [dbo].[DocumentFields] (
    [documentFieldsID]          INT            IDENTITY (1, 1) NOT NULL,
    [documentFieldsName_A]      NVARCHAR (50)  NULL,
    [documentFieldsName_E]      NVARCHAR (50)  NULL,
    [documentFieldsDescription] NVARCHAR (250) NULL,
    [documentFields]            NVARCHAR (50)  NULL,
    [documentFieldsActive]      BIT            NULL,
    [documentTypeID_FK]         INT            NULL,
    [documentFieldRequired]     BIT            NULL,
    [ViewBySearch]              BIT            NULL,
    [documentFieldSequence]     INT            NULL,
    [entryDate]                 DATETIME       CONSTRAINT [DF_DocumentFields_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)  NULL,
    [hostName]                  NVARCHAR (200) CONSTRAINT [DF_DocumentFields_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DocumentFields] PRIMARY KEY CLUSTERED ([documentFieldsID] ASC),
    CONSTRAINT [FK_DocumentFields_DocumentType] FOREIGN KEY ([documentTypeID_FK]) REFERENCES [dbo].[DocumentType] ([documentTypeID])
);

