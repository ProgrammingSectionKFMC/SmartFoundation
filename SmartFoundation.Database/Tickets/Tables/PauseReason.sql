CREATE TABLE [Tickets].[PauseReason] (
    [pauseReasonID]     INT             IDENTITY (1, 1) NOT NULL,
    [pauseReasonCode]   NVARCHAR (50)   NOT NULL,
    [pauseReasonName_A] NVARCHAR (200)  NULL,
    [pauseReasonName_E] NVARCHAR (200)  NULL,
    [pauseReasonDesc]   NVARCHAR (1000) NULL,
    [pauseReasonActive] BIT             NULL,
    [entryDate]         DATETIME        CONSTRAINT [DF_Tickets_PauseReason_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)   NULL,
    [hostName]          NVARCHAR (200)  NULL,
    [pauseReasonDesc_A] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_PauseReason] PRIMARY KEY CLUSTERED ([pauseReasonID] ASC)
);


GO

