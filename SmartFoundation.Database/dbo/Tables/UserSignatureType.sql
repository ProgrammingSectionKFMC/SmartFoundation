CREATE TABLE [dbo].[UserSignatureType] (
    [UserSignatureTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [UserSignatureTypeName_A] NVARCHAR (500) NULL,
    [UserSignatureTypeActive] BIT            NULL,
    CONSTRAINT [PK_UserSignatureType] PRIMARY KEY CLUSTERED ([UserSignatureTypeID] ASC)
);

