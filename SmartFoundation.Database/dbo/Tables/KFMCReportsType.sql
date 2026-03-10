CREATE TABLE [dbo].[KFMCReportsType] (
    [KFMCReportsTypeID]      INT            IDENTITY (1, 1) NOT NULL,
    [KFMCReportsName_A]      NVARCHAR (200) NULL,
    [KFMCReportsName_E]      NVARCHAR (200) NULL,
    [KFMCReportsPdfLink]     NVARCHAR (MAX) NULL,
    [KFMCReportsCrptLink]    NVARCHAR (MAX) NULL,
    [ProgramID_FK]           INT            NULL,
    [DistributorID_FK]       INT            NULL,
    [KFMCReportsHeaderID_FK] INT            NULL,
    [KFMCReportsActive]      BIT            NULL,
    CONSTRAINT [PK_KFMCReportsType] PRIMARY KEY CLUSTERED ([KFMCReportsTypeID] ASC)
);

