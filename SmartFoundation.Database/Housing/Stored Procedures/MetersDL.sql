-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[MetersDL] 
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
	   


              






          -- Residents Data
            select 
             m.[meterID]
            ,m.[meterNo]
            ,m.[meterName_A]
            ,m.[meterName_E]
            ,mst.meterServiceTypeName_A
            ,m.[meterTypeID_FK]
            ,mt.[meterTypeName_A]
            ,mst.meterServiceTypeID
            
            ,msp.meterServicePriceID
            ,msp.meterServicePrice
            
            ,m.[meterDescription]
            ,convert(nvarchar(10),m.[meterStartDate],23) as meterStartDate
            ,m.[meterEndDate]
            ,m.[meterActive]
            ,mr.meterReadValue as firstReadValue
            ,m.[IdaraId_FK]

            
            from 
            [DATACORE].[Housing].[Meter] m 
            inner join [DATACORE].[Housing].[MeterType] mt on m.meterTypeID_FK = mt.meterTypeID
            inner join [DATACORE].[Housing].[MeterServiceType] mst on mt.meterServiceTypeID_FK = mst.meterServiceTypeID
            inner join [DATACORE].Housing.[MeterServicePrice] msp on msp.meterTypeID_FK = mt.meterTypeID
            inner join  Housing.MeterRead mr on m.meterID = mr.meterID_FK and mr.meterReadActive = 1 and  mr.meterReadTypeID_FK = 4
            where m.idaraID_FK = @idaraID and m.meterActive = 1 and mt.meterTypeActive = 1 and mst.meterServiceTypeActive = 1 and msp.meterServicePriceActive = 1

            order by m.meterID desc



            SELECT mm.[meterTypeID]
                  ,mm.[meterServiceTypeID_FK]
                  ,mst.[meterServiceTypeName_A]
                  ,msp.meterServicePrice
                  ,mm.[meterTypeName_A]
                  ,mm.[meterTypeName_E]
                  ,mm.[meterTypeDescription]
                  ,mm.[meterTypeConversionFactor]
                  ,mm.[meterMaxRead]
                  ,CONVERT(nvarchar(10),mm.[meterTypeStartDate],23) as meterTypeStartDate
                  ,mm.[meterTypeEndDate]
                  ,mm.[meterTypeActive]
                  ,mm.[IdaraId_FK]
                  ,mm.[entryDate]
                  ,mm.[entryData]
                  ,mm.[hostName]
              FROM [DATACORE].[Housing].[MeterType] mm
              inner join  Housing.MeterServiceType mst on mm.meterServiceTypeID_FK = mst.meterServiceTypeID
              inner join  Housing.MeterServicePrice msp on mm.meterTypeID = msp.meterTypeID_FK
              where mm.IdaraId_FK = @idaraID
              and meterTypeActive = 1

              order by mm.meterTypeID desc





                   SELECT 
                   mbt.[meterForBuildingID]
                  ,mbt.[meterID_FK]
                  ,mbt.[buildingDetailsID_FK]
                  ,mbt.[meterForBuildingEndDate]
                  ,mbt.[meterForBuildingActive]
                  ,m.meterNo
                  ,m.meterName_A
                  ,m.meterName_E
                  ,bd.buildingDetailsNo
                  ,bd.buildingClassName_A
                  ,bd.buildingTypeName_A
                  ,bd.buildingUtilityTypeName_A
                  ,bd.militaryLocationName_A
                  ,convert(nvarchar(10),mbt.[meterForBuildingStartDate],23) as meterForBuildingStartDate
                  ,bd.BuildingIdaraName
                  ,bd.BuildingIdaraID
                  
                FROM [DATACORE].[Housing].[MeterForBuilding] mbt
                inner join [DATACORE].[Housing].[Meter] m on mbt.meterID_FK = m.meterID
                inner join [DATACORE].[Housing].[V_GetGeneralListForBuilding] bd on mbt.buildingDetailsID_FK = bd.buildingDetailsID
                where m.idaraID_FK = @idaraID and mbt.meterForBuildingActive = 1 and m.meterActive = 1
                order by mbt.meterForBuildingID desc



             SELECT [meterServiceTypeID]
                  ,[meterServiceTypeName_A]
                 
              FROM [DATACORE].[Housing].[MeterServiceType] mst 
              inner join  Housing.MeterServiceTypeLinkedWithIdara mi on mst.meterServiceTypeID = mi.MeterServiceTypeID_FK
              where mst.meterServiceTypeActive = 1 and mi.MeterServiceTypeLinkedWithIdaraActive = 1 and mi.Idara_FK = @idaraID


              SELECT mt.meterTypeID
                  ,mt.meterTypeName_A
                 
              FROM [DATACORE].[Housing].[MeterType] mt 
              inner join Housing.MeterServiceType mst on mt.meterServiceTypeID_FK = mst.meterServiceTypeID
              inner join  Housing.MeterServiceTypeLinkedWithIdara mi on mst.meterServiceTypeID = mi.MeterServiceTypeID_FK
              where mt.meterTypeActive = 1 
              and mst.meterServiceTypeActive = 1
              and mi.MeterServiceTypeLinkedWithIdaraActive = 1 
              and mi.Idara_FK = @idaraID 
              and mt.IdaraId_FK = @idaraID



              select 
             m.[meterID]
            ,cast(m.[meterNo] as nvarchar(400)) meterNo
            ,m.[meterTypeID_FK]

            from 
            [DATACORE].[Housing].[Meter] m 
            inner join [DATACORE].[Housing].[MeterType] mt on m.meterTypeID_FK = mt.meterTypeID
            left join  Housing.MeterForBuilding mbt on m.meterID = mbt.meterID_FK and mbt.meterForBuildingActive = 1

            where m.meterActive = 1  and mt.meterTypeActive = 1 and mbt.meterForBuildingID is null and m.IdaraId_FK = @idaraID
          

