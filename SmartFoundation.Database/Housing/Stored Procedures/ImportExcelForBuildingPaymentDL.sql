-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [Housing].[ImportExcelForBuildingPaymentDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
  -- Assign Data

          
 SELECT  [BillChargeTypeID]
                  ,[BillChargeTypeName_A]
      
        FROM [DATACORE].[Housing].[BillChargeType] 
        where BillChargeTypeActive = 1 and BillChargeTypeID <> 5
        order by BillChargeTypeID asc


        DECLARE @StartYear INT = 2017;
        DECLARE @EndYear INT = YEAR(GETDATE());
        
        ;WITH YearsCTE AS
        (
            SELECT @StartYear AS Year_
        
            UNION ALL
        
            SELECT Year_ + 1
            FROM YearsCTE
            WHERE Year_ + 1 <= @EndYear
        )
        SELECT
    billChargeType.BillChargeTypeID,
    years.Year_
FROM YearsCTE years
CROSS JOIN Housing.BillChargeType billChargeType
WHERE billChargeType.BillChargeTypeActive = 1
  AND billChargeType.BillChargeTypeID <> 5
ORDER BY
    billChargeType.BillChargeTypeID,
    years.Year_
OPTION (MAXRECURSION 100);

        -- DECLARE @StartYear INT = 2017;
        --DECLARE @EndYear   INT = YEAR(GETDATE());
        
        --;WITH YearsCTE AS
        --(
        --    SELECT @StartYear AS Year_
        --    UNION ALL
        --    SELECT Year_ + 1
        --    FROM YearsCTE
        --    WHERE Year_ + 1 <= @EndYear
        --)
        --SELECT Year_
        --FROM YearsCTE
        --ORDER BY Year_
        --OPTION (MAXRECURSION 100);



        DECLARE @StartDate DATE = '2017-01-01';
        DECLARE @EndDate   DATE = EOMONTH(GETDATE());
        
        ;WITH MonthsCTE AS
        (
            SELECT @StartDate AS MonthStart
            UNION ALL
            SELECT DATEADD(MONTH, 1, MonthStart)
            FROM MonthsCTE
            WHERE DATEADD(MONTH, 1, MonthStart) <= @EndDate
        )
        SELECT
            YEAR(MonthStart)  AS Year_,
            MONTH(MonthStart) AS MonthNumber,
            CASE MONTH(MonthStart)
                WHEN 1  THEN N'يناير'
                WHEN 2  THEN N'فبراير'
                WHEN 3  THEN N'مارس'
                WHEN 4  THEN N'أبريل'
                WHEN 5  THEN N'مايو'
                WHEN 6  THEN N'يونيو'
                WHEN 7  THEN N'يوليو'
                WHEN 8  THEN N'أغسطس'
                WHEN 9  THEN N'سبتمبر'
                WHEN 10 THEN N'أكتوبر'
                WHEN 11 THEN N'نوفمبر'
                WHEN 12 THEN N'ديسمبر'
            END AS ArabicMonthName
        FROM MonthsCTE
        ORDER BY MonthStart
        OPTION (MAXRECURSION 1000);

        --------------------------------------

        SELECT  
       d.[deductListID]
      ,d.[deductTypeID_FK]
      ,p.deductTypeName_A
      ,c.BillChargeTypeName_A
      ,d.[DeductListStatusID_FK]
      ,d.[deductUID]
      ,d.[deductName]
      ,d.[amountTypeID_FK]
      ,d.[paymentTypeID_FK]
      ,d.[issueMonth]
      ,d.[issueYear]
      ,d.[paymentNo]
      ,CONVERT(nvarchar(10), d.paymentDate, 23) AS paymentDate
      ,d.[description]
      ,d.[deductActive]
      ,d.[BillChargeTypeID_FK]
      ,d.[IdaraId_FK]
      ,d.[entryDate]
      ,d.[entryData]
      ,d.[hostName]

  FROM [DATACORE].[Housing].[DeductList] d
  inner join Housing.UploadExcelImportLog excelLog on excelLog.DeductListID_FK = d.deductListID
  inner join Housing.DeductType p on d.deductTypeID_FK = p.deductTypeID
  inner join Housing.BillChargeType c on d.BillChargeTypeID_FK = c.BillChargeTypeID
  where d.deductActive = 1
  and d.IdaraId_FK = @idaraID
  order by deductListID desc

  /* المسيرات الصادرة التي يسمح بربط ملفات الحسم الواردة بها. */
  SELECT reportRow.DeductListReportID,
         CONCAT(reportRow.ReportNo, N' - ', reportRow.PeriodYear, N'/', RIGHT(N'0'+CONVERT(nvarchar(2),reportRow.PeriodMonth),2),
                N' - ', CASE WHEN reportRow.BillingType=N'RENT' THEN N'إيجار' ELSE ISNULL(serviceType.meterServiceTypeName_A,N'خدمة') END) AS DeductListReportName
  FROM Housing.DeductListReport reportRow
  LEFT JOIN Housing.MeterServiceType serviceType ON serviceType.meterServiceTypeID=reportRow.MeterServiceTypeID_FK
  WHERE reportRow.IdaraID_FK=@idaraID AND reportRow.ReportStatus=N'SENT' AND reportRow.IsCurrent=1
  ORDER BY reportRow.SentDate DESC,reportRow.DeductListReportID DESC;




  SELECT
    serviceType.BillChargeTypeID_FK,
    reportRow.PeriodYear,
    reportRow.PeriodMonth,
    reportRow.DeductListReportID,
    CONCAT(
        reportRow.ReportNo, N' - ',
        serviceType.meterServiceTypeName_A, N' - ',
        reportRow.PeriodYear, N'/',
        RIGHT(N'0' + CONVERT(NVARCHAR(2), reportRow.PeriodMonth), 2)
    ) AS DeductListReportName
FROM Housing.DeductListReport reportRow
INNER JOIN Housing.MeterServiceType serviceType
    ON serviceType.meterServiceTypeID =
       reportRow.MeterServiceTypeID_FK
WHERE reportRow.IdaraID_FK = @idaraID
  AND reportRow.ReportStatus = N'SENT'
  AND reportRow.IsCurrent = 1
  AND reportRow.BillingType = N'SERVICE'
  AND reportRow.CalculationMethod = N'METERED'
ORDER BY
    serviceType.BillChargeTypeID_FK,
    reportRow.PeriodYear,
    reportRow.PeriodMonth,
    reportRow.ReportNo DESC;

   
END

GO

