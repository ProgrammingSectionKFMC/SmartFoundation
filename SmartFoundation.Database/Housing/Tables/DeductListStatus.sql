CREATE TABLE [Housing].[DeductListStatus] (
    [DeductListStatusID]     INT            IDENTITY (1, 1) NOT NULL,
    [DeductListStatusName_A] NVARCHAR (100) NULL,
    [DeductListStatusName_E] NVARCHAR (100) NULL,
    [DeductListStatusActive] BIT            NULL,
    CONSTRAINT [PK_DeductListStatus] PRIMARY KEY CLUSTERED ([DeductListStatusID] ASC)
);

