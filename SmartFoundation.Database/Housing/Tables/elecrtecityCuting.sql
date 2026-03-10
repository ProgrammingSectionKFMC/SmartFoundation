CREATE TABLE [Housing].[elecrtecityCuting] (
    [ID]         INT             IDENTITY (1, 1) NOT NULL,
    [userid]     INT             NULL,
    [natoinalID] BIGINT          NULL,
    [name]       NVARCHAR (1000) NULL,
    [unitname]   NVARCHAR (1000) NULL,
    [amount]     DECIMAL (18, 2) NULL,
    [unitcode]   INT             NULL,
    [states]     NVARCHAR (500)  NULL,
    [cutingDate] INT             NULL,
    [cutingcode] INT             NULL,
    [cutingType] NVARCHAR (1000) NULL,
    CONSTRAINT [PK_elecrtecityCuting] PRIMARY KEY CLUSTERED ([ID] ASC)
);

