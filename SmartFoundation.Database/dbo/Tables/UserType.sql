CREATE TABLE [dbo].[UserType] (
    [userTypeID]          INT            IDENTITY (1, 1) NOT NULL,
    [userTypeName_A]      NVARCHAR (50)  NULL,
    [userTypeName_E]      NVARCHAR (50)  NULL,
    [userTypeDescription] NVARCHAR (200) NULL,
    [userTypeActive]      BIT            NULL,
    CONSTRAINT [PK_UserType] PRIMARY KEY CLUSTERED ([userTypeID] ASC)
);

