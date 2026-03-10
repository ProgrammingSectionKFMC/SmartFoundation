CREATE TABLE [dbo].[Idara] (
    [idaraID]           BIGINT         IDENTITY (1, 1) NOT NULL,
    [idaraClass_A]      NVARCHAR (10)  NULL,
    [idaraClass_E]      NVARCHAR (10)  NULL,
    [idaraLongName_A]   NVARCHAR (300) NULL,
    [idaraShortName_A]  NVARCHAR (150) NULL,
    [idaraLongName_E]   NVARCHAR (300) NULL,
    [idaraShortName_E]  NVARCHAR (150) NULL,
    [idaraCode]         NVARCHAR (10)  NULL,
    [idaraLogo]         IMAGE          NULL,
    [organizationID_FK] BIGINT         NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_Idara_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) CONSTRAINT [DF_Idara_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Idara] PRIMARY KEY CLUSTERED ([idaraID] ASC)
);

