CREATE TABLE [dbo].[PhoneType] (
    [phoneTypeID]          INT            IDENTITY (1, 1) NOT NULL,
    [phoneTypeName_A]      NVARCHAR (50)  NULL,
    [phoneTypeName_E]      NVARCHAR (50)  NULL,
    [phoneTypeDescription] NVARCHAR (250) NULL,
    [phoneTypeActive]      BIT            NULL,
    CONSTRAINT [PK_PhoneType] PRIMARY KEY CLUSTERED ([phoneTypeID] ASC)
);

