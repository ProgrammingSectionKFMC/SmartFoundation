CREATE TABLE [dbo].[OperatingSystem] (
    [OSID]     INT            IDENTITY (1, 1) NOT NULL,
    [OSName_A] NVARCHAR (100) NULL,
    [OSName_E] NVARCHAR (100) NULL,
    [OSActive] BIT            NULL,
    CONSTRAINT [PK_OperatingSystem] PRIMARY KEY CLUSTERED ([OSID] ASC)
);

