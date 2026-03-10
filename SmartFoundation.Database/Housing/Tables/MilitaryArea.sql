CREATE TABLE [Housing].[MilitaryArea] (
    [militaryAreaID]          INT            IDENTITY (1, 1) NOT NULL,
    [militaryAreaCode]        NVARCHAR (10)  NULL,
    [militaryAreaName_A]      NVARCHAR (150) NULL,
    [militaryAreaName_E]      NVARCHAR (150) NULL,
    [militaryAreaDescription] NVARCHAR (500) NULL,
    [militaryAreaIsActive]    BIT            NULL,
    [entryDate]               DATETIME       CONSTRAINT [DF_MilitaryArea_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)  NULL,
    [hostName]                NVARCHAR (200) NULL,
    CONSTRAINT [PK_MilitaryArea] PRIMARY KEY CLUSTERED ([militaryAreaID] ASC)
);

