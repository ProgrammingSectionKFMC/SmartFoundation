CREATE TABLE [support].[TicketType] (
    [ticketTypeID]     TINYINT        NOT NULL,
    [ticketTypeCode]   NVARCHAR (50)  NOT NULL,
    [ticketTypeName_A] NVARCHAR (200) NOT NULL,
    [ticketTypeName_E] NVARCHAR (200) NULL,
    [ticketTypeActive] BIT            CONSTRAINT [DF_support_TicketType_Active] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_support_TicketType] PRIMARY KEY CLUSTERED ([ticketTypeID] ASC),
    CONSTRAINT [UQ_support_TicketType_Code] UNIQUE NONCLUSTERED ([ticketTypeCode] ASC)
);

