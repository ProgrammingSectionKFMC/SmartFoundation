CREATE TABLE [WH].[CategoryLevelResponsible] (
    [categoryLevelResponsibleID]        INT            NOT NULL,
    [categoryLevelID_FK]                BIGINT         NULL,
    [distributorID_FK]                  INT            NULL,
    [categoryLevelResponsibleStartDate] DATETIME       NULL,
    [categoryLevelResponsibleEndDate]   DATETIME       NULL,
    [categoryLevelResponsibleActive]    BIT            NULL,
    [hostName]                          NVARCHAR (200) NULL,
    [entryDate]                         DATETIME       CONSTRAINT [DF_CategoryLevelResponsible_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                         NVARCHAR (20)  NULL,
    CONSTRAINT [PK_CategoryLevelResponsible] PRIMARY KEY CLUSTERED ([categoryLevelResponsibleID] ASC),
    CONSTRAINT [FK_CategoryLevelResponsible_CategoryLevel] FOREIGN KEY ([categoryLevelID_FK]) REFERENCES [WH].[CategoryLevel] ([categoryLevelID])
);

