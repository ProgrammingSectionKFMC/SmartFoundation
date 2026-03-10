CREATE TABLE [dbo].[MilitaryUnit] (
    [militaryUnitID]        INT            IDENTITY (1, 1) NOT NULL,
    [militaryUnitCode]      NVARCHAR (20)  NULL,
    [militaryUnitName_A]    NVARCHAR (100) NULL,
    [militaryUnitName_E]    NVARCHAR (100) NULL,
    [militaryUnitShortName] NVARCHAR (50)  NULL,
    [militaryUnitAreaID_FK] INT            NULL,
    [entryDate]             DATETIME       CONSTRAINT [DF_MilitaryUnit_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)  NULL,
    [hostName]              NVARCHAR (200) NULL,
    CONSTRAINT [PK_MilitaryUnit] PRIMARY KEY CLUSTERED ([militaryUnitID] ASC)
);

