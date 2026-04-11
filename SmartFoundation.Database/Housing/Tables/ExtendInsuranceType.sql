CREATE TABLE [Housing].[ExtendInsuranceType] (
    [ExtendInsuranceTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [ExtendInsuranceTypeName_A] NVARCHAR (500) NULL,
    [ExtendInsuranceTypeName_E] NVARCHAR (500) NULL,
    [ExtendInsuranceTypeActive] BIT            NULL,
    CONSTRAINT [PK_ExtendInsuranceType] PRIMARY KEY CLUSTERED ([ExtendInsuranceTypeID] ASC)
);

