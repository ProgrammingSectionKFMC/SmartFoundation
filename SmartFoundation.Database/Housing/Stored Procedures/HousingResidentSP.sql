
CREATE PROCEDURE [Housing].[HousingResidentSP] 
(
      @Action                               NVARCHAR(200)
    , @ActionID                             BIGINT          = NULL
    , @residentInfoID                       NVARCHAR(100)   = NULL
    , @NationalID                           NVARCHAR(100)   = NULL
    , @GeneralNo                            NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo             NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate           NVARCHAR(1000)  = NULL
    , @WaitingClassID                       NVARCHAR(1000)  = NULL
    , @WaitingClassName                     NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeID                   NVARCHAR(1000)  = NULL
    , @WaitingOrderTypeName                 NVARCHAR(1000)  = NULL
    , @waitingClassSequence                 NVARCHAR(1000)  = NULL
    , @WaitingListOrder                     NVARCHAR(1000)  = NULL
    , @FullName_A                           NVARCHAR(1000)  = NULL
    , @buildingDetailsID                    NVARCHAR(1000)  = NULL
    , @AssignPeriodID                       NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(1000)  = NULL
    , @LastActionTypeID                     NVARCHAR(1000)  = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
    , @BuildingActionTypeCases              NVARCHAR(1000)  = NULL
    , @OccupentLetterNo                     NVARCHAR(1000)  = NULL
    , @OccupentLetterDate                   NVARCHAR(1000)  = NULL
    , @OccupentDate                         NVARCHAR(1000)  = NULL
    , @idaraID_FK                           NVARCHAR(10)    = NULL
    , @entryData                            NVARCHAR(20)    = NULL
    , @hostName                             NVARCHAR(200)   = NULL
)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE 
          @NewID BIGINT = NULL
        , @Note  NVARCHAR(MAX) = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));

    DECLARE @buildingDetailsNo nvarchar(200) 
    set @buildingDetailsNo = (select b.buildingDetailsNo from Housing.V_GetGeneralListForBuilding b where b.buildingDetailsID = @buildingDetailsID);

    Declare @HasMeterService int
    set @HasMeterService =(select count(*) 
    from  Housing.MeterForBuilding m 
    where m.buildingDetailsID_FK = @buildingDetailsID 
    and m.meterForBuildingActive = 1 
    and (m.meterForBuildingEndDate is null or cast(m.meterForBuildingEndDate as date) > cast(GETDATE() as date)))

    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END

   


         IF @Action IN(N'CustdyRecord')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يجب كتابة العهد والملاحظات على المنزل', 1;
            END

           
        END

        

     

        ----------------------------------------------------------------
        -- CustdyRecord
        ----------------------------------------------------------------
        IF @Action = N'HOUSINGESRESIDENTSCUSTDY'
        BEGIN
       


            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (46)
            BEGIN
                ;THROW 50001, N'بانتظار قراءة عدادات الخدمات', 1;
            END



            Declare @buildingActionTypeID_FK INT

            select 
            @buildingActionTypeID_FK =
            case 
            when w.LastActionTypeID = 45 and @HasMeterService > 0 then 46
            when w.LastActionTypeID = 45 and @HasMeterService < 1 then 47 
            else 
            9999
            END
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID
            and w.ActionID = @ActionID

            IF 
            (
               @buildingActionTypeID_FK = 9999 
            )
            BEGIN
                ;THROW 50001, N'حصل خطأ ما Has Meter Service', 1;
            END

          

            


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionActive
                , CustdyRecord
                , buildingActionParentID
                , AssignPeriodID_FK
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  @buildingActionTypeID_FK
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );


            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل العهد والملاحظات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسجيل العهد والملاحظات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"CustdyRecord": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"AssignPeriodID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @AssignPeriodID), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'HOUSINGESRESIDENTSCUSTDY'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تسجيل العهد والملاحظات بنجاح' AS Message_;
            RETURN;
        END


      
        ----------------------------------------------------------------
        -- FinalOccupent
        ----------------------------------------------------------------
        ELSE IF @Action = N'HOUSINGESRESIDENTS'
        BEGIN
            -- Serialize occupancy changes with exit creation/edit/cancellation.
            -- Masters_CRUD owns the outer transaction and releases this lock.
            DECLARE @OccupancyLockResult INT;
            DECLARE @OccupancyLockResource NVARCHAR(255) = CONCAT(
                N'Housing.Occupancy:', @IdaraID_INT, N':', TRY_CONVERT(BIGINT, @buildingDetailsID));
            EXEC @OccupancyLockResult = sys.sp_getapplock
                  @Resource = @OccupancyLockResource
                , @LockMode = 'Exclusive'
                , @LockOwner = 'Transaction'
                , @LockTimeout = 10000;
            IF @OccupancyLockResult < 0
                THROW 50001, N'تجري معالجة أخرى للمنزل؛ يرجى إعادة المحاولة.', 1;
       
            IF (SELECT COUNT(*) FROM Housing.V_Occupant e WHERE e.residentInfoID = @residentInfoID) > 0
            
            BEGIN
            declare @msg nvarchar(1000) = N'المستفيد ساكن حاليا او لازال تحت اجراءات الاخلاء بالمنزل رقم : '+(select top(1) e.buildingDetailsNo FROM Housing.V_Occupant e WHERE e.residentInfoID = @residentInfoID)+N' في '+(select top(1) i.idaraLongName_A FROM Housing.V_Occupant e inner join dbo.Idara i on e.LastActionIdaraID =i.idaraID WHERE e.residentInfoID = @residentInfoID)+N' يجب انهاء اجراءات الاخلاء وتحصيل جميع المستحقات قبل اعتماد تسكينه بالمنزل الجديد '
                ;THROW 50001, @msg, 1;
            END

            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END


            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_WaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


              IF 
            (
               select w.LastActionTypeID from Housing.V_WaitingList w where w.ActionID = @ActionID 
            ) in (46)
            BEGIN
                ;THROW 50001, N'بانتظار قراءة عدادات الخدمات', 1;
            END

            DECLARE
                  @OccupentDateValue DATE
                , @LastResidentExitDate DATE
                , @PreviousOccupantID BIGINT
                , @PreviousOccupantName NVARCHAR(300)
                , @PreviousOccupantNationalID NVARCHAR(50)
                , @PreviousOccupantExitDate DATE
                , @AvailableFromDate DATE
                , @PreviousOccupancyMessage NVARCHAR(1000)
                , @CurrentAssignActionID BIGINT
                , @CurrentAssignActionTypeID INT
                , @BuildingStateBeforeAssign INT;

