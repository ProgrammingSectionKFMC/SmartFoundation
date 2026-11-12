CREATE TABLE [Tickets].[Priority] (
    [priorityID]     INT             IDENTITY (1, 1) NOT NULL,
    [priorityCode]   NVARCHAR (50)   NOT NULL,
    [priorityName_A] NVARCHAR (200)  NULL,
    [priorityName_E] NVARCHAR (200)  NULL,
    [priorityDesc]   NVARCHAR (1000) NULL,
    [priorityLevel]  INT             NULL,
    [priorityActive] BIT             NULL,
    [entryDate]      DATETIME        CONSTRAINT [DF_Tickets_Priority_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)   NULL,
    [hostName]       NVARCHAR (200)  NULL,
    [priorityDesc_A] NVARCHAR (1000) NULL,
    [priorityColor]  NVARCHAR (20)   NULL,
    CONSTRAINT [PK_Tickets_Priority] PRIMARY KEY CLUSTERED ([priorityID] ASC)
);


GO

