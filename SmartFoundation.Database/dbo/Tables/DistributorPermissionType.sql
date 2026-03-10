CREATE TABLE [dbo].[DistributorPermissionType] (
    [distributorPermissionTypeID]        BIGINT         IDENTITY (1, 1) NOT NULL,
    [permissionTypeID_FK]                INT            NULL,
    [DistributorID_FK]                   BIGINT         NULL,
    [distributorPermissionTypeStartDate] DATETIME       NULL,
    [distributorPermissionTypeEndDate]   DATETIME       NULL,
    [distributorPermissionTypeActive]    BIT            NULL,
    [permissionAuthLvl]                  INT            CONSTRAINT [DF_DistributorPermissionType_permissionAuthLvl] DEFAULT ((3)) NOT NULL,
    [entryDate]                          DATETIME       NULL,
    [entryData]                          NVARCHAR (20)  NULL,
    [hostName]                           NVARCHAR (200) NULL,
    CONSTRAINT [PK_distributorPermissionType] PRIMARY KEY CLUSTERED ([distributorPermissionTypeID] ASC),
    CONSTRAINT [FK_DistributorPermissionType_Distributor] FOREIGN KEY ([DistributorID_FK]) REFERENCES [dbo].[Distributor] ([distributorID]),
    CONSTRAINT [FK_DistributorPermissionType_PermissionType] FOREIGN KEY ([permissionTypeID_FK]) REFERENCES [dbo].[PermissionType] ([permissionTypeID])
);

