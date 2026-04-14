CREATE TABLE [support].[TicketPriority] (
    [priorityID]     TINYINT        NOT NULL,
    [priorityName_A] NVARCHAR (100) NOT NULL,
    [priorityName_E] NVARCHAR (100) NULL,
    [priorityActive] BIT            CONSTRAINT [DF_support_TicketPriority_Active] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_support_TicketPriority] PRIMARY KEY CLUSTERED ([priorityID] ASC)
);

