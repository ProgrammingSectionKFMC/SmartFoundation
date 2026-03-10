CREATE TABLE [Housing].[BillDeductType] (
    [billDeductTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [billPeriodTypeID_FK]       INT             NULL,
    [billDeductTypeName_A]      NVARCHAR (100)  NULL,
    [billDeductTypeName_E]      NVARCHAR (100)  NULL,
    [billDeductTypeDescription] NVARCHAR (1000) NULL,
    [billDeductTypeParent]      INT             NULL,
    [billDeductTypeActive]      BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_BillDeductType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillDeductType] PRIMARY KEY CLUSTERED ([billDeductTypeID] ASC),
    CONSTRAINT [FK_BillDeductType_BillPeriodType] FOREIGN KEY ([billPeriodTypeID_FK]) REFERENCES [Housing].[BillPeriodType] ([billPeriodTypeID])
);

