CREATE TABLE [Housing].[ResidentStatus] (
    [residentStatusID]          INT             IDENTITY (1, 1) NOT NULL,
    [residentStatusName_A]      NVARCHAR (100)  NULL,
    [residentStatusName_E]      NVARCHAR (100)  NULL,
    [residentStatusDescription] NVARCHAR (1000) NULL,
    [residentStatusActive]      BIT             NULL,
    [entryDate]                 DATETIME        CONSTRAINT [DF_ResidentStatus_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                 NVARCHAR (20)   NULL,
    [hostName]                  NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentStatus] PRIMARY KEY CLUSTERED ([residentStatusID] ASC)
);

