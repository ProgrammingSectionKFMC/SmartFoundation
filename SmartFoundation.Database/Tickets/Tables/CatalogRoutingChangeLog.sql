CREATE TABLE [Tickets].[CatalogRoutingChangeLog] (
    [catalogRoutingChangeLogID]  BIGINT          IDENTITY (1, 1) NOT NULL,
    [serviceID_FK]               BIGINT          NOT NULL,
    [idaraID_FK]                 INT             NOT NULL,
    [oldRoutingRuleID_FK]        BIGINT          NULL,
    [newRoutingRuleID_FK]        BIGINT          NULL,
    [changeReason]               NVARCHAR (2000) NULL,
    [sourceArbitrationCaseID_FK] BIGINT          NULL,
    [approvedByUserID]           INT             NULL,
    [effectiveFrom]              DATETIME        NOT NULL,
    [loggedDate]                 DATETIME        CONSTRAINT [DF_Tickets_CatalogRoutingChangeLog_loggedDate] DEFAULT (getdate()) NOT NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_Tickets_CatalogRoutingChangeLog_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)   NULL,
    [hostName]                   NVARCHAR (200)  NULL,
    [changeReason_A]             NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_CatalogRoutingChangeLog] PRIMARY KEY CLUSTERED ([catalogRoutingChangeLogID] ASC)
);


GO

