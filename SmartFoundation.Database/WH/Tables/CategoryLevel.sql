CREATE TABLE [WH].[CategoryLevel] (
    [categoryLevelID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [categoryLevelName_A]      NVARCHAR (100)  NULL,
    [categoryLevelName_E]      NVARCHAR (100)  NULL,
    [categoryLevelParentID_FK] BIGINT          NULL,
    [categoryGroupLifeID_FK]   INT             NULL,
    [unitID_FK]                INT             NULL,
    [categoryLevelDescription] NVARCHAR (1000) NULL,
    [oldGroupID]               INT             NULL,
    [oldCODE]                  NVARCHAR (50)   NULL,
    [categoryLevelActive]      BIT             NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_CategoryLevel_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    CONSTRAINT [PK_CategoryLevel] PRIMARY KEY CLUSTERED ([categoryLevelID] ASC),
    CONSTRAINT [FK_CategoryLevel_CategoryGroupLife] FOREIGN KEY ([categoryGroupLifeID_FK]) REFERENCES [WH].[CategoryGroupLife] ([categoryGroupLifeID]),
    CONSTRAINT [FK_CategoryLevel_CategoryLevel] FOREIGN KEY ([categoryLevelParentID_FK]) REFERENCES [WH].[CategoryLevel] ([categoryLevelID]),
    CONSTRAINT [FK_CategoryLevel_Unit] FOREIGN KEY ([unitID_FK]) REFERENCES [WH].[Unit] ([unitID])
);

