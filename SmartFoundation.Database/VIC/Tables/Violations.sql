CREATE TABLE [VIC].[Violations] (
    [violationID]          INT             IDENTITY (1, 1) NOT NULL,
    [violationTypeRoot_FK] INT             NULL,
    [chassisNumber_FK]     NVARCHAR (100)  NULL,
    [violationDate]        DATE            NULL,
    [violationPrice]       DECIMAL (18, 2) NULL,
    [violationLocation]    NVARCHAR (300)  NULL,
    [PaymentDate]          DATETIME        NULL,
    [entryPayment]         NVARCHAR (50)   NULL,
    [entrydata]            NVARCHAR (50)   NULL,
    [entrydate]            DATETIME        CONSTRAINT [DF_Violations_entrydate] DEFAULT (getdate()) NULL,
    [hostname]             NVARCHAR (200)  NULL,
    [IdaraID_FK]           BIGINT          NULL,
    CONSTRAINT [PK_Violations] PRIMARY KEY CLUSTERED ([violationID] ASC),
    CONSTRAINT [FK_Violations_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID])
);