SET @OccupentDateValue =
    TRY_CONVERT(DATE, NULLIF(@OccupentDate, N''));

IF @OccupentDateValue IS NULL
BEGIN
    ;THROW 50001, N'تاريخ التسكين غير صحيح', 1;
END;

------------------------------------------------------------
-- الشرط الأول:
-- تاريخ التسكين يجب أن يكون بعد آخر إخلاء للمستفيد نفسه
-- الحركة 3 = إخلاء نهائي
------------------------------------------------------------
SELECT
    @LastResidentExitDate =
        MAX(
            CONVERT(
                DATE,
                COALESCE(
                      ba.ExitDate
                    , ba.buildingActionDate
                    , ba.entryDate
                )
            )
        )
FROM Housing.BuildingAction ba
WHERE ba.residentInfoID_FK =
      TRY_CONVERT(BIGINT, @residentInfoID)
  AND ba.buildingActionTypeID_FK = 3
  AND ba.buildingActionActive = 1;

IF @LastResidentExitDate IS NOT NULL
   AND @OccupentDateValue <= @LastResidentExitDate
BEGIN
    DECLARE @ResidentExitDateMessage NVARCHAR(1000);

    SET @ResidentExitDateMessage =
        CONCAT(
              N'لا يمكن اعتماد التسكين؛ يجب أن يكون تاريخ التسكين بعد آخر إخلاء للمستفيد بتاريخ '
            , CONVERT(NVARCHAR(10), @LastResidentExitDate, 23)
        );

    ;THROW 50001, @ResidentExitDateMessage, 1;
END;

------------------------------------------------------------
-- الشرط الثاني:
-- يجب أن يكون المنزل شاغراً طوال الفترة من تاريخ التسكين
-- المطلوب وحتى تاريخ الاعتماد. لا يكفي التحقق من حالة المنزل
-- الحالية، لأن التسكين بأثر رجعي قد يتداخل مع ساكن سابق.
------------------------------------------------------------
;WITH PreviousOccupancies AS
(
    SELECT
          occupancy.OccupancyActionID AS buildingActionID
        , occupancy.residentInfoID_FK
        , occupancy.OccupentDate
        , occupancy.ExitDate
    FROM Housing.fn_BuildingOccupancyPeriods(TRY_CONVERT(BIGINT, @buildingDetailsID), @IdaraID_INT) occupancy
    WHERE occupancy.residentInfoID_FK <> TRY_CONVERT(BIGINT, @residentInfoID)
      AND occupancy.OccupentDate <= CASE WHEN @OccupentDateValue > CAST(GETDATE() AS DATE)
                                         THEN @OccupentDateValue ELSE CAST(GETDATE() AS DATE) END
      AND (
            occupancy.ExitDate IS NULL
            OR occupancy.ExitDate >= @OccupentDateValue
          )
)
SELECT TOP (1)
      @PreviousOccupantID = previousOccupancy.residentInfoID_FK
    , @PreviousOccupantName = LTRIM(RTRIM(CONCAT_WS(N' ',
            residentDetails.firstName_A,
            residentDetails.secondName_A,
            residentDetails.thirdName_A,
            residentDetails.lastName_A)))
    , @PreviousOccupantNationalID = residentInfo.NationalID
    , @PreviousOccupantExitDate = previousOccupancy.ExitDate
FROM PreviousOccupancies previousOccupancy
LEFT JOIN Housing.ResidentInfo residentInfo
    ON residentInfo.residentInfoID = previousOccupancy.residentInfoID_FK
