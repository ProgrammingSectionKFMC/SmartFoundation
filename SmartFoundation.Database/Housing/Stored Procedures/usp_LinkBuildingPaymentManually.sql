
/* ربط يدوي بعد تحقق الموظف من المبنى. */
CREATE   PROCEDURE [Housing].[usp_LinkBuildingPaymentManually]
    @PaymentID bigint,
    @BuildingDetailsID bigint,
    @ChangedBy nvarchar(100),
    @Note nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM [Housing].[BuildingPayment] WHERE [paymentID] = @PaymentID)
        THROW 58200, N'السداد غير موجود.', 1;
    IF NOT EXISTS (SELECT 1 FROM [Housing].[BuildingDetails] WHERE [buildingDetailsID] = @BuildingDetailsID)
        THROW 58201, N'المبنى غير موجود.', 1;
    IF EXISTS
    (
        SELECT 1 FROM [Housing].[BuildingPayment]
        WHERE [paymentID] = @PaymentID AND [residentInfoID_FK] IS NULL
    )
        THROW 58202, N'يجب ربط المستفيد أولا قبل ربط المبنى.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM [Housing].[BuildingPayment] paymentRow
        JOIN [Housing].[BuildingAction] actionRow
          ON actionRow.[residentInfoID_FK] = paymentRow.[residentInfoID_FK]
         AND actionRow.[buildingDetailsID_FK] = @BuildingDetailsID
         AND actionRow.[buildingActionTypeID_FK] = 2
         AND actionRow.[buildingActionActive] = 1
        WHERE paymentRow.[paymentID] = @PaymentID
    )
        THROW 58203, N'لا توجد فترة سكن للمستفيد في المبنى المحدد.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE [Housing].[BuildingPayment]
        SET [buildingDetailsID_FK] = CONVERT(nvarchar(400), @BuildingDetailsID),
            [buildingPaymentLinkStatusID_FK] = 1,
            [paymentLinkNote] = COALESCE(@Note, N'تم الربط بالمبنى يدويا.')
        OUTPUT
            inserted.[paymentID], deleted.[buildingPaymentLinkStatusID_FK],
            inserted.[buildingPaymentLinkStatusID_FK], deleted.[buildingDetailsID_FK],
            inserted.[buildingDetailsID_FK], N'MANUAL',
            inserted.[paymentLinkNote], @ChangedBy, GETDATE()
        INTO [Housing].[BuildingPaymentLinkAudit]
        (
            paymentID_FK, oldLinkStatusID, newLinkStatusID,
            oldBuildingDetailsID, newBuildingDetailsID,
            linkMethod, linkNote, changedBy, changedDate
        )
        WHERE [paymentID] = @PaymentID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

