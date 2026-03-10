CREATE TABLE [Housing].[ResidentRentExemptionType] (
    [ResidentRentExemptionTypeID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [ResidentRentExemptionTypeName_A]      NVARCHAR (1000) NULL,
    [ResidentRentExemptionTypeName_E]      NVARCHAR (1000) NULL,
    [ResidentRentExemptionTypeActive]      BIT             NULL,
    [ResidentRentExemptionTypeDescription] NVARCHAR (1000) NULL,
    [ResidentRentExemptionTypePercentage]  INT             NULL,
    [idaraID_FK]                           BIGINT          NULL,
    [entryDate]                            DATETIME        CONSTRAINT [DF_ResidentRentExemptionType_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                            NVARCHAR (20)   NULL,
    [hostName]                             NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentRentExemptionType] PRIMARY KEY CLUSTERED ([ResidentRentExemptionTypeID] ASC),
    CONSTRAINT [FK_ResidentRentExemptionType_Idara] FOREIGN KEY ([idaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID])
);