OUTER APPLY
(
    SELECT TOP (1)
          rd.firstName_A
        , rd.secondName_A
        , rd.thirdName_A
        , rd.lastName_A
    FROM Housing.ResidentDetails rd
    WHERE rd.residentInfoID_FK = previousOccupancy.residentInfoID_FK
      AND rd.residentDetailsActive = 1
    ORDER BY rd.residentDetailsID DESC
) residentDetails
ORDER BY
      CASE WHEN previousOccupancy.ExitDate IS NULL THEN 0 ELSE 1 END
    , previousOccupancy.ExitDate DESC
    , previousOccupancy.OccupentDate DESC
    , previousOccupancy.buildingActionID DESC
OPTION (MAXRECURSION 32767);

IF @PreviousOccupantID IS NOT NULL
BEGIN
    SET @PreviousOccupantName = COALESCE(
        NULLIF(@PreviousOccupantName, N''),
        CONCAT(N'رقم ', @PreviousOccupantID));

    IF NULLIF(LTRIM(RTRIM(@PreviousOccupantNationalID)), N'') IS NOT NULL
    BEGIN
        SET @PreviousOccupantName = CONCAT(
            @PreviousOccupantName,
            N' (هوية: ',
            @PreviousOccupantNationalID,
            N')');
    END;

    IF @PreviousOccupantExitDate IS NULL
    BEGIN
        SET @PreviousOccupancyMessage = CONCAT(
              N'لا يمكن اعتماد التسكين؛ المنزل مسكون بالمستفيد '
            , @PreviousOccupantName
            , N' ولم يتم تسجيل إخلاء سارٍ له.');

        ;THROW 50001, @PreviousOccupancyMessage, 1;
    END;

    SET @AvailableFromDate = DATEADD(DAY, 1, @PreviousOccupantExitDate);

    SET @PreviousOccupancyMessage = CONCAT(
          N'لا يمكن اعتماد التسكين؛ المنزل مسكون بالمستفيد '
        , @PreviousOccupantName
        , N' حتى تاريخ '
        , CONVERT(NVARCHAR(10), @PreviousOccupantExitDate, 23)
        , N'، ومتاح للتسكين ابتداءً من '
        , CONVERT(NVARCHAR(10), @AvailableFromDate, 23)
        , N'.');

    ;THROW 50001, @PreviousOccupancyMessage, 1;
END;

------------------------------------------------------------
-- الوصول من آخر حركة حالية 47 إلى حركة التخصيص الحالية
--
-- التخصيص الأول  = 38
-- التخصيص الثاني = 40
------------------------------------------------------------
;WITH CurrentActionChain AS
(
    SELECT
          ba.buildingActionID
        , ba.buildingActionTypeID_FK
        , ba.buildingActionParentID
        , ba.buildingDetailsID_FK
        , ba.residentInfoID_FK
        , 0 AS ChainLevel
    FROM Housing.BuildingAction ba
    WHERE ba.buildingActionID =
          TRY_CONVERT(BIGINT, @LastActionID)
      AND ba.residentInfoID_FK =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND ba.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND ba.IdaraId_FK = @IdaraID_INT
      AND ba.buildingActionActive = 1

    UNION ALL

    SELECT
          parentBa.buildingActionID
        , parentBa.buildingActionTypeID_FK
        , parentBa.buildingActionParentID
        , parentBa.buildingDetailsID_FK
        , parentBa.residentInfoID_FK
        , child.ChainLevel + 1
    FROM Housing.BuildingAction parentBa
    INNER JOIN CurrentActionChain child
        ON parentBa.buildingActionID =
           child.buildingActionParentID
    WHERE child.ChainLevel < 10
      AND parentBa.residentInfoID_FK =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND parentBa.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND parentBa.IdaraId_FK = @IdaraID_INT
      AND parentBa.buildingActionActive = 1
)
SELECT TOP (1)
      @CurrentAssignActionID = buildingActionID
    , @CurrentAssignActionTypeID = buildingActionTypeID_FK
FROM CurrentActionChain
WHERE buildingActionTypeID_FK IN (38, 40)
ORDER BY ChainLevel ASC
OPTION (MAXRECURSION 10);

IF @CurrentAssignActionID IS NULL
   OR @CurrentAssignActionTypeID NOT IN (38, 40)
BEGIN
    ;THROW 50001,
        N'تعذر تحديد حركة التخصيص المرتبطة بطلب التسكين',
        1;
END;

------------------------------------------------------------
-- الشرط الثاني:
-- آخر حالة فعلية للمنزل قبل التخصيص الحالي يجب أن تكون حالة جاهزية.
------------------------------------------------------------
SELECT TOP (1)
    @BuildingStateBeforeAssign =
        previousAction.buildingActionTypeID_FK
FROM Housing.BuildingAction previousAction
WHERE previousAction.buildingDetailsID_FK =
      TRY_CONVERT(BIGINT, @buildingDetailsID)
  AND previousAction.buildingActionActive = 1
  AND previousAction.buildingActionID <
      @CurrentAssignActionID

  AND previousAction.buildingActionTypeID_FK IN (5, 39, 41, 42, 43, 44)
