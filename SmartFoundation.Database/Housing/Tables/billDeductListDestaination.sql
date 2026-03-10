CREATE TABLE [Housing].[billDeductListDestaination] (
    [billDeductListDestainationID]          INT             IDENTITY (1, 1) NOT NULL,
    [billDeductListDestainationName_A]      NVARCHAR (100)  NULL,
    [billDeductListDestainationName_E]      NVARCHAR (100)  NULL,
    [billDeductListDestainationDescription] NVARCHAR (1000) NULL,
    [billDeductListDestainationActive]      BIT             NULL,
    [entryDate]                             DATETIME        NULL,
    [entryData]                             NVARCHAR (20)   NULL,
    [hostName]                              NVARCHAR (200)  NULL,
    CONSTRAINT [PK_billDeductListDestaination] PRIMARY KEY CLUSTERED ([billDeductListDestainationID] ASC)
);

