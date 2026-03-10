CREATE TABLE [dbo].[permissionAuthLvl] (
    [permissionAuthLvlID]          INT             IDENTITY (1, 1) NOT NULL,
    [permissionAuthLvlName_A]      NVARCHAR (500)  NULL,
    [permissionAuthLvlName_E]      NVARCHAR (500)  NULL,
    [permissionAuthLvlDescription] NVARCHAR (4000) NULL,
    [permissionAuthLvlActive]      BIT             NULL,
    CONSTRAINT [PK_permissionAuthLvl] PRIMARY KEY CLUSTERED ([permissionAuthLvlID] ASC)
);

