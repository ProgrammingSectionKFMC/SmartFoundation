CREATE TABLE [Housing].[MilitaryAreaCity] (
    [militaryAreaCityID]          INT            IDENTITY (1, 1) NOT NULL,
    [militaryAreaCityCode]        NVARCHAR (10)  NULL,
    [militaryAreaID_FK]           INT            NULL,
    [militaryAreaCityName_A]      NVARCHAR (150) NULL,
    [militaryAreaCityName_E]      NVARCHAR (150) NULL,
    [militaryAreaCityDescription] NVARCHAR (500) NULL,
    [militaryAreaCityActive]      BIT            NULL,
    [entryDate]                   DATETIME       CONSTRAINT [DF_MilitaryAreaCity_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                   NVARCHAR (20)  NULL,
    [hostName]                    NVARCHAR (200) NULL,
    CONSTRAINT [PK_MilitaryAreaCity] PRIMARY KEY CLUSTERED ([militaryAreaCityID] ASC),
    CONSTRAINT [FK_MilitaryAreaCity_MilitaryArea] FOREIGN KEY ([militaryAreaID_FK]) REFERENCES [Housing].[MilitaryArea] ([militaryAreaID])
);

