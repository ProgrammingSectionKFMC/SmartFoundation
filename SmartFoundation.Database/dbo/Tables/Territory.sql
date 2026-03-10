CREATE TABLE [dbo].[Territory] (
    [territoryID]          INT            IDENTITY (1, 1) NOT NULL,
    [territoryName_A]      NVARCHAR (100) NULL,
    [territoryName_E]      NVARCHAR (100) NULL,
    [territoryDescription] NVARCHAR (300) NULL,
    [continentName_A]      NVARCHAR (100) NULL,
    [continentName_E]      NVARCHAR (100) NULL,
    CONSTRAINT [PK_Territory] PRIMARY KEY CLUSTERED ([territoryID] ASC)
);

