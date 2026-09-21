CREATE   PROCEDURE [Housing].[DeductListReportDL] 

      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @Year INT=NULL
    , @Month INT=NULL
    , @ReportID BIGINT=NULL


AS
BEGIN
 SET NOCOUNT ON;
 
 
 SELECT 
       r.[DeductListReportID]
      ,r.[IdaraID_FK]
      ,r.[ReportNo]
      ,r.[PeriodMonth]
      ,r.[PeriodYear]
      ,s.meterServiceTypeName_A
      ,r.[BillingType]
      ,r.[MeterServiceTypeID_FK]
      ,r.[CalculationMethod]
      ,r.[RevisionNo]
      ,r.[ReportStatus]
      ,case 
       when r.[ReportStatus] = N'DRAFT' then N'تحت الاجراء'
       when r.[ReportStatus] = N'APPROVED' then N'معتمد'
       when r.[ReportStatus] = N'SENT' then N'مرسل'
       when r.[ReportStatus] = N'CANCELLED' then N'ملغى'
       ELSE
       N'غير معروف'
       END ReportStatusArabic
      ,r.[IsCurrent]
      ,r.[InvoiceCount]
      ,r.[AmountBeforeTax]
      ,r.[TaxAmount]
      ,r.[TotalAmount]
      ,convert(nvarchar(10),r.[ApprovedDate],111) ApprovedDate
      --,r.[ApprovedBy]
      ,fs.FullName ApprovedBy
      --,r.[SentDate]
      ,convert(nvarchar(10),r.[SentDate],111) SentDate
      --,r.[SentBy]
      ,fss.FullName SentBy
      ,r.[ExternalReferenceNo]
      ,convert(nvarchar(10),r.[ExternalReferenceDate],111) ExternalReferenceDate
      ,r.[Notes]
      ,r.[entryDate]
      ,r.[entryData]
      ,r.[hostName],
 i.idaraLongName_A,
 ISNULL(x.ImportedAmount,0) ImportedAmount,
 ISNULL(x.ImportedRows,0) ImportedRows,
 r.TotalAmount-ISNULL(x.ImportedAmount,0) DifferenceAmount

  FROM Housing.DeductListReport r 
 JOIN dbo.Idara i ON i.idaraID=r.IdaraID_FK 
 LEFT JOIN Housing.MeterServiceType s ON s.meterServiceTypeID=r.MeterServiceTypeID_FK
 OUTER APPLY(SELECT SUM(ImportedAmount) ImportedAmount,SUM(ImportedRows) ImportedRows FROM Housing.DeductListReportImport z WHERE z.DeductListReportID_FK=r.DeductListReportID)x
 left join dbo.V_GetFullSystemUsersDetails fs on r.ApprovedBy = fs.usersID
 left join dbo.V_GetFullSystemUsersDetails fss on r.SentBy = fss.usersID
 WHERE r.IdaraID_FK=@IdaraID 
 AND r.PeriodYear=@Year
 AND  r.PeriodMonth=@Month 
 ORDER BY r.DeductListReportID DESC;
 
 
 SELECT 
 
       d.[DeductListReportDetailsID]
      ,d.[DeductListReportID_FK]
      ,d.[BillsID_FK]
      ,d.[BillNumber]
      ,d.[ResidentInfoID_FK]
      ,d.[GeneralNo_FK]
      ,d.[IDNumber]
      ,d.[BuildingDetailsID_FK]
      ,d.[BuildingDetailsNo]
      ,d.[MeterID_FK]
      ,d.[MeterNo]
      ,d.[BillsFromDate]
      ,d.[BillsToDate]
      ,d.[AmountBeforeTax]
      ,d.[TaxAmount]
      ,d.[TotalAmount]
      ,d.[entryDate]
      ,d.[ResidentFullName_A]
 
 FROM Housing.DeductListReportDetails d 
 WHERE @ReportID IS NOT NULL 
 AND d.DeductListReportID_FK=@ReportID 
 ORDER BY d.DeductListReportDetailsID;
 
 
 SELECT x.*,l.deductName,l.paymentNo,l.paymentDate,log.OriginalFileName,log.UploadedAt 
 FROM Housing.DeductListReportImport x 
 JOIN Housing.DeductList l ON l.deductListID=x.DeductListID_FK 
 LEFT JOIN Housing.UploadExcelImportLog log ON log.DeductListID_FK=l.deductListID 
 WHERE @ReportID IS NOT NULL 
 AND x.DeductListReportID_FK=@ReportID 
 ORDER BY x.DeductListReportImportID DESC;
 
 
 SELECT serviceType.meterServiceTypeID,serviceType.meterServiceTypeName_A
 FROM Housing.MeterServiceType serviceType
 WHERE serviceType.meterServiceTypeActive=1
   AND EXISTS
   (
       SELECT 1
       FROM Housing.Bills bill
       WHERE bill.BillActive=1
         AND bill.IdaraID_FK=@IdaraID
         AND bill.meterServiceTypeID=serviceType.meterServiceTypeID
         AND bill.PeriodYear=@Year
         AND bill.PeriodMonth=@Month
         AND EXISTS
         (
             SELECT 1
             FROM Housing.V_Occupant occupant
             WHERE occupant.residentInfoID=bill.residentInfoID_FK
               AND occupant.IdaraId=@IdaraID
         )
   )
 ORDER BY serviceType.meterServiceTypeName_A;




 SELECT YEAR(GETDATE()) - v.number AS [YearID],YEAR(GETDATE()) - v.number AS [YearNo]
FROM master..spt_values v
WHERE v.type = 'P'
  AND v.number BETWEEN 0 AND YEAR(GETDATE()) - 2017
ORDER BY [YearNo] desc;




------------------------------------------------------------
-- الأشهر المتاحة لكل سنة
------------------------------------------------------------
;WITH Years AS
(
    SELECT
        YEAR(GETDATE()) - v.number AS YearNo
    FROM master..spt_values v
    WHERE v.type = 'P'
      AND v.number BETWEEN 0 AND YEAR(GETDATE()) - 2017
)
SELECT
      y.YearNo
    , m.number AS MonthID
    , m.number AS MonthNo
FROM Years y
CROSS JOIN master..spt_values m
WHERE m.type = 'P'
  AND m.number BETWEEN 1 AND
      CASE
          WHEN y.YearNo < YEAR(GETDATE())
              THEN 12

          WHEN y.YearNo = YEAR(GETDATE())
              THEN MONTH(GETDATE()) - 1

          ELSE 0
      END
ORDER BY
      y.YearNo DESC,
      m.number ASC;


END;
