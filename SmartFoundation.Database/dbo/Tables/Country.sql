CREATE TABLE [dbo].[Country] (
    [countryID]         INT            IDENTITY (1, 1) NOT NULL,
    [countryName_A]     NVARCHAR (100) NULL,
    [countryName_E]     NVARCHAR (100) NULL,
    [countryDescrption] NVARCHAR (200) NULL,
    [countryActive]     BIT            NULL,
    [territoryID_FK]    INT            NULL,
    CONSTRAINT [PK_Country] PRIMARY KEY CLUSTERED ([countryID] ASC),
    CONSTRAINT [FK_Country_Territory] FOREIGN KEY ([territoryID_FK]) REFERENCES [dbo].[Territory] ([territoryID])
);

