CREATE TABLE [Housing].[BillChargeType] (
    [BillChargeTypeID]      INT            IDENTITY (1, 1) NOT NULL,
    [MeterServiceTypeID_FK] INT            NULL,
    [BillChargeTypeName_A]  NVARCHAR (100) NOT NULL,
    [BillChargeTypeActive]  BIT            CONSTRAINT [DF__BillCharg__BillC__49266EE7] DEFAULT ((1)) NOT NULL,
    [entryData]             NVARCHAR (20)  NULL,
    [hostName]              NVARCHAR (200) NULL,
    CONSTRAINT [PK__BillChar__EA222EF90E266B5A] PRIMARY KEY CLUSTERED ([BillChargeTypeID] ASC)
);

