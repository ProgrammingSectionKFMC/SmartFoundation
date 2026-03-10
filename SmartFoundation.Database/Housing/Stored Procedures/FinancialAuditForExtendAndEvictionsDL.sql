-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[FinancialAuditForExtendAndEvictionsDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      BIGINT
    , @hostname       NVARCHAR(400)
	,@residentInfoID   BIGINT
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	    -- MeterReadForOccubentAndExit Data
 -- HousingExtend Data
        -- FinancialAuditForExtendAndEvictions Data
        Declare @buildingDetailsID   BIGINT
        set @buildingDetailsID = (
        select Top(1) w.buildingDetailsID 
        from Housing.V_WaitingList w 
        where w.residentInfoID = @residentInfoID and w.LastActionTypeID in (51,57) 
        order by w.LastActionID desc)

        ------------------------------1--------------------------------------------
       
             SELECT 
                 fr.residentInfoID [residentInfoID]
                ,fr.NationalID [NationalID]
                ,fr.generalNo_FK [generalNo_FK]
                ,fr.firstName_A [firstName_A]
                ,fr.secondName_A [secondName_A]
                ,fr.thirdName_A [thirdName_A]
                ,fr.lastName_A [lastName_A]
                ,fr.firstName_E [firstName_E]
                ,fr.secondName_E [secondName_E]
                ,fr.thirdName_E [thirdName_E]
                ,fr.lastName_E [lastName_E]
                ,LTRIM(RTRIM(
                 CONCAT_WS(N' ',
                     fr.firstName_A,
                     fr.secondName_A,
                     fr.thirdName_A,
                     fr.lastName_A
                 )
                 )) AS FullName_A
                ,LTRIM(RTRIM(
                 CONCAT_WS(N' ',
                     fr.firstName_E,
                     fr.secondName_E,
                     fr.thirdName_E,
                     fr.lastName_E
                 )
                 )) AS FullName_E
                ,fr.rankID_FK [rankID_FK]
                ,fr.rankNameA
                ,fr.militaryUnitID_FK [militaryUnitID_FK]
                ,fr.militaryUnitName_A
                ,fr.martialStatusID_FK [martialStatusID_FK]
                ,fr.maritalStatusName_A
                ,fr.dependinceCounter [dependinceCounter]
                ,fr.nationalityID_FK [nationalityID_FK]
                ,fr.nationalityName_A
                ,fr.genderID_FK [genderID_FK]
                ,fr.genderName_A
                ,convert(nvarchar(10),fr.birthdate,23) birthdate
                ,fr.residentcontactDetails
                ,fr.note [note]
                ,fr.IdaraID IdaraID
                ,fr.IdaraName IdaraName
                ,w.buildingDetailsID
                ,w.buildingDetailsNo
                ,r.buildingRentAmount
                ,w.LastActionID
                ,w.LastActionTypeID
                ,w.ActionID
                ,convert(nvarchar(10),w.LastActionDate,23) LastActionDate
                ,w.LastActionExtendReasonTypeID
                
           FROM [DATACORE].[Housing].V_WaitingList w
           inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
           inner join Housing.V_buildingWithRent r on w.buildingDetailsID = r.buildingDetailsID
           where w.LastActionTypeID in (51,57) 
           and fr.residentInfoID = @residentInfoID
           and fr.IdaraID = @idaraID

           

           -----------------------------------2-----------------------------------------------------------------------------------------



          
        SELECT 
            rd.FullName_A+' - '+rd.NationalID+' - '+case when w.LastActionTypeID = 51 then N'امهال' when w.LastActionTypeID = 57 then N'اخلاء' END as FullName_A,
            w.residentInfoID
          
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (51,57)
      order by   w.waitingClassSequence asc


      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)


--------------------------------------3--------------------------------------------------------------------------------------------------------------

IF @residentInfoID IS NOT NULL
Begin

SELECT 
       ROW_NUMBER() OVER (ORDER BY bt.BillChargeTypeID ASC) AS order_
      ,ISNULL(s.[residentInfoID], @residentInfoID) AS residentInfoID
      ,bt.[BillChargeTypeID]
      ,bt.[BillChargeTypeName_A]
      ,ISNULL(s.[buildingDetailsID], -1) AS buildingDetailsID 
      ,ISNULL(b.buildingDetailsNo, N'لايوجد') AS buildingDetailsNo 
      ,ISNULL(s.[SumBillsTotalPrice], 0) AS SumBillsTotalPrice
      ,ISNULL(s.[SumTotalPaidBills], 0) AS SumTotalPaidBills
      ,ISNULL(s.[Remaining], 0) AS Remaining
      ,CASE
          WHEN ISNULL(s.[Remaining], 0) > 0 THEN N'فواتير ' + bt.BillChargeTypeName_A + N' مستحقة للادارة'
          WHEN ISNULL(s.[Remaining], 0) < 0 THEN N'فواتير ' + bt.BillChargeTypeName_A + N' زائدة للمستفيد'
          ELSE N'لايوجد مطالبات'
       END AS BillsStatus
      ,CASE
          WHEN ISNULL(s.[Remaining], 0) > 0 THEN 0
          WHEN ISNULL(s.[Remaining], 0) < 0 THEN 1
          ELSE 2
       END AS BillsStatusID
