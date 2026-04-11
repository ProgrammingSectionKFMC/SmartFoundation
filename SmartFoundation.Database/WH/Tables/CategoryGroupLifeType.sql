CREATE TABLE [WH].[CategoryGroupLifeType] (
    [categoryGroupLifeTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [categoryGroupLifeTypeName_A]      NVARCHAR (100)  NULL,
    [categoryGroupLifeTypeName_E]      NVARCHAR (100)  NULL,
    [categoryGroupLifeTypeDescription] NVARCHAR (1000) NULL,
    [categoryGroupLifeTypeActive]      BIT             NULL,
    [hostName]                         NVARCHAR (200)  NULL,
    [entryDate]                        DATETIME        CONSTRAINT [DF_CategoryGroupLifeType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                        NVARCHAR (20)   NULL,
    CONSTRAINT [PK_CategoryGroupLifeType] PRIMARY KEY CLUSTERED ([categoryGroupLifeTypeID] ASC)
);

