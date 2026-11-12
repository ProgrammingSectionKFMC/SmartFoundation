CREATE TABLE [Housing].[ResidentRentExemptionPayment] (
    [residentRentExemptionPaymentID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentRentExemptionID_FK]     BIGINT          NOT NULL,
    [paymentID_FK]                   BIGINT          NOT NULL,
    [billsID_FK]                     BIGINT          NOT NULL,
    [exemptionFromDate]              DATE            NOT NULL,
    [exemptionToDate]                DATE            NOT NULL,
    [exemptionAmount]                DECIMAL (18, 2) NOT NULL,
    [sourceType]                     NVARCHAR (30)   NOT NULL,
    [paymentActive]                  BIT             CONSTRAINT [DF_ResidentRentExemptionPayment_paymentActive] DEFAULT ((1)) NOT NULL,
    [canceledBy]                     NVARCHAR (20)   NULL,
    [canceledDate]                   DATETIME        NULL,
    [canceledReason]                 NVARCHAR (500)  NULL,
    [entryDate]                      DATETIME        CONSTRAINT [DF_ResidentRentExemptionPayment_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]                      NVARCHAR (20)   NULL,
    [hostName]                       NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ResidentRentExemptionPayment] PRIMARY KEY CLUSTERED ([residentRentExemptionPaymentID] ASC),
    CONSTRAINT [FK_ResidentRentExemptionPayment_Bill] FOREIGN KEY ([billsID_FK]) REFERENCES [Housing].[Bills] ([BillsID]),
    CONSTRAINT [FK_ResidentRentExemptionPayment_Exemption] FOREIGN KEY ([residentRentExemptionID_FK]) REFERENCES [Housing].[ResidentRentExemption] ([residentRentExemptionID]),
    CONSTRAINT [FK_ResidentRentExemptionPayment_Payment] FOREIGN KEY ([paymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID])
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_ResidentRentExemptionPayment_ActiveBill]
    ON [Housing].[ResidentRentExemptionPayment]([residentRentExemptionID_FK] ASC, [billsID_FK] ASC) WHERE ([paymentActive]=(1));


GO

CREATE NONCLUSTERED INDEX [IX_ResidentRentExemptionPayment_Payment]
    ON [Housing].[ResidentRentExemptionPayment]([paymentID_FK] ASC, [paymentActive] ASC);


GO

