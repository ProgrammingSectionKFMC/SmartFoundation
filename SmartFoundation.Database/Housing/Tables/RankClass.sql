CREATE TABLE [Housing].[RankClass] (
    [rankClassID]          INT             IDENTITY (1, 1) NOT NULL,
    [rankClassName_A]      NVARCHAR (100)  NULL,
    [rankClassName_E]      NVARCHAR (100)  NULL,
    [rankClassDescription] NVARCHAR (1000) NULL,
    [entryDate]            DATETIME        CONSTRAINT [DF_RankClass_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)   NULL,
    [hostName]             NVARCHAR (200)  NULL,
    CONSTRAINT [PK_RankClass] PRIMARY KEY CLUSTERED ([rankClassID] ASC)
);