;WITH B AS
(
    SELECT
        b.buildingDetailsID,
        b.buildingDetailsNo
    FROM  Housing.V_GetGeneralListForBuilding b
    WHERE b.buildingDetailsActive = 1
      AND b.BuildingIdaraID = 1
),
AggService AS
(
    SELECT
        mb.buildingDetailsID_FK AS buildingDetailsID,
        ServiceNameClean =
            NULLIF(
                LTRIM(RTRIM(
                    REPLACE(ISNULL(mst.meterServiceTypeName_A, N''), N'خدمة عدادات ', N'')
                )),
                N''
            ),
        Cnt = COUNT_BIG(*)
    FROM  Housing.MeterForBuilding mb
    INNER JOIN  Housing.Meter m
        ON m.meterID = mb.meterID_FK
       AND m.meterActive = 1
    INNER JOIN  Housing.MeterType mt
        ON mt.meterTypeID = m.meterTypeID_FK
       AND mt.meterTypeActive = 1
    INNER JOIN  Housing.MeterServiceType mst
        ON mst.meterServiceTypeID = mt.meterServiceTypeID_FK
       AND mst.meterServiceTypeActive = 1
    WHERE mb.meterForBuildingActive = 1
      AND NULLIF(LTRIM(RTRIM(ISNULL(mst.meterServiceTypeName_A, N''))), N'') IS NOT NULL
    GROUP BY
        mb.buildingDetailsID_FK,
        NULLIF(
            LTRIM(RTRIM(
                REPLACE(ISNULL(mst.meterServiceTypeName_A, N''), N'خدمة عدادات ', N'')
            )),
            N''
        )
),
Agg AS
(
    SELECT
        s.buildingDetailsID,
        TotalCnt = SUM(s.Cnt),
        Summary  = STRING_AGG(CONCAT(s.ServiceNameClean, N' x', s.Cnt), N', ')
    FROM AggService s
    WHERE s.ServiceNameClean IS NOT NULL
    GROUP BY s.buildingDetailsID
)
SELECT
    b.buildingDetailsID,
    b.buildingDetailsNo
    + CASE
        WHEN ISNULL(a.TotalCnt, 0) = 0 THEN N' (المبنى غير مرتبط باي عداد)'
        ELSE N' (' + ISNULL(a.Summary, N'') + N')'
      END AS buildingDetailsNoWithMeters
FROM B b
LEFT JOIN Agg a
    ON a.buildingDetailsID = b.buildingDetailsID
ORDER BY b.buildingDetailsNo;


                --SELECT
                --    b.buildingDetailsID,
                --    b.buildingDetailsNo
                --    + CASE
                --        WHEN ISNULL(x.TotalCnt, 0) = 0 THEN N' (المبنى غير مرتبط باي عداد)'
                --        ELSE N' (' + x.Summary + N')'
                --      END AS buildingDetailsNoWithMeters
                --FROM  Housing.V_GetGeneralListForBuilding b
                --OUTER APPLY
                --(
                --    SELECT
                --        -- مجموع العدادات المرتبطة (علشان نعرف هل فيه ارتباط أو لا)
                --        (SELECT COUNT(*)
                --         FROM  Housing.MeterForBuilding mb
                --         WHERE mb.buildingDetailsID_FK = b.buildingDetailsID
                --           AND mb.meterForBuildingActive = 1
                --        ) AS TotalCnt,
                
                --        -- ملخص (كهرباء x2, غاز x1, ماء x3)
                --        (
                --            SELECT STRING_AGG(CONCAT(z.ServiceNameClean, N' x', z.Cnt), N', ')
                --            FROM
                --            (
                --                SELECT
                --                    NULLIF(
                --                        LTRIM(RTRIM(
                --                            REPLACE(ISNULL(mst.meterServiceTypeName_A, N''), N'خدمة عدادات ', N'')
                --                        )),
                --                        N''
                --                    ) AS ServiceNameClean,
                --                    COUNT(*) AS Cnt
                --                FROM  Housing.MeterForBuilding mb
                --                INNER JOIN  Housing.Meter m
                --                    ON m.meterID = mb.meterID_FK
                --                   AND m.meterActive = 1
                --                INNER JOIN  Housing.MeterType mt
                --                    ON mt.meterTypeID = m.meterTypeID_FK
                --                   AND mt.meterTypeActive = 1
                --                INNER JOIN  Housing.MeterServiceType mst
                --                    ON mst.meterServiceTypeID = mt.meterServiceTypeID_FK
                --                   AND mst.meterServiceTypeActive = 1
                --                WHERE mb.buildingDetailsID_FK = b.buildingDetailsID
                --                  AND mb.meterForBuildingActive = 1
                --                  AND NULLIF(LTRIM(RTRIM(ISNULL(mst.meterServiceTypeName_A, N''))), N'') IS NOT NULL
                --                GROUP BY
                --                    NULLIF(
                --                        LTRIM(RTRIM(
                --                            REPLACE(ISNULL(mst.meterServiceTypeName_A, N''), N'خدمة عدادات ', N'')
                --                        )),
                --                        N''
                --                    )
                --            ) z
                --            WHERE z.ServiceNameClean IS NOT NULL
                --        ) AS Summary
                --) x
                --WHERE b.buildingDetailsActive = 1
                --  AND b.BuildingIdaraID = 1;


END
