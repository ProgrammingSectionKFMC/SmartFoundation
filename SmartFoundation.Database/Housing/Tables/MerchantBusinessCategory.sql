CREATE TABLE [Housing].[MerchantBusinessCategory] (
    [merchantBusinessCategoryID]     INT            IDENTITY (1, 1) NOT NULL,
    [merchantBusinessCategoryName_A] NVARCHAR (500) NULL,
    [merchantBusinessCategoryName_E] NVARCHAR (500) NULL,
    [merchantBusinessCategoryActive] BIT            NULL,
    [entryDate]                      DATETIME       CONSTRAINT [DF_MerchantBusinessCategory_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (20)  NULL,
    [hostName]                       NVARCHAR (200) NULL,
    CONSTRAINT [PK_MerchantBusinessCategory] PRIMARY KEY CLUSTERED ([merchantBusinessCategoryID] ASC)
);

