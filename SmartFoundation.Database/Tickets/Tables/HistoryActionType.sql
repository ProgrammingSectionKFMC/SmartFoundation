CREATE TABLE [Tickets].[HistoryActionType] (
    [historyActionTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [actionTypeCode]          NVARCHAR (50)  NOT NULL,
    [actionTypeName_A]        NVARCHAR (200) NOT NULL,
    [actionTypeName_E]        NVARCHAR (200) NULL,
    [historyActionTypeActive] BIT            CONSTRAINT [DF_Tickets_HistoryActionType_Active] DEFAULT ((1)) NOT NULL,
    [entryDate]               DATETIME       CONSTRAINT [DF_Tickets_HistoryActionType_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]               NVARCHAR (20)  NULL,
    [hostName]                NVARCHAR (200) NULL,
    CONSTRAINT [PK_Tickets_HistoryActionType] PRIMARY KEY CLUSTERED ([historyActionTypeID] ASC),
    CONSTRAINT [UQ_Tickets_HistoryActionType_Code] UNIQUE NONCLUSTERED ([actionTypeCode] ASC)
);


GO

