CREATE TABLE [dbo].[Divison] (
    [divID]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [divName_A]      NVARCHAR (50)  NULL,
    [divName_E]      NVARCHAR (50)  NULL,
    [divDescription] NCHAR (10)     NULL,
    [divStartDate]   DATE           NULL,
    [divEndDate]     DATE           NULL,
    [divActive]      BIT            NULL,
    [entryDate]      DATETIME       CONSTRAINT [DF_Divison_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)  NULL,
    [hostName]       NVARCHAR (200) CONSTRAINT [DF_Divison_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Divison] PRIMARY KEY CLUSTERED ([divID] ASC)
);

