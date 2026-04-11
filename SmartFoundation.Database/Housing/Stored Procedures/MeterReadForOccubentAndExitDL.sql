-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[MeterReadForOccubentAndExitDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	,@residentInfoID   INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	    -- MeterReadForOccubentAndExit Data

          
       SELECT 
            w.ActionID,
            rd.FullName_A as FullName_A,
            w.NationalID,
            w.GeneralNo,
            w.ActionDecisionNo,
            convert(nvarchar(10),w.[ActionDecisionDate],23) ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
            w.LastActionTypeID,
            w.LastActionID,
            ba.buildingActionTypeResidentAlias,
            
           
            w.buildingDetailsID,
            w.buildingDetailsNo,
            mbb.meterNo,
           
            w.IdaraId,
            w.AssignPeriodID
            ,
           
            mbb.meterID,
            mst.meterServiceTypeName_A,
            mst.meterServiceTypeID,
            mty.meterTypeName_A,
            mty.meterMaxRead,
              case 
             when m.BuildingActionID_FK is not null then  convert(nvarchar,mw.BeforeLastReadValue)
             when m.BuildingActionID_FK is null then N''
             END BeforeLastReadValue,
           
            m.meterReadValue,
             case 
             when m.BuildingActionID_FK is not null then  convert(nvarchar,mw.ReadDiff)
             when m.BuildingActionID_FK is null then N''
             END ReadDiff,
            
            case when m.BuildingActionID_FK is not null and mw.BeforeLastReadValue > m.meterReadValue then N'1'
            else
            N'0'
            END ReadSizeStatus,
            case when m.BuildingActionID_FK is not null and mw.BeforeLastReadValue > m.meterReadValue then N'تحقق من القراءة'
            else
            N'لايوجد ملاحظة'
            END ReadSizeStatusText,

            
            mr.meterReadID,
            w.LastActionDate,
            w.buildingActionRoot,

              case 
             when m.BuildingActionID_FK is not null then N'تم تسجيل قراءة العداد'
             when m.BuildingActionID_FK is null then N'بانتظار تسجيل القراءة'
             END ReadStatus,
             case 
            when w.LastActionTypeID = 46 then N'قراءة تسكين'
            when w.LastActionTypeID = 59 then N'قراءة اخلاء'
             END ReadType,
             case 
             when m.BuildingActionID_FK is not null then N'1'
             when m.BuildingActionID_FK is null then N'0'
             END ReadStatusInt,
             isnull(w.LastActionNote,w.ActionNote) ActionNote,
             b.BillsID,
             w.LastActionDecisionDate,
             w.LastActionDecisionNo
             
             
           
            
            
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd ON w.residentInfoID = rd.residentInfoID
    Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    left Join Housing.V_GetListMetersLinkedWithBuildings mbb on w.buildingDetailsID = mbb.buildingDetailsID_FK
    left join Housing.V_GetListAllMetersLastRead mr on mbb.meterID = mr.meterID_FK
    left join [Housing].[V_GetListAllMetersLastAndBeforeLastRead_WithWrap] mw on mbb.meterID = mw.meterID_FK
    left join Housing.MeterRead m on mr.meterReadID = m.meterReadID
    left join Housing.MeterReadType mrt on m.meterReadTypeID_FK = mrt.meterReadTypeID
    left join Housing.MeterServiceType mst on mbb.meterServiceTypeID_FK = mst.meterServiceTypeID
    left join Housing.MeterType mty on mbb.meterTypeID_FK = mty.meterTypeID
    left join Housing.Bills b on m.meterReadID = b.meterReadID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (46,59)
      AND w.residentInfoID = @residentInfoID
      order by   w.waitingClassSequence asc





          
        SELECT 
            rd.FullName_A+' - '+rd.NationalID+' - '+ case 
             when w.LastActionTypeID = 46 then N'قراءة تسكين'
             when w.LastActionTypeID in(59) then N'قراءة اخلاء'
             END as FullName_A,
            w.residentInfoID
          
    FROM Housing.V_WaitingList w 
    INNER JOIN Housing.V_GetFullResidentDetails rd 
        ON w.residentInfoID = rd.residentInfoID
        Inner Join Housing.BuildingActionType ba on w.LastActionTypeID = ba.buildingActionTypeID
    WHERE w.IdaraId = @idaraID
      AND  w.LastActionTypeID in (46,59)
      order by   w.waitingClassSequence asc


      --or w.LastActionTypeID in (2,3,18,19,20,21,22,23,24,26,27,28,33,34,35)




     -- AssignPeriod DDL
            --SELECT c.AssignPeriodID,c.AssignPeriodDescrption
            --FROM [DATACORE].[Housing].[AssignPeriod] c
            --where  c.IdaraId_FK = @idaraID and c.AssignPeriodActive = 1 and c.AssignPeriodClose = 0 and c.AssignPeriodEnddate is not null
            --and c.AssignPeriodFinalEND = 1 and c.AssignPeriodFinalEnddate is null
            --order by c.AssignPeriodID asc

END