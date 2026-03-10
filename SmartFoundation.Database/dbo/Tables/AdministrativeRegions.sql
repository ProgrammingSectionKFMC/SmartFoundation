CREATE TABLE [dbo].[AdministrativeRegions] (
    [regionID]          INT            IDENTITY (1, 1) NOT NULL,
    [regionName_A]      NVARCHAR (100) NULL,
    [regionName_E]      NVARCHAR (100) NULL,
    [regionStartDate]   DATETIME       NULL,
    [regionEndDate]     DATETIME       NULL,
    [regionDescription] NVARCHAR (200) NULL,
    [regionActive]      BIT            NULL,
    [countryID_FK]      INT            NULL,
    PRIMARY KEY CLUSTERED ([regionID] ASC),
    CONSTRAINT [FK_Regions_Countries_FK] FOREIGN KEY ([countryID_FK]) REFERENCES [dbo].[Countries] ([countryID])
);

