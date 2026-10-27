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
    ,@buildingDetailsID BIGINT = NULL
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	    -- MeterReadForOccubentAndExit Data
 -- HousingExtend Data
        -- FinancialAuditForExtendAndEvictions Data
        


    -- PERFORMANCE ONLY: materialize resident financial rows once, preserving
    -- the current financial view's FULL OUTER JOIN semantics and all idara values.
    -- IMPORTANT: The original building totals do not filter idaraID and the
    -- general-balance alert checks department eligibility separately; filtering
    -- this materialization by @idaraID would silently change those results.
    -- SELECT INTO does NOT emit an extra result set to the caller.
    IF @residentInfoID IS NOT NULL
    BEGIN
        SELECT
            COALESCE(br.residentInfoID, po.residentInfoID) AS residentInfoID,
            COALESCE(br.BillChargeTypeID, po.BillChargeTypeID) AS BillChargeTypeID,
            COALESCE(br.BillChargeTypeName_A, po.BillChargeTypeName_A)
                AS BillChargeTypeName_A,
            COALESCE(br.buildingDetailsID, po.buildingDetailsID) AS buildingDetailsID,
            ISNULL(br.SumBillsTotalPrice, 0) AS SumBillsTotalPrice,
            ISNULL(po.SumTotalPaidBills, 0) AS SumTotalPaidBills,
            ISNULL(br.SumBillsTotalPrice, 0)
                - ISNULL(po.SumTotalPaidBills, 0) AS Remaining,
            COALESCE(br.idaraID, po.idaraID) AS idaraID
        INTO #FinancialBalance
        FROM
        (
            SELECT residentInfoID, BillChargeTypeID, BillChargeTypeName_A,
                   buildingDetailsID, SumBillsTotalPrice, idaraID
            FROM Housing.V_SumBillsTotalPriceForResident
            WHERE residentInfoID = @residentInfoID
        ) AS br
        FULL OUTER JOIN
        (
            SELECT residentInfoID, BillChargeTypeID, BillChargeTypeName_A,
                   buildingDetailsID, SumTotalPaidBills, idaraID
            FROM Housing.V_SumBillsTotalPaidByResident
            WHERE residentInfoID = @residentInfoID
        ) AS po
            ON br.residentInfoID = po.residentInfoID
           AND br.BillChargeTypeID = po.BillChargeTypeID
           AND br.idaraID = po.idaraID
           AND br.buildingDetailsID = po.buildingDetailsID;
    END;

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
                ,isnull(r.buildingRentAmount,0.00) buildingRentAmount
                ,w.LastActionID
                ,w.LastActionTypeID
                ,w.ActionID
                ,convert(nvarchar(10),w.LastActionDate,23) LastActionDate
                ,w.LastActionExtendReasonTypeID
                ,convert(nvarchar(10),w.OccupentDate,23) OccupentDate
                ,convert(nvarchar(10),w.ExitDate,23) ExitDate

                
           FROM [DATACORE].[Housing].V_WaitingList w
           inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
           left join Housing.V_buildingWithRent r on w.buildingDetailsID = r.buildingDetailsID
           WHERE w.LastActionTypeID IN (51,57)
            AND w.residentInfoID = @residentInfoID
            AND w.buildingDetailsID = @buildingDetailsID
            AND w.IdaraId = @idaraID
            AND fr.IdaraID = @idaraID

           

           -----------------------------------2-----------------------------------------------------------------------------------------



          
        SELECT
    CONCAT(
        rd.rankNameA,
        N' - ',
        rd.FullName_A,
        N' - ',
        rd.NationalID,
        N' - ',
        CASE
            WHEN w.LastActionTypeID = 51 THEN N'إمهال'
            WHEN w.LastActionTypeID = 57 THEN N'إخلاء'
        END,
        N' - المنزل ',
        w.buildingDetailsNo
    ) AS FullName_A,

    w.residentInfoID,

    CONCAT(
        CONVERT(NVARCHAR(20), w.residentInfoID),
        N'|',
        CONVERT(NVARCHAR(20), w.buildingDetailsID)
    ) AS AuditSelectionKey

FROM Housing.V_WaitingList w

INNER JOIN Housing.V_GetFullResidentDetails rd
    ON w.residentInfoID = rd.residentInfoID

