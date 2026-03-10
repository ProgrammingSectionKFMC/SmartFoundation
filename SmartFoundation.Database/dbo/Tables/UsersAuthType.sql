CREATE TABLE [dbo].[UsersAuthType] (
    [UsersAuthTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [UsersAuthTypeName_A] NVARCHAR (500) NULL,
    [UsersAuthTypeName_E] NVARCHAR (500) NULL,
    [UsersAuthTypeActive] BIT            NULL,
    CONSTRAINT [PK_UsersAuthType] PRIMARY KEY CLUSTERED ([UsersAuthTypeID] ASC)
);

