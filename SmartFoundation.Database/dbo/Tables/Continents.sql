CREATE TABLE [dbo].[Continents] (
    [continentID]          INT            IDENTITY (1, 1) NOT NULL,
    [continentName_A]      NVARCHAR (100) NULL,
    [continentName_E]      NVARCHAR (100) NULL,
    [continentStartDate]   DATETIME       NULL,
    [continentEndDate]     DATETIME       NULL,
    [continentDescription] NVARCHAR (200) NULL,
    [continentActive]      BIT            NULL,
    PRIMARY KEY CLUSTERED ([continentID] ASC)
);

