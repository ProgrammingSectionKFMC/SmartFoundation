CREATE TABLE [Housing].[ExtendReasonType] (
    [ExtendReasonTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [ExtendReasonTypeName_A] NVARCHAR (500) NULL,
    [ExtendReasonTypeName_E] NVARCHAR (500) NULL,
    [InsuranceRequired]      BIT            NOT NULL,
    [Active]                 BIT            NOT NULL
);

