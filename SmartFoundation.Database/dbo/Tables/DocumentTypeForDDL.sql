CREATE TABLE [dbo].[DocumentTypeForDDL] (
    [DocumentTypeForDDLID] INT             IDENTITY (1, 1) NOT NULL,
    [DocumentTypeID_FK]    INT             NULL,
    [DocumentTypeName_A]   NVARCHAR (1000) NULL,
    [DocumentTypeName_E]   NVARCHAR (1000) NULL,
    [DocumentTypeActive]   BIT             NULL,
    [ParentID]             INT             NULL,
    [Penelty]              NVARCHAR (500)  NULL
);

