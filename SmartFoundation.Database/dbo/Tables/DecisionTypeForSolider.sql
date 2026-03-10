CREATE TABLE [dbo].[DecisionTypeForSolider] (
    [DecisionTypeID]          INT            IDENTITY (1, 1) NOT NULL,
    [DecisionCategoryID_FK]   INT            NULL,
    [DecisionTypeForDSD]      INT            NULL,
    [DecisionTypeSecrecy]     INT            NULL,
    [DecisionTypeName_A]      NVARCHAR (50)  NULL,
    [DecisionTypeName_E]      NVARCHAR (50)  NULL,
    [DecisionTypeDescription] NVARCHAR (250) NULL,
    [DecisionTypeActive]      BIT            NULL,
    [DecisionTypeDisplay]     BIT            NULL,
    [entryDate]               DATETIME       NULL,
    [entryData]               NVARCHAR (20)  NULL,
    [hostName]                NVARCHAR (200) NULL,
    CONSTRAINT [PK_DecisionTypeForSolider] PRIMARY KEY CLUSTERED ([DecisionTypeID] ASC)
);

