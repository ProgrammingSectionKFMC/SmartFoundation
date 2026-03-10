CREATE TABLE [dbo].[State] (
    [stateID]          INT            IDENTITY (1, 1) NOT NULL,
    [shortName_A]      NVARCHAR (50)  NULL,
    [stateName_A]      NVARCHAR (50)  NULL,
    [stateName_E]      NVARCHAR (50)  NULL,
    [stateDescription] NVARCHAR (200) NULL,
    [stateActive]      BIT            NULL,
    [countryID_FK]     INT            NULL,
    CONSTRAINT [PK_State] PRIMARY KEY CLUSTERED ([stateID] ASC),
    CONSTRAINT [FK_State_Country1] FOREIGN KEY ([countryID_FK]) REFERENCES [dbo].[Country] ([countryID])
);