ORDER BY previousAction.buildingActionID DESC;

IF @BuildingStateBeforeAssign IS NULL
   OR @BuildingStateBeforeAssign NOT IN (5, 39, 41, 42, 43, 44)
BEGIN
    DECLARE @BuildingStateMessage NVARCHAR(1000);

    SET @BuildingStateMessage =
        CONCAT(
              N'لا يمكن اعتماد التسكين؛ المنزل لم يكن جاهزاً للسكن عند تخصيصه. آخر حالة قبل التخصيص: '
            , ISNULL(
                  CONVERT(
                      NVARCHAR(20),
                      @BuildingStateBeforeAssign
                  ),
                  N'غير موجودة'
              )
        );

    ;THROW 50001, @BuildingStateMessage, 1;
END;

------------------------------------------------------------
-- التأكد من عدم تخصيص أو تسكين المنزل لمستفيد آخر
-- بعد بداية التخصيص الحالي
------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM Housing.BuildingAction conflictingAction
    WHERE conflictingAction.buildingDetailsID_FK =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND conflictingAction.buildingActionActive = 1
      AND conflictingAction.buildingActionID >
          @CurrentAssignActionID
      AND conflictingAction.residentInfoID_FK <>
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND conflictingAction.buildingActionTypeID_FK IN
          (
              2,   -- تسكين نهائي
              38,  -- تخصيص أول
              40,  -- تخصيص ثانٍ
              45,  -- موافقة على المنزل
              46,  -- انتظار قراءة التسكين
              47   -- اكتمال قراءة التسكين
          )
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد التسكين؛ تم تخصيص المنزل أو تسكينه لمستفيد آخر',
        1;
END;

------------------------------------------------------------
-- التأكد من أن الحالة الحالية للطلب هي 47
------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM Housing.V_WaitingList w
    WHERE w.ActionID = @ActionID
      AND w.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND w.buildingDetailsID =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND w.IdaraId = @IdaraID_INT
      AND w.LastActionID =
          TRY_CONVERT(BIGINT, @LastActionID)
      AND w.LastActionTypeID = 47
)
BEGIN
    ;THROW 50001,
        N'لا يمكن اعتماد التسكين؛ لم تكتمل قراءة العدادات أو تغيرت حالة الطلب',
        1;
END;


              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingDetailsID_FK
                , buildingDetailsNo
                , buildingActionExtraText2
                , buildingActionExtraText3
                , buildingActionDate
                , OccupentDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , AssignPeriodID_FK
                , buildingActionExtraType1
                , buildingActionExtraType2
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  2
                , @residentInfoID
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , @buildingDetailsID
                , @buildingDetailsNo
                , @OccupentLetterDate
                , @OccupentLetterNo
                , @OccupentDate
                , @OccupentDate
                , 1
                , @Notes
                , @LastActionID
                , @AssignPeriodID
                , @WaitingClassID
                , @WaitingOrderTypeID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );

            SET @NewID = SCOPE_IDENTITY();
            
            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي', 1; -- برمجي
            END

            
            DECLARE @BillsResidentInfoID BIGINT =
    TRY_CONVERT(BIGINT, @residentInfoID);

DECLARE @BillsGeneralNo BIGINT =
    TRY_CONVERT(BIGINT, @GeneralNo);

DECLARE @BillsBuildingDetailsID BIGINT =
    TRY_CONVERT(BIGINT, @buildingDetailsID);

DECLARE @BillsOccupentDate DATE =
    TRY_CONVERT(DATE, @OccupentDate);

