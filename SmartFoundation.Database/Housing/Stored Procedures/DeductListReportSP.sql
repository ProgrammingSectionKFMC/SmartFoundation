CREATE PROCEDURE Housing.DeductListReportSP @Action NVARCHAR(50),@ReportID BIGINT=NULL,@Year INT=NULL,@Month INT=NULL,@BillingType NVARCHAR(20)=NULL,@ServiceID INT=NULL,@CalculationMethod NVARCHAR(30)=NULL,@ReportNo NVARCHAR(50)=NULL,@ExternalReferenceNo NVARCHAR(100)=NULL,@ExternalReferenceDate DATE=NULL,@Notes NVARCHAR(1000)=NULL,@IdaraID BIGINT,@EntryData NVARCHAR(20),@HostName NVARCHAR(200)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @TransactionCount INT=@@TRANCOUNT;
 BEGIN TRY
 IF @TransactionCount=0 BEGIN TRAN;
 IF @Action=N'CREATEDEDUCTLISTREPORT'
 BEGIN
  IF @Year IS NULL OR @Month NOT BETWEEN 1 AND 12 OR @BillingType<>N'SERVICE' OR @ServiceID IS NULL THROW 50001,N'بيانات شهر ونوع الخدمة مطلوبة لإنشاء المسير.',1;
  SET @CalculationMethod=N'ALL_METHODS';

  /* وجود فاتورة قراءة فعلية يلزم إغلاق فترتها؛ فواتير الفراغات والثابت لا تتطلب إغلاق فترة قراءة. */
  IF EXISTS
  (
      SELECT 1
      FROM Housing.Bills bill
      WHERE bill.BillActive=1
        AND bill.IdaraID_FK=@IdaraID
        AND bill.meterServiceTypeID=@ServiceID
        AND bill.PeriodYear=@Year
        AND bill.PeriodMonth=@Month
        AND bill.meterID IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1 FROM Housing.BillCalculation calculation
            WHERE calculation.BillsID_FK=bill.BillsID
        )
        AND NOT EXISTS
        (
            SELECT 1
            FROM Housing.BillPeriod billPeriod
            JOIN Housing.BillPeriodType billPeriodType ON billPeriodType.billPeriodTypeID=billPeriod.billPeriodTypeID_FK
            WHERE billPeriod.billPeriodID=bill.CurrentPeriodID
              AND billPeriod.IdaraId_FK=@IdaraID
              AND billPeriodType.meterServiceTypeID_FK=@ServiceID
              AND billPeriod.billPeriodActive=0
              AND NULLIF(LTRIM(RTRIM(billPeriod.ClosedBy)),N'') IS NOT NULL
        )
  ) THROW 50001,N'لا يمكن إنشاء المسير قبل إغلاق فترة قراءة العدادات المفوترة نهائياً.',1;

  IF NOT EXISTS
  (
      SELECT 1
      FROM Housing.Bills bill
      WHERE bill.BillActive=1
        AND bill.IdaraID_FK=@IdaraID
        AND bill.meterServiceTypeID=@ServiceID
        AND bill.PeriodYear=@Year
        AND bill.PeriodMonth=@Month
        AND EXISTS
        (
            SELECT 1 FROM Housing.V_Occupant occupant
            WHERE occupant.residentInfoID=bill.residentInfoID_FK
              AND occupant.IdaraId=@IdaraID
        )
  ) THROW 50001,N'لا توجد فواتير مرصودة ومؤهلة لهذه الخدمة في الشهر المحدد.',1;
  IF EXISTS(SELECT 1 FROM Housing.DeductListReport WHERE IdaraID_FK=@IdaraID AND PeriodYear=@Year AND PeriodMonth=@Month AND BillingType=@BillingType AND ISNULL(MeterServiceTypeID_FK,0)=ISNULL(@ServiceID,0) AND IsCurrent=1) THROW 50001,N'يوجد مسير حالي لهذه الخدمة والشهر.',1;
  SET @ReportNo=CONVERT(NVARCHAR(50),NEXT VALUE FOR Housing.DeductListReportNoSequence);
  INSERT Housing.DeductListReport(IdaraID_FK,PeriodYear,PeriodMonth,BillingType,MeterServiceTypeID_FK,CalculationMethod,ReportNo,Notes,entryData,hostName) VALUES(@IdaraID,@Year,@Month,@BillingType,@ServiceID,@CalculationMethod,@ReportNo,@Notes,@EntryData,@HostName);
  SET @ReportID=SCOPE_IDENTITY();
  INSERT Housing.DeductListReportDetails(DeductListReportID_FK,BillsID_FK,BillNumber,ResidentInfoID_FK,GeneralNo_FK,IDNumber,ResidentFullName_A,MilitaryUnitName_A,BuildingDetailsID_FK,BuildingDetailsNo,MeterID_FK,MeterNo,BillsFromDate,BillsToDate,AmountBeforeTax,TaxAmount,TotalAmount)
  SELECT @ReportID,b.BillsID,b.BillNumber,b.residentInfoID_FK,COALESCE(b.generalNo_FK,person.GeneralNo_FK),r.NationalID,person.FullName_A,person.MilitaryUnitName_A,b.buildingDetailsID,COALESCE(NULLIF(b.buildingDetailsNo,N''),building.buildingDetailsNo),b.meterID,b.meterNo,CONVERT(date,b.BillsFromDate),CONVERT(date,b.BillsToDate),ISNULL(b.PRICE,0),ISNULL(b.PRICETAX,0),ISNULL(b.TotalPrice,0)
  FROM Housing.Bills b
  LEFT JOIN Housing.ResidentInfo r ON r.residentInfoID=b.residentInfoID_FK
  LEFT JOIN Housing.BuildingDetails building ON building.buildingDetailsID=b.buildingDetailsID
  OUTER APPLY
  (
      SELECT TOP(1)
          LTRIM(RTRIM(CONCAT_WS(N' ',details.firstName_A,details.secondName_A,details.thirdName_A,details.lastName_A))) FullName_A,
          details.generalNo_FK AS GeneralNo_FK,
          militaryUnit.militaryUnitName_A AS MilitaryUnitName_A
      FROM Housing.ResidentDetails details
      LEFT JOIN dbo.MilitaryUnit militaryUnit ON militaryUnit.militaryUnitID=details.militaryUnitID_FK
      WHERE details.residentInfoID_FK=b.residentInfoID_FK AND details.IdaraId_FK=@IdaraID
      ORDER BY ISNULL(details.residentDetailsActive,0) DESC,details.residentDetailsID DESC
  ) person
  WHERE b.BillActive=1 AND b.IdaraID_FK=@IdaraID AND b.PeriodYear=@Year AND b.PeriodMonth=@Month AND b.meterServiceTypeID=@ServiceID
    AND EXISTS
    (
        SELECT 1
        FROM Housing.V_Occupant occupant
        WHERE occupant.residentInfoID=b.residentInfoID_FK
          AND occupant.IdaraId=@IdaraID
    );
  IF NOT EXISTS(SELECT 1 FROM Housing.DeductListReportDetails WHERE DeductListReportID_FK=@ReportID) THROW 50001,N'لا توجد فواتير مؤهلة للمسير المحدد.',1;
  UPDATE r SET InvoiceCount=x.c,AmountBeforeTax=x.a,TaxAmount=x.t,TotalAmount=x.total FROM Housing.DeductListReport r CROSS APPLY(SELECT COUNT(*)c,SUM(AmountBeforeTax)a,SUM(TaxAmount)t,SUM(TotalAmount)total FROM Housing.DeductListReportDetails WHERE DeductListReportID_FK=@ReportID)x WHERE r.DeductListReportID=@ReportID;
 END
 ELSE IF @Action=N'APPROVEDEDUCTLISTREPORT' UPDATE Housing.DeductListReport SET ReportStatus=N'APPROVED',ApprovedDate=GETDATE(),ApprovedBy=@EntryData WHERE DeductListReportID=@ReportID AND IdaraID_FK=@IdaraID AND ReportStatus=N'DRAFT';
 ELSE IF @Action=N'SENDDEDUCTLISTREPORT' UPDATE Housing.DeductListReport SET ReportStatus=N'SENT',SentDate=GETDATE(),SentBy=@EntryData,ExternalReferenceNo=@ExternalReferenceNo,ExternalReferenceDate=@ExternalReferenceDate WHERE DeductListReportID=@ReportID AND IdaraID_FK=@IdaraID AND ReportStatus=N'APPROVED';
 ELSE IF @Action=N'CANCELDEDUCTLISTREPORT' UPDATE Housing.DeductListReport SET ReportStatus=N'CANCELLED',IsCurrent=0 WHERE DeductListReportID=@ReportID AND IdaraID_FK=@IdaraID AND ReportStatus=N'DRAFT';
 ELSE THROW 50001,N'العملية غير مسجلة.',1;
 IF @@ROWCOUNT=0 AND @Action<>N'CREATEDEDUCTLISTREPORT' THROW 50001,N'لا يمكن تنفيذ العملية بالحالة الحالية أو خارج الإدارة.',1;
 IF @TransactionCount=0 COMMIT;
 SELECT CAST(1 AS bit) IsSuccessful,N'تم تنفيذ العملية بنجاح.' Message_;
 END TRY
 BEGIN CATCH
  -- This procedure is called by dbo.Masters_CRUD through INSERT ... EXEC.
  -- A child procedure cannot ROLLBACK the caller's transaction in that context.
  IF @TransactionCount=0 AND XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH
END;
