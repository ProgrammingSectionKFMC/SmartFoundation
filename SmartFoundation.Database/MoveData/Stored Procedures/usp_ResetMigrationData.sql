
CREATE   PROCEDURE [MoveData].[usp_ResetMigrationData]
    @ConfirmReset bit = 0,
    @RollbackAfterTest bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DB_NAME() <> N'DATACORE'
        THROW 59000, N'This procedure can run only in the DATACORE database.', 1;

    IF @ConfirmReset <> 1
        THROW 59001, N'Reset was not confirmed. Pass @ConfirmReset = 1.', 1;

    DECLARE @Before TABLE
    (
        TableOrder int NOT NULL,
        TableName nvarchar(300) NOT NULL,
        RowCount_ bigint NOT NULL
    );

    INSERT @Before(TableOrder,TableName,RowCount_)
    SELECT -13,N'Housing.BillCalculationDetails',COUNT_BIG(*) FROM [Housing].[BillCalculationDetails]
    UNION ALL SELECT -12,N'Housing.BillCalculation',COUNT_BIG(*) FROM [Housing].[BillCalculation]
    UNION ALL SELECT -11,N'Housing.BuildingSpace',COUNT_BIG(*) FROM [Housing].[BuildingSpace]
    UNION ALL SELECT -10,N'Housing.DeductListReportImport',COUNT_BIG(*) FROM [Housing].[DeductListReportImport]
    UNION ALL SELECT -9,N'Housing.DeductListReportDetails',COUNT_BIG(*) FROM [Housing].[DeductListReportDetails]
    UNION ALL SELECT -8,N'Housing.DeductListReport',COUNT_BIG(*) FROM [Housing].[DeductListReport]
    UNION ALL SELECT -7,N'Housing.MonthlyBillingRunDetails',COUNT_BIG(*) FROM [Housing].[MonthlyBillingRunDetails]
    UNION ALL SELECT -6,N'Housing.MonthlyBillingRun',COUNT_BIG(*) FROM [Housing].[MonthlyBillingRun]
    UNION ALL SELECT -5,N'Housing.ResidentRentExemptionPayment',COUNT_BIG(*) FROM [Housing].[ResidentRentExemptionPayment]
    UNION ALL SELECT -4,N'Housing.RentBillsAdjustment',COUNT_BIG(*) FROM [Housing].[RentBillsAdjustment]
    UNION ALL SELECT -3,N'Housing.ResidentRentExemption',COUNT_BIG(*) FROM [Housing].[ResidentRentExemption]
    UNION ALL SELECT -2,N'Housing.OccupantCustodyAction',COUNT_BIG(*) FROM [Housing].[OccupantCustodyAction]
    UNION ALL SELECT -1,N'Housing.RentBills',COUNT_BIG(*) FROM [Housing].[RentBills]
    UNION ALL SELECT  0,N'Housing.UploadExcelImportLog',COUNT_BIG(*) FROM [Housing].[UploadExcelImportLog]
    UNION ALL SELECT  1,N'Housing.BillsDeductListDetails',COUNT_BIG(*) FROM [Housing].[BillsDeductListDetails]
    UNION ALL SELECT  2,N'Housing.BillDeductAction',COUNT_BIG(*) FROM [Housing].[BillDeductAction]
    UNION ALL SELECT  3,N'Housing.BillDeductList',COUNT_BIG(*) FROM [Housing].[BillDeductList]
    UNION ALL SELECT  4,N'Housing.BuildingPaymentLinkAudit',COUNT_BIG(*) FROM [Housing].[BuildingPaymentLinkAudit]
    UNION ALL SELECT  5,N'Housing.ExtendInsurance',COUNT_BIG(*) FROM [Housing].[ExtendInsurance]
    UNION ALL SELECT  6,N'Housing.BuildingPayment',COUNT_BIG(*) FROM [Housing].[BuildingPayment]
    UNION ALL SELECT  7,N'Housing.Bills',COUNT_BIG(*) FROM [Housing].[Bills]
    UNION ALL SELECT  8,N'Housing.DeductList',COUNT_BIG(*) FROM [Housing].[DeductList]
    UNION ALL SELECT  9,N'Housing.MeterRead',COUNT_BIG(*) FROM [Housing].[MeterRead]
    UNION ALL SELECT 10,N'Housing.MeterForBuilding',COUNT_BIG(*) FROM [Housing].[MeterForBuilding]
    UNION ALL SELECT 11,N'Housing.MeterServicePrice',COUNT_BIG(*) FROM [Housing].[MeterServicePrice]
    UNION ALL SELECT 12,N'Housing.Meter',COUNT_BIG(*) FROM [Housing].[Meter]
    UNION ALL SELECT 13,N'Housing.BillPeriod',COUNT_BIG(*) FROM [Housing].[BillPeriod]
    UNION ALL SELECT 14,N'Housing.MeterType',COUNT_BIG(*) FROM [Housing].[MeterType]
    UNION ALL SELECT 15,N'Housing.BuildingAssign',COUNT_BIG(*) FROM [Housing].[BuildingAssign]
    UNION ALL SELECT 16,N'Housing.BuildingAction',COUNT_BIG(*) FROM [Housing].[BuildingAction]
    UNION ALL SELECT 17,N'Housing.AssignPeriod',COUNT_BIG(*) FROM [Housing].[AssignPeriod]
    UNION ALL SELECT 18,N'Housing.BuildingRent',COUNT_BIG(*) FROM [Housing].[BuildingRent]
    UNION ALL SELECT 19,N'Housing.ResidentContactInfo',COUNT_BIG(*) FROM [Housing].[ResidentContactInfo]
    UNION ALL SELECT 20,N'Housing.ResidentDetails',COUNT_BIG(*) FROM [Housing].[ResidentDetails]
    UNION ALL SELECT 21,N'Housing.BuildingDetailsMeterServices',COUNT_BIG(*) FROM [Housing].[BuildingDetailsMeterServices]
    UNION ALL SELECT 22,N'Housing.BuildingDetails',COUNT_BIG(*) FROM [Housing].[BuildingDetails]
    UNION ALL SELECT 23,N'Housing.ResidentInfo',COUNT_BIG(*) FROM [Housing].[ResidentInfo]
    UNION ALL SELECT 24,N'Housing.MilitaryLocation',COUNT_BIG(*) FROM [Housing].[MilitaryLocation]
    UNION ALL SELECT 25,N'dbo.MilitaryUnit',COUNT_BIG(*) FROM [dbo].[MilitaryUnit];

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Transactional estimated billing data; preserve policy and space-type configuration. */
        DELETE FROM [Housing].[BillCalculationDetails];
        DELETE FROM [Housing].[BillCalculation];
        DELETE FROM [Housing].[BuildingSpace];

        /* مسيرات الحسم: الأبناء أولاً قبل قوائم الحسم والفواتير. */
        DELETE FROM [Housing].[DeductListReportImport];
        DELETE FROM [Housing].[DeductListReportDetails];
        DELETE FROM [Housing].[DeductListReport];

        /* Children and financial details first. */
        DELETE FROM [Housing].[MonthlyBillingRunDetails];
        DELETE FROM [Housing].[MonthlyBillingRun];
        DELETE FROM [Housing].[ResidentRentExemptionPayment];
        DELETE FROM [Housing].[RentBillsAdjustment];
        DELETE FROM [Housing].[ResidentRentExemption];
        DELETE FROM [Housing].[OccupantCustodyAction];
        DELETE FROM [Housing].[RentBills];

        /* This is a test environment: remove every imported-file fingerprint. */
        DELETE FROM [Housing].[UploadExcelImportLog];
        DELETE FROM [Housing].[BillsDeductListDetails];
        DELETE FROM [Housing].[BillDeductAction];
        DELETE FROM [Housing].[BillDeductList];
        DELETE FROM [Housing].[BuildingPaymentLinkAudit];
        DELETE FROM [Housing].[ExtendInsurance];
        DELETE FROM [Housing].[BuildingPayment];
        DELETE FROM [Housing].[Bills];
        DELETE FROM [Housing].[DeductList];

        /* Meter transactions and master data. */
        DELETE FROM [Housing].[MeterRead];
        DELETE FROM [Housing].[MeterForBuilding];
        DELETE FROM [Housing].[MeterServicePrice];
        DELETE FROM [Housing].[Meter];
        DELETE FROM [Housing].[BillPeriod];
        DELETE FROM [Housing].[MeterType];

        /* Housing actions, buildings, residents, and their masters. */
        DELETE FROM [Housing].[BuildingAssign];
        DELETE FROM [Housing].[BuildingAction];
        DELETE FROM [Housing].[AssignPeriod];
        DELETE FROM [Housing].[BuildingRent];
        DELETE FROM [Housing].[ResidentContactInfo];
        DELETE FROM [Housing].[ResidentDetails];
        DELETE FROM [Housing].[BuildingDetailsMeterServices];
        DELETE FROM [Housing].[BuildingDetails];
        DELETE FROM [Housing].[ResidentInfo];
        DELETE FROM [Housing].[MilitaryLocation];
        DELETE FROM [dbo].[MilitaryUnit];

        /* DELETE does not reset identities; reseed empty tables so next value is 1. */
        DBCC CHECKIDENT (N'Housing.BillCalculationDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BillCalculation', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingSpace', RESEED, 0) WITH NO_INFOMSGS;

        DBCC CHECKIDENT (N'Housing.DeductListReportImport', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.DeductListReportDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.DeductListReport', RESEED, 0) WITH NO_INFOMSGS;
        ALTER SEQUENCE Housing.DeductListReportNoSequence RESTART WITH 1;

        DBCC CHECKIDENT (N'Housing.MonthlyBillingRunDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MonthlyBillingRun', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ResidentRentExemptionPayment', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.RentBillsAdjustment', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ResidentRentExemption', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.OccupantCustodyAction', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.RentBills', RESEED, 0) WITH NO_INFOMSGS;

        DBCC CHECKIDENT (N'Housing.UploadExcelImportLog', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BillsDeductListDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BillDeductAction', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BillDeductList', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingPaymentLinkAudit', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ExtendInsurance', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingPayment', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.Bills', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.DeductList', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MeterRead', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MeterForBuilding', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MeterServicePrice', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.Meter', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BillPeriod', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MeterType', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingAssign', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingAction', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.AssignPeriod', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingRent', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ResidentContactInfo', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ResidentDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingDetailsMeterServices', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.BuildingDetails', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.ResidentInfo', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'Housing.MilitaryLocation', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT (N'dbo.MilitaryUnit', RESEED, 0) WITH NO_INFOMSGS;

        SELECT
            @RollbackAfterTest AS RollbackAfterTest,
            TableName,
            RowCount_ AS RowsBeforeReset,
            CONVERT(bigint,0) AS RowsAfterReset
        FROM @Before
        ORDER BY TableOrder;

        IF @RollbackAfterTest=1
            ROLLBACK TRANSACTION;
        ELSE
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
