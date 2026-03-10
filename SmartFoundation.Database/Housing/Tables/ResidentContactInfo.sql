CREATE TABLE [Housing].[ResidentContactInfo] (
    [residentcontactInfoID]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentInfoID_FK]            BIGINT          NULL,
    [residentcontanctTypeID_FK]    INT             NULL,
    [residentcontactDetails]       NVARCHAR (500)  NULL,
    [residentcontactInfoStartDate] DATETIME        NULL,
    [residentcontactInfoEndDate]   DATETIME        NULL,
    [residentcontactInfoNote]      NVARCHAR (4000) NULL,
    [residentcontactInfoActive]    BIT             NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_ResidentContactInfo_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentContactInfo] PRIMARY KEY CLUSTERED ([residentcontactInfoID] ASC),
    CONSTRAINT [FK_ResidentContactInfo_ResidentContactType] FOREIGN KEY ([residentcontanctTypeID_FK]) REFERENCES [Housing].[ResidentContactType] ([residentcontanctTypeID]),
    CONSTRAINT [FK_ResidentContactInfo_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID])
);

