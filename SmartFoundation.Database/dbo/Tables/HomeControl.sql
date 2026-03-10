CREATE TABLE [dbo].[HomeControl] (
    [homeControlID]         INT             IDENTITY (1, 1) NOT NULL,
    [distributorID_FK]      INT             NULL,
    [DivCardTitle]          NVARCHAR (200)  NULL,
    [DivCardClass]          NVARCHAR (500)  NULL,
    [userControlTitle]      NVARCHAR (300)  NULL,
    [userControlCode]       NVARCHAR (MAX)  NULL,
    [tabControlActive]      BIT             NULL,
    [tabControlDescription] NVARCHAR (1000) NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_HomeControl._entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  CONSTRAINT [DF_HomeControl._hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_HomeControl.] PRIMARY KEY CLUSTERED ([homeControlID] ASC)
);

