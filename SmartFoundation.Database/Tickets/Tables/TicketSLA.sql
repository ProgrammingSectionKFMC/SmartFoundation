CREATE TABLE [Tickets].[TicketSLA] (
    [ticketSLAID]        BIGINT         IDENTITY (1, 1) NOT NULL,
    [ticketID_FK]        BIGINT         NOT NULL,
    [idaraID_FK]         INT            NOT NULL,
    [slaTypeCode]        NVARCHAR (50)  NOT NULL,
    [targetMinutes]      INT            NULL,
    [elapsedMinutes]     INT            NULL,
    [remainingMinutes]   INT            NULL,
    [isBreached]         BIT            NULL,
    [slaStartDate]       DATETIME       NULL,
    [slaStopDate]        DATETIME       NULL,
    [slaCompletionDate]  DATETIME       NULL,
    [lastCalculatedDate] DATETIME       NULL,
    [ticketSLAActive]    BIT            NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_Tickets_TicketSLA_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)  NULL,
    [hostName]           NVARCHAR (200) NULL,
    CONSTRAINT [PK_Tickets_TicketSLA] PRIMARY KEY CLUSTERED ([ticketSLAID] ASC)
);


GO

