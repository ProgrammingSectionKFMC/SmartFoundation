CREATE TABLE [dbo].[City] (
    [cityID]          INT            IDENTITY (1, 1) NOT NULL,
    [cityName_A]      NVARCHAR (100) NULL,
    [cityName_E]      NVARCHAR (100) NULL,
    [cityDescription] NVARCHAR (250) NULL,
    [cityActive]      BIT            NULL,
    [stateID_FK]      INT            NULL,
    CONSTRAINT [PK_City] PRIMARY KEY CLUSTERED ([cityID] ASC),
    CONSTRAINT [FK_City_State1] FOREIGN KEY ([stateID_FK]) REFERENCES [dbo].[State] ([stateID])
);

