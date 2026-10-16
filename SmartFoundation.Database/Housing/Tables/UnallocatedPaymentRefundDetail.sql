CREATE TABLE [Housing].[UnallocatedPaymentRefundDetail] (
    [RefundDetailID]  BIGINT          IDENTITY (1, 1) NOT NULL,
    [RefundID_FK]     BIGINT          NOT NULL,
    [PaymentID_FK]    BIGINT          NOT NULL,
    [AllocatedAmount] DECIMAL (18, 2) NOT NULL,
    CONSTRAINT [PK_HUPRD] PRIMARY KEY CLUSTERED ([RefundDetailID] ASC),
    CONSTRAINT [CK_HUPRD_AllocatedAmount] CHECK ([AllocatedAmount]>(0)),
    CONSTRAINT [FK_HUPRD_Payment] FOREIGN KEY ([PaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [FK_HUPRD_Refund] FOREIGN KEY ([RefundID_FK]) REFERENCES [Housing].[UnallocatedPaymentRefund] ([RefundID]),
    CONSTRAINT [UQ_HUPRD_RefundPayment] UNIQUE NONCLUSTERED ([RefundID_FK] ASC, [PaymentID_FK] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_HUPRD_Payment]
    ON [Housing].[UnallocatedPaymentRefundDetail]([PaymentID_FK] ASC)
    INCLUDE([AllocatedAmount]);

