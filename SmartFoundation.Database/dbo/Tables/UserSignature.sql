CREATE TABLE [dbo].[UserSignature] (
    [userSignatureID]        INT            IDENTITY (1, 1) NOT NULL,
    [userID_FK]              INT            NULL,
    [userSignatureName]      NVARCHAR (150) NULL,
    [userSignatureLarge]     IMAGE          NULL,
    [userSignatureSmall]     IMAGE          NULL,
    [userSignatureStamp]     IMAGE          NULL,
    [UserSignatureTypeID_FK] INT            NULL,
    [userSignatureActive]    BIT            NULL,
    [entryDate]              DATETIME       CONSTRAINT [DF_UserSignature_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)  NULL,
    [hostName]               NVARCHAR (200) CONSTRAINT [DF_UserSignature_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_UserSignature] PRIMARY KEY CLUSTERED ([userSignatureID] ASC)
);

