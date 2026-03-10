CREATE TABLE [Housing].[BuildingAssignCount] (
    [BuildingAssignCountID]         INT             IDENTITY (1, 1) NOT NULL,
    [BuildingAssignCount]           INT             CONSTRAINT [DF_BuildingAssignCount_BuildingAssignCount] DEFAULT ((1)) NOT NULL,
    [BuildingAssignCountLetterNo]   NVARCHAR (100)  NULL,
    [BuildingAssignCountLetterDate] DATETIME        NULL,
    [BuildingAssignCountNote]       NVARCHAR (1000) NULL,
    [Active]                        BIT             NULL,
    [entryDate]                     DATETIME        CONSTRAINT [DF_BuildingAssignCount_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                     NVARCHAR (20)   NULL,
    [hostName]                      NVARCHAR (200)  NULL
);

