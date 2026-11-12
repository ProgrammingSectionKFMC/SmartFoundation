CREATE TABLE [Tickets].[ServiceRoutingRule] (
    [serviceRoutingRuleID]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [serviceID_FK]             BIGINT          NOT NULL,
    [idaraID_FK]               INT             NOT NULL,
    [targetDSDID_FK]           INT             NOT NULL,
    [queueDistributorID_FK]    INT             NULL,
    [effectiveFrom]            DATETIME        NOT NULL,
    [effectiveTo]              DATETIME        NULL,
    [approvedByUserID]         INT             NULL,
    [changeReason]             NVARCHAR (1000) NULL,
    [serviceRoutingRuleActive] BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_Tickets_ServiceRoutingRule_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    [changeReason_A]           NVARCHAR (1000) NULL,
    CONSTRAINT [PK_Tickets_ServiceRoutingRule] PRIMARY KEY CLUSTERED ([serviceRoutingRuleID] ASC)
);


GO