INNER JOIN Housing.BuildingActionType ba
    ON w.LastActionTypeID = ba.buildingActionTypeID

WHERE w.IdaraId = @idaraID
  AND w.LastActionTypeID IN (51,57)

ORDER BY w.LastActionEntryDate DESC;


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
      --,ISNULL(s.[Remaining], 0) AS Remaining
      ,case
        when ISNULL(s.[Remaining], 0) < 0 then ISNULL(s.[Remaining], 0) * -1
        else ISNULL(s.[Remaining], 0)
        end as Remaining
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
LEFT JOIN #FinancialBalance s
       ON s.BillChargeTypeID = bt.BillChargeTypeID
      AND s.residentInfoID = @residentInfoID
      AND s.buildingDetailsID = @buildingDetailsID
LEFT JOIN Housing.V_GetGeneralListForBuilding b
       ON s.buildingDetailsID = b.buildingDetailsID
ORDER BY bt.BillChargeTypeID ASC;
END


--------------------------------------4--------------------------------------
-- Empty result set retained for DataSet compatibility.
-- No dependency on Housing.V_ResidentFinancialSummary.

SELECT
    CAST(NULL AS DECIMAL(18,2)) AS AllAmountresidual,
    CAST(NULL AS DECIMAL(18,2)) AS RentBillsAmountresidual,
    CAST(NULL AS DECIMAL(18,2)) AS ServiceBillsAmountresidual
WHERE 1 = 0;
----------------------------------------4--------------------------------------------------------------------------------------------------------------


--         SELECT
      
--        (([TotalRentBillsAmount]+[TotalServiceBillsAmount]) - ([TotalRentBillsPaid]+[TotalServiceBillsPaid])) AllAmountresidual
      
--      ,([TotalRentBillsAmount] - [TotalRentBillsPaid]) RentBillsAmountresidual
--      ,([TotalServiceBillsAmount] - [TotalServiceBillsPaid]) ServiceBillsAmountresidual


--        FROM [DATACORE].[Housing].V_WaitingList w
--           inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
--        inner join [DATACORE].[Housing].[V_ResidentFinancialSummary] s on fr.residentInfoID = s.residentInfoID

--        where s.residentInfoID = @residentInfoID
--        AND  w.LastActionTypeID in (51,57)
--        and fr.IdaraID = @idaraID




        
----------------------------------5----------------------------------

SELECT
    t.buildingPaymentTypeID AS billPaymentTypeID,
    t.buildingPaymentTypeName_A AS billPaymentTypeName_A
FROM Housing.BuildingPaymentType t
WHERE t.buildingPaymentDestainationID_FK = 1;


----------------------------------6----------------------------------

SELECT
    t.buildingPaymentTypeID AS billPaymentTypeID,
    t.buildingPaymentTypeName_A AS billPaymentTypeName_A
FROM Housing.BuildingPaymentType t
WHERE t.buildingPaymentDestainationID_FK = 2;


----------------------------------7----------------------------------

SELECT
    t.buildingPaymentTypeID AS billPaymentTypeID,
    t.buildingPaymentTypeName_A AS billPaymentTypeName_A
