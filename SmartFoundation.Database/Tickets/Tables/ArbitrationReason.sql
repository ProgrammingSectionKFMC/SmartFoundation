CREATE TABLE [Tickets].[ArbitrationReason] (
    [arbitrationReasonID]     INT             IDENTITY (1, 1) NOT NULL,
    [arbitrationReasonCode]   NVARCHAR (50)   NOT NULL,
    [arbitrationReasonName_A] NVARCHAR (200)  NULL,
    [arbitrationReasonName_E] NVARCHAR (200)  NULL,
    [arbitrationReasonDesc]   NVARCHAR (1000) NULL,
    [arbitrationReasonActive] BIT             NULL,
    [entryDate]               DATETIME        CONSTRAINT [DF_Tickets_ArbitrationReason_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)   NULL,
    [hostName]                NVARCHAR (200)  NULL,
    [arbitrationReasonDesc_A] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_ArbitrationReason] PRIMARY KEY CLUSTERED ([arbitrationReasonID] ASC)
);


GO

