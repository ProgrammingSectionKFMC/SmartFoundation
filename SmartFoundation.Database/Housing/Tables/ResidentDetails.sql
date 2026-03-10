CREATE TABLE [Housing].[ResidentDetails] (
    [residentDetailsID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentInfoID_FK]        BIGINT          NOT NULL,
    [generalNo_FK]             BIGINT          NULL,
    [rankID_FK]                INT             NULL,
    [militaryUnitID_FK]        INT             NULL,
    [martialStatusID_FK]       INT             NULL,
    [dependinceCounter]        INT             NULL,
    [nationalityID_FK]         INT             NULL,
    [genderID_FK]              INT             NULL,
    [firstName_A]              NVARCHAR (50)   NULL,
    [secondName_A]             NVARCHAR (50)   NULL,
    [thirdName_A]              NVARCHAR (50)   NULL,
    [lastName_A]               NVARCHAR (50)   NULL,
    [firstName_E]              NVARCHAR (50)   NULL,
    [secondName_E]             NVARCHAR (50)   NULL,
    [thirdName_E]              NVARCHAR (50)   NULL,
    [lastName_E]               NVARCHAR (50)   NULL,
    [note]                     NVARCHAR (1000) NULL,
    [birthdate]                DATE            NULL,
    [residentDetailsStartDate] DATETIME        NULL,
    [residentDetailsEndDate]   DATETIME        NULL,
    [IdaraId_FK]               BIGINT          NULL,
    [residentDetailsActive]    BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_ResidentDetails_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentDetails] PRIMARY KEY CLUSTERED ([residentDetailsID] ASC),
    CONSTRAINT [FK_ResidentDetails_Gender] FOREIGN KEY ([genderID_FK]) REFERENCES [dbo].[Gender] ([genderID]),
    CONSTRAINT [FK_ResidentDetails_Idara] FOREIGN KEY ([IdaraId_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_ResidentDetails_MaritalStatus] FOREIGN KEY ([martialStatusID_FK]) REFERENCES [dbo].[MaritalStatus] ([maritalStatusID]),
    CONSTRAINT [FK_ResidentDetails_MilitaryUnit] FOREIGN KEY ([militaryUnitID_FK]) REFERENCES [dbo].[MilitaryUnit] ([militaryUnitID]),
    CONSTRAINT [FK_ResidentDetails_Nationality] FOREIGN KEY ([nationalityID_FK]) REFERENCES [dbo].[Nationality] ([nationalityID]),
    CONSTRAINT [FK_ResidentDetails_Rank] FOREIGN KEY ([rankID_FK]) REFERENCES [dbo].[Rank] ([rankID]),
    CONSTRAINT [FK_ResidentDetails_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID])
);


GO
CREATE NONCLUSTERED INDEX [IX_ResidentDetails_LastActive]
    ON [Housing].[ResidentDetails]([residentInfoID_FK] ASC, [IdaraId_FK] ASC, [residentDetailsActive] ASC, [residentDetailsID] DESC)
    INCLUDE([generalNo_FK], [firstName_A], [secondName_A], [thirdName_A], [lastName_A]);

