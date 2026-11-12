CREATE TABLE [Tickets].[ClarificationReason] (
    [clarificationReasonID]     INT             IDENTITY (1, 1) NOT NULL,
    [clarificationReasonCode]   NVARCHAR (50)   NOT NULL,
    [clarificationReasonName_A] NVARCHAR (200)  NULL,
    [clarificationReasonName_E] NVARCHAR (200)  NULL,
    [clarificationReasonDesc]   NVARCHAR (1000) NULL,
    [clarificationReasonActive] BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_Tickets_ClarificationReason_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    [clarificationReasonDesc_A] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_ClarificationReason] PRIMARY KEY CLUSTERED ([clarificationReasonID] ASC)
);


GO

