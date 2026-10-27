-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[FinancialAuditForUserDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      BIGINT
    , @hostname       NVARCHAR(400)
	, @NationalID      NVARCHAR(20) = NULL
    
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	    -- MeterReadForOccubentAndExit Data
 -- HousingExtend Data
        -- FinancialAuditForExtendAndEvictions Data

       


        Declare @buildingDetailsID   BIGINT, @residentInfoID   BIGINT

         set @residentInfoID = (select Top(1) f.residentInfoID 
        from Housing.V_GetFullResidentDetails f 
        where f.NationalID = @NationalID
        order by f.residentDetailsID desc)


        set @buildingDetailsID = (
        select Top(1) w.buildingDetailsID 
        from Housing.V_WaitingList w 
        where w.residentInfoID = @residentInfoID --and w.LastActionTypeID in (51,57) 
        order by w.LastActionID desc)


        

        -- PERFORMANCE ONLY: one materialization of the current financial-view result
        -- for this resident and department. The source views and all financial rules
        -- (occupancy dates, Hijri periods, payment link statuses, NULL building semantics)
        -- remain unchanged. This SELECT INTO does not emit a DataSet result set.
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
                  AND idaraID = @idaraID
            ) AS br
            FULL OUTER JOIN
            (
                SELECT residentInfoID, BillChargeTypeID, BillChargeTypeName_A,
                       buildingDetailsID, SumTotalPaidBills, idaraID
                FROM Housing.V_SumBillsTotalPaidByResident
                WHERE residentInfoID = @residentInfoID
                  AND idaraID = @idaraID
            ) AS po
                ON br.residentInfoID = po.residentInfoID
               AND br.BillChargeTypeID = po.BillChargeTypeID
               AND br.idaraID = po.idaraID
               AND br.buildingDetailsID = po.buildingDetailsID;
        END;

        ------------------------------1--------------------------------------------
       
             SELECT top(1)
               ROW_NUMBER() OVER (ORDER BY w.LastActionID DESC) AS order_
                , fr.residentInfoID [residentInfoID]
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
                --,w.buildingDetailsID
                --,w.buildingDetailsNo
                --,r.buildingRentAmount
                ,w.LastActionID
                ,w.LastActionTypeID
                ,w.ActionID
                ,convert(nvarchar(10),w.LastActionDate,23) LastActionDate
                ,w.LastActionExtendReasonTypeID
                
           FROM [DATACORE].[Housing].V_WaitingList w
           inner join [DATACORE].[Housing].V_GetFullResidentDetails fr on fr.residentInfoID = w.residentInfoID
           --inner join Housing.V_buildingWithRent r on w.buildingDetailsID = r.buildingDetailsID
           where 
          -- w.LastActionTypeID in (51,57) 
           --and 
           fr.residentInfoID = @residentInfoID
           and fr.IdaraID = @idaraID

           order by w.LastActionID desc

           

           -----------------------------------2-----------------------------------------------------------------------------------------



          
    --    SELECT 
    --        rd.FullName_A+' - '+rd.NationalID+' - '+case when w.LastActionTypeID = 51 then N'امهال' when w.LastActionTypeID = 57 then N'اخلاء' END as FullName_A,
    --        w.residentInfoID
          
    --FROM Housing.V_WaitingList w 
    --INNER JOIN Housing.V_GetFullResidentDetails rd 
    --    ON w.residentInfoID = rd.residentInfoID
    --    Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    --WHERE w.IdaraId = @idaraID
    --  AND  w.LastActionTypeID in (51,57)
    --  order by   w.waitingClassSequence asc


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
LEFT JOIN  #FinancialBalance s
       ON s.BillChargeTypeID = bt.BillChargeTypeID
      AND s.residentInfoID = @residentInfoID
      AND s.buildingDetailsID IS NOT NULL
      AND s.idaraID = @idaraID
LEFT JOIN Housing.V_GetGeneralListForBuilding b
       ON s.buildingDetailsID = b.buildingDetailsID
ORDER BY bt.BillChargeTypeID ASC;
END




--------------------------------------4--------------------------------------------------------------------------------------------------------------


        -- Result Set 4
-- Legacy financial summary placeholder.
-- Preserve DataSet position and original column names.
-- No obsolete financial view execution.

SELECT
    CAST(NULL AS BIGINT) AS order_,
    CAST(NULL AS DECIMAL(38,2)) AS AllAmountresidual,
    CAST(NULL AS DECIMAL(38,2)) AS RentBillsAmountresidual,
    CAST(NULL AS DECIMAL(38,2)) AS ServiceBillsAmountresidual
