CREATE TABLE [dbo].[ManagerListType] (
    [ManagerListTypeID]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [ManagerListTypeName_A] NVARCHAR (2000) NULL,
    [ManagerListTypeName_E] NVARCHAR (2000) NULL,
    [ManagerListTypeActive] NVARCHAR (2000) NULL,
    [IdaraIs_FK]            BIGINT          NULL,
    CONSTRAINT [PK_ManagerListType] PRIMARY KEY CLUSTERED ([ManagerListTypeID] ASC)
);


GO

