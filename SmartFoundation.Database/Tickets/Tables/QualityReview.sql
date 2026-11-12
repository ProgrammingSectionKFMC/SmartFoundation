CREATE TABLE [Tickets].[QualityReview] (
    [qualityReviewID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]              BIGINT          NOT NULL,
    [idaraID_FK]               INT             NOT NULL,
    [reviewerUserID]           INT             NOT NULL,
    [reviewScope]              NVARCHAR (200)  NULL,
    [qualityReviewResultID_FK] INT             NULL,
    [reviewNotes]              NVARCHAR (2000) NULL,
    [reviewDate]               DATETIME        CONSTRAINT [DF_Tickets_QualityReview_reviewDate] DEFAULT (getdate()) NOT NULL,
    [returnToUserID]           INT             NULL,
    [finalized]                BIT             NULL,
    [qualityReviewActive]      BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_Tickets_QualityReview_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    [reviewNotes_A]            NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_QualityReview] PRIMARY KEY CLUSTERED ([qualityReviewID] ASC)
);


GO

