CREATE TABLE [dbo].[contactInfo] (
    [contactInfoID]        INT             IDENTITY (1, 1) NOT NULL,
    [contanctTypeID_FK]    INT             NULL,
    [userID_FK]            INT             NULL,
    [contactDetails]       NVARCHAR (500)  NULL,
    [contactInfoStartDate] DATETIME        NULL,
    [contactInfoEndDate]   DATETIME        NULL,
    [contactInfoActive]    BIT             NULL,
    [entryDate]            DATETIME        CONSTRAINT [DF_contactInfo_entryDate] DEFAULT (getdate()) NULL,
    [entryData]            NVARCHAR (20)   NULL,
    [hostName]             NVARCHAR (200)  NULL,
    [contactInfoNote]      NVARCHAR (4000) NULL,
    CONSTRAINT [PK_contactInfo] PRIMARY KEY CLUSTERED ([contactInfoID] ASC),
    CONSTRAINT [FK_contactInfo_contactType] FOREIGN KEY ([contanctTypeID_FK]) REFERENCES [dbo].[contactType] ([contanctTypeID])
);

