CREATE TABLE [Housing].[BillsPaidDeductListType] (
    [BillsPaidDeductListTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [BillsPaidDeductListTypeName_A]      NVARCHAR (100)  NULL,
    [BillsPaidDeductListTypeName_E]      NVARCHAR (100)  NULL,
    [BillsPaidDeductListTypeDescription] NVARCHAR (1000) NULL,
    [BillsPaidDeductListTypeActive]      BIT             NULL,
    [entryDate]                          DATETIME        CONSTRAINT [DF_BillsPaidDeductListType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                          NVARCHAR (20)   NULL,
    [hostName]                           NVARCHAR (200)  NULL,
    CONSTRAINT [PK_BillsPaidDeductListType] PRIMARY KEY CLUSTERED ([BillsPaidDeductListTypeID] ASC)
);

