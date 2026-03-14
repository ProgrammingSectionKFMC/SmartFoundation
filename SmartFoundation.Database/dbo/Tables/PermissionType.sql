CREATE TABLE [dbo].[PermissionType] (
    [permissionTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [permissionTypeName_A] NVARCHAR (500) NULL,
    [permissionTypeName_E] NVARCHAR (500) NULL,
    [permissionTypeActive] BIT            NULL,
    [RoleID_FK]            BIGINT         NULL,
    CONSTRAINT [PK_PermissionType_1] PRIMARY KEY CLUSTERED ([permissionTypeID] ASC),
    CONSTRAINT [FK_PermissionType_Role] FOREIGN KEY ([RoleID_FK]) REFERENCES [dbo].[Role] ([roleID])
);

