CREATE TABLE [dbo].[MaritalStatus] (
    [maritalStatusID]          INT            IDENTITY (1, 1) NOT NULL,
    [maritalStatusName_A]      NVARCHAR (100) NULL,
    [maritalStatusName_E]      NVARCHAR (100) NULL,
    [maritalStatusDescription] NVARCHAR (250) NULL,
    [maritalStatusActive]      BIT            NULL,
    CONSTRAINT [PK_MaritalStatus] PRIMARY KEY CLUSTERED ([maritalStatusID] ASC)
);

