CREATE TYPE [Housing].[ImportExcelForBuildingPaymentRowType] AS TABLE (
    [RowNo]        INT            NOT NULL,
    [IDNumber]     NVARCHAR (255) NULL,
    [unitID]       NVARCHAR (255) NULL,
    [generalNo_FK] NVARCHAR (255) NULL,
    [amount]       NVARCHAR (255) NULL);

