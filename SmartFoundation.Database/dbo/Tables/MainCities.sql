CREATE TABLE [dbo].[MainCities] (
    [cityID]          INT            IDENTITY (1, 1) NOT NULL,
    [cityName_A]      NVARCHAR (100) NULL,
    [cityName_E]      NVARCHAR (100) NULL,
    [cityStartDate]   DATETIME       NULL,
    [cityEndDate]     DATETIME       NULL,
    [cityDescription] NVARCHAR (200) NULL,
    [cityActive]      BIT            NULL,
    [regionID_FK]     INT            NULL,
    PRIMARY KEY CLUSTERED ([cityID] ASC),
    CONSTRAINT [FK_Cities_Regions_FK] FOREIGN KEY ([regionID_FK]) REFERENCES [dbo].[AdministrativeRegions] ([regionID])
);