WHERE 1 = 0;




        
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
      Select e.ExtendReasonTypeID,e.ExtendReasonTypeName_A 
      from Housing.ExtendReasonType e
      where e.Active = 1

       
        ----------------------------------10------------------------------------------------------------------------------------------------------------------
      
      
     -- Performance: when no matching resident was resolved, keep the same
     -- two result sets and schemas, without executing financial aggregation.
     IF @residentInfoID IS NULL
     BEGIN
         -- Result set: building balances (empty schema-compatible result).
         SELECT
             CAST(NULL AS BIGINT)        AS order_,
             CAST(NULL AS BIGINT)        AS residentInfoID,
             CAST(NULL AS NVARCHAR(20))  AS buildingDetailsNo,
             CAST(NULL AS DECIMAL(10,2)) AS buildingRentAmount,
             CAST(NULL AS BIGINT)        AS buildingDetailsID,
             CAST(NULL AS DECIMAL(38,2)) AS SumBillsTotalPrice,
             CAST(NULL AS DECIMAL(38,2)) AS SumTotalPaidBills,
             CAST(NULL AS DECIMAL(38,2)) AS Remaining,
             CAST(N'' AS NVARCHAR(25))   AS BillsStatus,
             CAST(0 AS INT)              AS BillsStatusID,
             CAST(NULL AS BIT)           AS CanLinkGeneralBalance
         WHERE 1 = 0;

         -- Result set: unallocated general balance (empty schema-compatible result).
         SELECT
             CAST(NULL AS BIGINT)         AS order_,
             CAST(NULL AS BIGINT)         AS residentInfoID,
             CAST(NULL AS BIGINT)         AS BillChargeTypeID,
             CAST(N'' AS NVARCHAR(100))    AS BillChargeTypeName_A,
             CAST(NULL AS DECIMAL(38,2))  AS SumBillsTotalPrice,
             CAST(NULL AS DECIMAL(38,2))  AS SumTotalPaidBills,
             CAST(NULL AS DECIMAL(38,2))  AS Remaining,
             CAST(N'' AS NVARCHAR(22))     AS BillsStatus,
             CAST(0 AS INT)               AS BillsStatusID
         WHERE 1 = 0;
     END
     ELSE
     BEGIN

     select alls.order_
     ,alls.residentInfoID
     ,b.buildingDetailsNo
     ,r.buildingRentAmount
     ,alls.buildingDetailsID
     ,alls.SumBillsTotalPrice
     ,alls.SumTotalPaidBills
     ,alls.Remaining
     ,alls.BillsStatus
     ,alls.BillsStatusID
     
,CAST(
    CASE
        WHEN alls.buildingDetailsID IS NULL
         AND alls.BillsStatusID = 1
         AND alls.SumTotalPaidBills > 0
        THEN 1
        ELSE 0
    END AS BIT
) AS CanLinkGeneralBalance

     From( 
      SELECT 
      ROW_NUMBER() OVER (ORDER BY e.residentInfoID DESC) AS order_,
    e.residentInfoID,e.buildingDetailsID,
    SUM(e.SumBillsTotalPrice) AS SumBillsTotalPrice,
    SUM(e.SumTotalPaidBills) AS SumTotalPaidBills,
    case
        when SUM(e.Remaining) < 0 then SUM(e.Remaining) * -1
        else SUM(e.Remaining)
    end as Remaining,
    --SUM(e.Remaining) AS Remaining,
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
FROM  #FinancialBalance e
WHERE e.residentInfoID = @residentInfoID
AND e.idaraID = @idaraID
AND e.buildingDetailsID IS NOT NULL
GROUP BY e.residentInfoID,e.buildingDetailsID) alls
left join Housing.V_GetGeneralListForBuilding b on alls.buildingDetailsID = b.buildingDetailsID
left join Housing.V_buildingWithRent r on b.buildingDetailsID = r.buildingDetailsID
;
     


----------------------------------11--------------------------------------------------------------------
-- GENERAL BALANCE
-- الرصيد العام للمستفيد دون ربط بمبنى
-- هذا الجدول مخصص للعرض المستقل فقط

SELECT
      ROW_NUMBER() OVER (
          ORDER BY v.BillChargeTypeID
      ) AS order_

    , v.residentInfoID

    , v.BillChargeTypeID

    , ct.BillChargeTypeName_A

    , CAST(
        COALESCE(SUM(v.SumBillsTotalPrice), 0)
        AS DECIMAL(38,2)
      ) AS SumBillsTotalPrice

    , CAST(
        COALESCE(SUM(v.SumTotalPaidBills), 0)
        AS DECIMAL(38,2)
      ) AS SumTotalPaidBills

    , CAST(
        ABS(COALESCE(SUM(v.Remaining), 0))
        AS DECIMAL(38,2)
      ) AS Remaining

    , CASE
        WHEN SUM(v.Remaining) < 0
            THEN N'رصيد عام فائض للمستفيد'

        WHEN SUM(v.Remaining) > 0
            THEN N'رصيد عام مستحق للإدارة'

        ELSE N'لا يوجد رصيد متبقٍ'
      END AS BillsStatus

    , CASE
        WHEN SUM(v.Remaining) < 0 THEN 1
        WHEN SUM(v.Remaining) > 0 THEN 0
        ELSE 2
      END AS BillsStatusID

FROM  #FinancialBalance v

INNER JOIN Housing.BillChargeType ct
    ON ct.BillChargeTypeID = v.BillChargeTypeID

WHERE v.residentInfoID = @residentInfoID
  AND v.idaraID = @idaraID
  AND v.buildingDetailsID IS NULL

GROUP BY
      v.residentInfoID
    , v.BillChargeTypeID
    , ct.BillChargeTypeName_A

ORDER BY v.BillChargeTypeID;
     END -- End branch for resolved resident (financial queries unchanged).

END