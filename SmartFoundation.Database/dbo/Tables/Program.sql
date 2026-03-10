CREATE TABLE [dbo].[Program] (
    [programID]          INT             IDENTITY (1, 1) NOT NULL,
    [programName_A]      NVARCHAR (100)  NULL,
    [programName_E]      NVARCHAR (100)  NULL,
    [programDescription] NVARCHAR (400)  NULL,
    [programActive]      BIT             NULL,
    [programLink]        NVARCHAR (500)  NULL,
    [programIcon]        NVARCHAR (50)   NULL,
    [programSerial]      INT             NULL,
    [entryDate]          DATETIME        CONSTRAINT [DF_Program_entryDate] DEFAULT (getdate()) NULL,
    [UpdatedBy]          NVARCHAR (4000) NULL,
    [UpdatedDate]        NVARCHAR (4000) NULL,
    [CanceledBy]         NVARCHAR (4000) NULL,
    [CanceledDate]       NVARCHAR (4000) NULL,
    [entryData]          NVARCHAR (20)   NULL,
    [hostName]           NVARCHAR (200)  NULL,
    CONSTRAINT [PK_Program] PRIMARY KEY CLUSTERED ([programID] ASC)
);

