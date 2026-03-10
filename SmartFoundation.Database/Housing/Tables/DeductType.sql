CREATE TABLE [Housing].[DeductType] (
    [deductTypeID]          INT             IDENTITY (1, 1) NOT NULL,
    [deductTypeName_A]      NVARCHAR (100)  NULL,
    [deductTypeName_E]      NVARCHAR (100)  NULL,
    [deductTypeDescription] NVARCHAR (1000) NULL,
    [deductTypeActive]      BIT             NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_DeductType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    CONSTRAINT [PK_DeductType] PRIMARY KEY CLUSTERED ([deductTypeID] ASC)
);