EXEC [Housing].[BackfillResidentServiceBills]
      @ResidentInfoID    = @BillsResidentInfoID
    , @GeneralNo         = @BillsGeneralNo
    , @BuildingDetailsID = @BillsBuildingDetailsID
    , @OccupentDate      = @BillsOccupentDate
    , @IdaraID           = @IdaraID_INT
    , @EntryData         = @entryData
    , @HostName          = @hostName;

            DECLARE @ToDate date = EOMONTH(DATEADD(MONTH, -1, GETDATE()));

            if(@OccupentDate <  @ToDate)
            begin

            /*
               فاتورة الإيجار لا تستحق على المنزل وهو خالٍ. إذا وجدت فاتورة
               قديمة غير مرتبطة بمستفيد وتتداخل مع السكن بأثر رجعي، نلغيها
               قبل إنشاء الفاتورة الصحيحة للمستفيد.
            */
            UPDATE vacantRentBill
               SET vacantRentBill.BillActive = 0,
                   vacantRentBill.CanceledBy = CONCAT(N'RETROACTIVE_OCCUPANCY:', @BillsResidentInfoID),
                   vacantRentBill.entryData = @entryData,
                   vacantRentBill.hostName = @hostName
            FROM Housing.Bills vacantRentBill
            LEFT JOIN Housing.BillPeriod vacantRentPeriod
              ON vacantRentPeriod.billPeriodID = vacantRentBill.CurrentPeriodID
             AND vacantRentPeriod.IdaraId_FK = vacantRentBill.idaraID_FK
            CROSS APPLY
            (
                SELECT
                      COALESCE
                      (
                          CAST(vacantRentBill.BillsFromDate AS date),
                          CAST(vacantRentPeriod.billPeriodStartDate AS date),
                          CASE
                              WHEN vacantRentBill.PeriodYear BETWEEN 1753 AND 9999
                               AND vacantRentBill.PeriodMonth BETWEEN 1 AND 12
                              THEN DATEFROMPARTS(vacantRentBill.PeriodYear, vacantRentBill.PeriodMonth, 1)
                          END
                      ) AS BillFromDate
                    , COALESCE
                      (
                          CAST(vacantRentBill.BillsToDate AS date),
                          CAST(vacantRentPeriod.billPeriodEndDate AS date),
                          CASE
                              WHEN vacantRentBill.PeriodYear BETWEEN 1753 AND 9999
                               AND vacantRentBill.PeriodMonth BETWEEN 1 AND 12
                              THEN EOMONTH(DATEFROMPARTS(vacantRentBill.PeriodYear, vacantRentBill.PeriodMonth, 1))
                          END
                      ) AS BillToDate
            ) vacantRentDate
            WHERE vacantRentBill.buildingDetailsID = @BillsBuildingDetailsID
              AND vacantRentBill.idaraID_FK = @IdaraID_INT
              AND vacantRentBill.BillChargeTypeID_FK = 1
              AND vacantRentBill.BillActive = 1
              AND vacantRentBill.residentInfoID_FK IS NULL
              AND vacantRentDate.BillFromDate <= @ToDate
              AND vacantRentDate.BillToDate >= @BillsOccupentDate;

            -- INSERT INTO [DATACORE].[Housing].[RentBills]
            --(
            --      [residentInfoID_FK]
            --     ,[buildingDetailsID_FK]
            --     ,[buildingRentTypeID_FK]
            --     ,[rentBillsAmount]
            --     ,[rentBillsFromDate]
            --     ,[rentBillsToDate]
            --     ,[rentBillsActive]
            --     ,[idaraID_FK]
            --     ,[entryData]
            --     ,[hostName]
            --)

            
             INSERT INTO [DATACORE].[Housing].[Bills]
            (
                  [residentInfoID_FK]
                 ,[generalNo_FK]
                 ,[buildingDetailsID]
                 ,[BillChargeTypeID_FK]
                 ,[buildingRentTypeID_FK]
                 ,[PeriodMonth]
                 ,[PeriodYear]
                 ,[PRICE]
                 ,[PRICETAX]
                 ,[TotalPrice]
                 ,[BillsFromDate]
                 ,[BillsToDate]
                 ,[BillActive]
                 ,[idaraID_FK]
                 ,[entryData]
                 ,[hostName]
            )
            SELECT 
            @residentInfoID,
            @GeneralNo,
            @buildingDetailsID,
            1,
            1,
            DATEPART(MONTH,r.CalcFromDate),
            DATEPART(YEAR,r.CalcFromDate),
            r.RentForMonth,
            0.00,
            r.RentForMonth,
            r.CalcFromDate,
            r.CalcToDate,
            1,
            @idaraID_FK,
            @entryData,
            @hostName
            FROM Housing.fn_CalcMonthlyBuildingRent_ByBuildingDetailsID(@buildingDetailsID,@OccupentDate, @ToDate) r
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM Housing.Bills existingRentBill WITH (UPDLOCK, HOLDLOCK)
                WHERE existingRentBill.residentInfoID_FK = @BillsResidentInfoID
                  AND existingRentBill.buildingDetailsID = @BillsBuildingDetailsID
                  AND existingRentBill.idaraID_FK = @IdaraID_INT
                  AND existingRentBill.BillChargeTypeID_FK = 1
                  AND existingRentBill.BillActive = 1
                  AND CAST(existingRentBill.BillsFromDate AS date) <= r.CalcToDate
                  AND CAST(existingRentBill.BillsToDate AS date) >= r.CalcFromDate
            )

             IF EXISTS
             (
                 SELECT 1
                 FROM Housing.fn_CalcMonthlyBuildingRent_ByBuildingDetailsID
                      (@buildingDetailsID, @OccupentDate, @ToDate) expectedRent
                 WHERE NOT EXISTS
                 (
                     SELECT 1
                     FROM Housing.Bills savedRentBill
                     WHERE savedRentBill.residentInfoID_FK = @BillsResidentInfoID
                       AND savedRentBill.buildingDetailsID = @BillsBuildingDetailsID
                       AND savedRentBill.idaraID_FK = @IdaraID_INT
                       AND savedRentBill.BillChargeTypeID_FK = 1
                       AND savedRentBill.BillActive = 1
                       AND CAST(savedRentBill.BillsFromDate AS date) <= expectedRent.CalcToDate
                       AND CAST(savedRentBill.BillsToDate AS date) >= expectedRent.CalcFromDate
                 )
             )
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي - RentBills', 1; -- برمجي
            END

            end

            EXEC Housing.GenerateMissingResidentFixedServiceBills
                  @ResidentInfoID = @BillsResidentInfoID
                , @GeneralNo = @BillsGeneralNo
                , @BuildingDetailsID = @BillsBuildingDetailsID
                , @OccupentDate = @BillsOccupentDate
                , @IdaraID = @IdaraID_INT
                , @EntryData = @entryData
                , @HostName = @hostName;

            --SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تسكين المستفيد بشكل نهائي - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionTypeID_FK), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingDetailsID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"CustdyRecord": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"AssignPeriodID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @AssignPeriodID), '') + N'"'
                + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[BuildingAction]'
                , N'HOUSINGESRESIDENTS'
                , @ActionID
                , @entryData
                , @Note
            );
            

            SELECT 1 AS IsSuccessful, N'تم تسكين المستفيد بشكل نهائي بنجاح' AS Message_;
            RETURN;
        END
        ----------------------------------------------------------------
        -- Cancel Housing Resident Before Final Occupancy
        ----------------------------------------------------------------
      ----------------------------------------------------------------
