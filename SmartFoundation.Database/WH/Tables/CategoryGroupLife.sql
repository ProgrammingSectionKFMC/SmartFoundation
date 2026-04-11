CREATE TABLE [WH].[CategoryGroupLife] (
    [categoryGroupLifeID]        INT            IDENTITY (1, 1) NOT NULL,
    [categoryGroupLifeTypeID_FK] INT            NULL,
    [categoryGroupID_FK]         INT            NULL,
    [categoryGroupLifeName_A]    NVARCHAR (100) NULL,
    [categoryGroupLifeName_E]    NVARCHAR (100) NULL,
    [categoryGroupLifeReturn]    BIT            NULL,
    [categoryGroupLifeActive]    BIT            NULL,
    [hostName]                   NVARCHAR (200) NULL,
    [entryDate]                  DATETIME       CONSTRAINT [DF_CategoryGroupLife_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)  NULL,
    CONSTRAINT [PK_CategoryGroupLife] PRIMARY KEY CLUSTERED ([categoryGroupLifeID] ASC),
    CONSTRAINT [FK_CategoryGroupLife_CategoryGroupLifeType] FOREIGN KEY ([categoryGroupLifeTypeID_FK]) REFERENCES [WH].[CategoryGroupLifeType] ([categoryGroupLifeTypeID])
);