FROM Housing.BuildingPaymentType t
WHERE t.buildingPaymentTypeID IN (1, 2);


        ---------------------------------8-------------------------------------------------------------------------------------------------------------------
    Select e.BillChargeTypeID,e.BillChargeTypeName_A 
      from Housing.BillChargeType e
      where e.BillChargeTypeActive  = 1

    
    
    --select r.buildingRentAmount * 40 insuranceRentAmount,r.buildingRentAmount

     --FROM [DATACORE].[Housing].V_WaitingList w
     --   inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
     --   inner join [DATACORE].[Housing].[V_ResidentFinancialSummary] s on fr.residentInfoID = s.residentInfoID
     --   inner join Housing.V_buildingWithRent r on w.buildingDetailsID = r.buildingDetailsID
     --   where s.residentInfoID = @residentInfoID
     --   AND  w.LastActionTypeID in (51,57)
     --   and fr.IdaraID = @idaraID




        ----------------------------------9------------------------------------------------------------------------------------------------------------------
      --Select e.ExtendReasonTypeID,e.ExtendReasonTypeName_A 
      --from Housing.ExtendReasonType e
      --where e.Active = 1

      Select e.BillChargeTypeID,e.BillChargeTypeName_A 
      from Housing.BillChargeType e
      where e.BillChargeTypeActive  = 1 and e.BillChargeTypeID <> 6

       
        ----------------------------------10------------------------------------------------------------------------------------------------------------------
     
     if(@residentInfoID is null)
     begin
     
     SELECT TOP (0) 
    e.residentInfoID,
    SUM(e.SumBillsTotalPrice) AS SumBillsTotalPrice,
    SUM(e.SumTotalPaidBills) AS SumTotalPaidBills,
    case
        when SUM(e.Remaining) < 0 then SUM(e.Remaining) * -1
        else SUM(e.Remaining)
    end as Remaining,
    --SUM(e.Remaining) AS Remaining,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN N'المستفيد مطالب بمبالغ مستحقة للادارة'
        WHEN SUM(e.Remaining) < 0 THEN N'يوجد مبالغ فائضة للمستفيد'
        ELSE N'لايوجد مطالبات'
    END AS BillsStatus,
    CASE 
        WHEN SUM(e.Remaining) > 0 THEN 0
        WHEN SUM(e.Remaining) < 0 THEN 1
        ELSE 2
    END AS BillsStatusID
FROM Housing.V_SumBillsTotalPriceAndTotalPaidForResident e
WHERE e.residentInfoID = @residentInfoID
AND e.buildingDetailsID = @buildingDetailsID
GROUP BY e.residentInfoID;
     
     end

     else
     begin

     SELECT 
    @residentInfoID AS residentInfoID,

    COALESCE(SUM(e.SumBillsTotalPrice), 0) AS SumBillsTotalPrice,
    COALESCE(SUM(e.SumTotalPaidBills), 0) AS SumTotalPaidBills,

    CASE
        WHEN COALESCE(SUM(e.Remaining), 0) < 0 
            THEN COALESCE(SUM(e.Remaining), 0) * -1
        ELSE COALESCE(SUM(e.Remaining), 0)
    END AS Remaining,

    CASE 
        WHEN COALESCE(SUM(e.Remaining), 0) > 0 THEN N'مطالب بمبالغ للادارة'
        WHEN COALESCE(SUM(e.Remaining), 0) < 0 THEN N'يوجد مبالغ زائدة للمستفيد'
        ELSE N'لايوجد مطالبات'
    END AS BillsStatus,

    CASE 
        WHEN COALESCE(SUM(e.Remaining), 0) > 0 THEN 0
        WHEN COALESCE(SUM(e.Remaining), 0) < 0 THEN 1
        ELSE 2
    END AS BillsStatusID

FROM #FinancialBalance e
WHERE e.residentInfoID = @residentInfoID
AND e.buildingDetailsID = @buildingDetailsID

     end

       ------------------------------------11----------------------------------------------------------------------------------------------------------------
      
       ------------------------------------------------------------
-- GENERAL BALANCE ALERT
-- رصيد المستفيد العام غير المرتبط بمبنى
-- يضاف كآخر Result Set دون تغيير ترتيب النتائج السابقة
------------------------------------------------------------
IF @residentInfoID IS NULL
BEGIN
    -- Same one-row DECIMAL(18,2) result as the original aggregate on NULL.
    SELECT CONVERT(DECIMAL(18,2), 0) AS UnlinkedGeneralCredit;
END
ELSE
BEGIN
SELECT
    CONVERT(
        DECIMAL(18,2),
        COALESCE(
            SUM(
                CASE
                    WHEN v.Remaining < 0
                    THEN -CONVERT(DECIMAL(18,2), v.Remaining)
                    ELSE CONVERT(DECIMAL(18,2), 0)
                END
            ),
            0
        )
    ) AS UnlinkedGeneralCredit
FROM #FinancialBalance v
WHERE v.residentInfoID = @residentInfoID
  AND v.buildingDetailsID IS NULL
  AND EXISTS
  (
      SELECT 1
      FROM Housing.V_GetFullResidentDetails r
      WHERE r.residentInfoID = @residentInfoID
        AND r.IdaraID = @idaraID
  );
END; -- END general-balance ELSE
END; -- END procedure