FROM Housing.BillChargeType bt
LEFT JOIN Housing.V_SumBillsTotalPriceAndTotalPaidForResident s
       ON s.BillChargeTypeID = bt.BillChargeTypeID
      AND s.residentInfoID = @residentInfoID
      AND (s.buildingDetailsID = @buildingDetailsID OR s.buildingDetailsID IS NULL)
LEFT JOIN Housing.V_GetGeneralListForBuilding b
       ON s.buildingDetailsID = b.buildingDetailsID
ORDER BY bt.BillChargeTypeID ASC;
END



--------------------------------------4--------------------------------------------------------------------------------------------------------------


         SELECT
      
        (([TotalRentBillsAmount]+[TotalServiceBillsAmount]) - ([TotalRentBillsPaid]+[TotalServiceBillsPaid])) AllAmountresidual
      
      ,([TotalRentBillsAmount] - [TotalRentBillsPaid]) RentBillsAmountresidual
      ,([TotalServiceBillsAmount] - [TotalServiceBillsPaid]) ServiceBillsAmountresidual


        FROM [DATACORE].[Housing].V_WaitingList w
           inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
        inner join [DATACORE].[Housing].[V_ResidentFinancialSummary] s on fr.residentInfoID = s.residentInfoID

        where s.residentInfoID = @residentInfoID
        AND  w.LastActionTypeID in (51,57)
        and fr.IdaraID = @idaraID




        ------------------------------5----------------------------------------------------------------------------------------------------------------------

        select 
        t.billPaymentTypeID,
        t.billPaymentTypeName_A
        from Housing.billPaymentType t 
        where t.billPaymentDestainationID_FK = 1
        

        ------------------------------6----------------------------------------------------------------------------------------------------------------------

         select 
        t.billPaymentTypeID,
        t.billPaymentTypeName_A
        from Housing.billPaymentType t 
        where t.billPaymentDestainationID_FK = 2
     
     ------------------------------------7----------------------------------------------------------------------------------------------------------------
     select 
        t.billPaymentTypeID,
        t.billPaymentTypeName_A
        from Housing.billPaymentType t 
        where t.billPaymentTypeID in(1,2)

        ---------------------------------8-------------------------------------------------------------------------------------------------------------------
     select r.buildingRentAmount * 40 insuranceRentAmount,r.buildingRentAmount

     FROM [DATACORE].[Housing].V_WaitingList w
        inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
        inner join [DATACORE].[Housing].[V_ResidentFinancialSummary] s on fr.residentInfoID = s.residentInfoID
        inner join Housing.V_buildingWithRent r on w.buildingDetailsID = r.buildingDetailsID
        where s.residentInfoID = @residentInfoID
        AND  w.LastActionTypeID in (51,57)
        and fr.IdaraID = @idaraID


        ----------------------------------9------------------------------------------------------------------------------------------------------------------
      Select e.ExtendReasonTypeID,e.ExtendReasonTypeName_A 
      from Housing.ExtendReasonType e
      where e.Active = 1

        ----------------------------------10------------------------------------------------------------------------------------------------------------------
      SELECT 
    e.residentInfoID,
    SUM(e.SumBillsTotalPrice) AS SumBillsTotalPrice,
    SUM(e.SumTotalPaidBills) AS SumTotalPaidBills,
    SUM(e.Remaining) AS Remaining,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN N'مطالب بمبالغ للادارة'
        WHEN SUM(e.Remaining) < 0 THEN N'يوجد مبالغ زائدة للمستفيد'
        ELSE N'لايوجد مطالبات'
    END AS BillsStatus,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN 0
        WHEN SUM(e.Remaining) < 0 THEN 1
        ELSE 2
    END AS BillsStatusID
FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
WHERE e.residentInfoID = @residentInfoID
AND (e.buildingDetailsID = @buildingDetailsID OR e.buildingDetailsID IS NULL)
GROUP BY e.residentInfoID;
     


END
