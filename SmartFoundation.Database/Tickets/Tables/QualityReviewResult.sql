CREATE TABLE [Tickets].[QualityReviewResult] (
    [qualityReviewResultID]     INT             IDENTITY (1, 1) NOT NULL,
    [qualityReviewResultCode]   NVARCHAR (50)   NOT NULL,
    [qualityReviewResultName_A] NVARCHAR (200)  NULL,
    [qualityReviewResultName_E] NVARCHAR (200)  NULL,
    [qualityReviewResultDesc]   NVARCHAR (1000) NULL,
    [qualityReviewResultActive] BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_Tickets_QualityReviewResult_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    [qualityReviewResultDesc_A] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_QualityReviewResult] PRIMARY KEY CLUSTERED ([qualityReviewResultID] ASC)
);


GO

