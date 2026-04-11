CREATE TABLE [Housing].[ResidentRentExemption] (
    [residentRentExemptionID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentRentExemptionTypeID_FK]   BIGINT          NULL,
    [residentInfoID_FK]                BIGINT          NULL,
    [buildingDetailsID_FK]             BIGINT          NULL,
    [residentRentExemptionActive]      BIT             NULL,
    [residentRentExemptionLetterNo]    NVARCHAR (500)  NULL,
    [residentRentExemptionLetterDate]  DATETIME        NULL,
    [residentRentExemptionStartDate]   DATETIME        NULL,
    [residentRentExemptionEndDate]     DATETIME        NULL,
    [residentRentExemptionDescription] NVARCHAR (1000) NULL,
    [idaraID_FK]                       BIGINT          NULL,
    [entryDate]                        DATETIME        CONSTRAINT [DF_ResidentRentExemption_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                        NVARCHAR (20)   NULL,
    [hostName]                         NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentRentExemption] PRIMARY KEY CLUSTERED ([residentRentExemptionID] ASC),
    CONSTRAINT [FK_ResidentRentExemption_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID]),
    CONSTRAINT [FK_ResidentRentExemption_ResidentRentExemptionType] FOREIGN KEY ([residentRentExemptionTypeID_FK]) REFERENCES [Housing].[ResidentRentExemptionType] ([ResidentRentExemptionTypeID])
);

