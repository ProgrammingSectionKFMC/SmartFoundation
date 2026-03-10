CREATE TABLE [dbo].[Organization] (
    [OrganizationID]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [OrganizationClass_A]     NVARCHAR (10)  NULL,
    [OrganizationClass_E]     NVARCHAR (10)  NULL,
    [OrganizationLongName_A]  NVARCHAR (300) NULL,
    [OrganizationShortName_A] NVARCHAR (150) NULL,
    [OrganizationLongName_E]  NVARCHAR (300) NULL,
    [OrganizationShortName_E] NVARCHAR (150) NULL,
    [OrganizationCode]        NVARCHAR (10)  NULL,
    [OrganizationLogo]        IMAGE          NULL,
    [entryDate]               DATETIME       CONSTRAINT [DF_Organization_entryDate] DEFAULT (getdate()) NULL,
    [entryData]               NVARCHAR (20)  NULL,
    [hostName]                NVARCHAR (200) NULL,
    CONSTRAINT [PK_Organization] PRIMARY KEY CLUSTERED ([OrganizationID] ASC)
);

