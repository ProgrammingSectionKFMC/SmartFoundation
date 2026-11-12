-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[HousingExitDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @NationalID NVARCHAR(400)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 -- HousingExit Data


DECLARE @residentInfoID BIGINT = NULL;
DECLARE @MatchedResidentCount INT = 0;

SELECT
    @MatchedResidentCount = COUNT(DISTINCT w.residentInfoID),
    @residentInfoID = MIN(w.residentInfoID)
FROM Housing.V_WaitingList w
WHERE w.NationalID = @NationalID
  AND w.IdaraId = @idaraID
  AND w.buildingActionRoot IN (2, 3);

IF @MatchedResidentCount > 1
BEGIN
    THROW 50001,
        N'توجد ملفات إسكان لمستفيدين مختلفين بالهوية نفسها داخل الإدارة؛ يلزم مراجعة البيانات.',
        1;
END;

IF @MatchedResidentCount = 0
    SET @residentInfoID = NULL;

            SELECT 

            w.ActionID,
            ROW_NUMBER() OVER (
            ORDER BY w.ActionDecisionDate ASC, w.GeneralNo ASC
            ) AS WaitingListOrder,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
             case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24) then Null
            else
            w.LastActionDecisionNo
            END LastActionDecisionNo,
            case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24) then Null
            else
            convert(nvarchar(10),w.[LastActionDecisionDate],23) 
            END LastActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
             case 
            when w.LastActionTypeID is null Then N'0' 
            ELSE
            w.LastActionTypeID
            END LastActionTypeID,


            w.LastActionID,
            case 
            when w.LastActionTypeID in (54,55,56,57,58,59,60,3) Then convert(nvarchar(10),w.LastActionDate,23)
            ELSE
            Null
            END LastActionDate,
           
            case 
            when w.LastActionTypeID in (48,49,50,51,52) Then N'تحت اجراءات الامهال' 
            when w.LastActionTypeID is null Then N'لازال بقائمة الانتظار' 
            ELSE
            ba.buildingActionTypeResidentAlias
            END buildingActionTypeResidentAlias
            ,
            w.buildingDetailsID,
            w.buildingDetailsNo,
            case 
            when w.LastActionTypeID in (2,48,49,50,51,52,24,54,55,56,57,58,59,60,3) then Null
            else
           isnull(w.LastActionNote,w.ActionNote)
            END ActionNote,

             case 
            when w.LastActionTypeID in (2,24) then 1
            else
            0
            END CanExit,
            b.TotalPrice penaltyPrice ,
            b.BillsID,
            b.PenaltyReason,
            

            w.IdaraId,
            (select count(*) from Housing.MeterForBuilding m 
            where m.buildingDetailsID_FK = w.buildingDetailsID 
            and m.IdaraID_FK = w.IdaraId 
            and m.meterForBuildingActive = 1) meterscount,
            convert(nvarchar(10),w.OccupentDate,23) OccupentDate,
            convert(nvarchar(10),w.ExitDate,23) AS ExitDate,

            mgr.PrintManagerCount,
            mgr.PrintManagerName,
            mgr.PrintManagerRank,
            mgr.PrintManagerPosition
           
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        left Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
        left join Housing.Bills b on w.residentInfoID = b.residentInfoID_FK and w.buildingDetailsID = b.buildingDetailsID and b.BillChargeTypeID_FK = 5 and b.BillActive = 1
        OUTER APPLY
        (
            SELECT
                COUNT(*) AS PrintManagerCount,
        
                CASE WHEN COUNT(*) = 1
                     THEN MAX(m.ManagerListName)
                END AS PrintManagerName,
        
                CASE WHEN COUNT(*) = 1
                     THEN MAX(m.ManagerListRank)
                END AS PrintManagerRank,
        
                CASE WHEN COUNT(*) = 1
                     THEN MAX(m.ManagerListPosition)
                END AS PrintManagerPosition
        
            FROM dbo.ManagerList m
            WHERE m.ManagerListActive = 1
              AND m.IdaraID_FK = @idaraID
              AND m.ManagerListTypeID_FK = 1
        ) mgr
    WHERE w.IdaraId = @idaraID
    and (w.buildingActionRoot = 2 or w.buildingActionRoot = 3)
      --AND  (w.LastActionTypeID in (2,24))
           --AND  (w.LastActionTypeID in (2,48,49,50,51,52,24,54,55,56,57,58,59,60) or w.LastActionTypeID is null)

     --AND  (w.LastActionTypeID in (2,48,49,50,51,52,24,54,55,56,57,58,59,60,3) or w.LastActionTypeID is null)
      AND w.residentInfoID = @residentInfoID
      order by w.LastActionEntryDate desc






END