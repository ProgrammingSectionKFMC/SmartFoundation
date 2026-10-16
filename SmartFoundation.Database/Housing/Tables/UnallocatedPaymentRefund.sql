CREATE TABLE [Housing].[UnallocatedPaymentRefund] (
    [RefundID]                  BIGINT           IDENTITY (1, 1) NOT NULL,
    [ResidentInfoID_FK]         BIGINT           NOT NULL,
    [BillChargeTypeID_FK]       INT              NOT NULL,
    [IdaraId_FK]                INT              NOT NULL,
    [BillPaymentTypeID_FK]      INT              NOT NULL,
    [RefundAmount]              DECIMAL (18, 2)  NOT NULL,
    [RefundDate]                DATE             NOT NULL,
    [RefundReference]           NVARCHAR (200)   NOT NULL,
    [RefundReferenceNormalized] AS               (upper(ltrim(rtrim([RefundReference])))) PERSISTED,
    [RefundDetails]             NVARCHAR (MAX)   NOT NULL,
    [RequestKey]                UNIQUEIDENTIFIER NOT NULL,
    [RefundStatus]              TINYINT          CONSTRAINT [DF_HUPR_Status] DEFAULT ((1)) NOT NULL,
    [EntryDate]                 DATETIME2 (3)    CONSTRAINT [DF_HUPR_EntryDate] DEFAULT (sysdatetime()) NOT NULL,
    [EntryData]                 NVARCHAR (40)    NOT NULL,
    [HostName]                  NVARCHAR (400)   NULL,
    [CancellationReason]        NVARCHAR (1000)  NULL,
    [CancellationDate]          DATETIME2 (7)    NULL,
    [CancellationEntryData]     NVARCHAR (40)    NULL,
    CONSTRAINT [PK_HUPR] PRIMARY KEY CLUSTERED ([RefundID] ASC),
    CONSTRAINT [CK_HUPR_Amount] CHECK ([RefundAmount]>(0)),
    CONSTRAINT [CK_HUPR_Details] CHECK (len(ltrim(rtrim([RefundDetails])))>(0)),
    CONSTRAINT [CK_HUPR_PaymentType] CHECK ([BillPaymentTypeID_FK]=(4)),
    CONSTRAINT [CK_HUPR_Reference] CHECK (len(ltrim(rtrim([RefundReference])))>(0)),
    CONSTRAINT [CK_HUPR_Status] CHECK ([RefundStatus]=(2) OR [RefundStatus]=(1)),
    CONSTRAINT [FK_HUPR_BillPaymentType] FOREIGN KEY ([BillPaymentTypeID_FK]) REFERENCES [Housing].[billPaymentType] ([billPaymentTypeID]),
    CONSTRAINT [FK_HUPR_ChargeType] FOREIGN KEY ([BillChargeTypeID_FK]) REFERENCES [Housing].[BillChargeType] ([BillChargeTypeID]),
    CONSTRAINT [FK_HUPR_Resident] FOREIGN KEY ([ResidentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID]),
    CONSTRAINT [UQ_HUPR_RequestKey] UNIQUE NONCLUSTERED ([RequestKey] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_HUPR_ResidentChargeStatus]
    ON [Housing].[UnallocatedPaymentRefund]([IdaraId_FK] ASC, [ResidentInfoID_FK] ASC, [BillChargeTypeID_FK] ASC, [RefundStatus] ASC)
    INCLUDE([RefundAmount], [RefundDate]);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_HUPR_RefundReference]
    ON [Housing].[UnallocatedPaymentRefund]([IdaraId_FK] ASC, [ResidentInfoID_FK] ASC, [BillChargeTypeID_FK] ASC, [RefundReferenceNormalized] ASC) WHERE ([RefundStatus]=(1));

