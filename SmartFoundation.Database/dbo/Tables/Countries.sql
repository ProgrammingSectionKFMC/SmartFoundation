CREATE TABLE [dbo].[Countries] (
    [countryID]          INT            IDENTITY (1, 1) NOT NULL,
    [countryName_A]      NVARCHAR (100) NULL,
    [countryName_E]      NVARCHAR (100) NULL,
    [countryStartDate]   DATETIME       NULL,
    [countryEndDate]     DATETIME       NULL,
    [countryDescription] NVARCHAR (200) NULL,
    [countryActive]      BIT            NULL,
    [continentID_FK]     INT            NULL,
    PRIMARY KEY CLUSTERED ([countryID] ASC),
    CONSTRAINT [FK_Countries_Continents_FK] FOREIGN KEY ([continentID_FK]) REFERENCES [dbo].[Continents] ([continentID])
);

