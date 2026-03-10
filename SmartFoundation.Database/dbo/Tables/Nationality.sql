CREATE TABLE [dbo].[Nationality] (
    [nationalityID]          INT            IDENTITY (1, 1) NOT NULL,
    [nationalityName_A]      NVARCHAR (50)  NULL,
    [nationalityName_E]      NVARCHAR (50)  NULL,
    [nationalityDescription] NVARCHAR (200) NULL,
    [countryID_FK]           INT            NULL,
    [nationalityActive]      BIT            NULL,
    CONSTRAINT [PK_Nationality] PRIMARY KEY CLUSTERED ([nationalityID] ASC),
    CONSTRAINT [FK_Nationality_Country] FOREIGN KEY ([countryID_FK]) REFERENCES [dbo].[Country] ([countryID])
);

