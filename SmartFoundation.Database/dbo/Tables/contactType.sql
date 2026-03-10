CREATE TABLE [dbo].[contactType] (
    [contanctTypeID]    INT           IDENTITY (1, 1) NOT NULL,
    [contactTypeName_A] NVARCHAR (50) NULL,
    [contactTypeName_E] NVARCHAR (50) NULL,
    CONSTRAINT [PK_contactType] PRIMARY KEY CLUSTERED ([contanctTypeID] ASC)
);

