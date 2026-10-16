CREATE PROCEDURE [Housing].[MonthlyBillingMonitorDL]
      @Year INT = NULL, @Month INT = NULL, @IdaraID BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Target DATE=DATEADD(MONTH,-1,CONVERT(date,GETDATE()));
    SET @Year=ISNULL(@Year,YEAR(@Target)); SET @Month=ISNULL(@Month,MONTH(@Target));
    SELECT r.*,i.idaraLongName_A,s.meterServiceTypeName_A
         ,CASE r.BillingType WHEN N'RENT' THEN N'الإيجارات' ELSE N'الخدمات' END BillingTypeName_A
         ,CASE r.CalculationMethod WHEN N'RENT' THEN N'إيجار' WHEN N'SERVICE_FIXED' THEN N'خدمة ثابتة' WHEN N'METER_FIXED' THEN N'عداد ثابت' ELSE r.CalculationMethod END CalculationMethodName_A
         ,CASE r.RunStatus WHEN N'PENDING' THEN N'بانتظار التشغيل' WHEN N'RUNNING' THEN N'قيد التشغيل' WHEN N'COMPLETED' THEN N'مكتمل' WHEN N'FAILED' THEN N'فشل' ELSE r.RunStatus END RunStatusName_A
    FROM Housing.MonthlyBillingRun r
    LEFT JOIN dbo.Idara i ON i.idaraID=r.IdaraID_FK
    LEFT JOIN Housing.MeterServiceType s ON s.meterServiceTypeID=r.MeterServiceTypeID_FK
    WHERE r.PeriodYear=@Year AND r.PeriodMonth=@Month AND (@IdaraID IS NULL OR r.IdaraID_FK=@IdaraID)
    ORDER BY r.IdaraID_FK,r.BillingType,r.MeterServiceTypeID_FK,r.CalculationMethod;

    SELECT d.*,b.BillNumber,bd.buildingDetailsNo,m.meterNo
         ,CASE d.ResultStatus WHEN N'EXISTING' THEN N'موجودة مسبقاً' WHEN N'BILLED' THEN N'تم الرصد' WHEN N'SKIPPED' THEN N'متجاوزة' WHEN N'FAILED' THEN N'فشل' ELSE d.ResultStatus END ResultStatusName_A
    FROM Housing.MonthlyBillingRunDetails d
    JOIN Housing.MonthlyBillingRun r ON r.MonthlyBillingRunID=d.MonthlyBillingRunID_FK
    LEFT JOIN Housing.Bills b ON b.BillsID=d.BillsID_FK
    LEFT JOIN Housing.BuildingDetails bd ON bd.buildingDetailsID=d.BuildingDetailsID_FK
    LEFT JOIN Housing.Meter m ON m.meterID=d.MeterID_FK
    WHERE r.PeriodYear=@Year AND r.PeriodMonth=@Month AND (@IdaraID IS NULL OR r.IdaraID_FK=@IdaraID)
    ORDER BY d.MonthlyBillingRunID_FK,d.ResultStatus,d.BuildingDetailsID_FK;

    SELECT DISTINCT i.idaraID,i.idaraLongName_A
    FROM 
    --Housing.MonthlyBillingRun r 
    --JOIN 
    dbo.Idara i --ON i.idaraID=r.IdaraID_FK
    --WHERE 
    --(@IdaraID IS NULL OR r.IdaraID_FK=@IdaraID) 
    ORDER BY i.idaraLongName_A;
END;