CREATE TABLE [WH].[Unit] (
    [unitID]        INT            IDENTITY (1, 1) NOT NULL,
    [unitName_A]    NVARCHAR (100) NULL,
    [unitName_E]    NVARCHAR (100) NULL,
    [unitCode]      NVARCHAR (20)  NULL,
    [unitActive]    BIT            NULL,
    [OldunitName_A] NVARCHAR (100) NULL,
    [OldunitName_E] NVARCHAR (100) NULL,
    [OldunitCode]   NVARCHAR (20)  NULL,
    [hostName]      NVARCHAR (200) NULL,
    [entryDate]     DATETIME       CONSTRAINT [DF_Unit_entryDate] DEFAULT (getdate()) NULL,
    [entryData]     NVARCHAR (20)  NULL,
    CONSTRAINT [PK_Unit] PRIMARY KEY CLUSTERED ([unitID] ASC)
);

