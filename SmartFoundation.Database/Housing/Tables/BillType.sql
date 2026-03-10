CREATE TABLE [Housing].[BillType] (
    [BillTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [BillTypeName_A] NVARCHAR (500) NULL,
    CONSTRAINT [PK_BillType] PRIMARY KEY CLUSTERED ([BillTypeID] ASC)
);

