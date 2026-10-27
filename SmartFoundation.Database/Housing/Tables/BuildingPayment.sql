CREATE TABLE [Housing].[BuildingPayment] (
    [paymentID]                      BIGINT           IDENTITY (1, 1) NOT NULL,
    [PaymentUID]                     UNIQUEIDENTIFIER CONSTRAINT [DF_BuildingPayment_PaymentUID] DEFAULT (newid()) NOT NULL,
    [buildingPaymentTypeID_FK]       INT              NULL,
    [generalNo_FK]                   BIGINT           NULL,
    [IDNumber]                       NVARCHAR (10)    NULL,
    [residentInfoID_FK]              BIGINT           NULL,
    [rankNameA]                      NVARCHAR (50)    NULL,
    [unitID]                         NVARCHAR (50)    NULL,
    [userName]                       NVARCHAR (500)   NULL,
    [buildingDetailsID_FK]           NVARCHAR (200)   NULL,
    [amount]                         DECIMAL (10, 2)  NULL,
    [deductListID_FK]                INT              NULL,
    [buildingPayementActive]         BIT              NULL,
    [BillChargeTypeID_FK]            BIGINT           NULL,
    [ExtendInsuranceID_FK]           BIGINT           NULL,
    [UnallocatedRefundID_FK]         BIGINT           NULL,
    [IdaraId_FK]                     INT              NULL,
    [entryDate]                      DATETIME         CONSTRAINT [DF_BuildingPayment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (2000)  NULL,
    [hostName]                       NVARCHAR (2000)  NULL,
    [buildingPaymentLinkStatusID_FK] INT              NULL,
    [paymentLinkNote]                NVARCHAR (1000)  NULL,
    CONSTRAINT [PK_BuildingPayment] PRIMARY KEY CLUSTERED ([paymentID] ASC),
    CONSTRAINT [FK_BuildingPayment_BuildingPaymentLinkStatus] FOREIGN KEY ([buildingPaymentLinkStatusID_FK]) REFERENCES [Housing].[BuildingPaymentLinkStatus] ([buildingPaymentLinkStatusID]),
    CONSTRAINT [FK_BuildingPayment_UnallocatedRefund] FOREIGN KEY ([UnallocatedRefundID_FK]) REFERENCES [Housing].[UnallocatedPaymentRefund] ([RefundID])
);






GO
CREATE NONCLUSTERED INDEX [IX_BuildingPayment_user]
    ON [Housing].[BuildingPayment]([generalNo_FK] ASC)
    INCLUDE([amount]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingPayment_LinkStatus]
    ON [Housing].[BuildingPayment]([buildingPaymentLinkStatusID_FK] ASC, [residentInfoID_FK] ASC, [BillChargeTypeID_FK] ASC, [buildingPayementActive] ASC)
    INCLUDE([buildingDetailsID_FK], [amount], [deductListID_FK], [IdaraId_FK]);


GO

/*
   يحمي كل إجراءات الإدخال الحالية، ومنها ImportExcelForBuildingPayment.
   لا يغير حالة تم إرسالها صراحة من أي إجراء.
*/
CREATE   TRIGGER [Housing].[TR_BuildingPayment_SetLinkStatus]
ON [Housing].[BuildingPayment]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE paymentRow
    SET [buildingPaymentLinkStatusID_FK] =
        CASE
            WHEN paymentRow.[residentInfoID_FK] IS NULL THEN 3
            WHEN NULLIF(LTRIM(RTRIM(paymentRow.[buildingDetailsID_FK])), N'') IS NULL THEN 2
            ELSE 1
        END
    FROM [Housing].[BuildingPayment] paymentRow
    JOIN inserted insertedRow ON insertedRow.[paymentID] = paymentRow.[paymentID]
    WHERE paymentRow.[buildingPaymentLinkStatusID_FK] IS NULL;
END;
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_BuildingPayment_UnallocatedRefundID]
    ON [Housing].[BuildingPayment]([UnallocatedRefundID_FK] ASC) WHERE ([UnallocatedRefundID_FK] IS NOT NULL);

