CREATE TABLE [dbo].[DocumentState] (
    [documentStateID]          INT            IDENTITY (1, 1) NOT NULL,
    [documentStateName_A]      NVARCHAR (50)  NULL,
    [documentStateName_E]      NVARCHAR (50)  NULL,
    [documentStateDescription] NVARCHAR (250) NULL,
    [documentStateActive]      BIT            NULL,
    [entryDate]                DATETIME       CONSTRAINT [DF_DocumentState_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)  NULL,
    [hostName]                 NVARCHAR (200) CONSTRAINT [DF_DocumentState_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DocumentState] PRIMARY KEY CLUSTERED ([documentStateID] ASC)
);

