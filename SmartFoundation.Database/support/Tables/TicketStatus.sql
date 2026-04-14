CREATE TABLE [support].[TicketStatus] (
    [statusID]     TINYINT        NOT NULL,
    [statusName_A] NVARCHAR (100) NOT NULL,
    [statusName_E] NVARCHAR (100) NULL,
    [statusActive] BIT            CONSTRAINT [DF_support_TicketStatus_Active] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_support_TicketStatus] PRIMARY KEY CLUSTERED ([statusID] ASC)
);

