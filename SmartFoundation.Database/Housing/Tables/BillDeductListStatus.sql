CREATE TABLE [Housing].[BillDeductListStatus] (
    [billDeductListStatusID]     INT            IDENTITY (1, 1) NOT NULL,
    [billDeductListStatusName_A] NVARCHAR (100) NULL,
    [billDeductListStatusName_E] NVARCHAR (100) NULL,
    [billDeductListStatusActive] BIT            NULL,
    CONSTRAINT [PK_BillDeductListStatus] PRIMARY KEY CLUSTERED ([billDeductListStatusID] ASC)
);

