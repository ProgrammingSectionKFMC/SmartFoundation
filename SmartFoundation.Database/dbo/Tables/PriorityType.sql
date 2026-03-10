CREATE TABLE [dbo].[PriorityType] (
    [priorityTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [priorityTypeName_A] NVARCHAR (100) NULL,
    [priorityTypeName_E] NVARCHAR (100) NULL,
    [priorityTypeActive] BIT            NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_PriorityType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK_PriorityType] PRIMARY KEY CLUSTERED ([priorityTypeID] ASC)
);

