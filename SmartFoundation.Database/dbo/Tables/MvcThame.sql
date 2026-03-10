CREATE TABLE [dbo].[MvcThame] (
    [MvcThameID]     INT            IDENTITY (1, 1) NOT NULL,
    [MvcThameName]   NVARCHAR (MAX) NULL,
    [MvcThameActive] BIT            NULL,
    CONSTRAINT [PK_MvcThame] PRIMARY KEY CLUSTERED ([MvcThameID] ASC)
);

