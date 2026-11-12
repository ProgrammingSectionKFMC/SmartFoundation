CREATE TABLE [Tickets].[ServiceCatalogSuggestion] (
    [serviceCatalogSuggestionID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [sourceTicketID_FK]          BIGINT          NULL,
    [idaraID_FK]                 INT             NOT NULL,
    [proposedServiceName_A]      NVARCHAR (500)  NULL,
    [proposedServiceName_E]      NVARCHAR (500)  NULL,
    [proposedServiceDesc]        NVARCHAR (2000) NULL,
    [proposedTargetDSDID_FK]     INT             NULL,
    [proposedPriorityID_FK]      INT             NULL,
    [approvalStatus]             NVARCHAR (50)   NULL,
    [approvedByUserID]           INT             NULL,
    [approvalDate]               DATETIME        NULL,
    [approvalNotes]              NVARCHAR (2000) NULL,
    [createdServiceID_FK]        BIGINT          NULL,
    [suggestionActive]           BIT             NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_Tickets_ServiceCatalogSuggestion_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (20)   NULL,
    [hostName]                   NVARCHAR (200)  NULL,
    [proposedServiceDesc_A]      NVARCHAR (2000) NULL,
    [approvalNotes_A]            NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_ServiceCatalogSuggestion] PRIMARY KEY CLUSTERED ([serviceCatalogSuggestionID] ASC)
);


GO

