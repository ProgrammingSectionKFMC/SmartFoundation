CREATE TABLE [dbo].[LocalAdministrations] (
    [adminID]          INT            IDENTITY (1, 1) NOT NULL,
    [adminName_A]      NVARCHAR (100) NULL,
    [adminName_E]      NVARCHAR (100) NULL,
    [adminStartDate]   DATETIME       NULL,
    [adminEndDate]     DATETIME       NULL,
    [adminDescription] NVARCHAR (200) NULL,
    [adminActive]      BIT            NULL,
    [cityID_FK]        INT            NULL,
    PRIMARY KEY CLUSTERED ([adminID] ASC),
    CONSTRAINT [FK_Admins_Cities_FK] FOREIGN KEY ([cityID_FK]) REFERENCES [dbo].[MainCities] ([cityID])
);

