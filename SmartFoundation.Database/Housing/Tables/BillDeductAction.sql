CREATE TABLE [Housing].[BillDeductAction] (
    [billDeductActionID]        INT             IDENTITY (1, 1) NOT NULL,
    [billDeductListID_FK]       INT             NULL,
    [billDeductListStatusID_FK] INT             NULL,
    [billDeductDigitalSignture] IMAGE           NULL,
    [billDeductNote]            NVARCHAR (1000) NULL,
    [billDeductActive]          BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_BillDeductAction_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillDeductAction] PRIMARY KEY CLUSTERED ([billDeductActionID] ASC),
    CONSTRAINT [FK_BillDeductAction_BillDeductList] FOREIGN KEY ([billDeductListID_FK]) REFERENCES [Housing].[BillDeductList] ([billDeductListID]),
    CONSTRAINT [FK_BillDeductAction_BillDeductListStatus] FOREIGN KEY ([billDeductListStatusID_FK]) REFERENCES [Housing].[BillDeductListStatus] ([billDeductListStatusID])
);

