CREATE TABLE [Tickets].[Service] (
    [serviceID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    [serviceCode]           NVARCHAR (100)  NOT NULL,
    [serviceName_A]         NVARCHAR (500)  NULL,
    [serviceName_E]         NVARCHAR (500)  NULL,
    [serviceDesc]           NVARCHAR (2000) NULL,
    [idaraID_FK]            INT             NOT NULL,
    [ticketClassID_FK]      INT             NULL,
    [defaultPriorityID_FK]  INT             NULL,
    [requiresLocation]      BIT             NULL,
    [allowsChildTickets]    BIT             NULL,
    [requiresQualityReview] BIT             NULL,
    [serviceActive]         BIT             NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_Tickets_Service_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    [serviceDesc_A]         NVARCHAR (2000) NULL,
    CONSTRAINT [PK_Tickets_Service] PRIMARY KEY CLUSTERED ([serviceID] ASC)
);


GO