-- CANCELHOUSINGRESIDENT
-- إلغاء إجراءات التسكين قبل التسكين النهائي رقم 2
----------------------------------------------------------------
ELSE IF @Action = N'CANCELHOUSINGRESIDENT'
BEGIN
    DECLARE
          @CancelActionTypeID  INT
        , @CurrentActionTypeID INT
        , @AssignActionTypeID  INT
        , @MeterReadActionID   BIGINT
        , @CancelReason        NVARCHAR(1000);

    SET @CancelReason =
        CONCAT(
              N'CANCELHOUSINGRESIDENT; User=', @entryData
            , N'; Date=', CONVERT(NVARCHAR(19), GETDATE(), 120)
            , N'; Reason=', @Notes
        );

    ------------------------------------------------------------
    -- التحققات الأساسية
    ------------------------------------------------------------
    IF @ActionID IS NULL
    BEGIN
        ;THROW 50001, N'رقم السجل مطلوب', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@residentInfoID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم المستفيد غير صحيح', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@LastActionID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم آخر حركة غير صحيح', 1;
    END;

    IF TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID, N'')) IS NULL
    BEGIN
        ;THROW 50001, N'رقم المنزل غير صحيح', 1;
    END;

    IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
    BEGIN
        ;THROW 50001, N'يجب كتابة سبب إلغاء التسكين', 1;
    END;

    ------------------------------------------------------------
    -- التأكد من وجود سجل الانتظار وتطابق بياناته
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.V_WaitingList w
        WHERE w.ActionID = @ActionID
          AND w.residentInfoID =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND w.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND w.IdaraId = @IdaraID_INT
    )
    BEGIN
        ;THROW 50001, N'السجل غير موجود', 1;
    END;

    ------------------------------------------------------------
    -- قراءة آخر حالة الفعلية من قاعدة البيانات
    ------------------------------------------------------------
    SELECT
        @CurrentActionTypeID = w.LastActionTypeID
    FROM Housing.V_WaitingList w
    WHERE w.ActionID = @ActionID
      AND w.residentInfoID =
          TRY_CONVERT(BIGINT, @residentInfoID)
      AND w.buildingDetailsID =
          TRY_CONVERT(BIGINT, @buildingDetailsID)
      AND w.IdaraId = @IdaraID_INT
      AND w.LastActionID =
          TRY_CONVERT(BIGINT, @LastActionID);

    IF @CurrentActionTypeID IS NULL
    BEGIN
        ;THROW 50001,
            N'تغيرت حالة المستفيد، يرجى تحديث الصفحة والمحاولة مرة أخرى',
            1;
    END;

    ------------------------------------------------------------
    -- يسمح بالإلغاء فقط قبل التسكين النهائي:
    -- 45 = موافقة المستفيد على المنزل
    -- 46 = بانتظار قراءة عدادات التسكين
    -- 47 = تم اعتماد قراءات التسكين
    ------------------------------------------------------------
    IF @CurrentActionTypeID NOT IN (45, 46, 47)
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ تم تسكين المستفيد نهائياً أو تغيرت حالته',
            1;
    END;

    ------------------------------------------------------------
    -- قفل آخر حركة وإعادة التحقق وقت التنفيذ
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM Housing.BuildingAction ba WITH (UPDLOCK, HOLDLOCK)
        WHERE ba.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND ba.buildingActionTypeID_FK IN (45, 46, 47)
          AND ba.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND ba.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND ba.IdaraId_FK = @IdaraID_INT
          AND ba.buildingActionActive = 1
    )
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ حالة المستفيد تغيرت',
            1;
    END;

    ------------------------------------------------------------
    -- لا يسمح بالإلغاء إذا أصبح المستفيد ساكناً فعلياً
    ------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM Housing.V_Occupant o
        WHERE o.residentInfoID =
              TRY_CONVERT(BIGINT, @residentInfoID)
    )
    BEGIN
        ;THROW 50001,
            N'لا يمكن إلغاء التسكين؛ تم تسكين المستفيد بشكل نهائي',
            1;
    END;

    ------------------------------------------------------------
    -- تتبع سلسلة الحركات:
    --
    -- التخصيص الأول:
    -- 38 -> 45 -> 46 -> 47
    --
    -- التخصيص الثاني:
    -- 40 -> 45 -> 46 -> 47
    ------------------------------------------------------------
    ;WITH ActionChain AS
    (
        SELECT
              ba.buildingActionID
            , ba.buildingActionTypeID_FK
            , ba.buildingActionParentID
            , 0 AS ChainLevel
        FROM Housing.BuildingAction ba
        WHERE ba.buildingActionID =
              TRY_CONVERT(BIGINT, @LastActionID)
          AND ba.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND ba.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND ba.IdaraId_FK = @IdaraID_INT
          AND ba.buildingActionActive = 1

        UNION ALL

        SELECT
              parentBa.buildingActionID
            , parentBa.buildingActionTypeID_FK
            , parentBa.buildingActionParentID
            , child.ChainLevel + 1
        FROM Housing.BuildingAction parentBa
        INNER JOIN ActionChain child
            ON parentBa.buildingActionID =
               child.buildingActionParentID
        WHERE child.ChainLevel < 10
          AND parentBa.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND parentBa.buildingDetailsID_FK =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND parentBa.IdaraId_FK = @IdaraID_INT
          AND parentBa.buildingActionActive = 1
    )
    SELECT
          @AssignActionTypeID =
              MAX(
                  CASE
                      WHEN buildingActionTypeID_FK IN (38, 40)
                      THEN buildingActionTypeID_FK
                  END
              )
        , @MeterReadActionID =
              MAX(
                  CASE
                      WHEN buildingActionTypeID_FK = 46
                      THEN buildingActionID
                  END
              )
    FROM ActionChain
    OPTION (MAXRECURSION 10);

    ------------------------------------------------------------
    -- تحديد نتيجة الإلغاء
    --
    -- 38 = التخصيص الأول  -> 39 رفض التخصيص الأول
    -- 40 = التخصيص الثاني -> 42 إلغاء أهلية السكن
    ------------------------------------------------------------
    SET @CancelActionTypeID =
        CASE @AssignActionTypeID
            WHEN 38 THEN 39
            WHEN 40 THEN 42
            ELSE 0
        END;

    IF ISNULL(@CancelActionTypeID, 0) = 0
    BEGIN
        ;THROW 50001,
            N'تعذر تحديد ما إذا كان التخصيص الأول أو الثاني',
            1;
    END;

    ------------------------------------------------------------
    -- إذا كانت الحالة 46 أو 47:
    -- إلغاء قراءات وفواتير التسكين المرتبطة بالعملية
    ------------------------------------------------------------
    IF @CurrentActionTypeID IN (46, 47)
    BEGIN
        IF @MeterReadActionID IS NULL
        BEGIN
            ;THROW 50001,
                N'تعذر تحديد حركة طلب قراءة عدادات التسكين',
                1;
        END;

        --------------------------------------------------------
        -- منع الإلغاء الآلي إذا كانت إحدى فواتير التسكين
        -- قد دخلت في مسير خصم أو تم تحصيلها
        --------------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM Housing.Bills b
            INNER JOIN Housing.MeterRead mr
                ON mr.meterReadID = b.meterReadID
            INNER JOIN Housing.BillsDeductListDetails d
                ON d.billsID_FK = b.BillsID
            WHERE mr.buildingActionID_FK =
                  @MeterReadActionID
              AND mr.residentInfoID_FK =
                  TRY_CONVERT(BIGINT, @residentInfoID)
              AND mr.buildingDetailsID =
                  TRY_CONVERT(BIGINT, @buildingDetailsID)
              AND mr.IdaraID_FK = @IdaraID_INT
              AND mr.meterReadTypeID_FK = 1
              AND b.BillTypeID_FK = 1
              AND b.BillActive = 1
              AND d.billActive = 1
              AND
              (
                    ISNULL(d.billPaid, 0) = 1
                 OR ISNULL(d.paidAmount, 0) > 0
                 OR d.billDeductListID_FK IS NOT NULL
              )
        )
        BEGIN
            ;THROW 50001,
                N'لا يمكن إلغاء التسكين آلياً؛ توجد فاتورة تسكين مدرجة في خصم أو تحصيل مالي',
                1;
        END;

        --------------------------------------------------------
        -- تعطيل فواتير التسكين المرتبطة بالقراءات فقط
        --
        -- BillTypeID_FK = 1:
        -- فاتورة قراءة تسكين
        --------------------------------------------------------
        UPDATE b
        SET
              b.BillActive = 0
            , b.CanceledBy = @CancelReason
        FROM Housing.Bills b
        INNER JOIN Housing.MeterRead mr
            ON mr.meterReadID = b.meterReadID
        WHERE mr.buildingActionID_FK =
              @MeterReadActionID
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND b.BillTypeID_FK = 1
          AND b.BillActive = 1;

        --------------------------------------------------------
        -- تعطيل قراءات التسكين
        --
        -- لا نشترط وجود قراءة، فقد يكون الطلب لا يزال
        -- بانتظار قيام القارئ بتسجيل القراءة
        --------------------------------------------------------
        UPDATE mr
        SET
              mr.meterReadActive = 0
            , mr.CanceledBy = @CancelReason
        FROM Housing.MeterRead mr
        WHERE mr.buildingActionID_FK =
              @MeterReadActionID
          AND mr.residentInfoID_FK =
              TRY_CONVERT(BIGINT, @residentInfoID)
          AND mr.buildingDetailsID =
              TRY_CONVERT(BIGINT, @buildingDetailsID)
          AND mr.IdaraID_FK = @IdaraID_INT
          AND mr.meterReadTypeID_FK = 1
          AND mr.meterReadActive = 1;
    END;

    ------------------------------------------------------------
    -- تسجيل حركة إلغاء التسكين
    ------------------------------------------------------------
    INSERT INTO Housing.BuildingAction
    (
          buildingActionTypeID_FK
        , residentInfoID_FK
        , generalNo_FK
        , buildingActionDecisionNo
        , buildingActionDecisionDate
        , buildingDetailsID_FK
        , buildingDetailsNo
        , buildingActionActive
        , buildingActionNote
        , buildingActionParentID
        , AssignPeriodID_FK
        , InAssignPeriod
        , IdaraId_FK
        , entryData
        , hostName
    )
    VALUES
    (
          @CancelActionTypeID
        , @residentInfoID
        , @GeneralNo
        , @buildingActionDecisionNo
        , @buildingActionDecisionDate
        , @buildingDetailsID
        , @buildingDetailsNo
        , 1
        , @Notes
        , @LastActionID
        , @AssignPeriodID
        , 0
        , @IdaraID_INT
        , @entryData
        , @hostName
    );

    IF @@ROWCOUNT = 0
    BEGIN
        ;THROW 50002,
            N'حصل خطأ في إلغاء التسكين',
            1;
    END;

    SET @NewID = SCOPE_IDENTITY();

    IF @NewID IS NULL OR @NewID <= 0
    BEGIN
        ;THROW 50002,
            N'حصل خطأ في إلغاء التسكين - Identity',
            1;
    END;

    ------------------------------------------------------------
    -- إعداد بيانات سجل التدقيق
    ------------------------------------------------------------
    SET @Note =
          N'{'
        + N'"buildingActionID":"'
        + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'')
        + N'"'

        + N',"buildingActionTypeID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @CancelActionTypeID),
              N''
          )
        + N'"'

        + N',"PreviousActionTypeID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @CurrentActionTypeID),
              N''
          )
        + N'"'

        + N',"AllocationActionTypeID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @AssignActionTypeID),
              N''
          )
        + N'"'

        + N',"MeterReadActionID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @MeterReadActionID),
              N''
          )
        + N'"'

        + N',"residentInfoID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @residentInfoID),
              N''
          )
        + N'"'

        + N',"generalNo_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @GeneralNo),
              N''
          )
        + N'"'

        + N',"buildingDetailsID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @buildingDetailsID),
              N''
          )
        + N'"'

        + N',"buildingDetailsNo":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @buildingDetailsNo),
              N''
          )
        + N'"'

        + N',"buildingActionParentID":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @LastActionID),
              N''
          )
        + N'"'

        + N',"AssignPeriodID_FK":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @AssignPeriodID),
              N''
          )
        + N'"'

        + N',"Notes":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @Notes),
              N''
          )
        + N'"'

        + N',"entryData":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @entryData),
              N''
          )
        + N'"'

        + N',"hostName":"'
        + ISNULL(
              CONVERT(NVARCHAR(MAX), @hostName),
              N''
          )
        + N'"}';

    ------------------------------------------------------------
    -- تسجيل العملية في AuditLog
    ------------------------------------------------------------
    INSERT INTO dbo.AuditLog
    (
          TableName
        , ActionType
        , RecordID
        , PerformedBy
        , Notes
    )
    VALUES
    (
          N'[Housing].[BuildingAction]'
        , N'CANCELHOUSINGRESIDENT'
        , @NewID
        , @entryData
        , @Note
    );

    ------------------------------------------------------------
    -- النتيجة حسب رقم فرصة التخصيص
    ------------------------------------------------------------
    IF @CancelActionTypeID = 39
    BEGIN
        SELECT
              1 AS IsSuccessful
            , N'تم إلغاء التسكين واحتسابه رفضاً للتخصيص للمرة الأولى'
              AS Message_;
    END;
    ELSE
    BEGIN
        SELECT
              1 AS IsSuccessful
            , N'تم إلغاء التسكين وإلغاء أحقية المستفيد في السكن نهائياً'
              AS Message_;
    END;

    RETURN;
END;

        
       

                  
        
       

        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END
