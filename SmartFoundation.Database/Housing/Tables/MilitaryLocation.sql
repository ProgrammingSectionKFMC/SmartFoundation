CREATE TABLE [Housing].[MilitaryLocation] (
    [militaryLocationID]          INT            IDENTITY (1, 1) NOT NULL,
    [militaryLocationCode]        NVARCHAR (10)  NULL,
    [militaryAreaCityID_FK]       INT            NULL,
    [militaryLocationName_A]      NVARCHAR (150) NULL,
    [militaryLocationName_E]      NVARCHAR (150) NULL,
    [militaryLocationCoordinates] NVARCHAR (50)  NULL,
    [militaryLocationDescription] NVARCHAR (500) NULL,
    [militaryLocationActive]      BIT            NULL,
    [IdaraId_FK]                  BIGINT         NULL,
    [entryDate]                   DATETIME       CONSTRAINT [DF_MilitaryLocation_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)  NULL,
    [hostName]                    NVARCHAR (200) NULL,
    CONSTRAINT [PK_MilitaryLocation] PRIMARY KEY CLUSTERED ([militaryLocationID] ASC),
    CONSTRAINT [FK_MilitaryLocation_Idara] FOREIGN KEY ([IdaraId_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_MilitaryLocation_MilitaryAreaCity] FOREIGN KEY ([militaryAreaCityID_FK]) REFERENCES [Housing].[MilitaryAreaCity] ([militaryAreaCityID])
);

