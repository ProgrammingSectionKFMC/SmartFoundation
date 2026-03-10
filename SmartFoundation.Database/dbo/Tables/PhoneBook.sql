CREATE TABLE [dbo].[PhoneBook] (
    [phoneBookID]      INT            IDENTITY (1, 1) NOT NULL,
    [phoneNo]          NVARCHAR (10)  NULL,
    [phoneDescription] NVARCHAR (150) NULL,
    [phoneType_FK]     INT            NULL,
    [phoneActive]      BIT            NULL,
    CONSTRAINT [PK_PhoneBook] PRIMARY KEY CLUSTERED ([phoneBookID] ASC),
    CONSTRAINT [FK_PhoneBook_PhoneType] FOREIGN KEY ([phoneType_FK]) REFERENCES [dbo].[PhoneType] ([phoneTypeID])
);

