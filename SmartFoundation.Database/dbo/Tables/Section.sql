CREATE TABLE [dbo].[Section] (
    [secID]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [secName_A]      NVARCHAR (50)  NULL,
    [secName_E]      NVARCHAR (50)  NULL,
    [secDescription] NVARCHAR (200) NULL,
    [secStartDate]   DATE           NULL,
    [secEndDate]     DATE           NULL,
    [secActive]      BIT            NULL,
    [entryDate]      DATETIME       CONSTRAINT [DF_Section_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)  NULL,
    [hostName]       NVARCHAR (200) CONSTRAINT [DF_Section_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Section] PRIMARY KEY CLUSTERED ([secID] ASC)
);

