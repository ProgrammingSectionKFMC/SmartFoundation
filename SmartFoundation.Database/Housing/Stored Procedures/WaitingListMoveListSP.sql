
CREATE PROCEDURE [Housing].[WaitingListMoveListSP] 
(
      @Action                       NVARCHAR(200)
    , @ActionID                     BIGINT          = NULL
    , @residentInfoID_FK            NVARCHAR(100)   = NULL
    , @NationalID                   NVARCHAR(100)   = NULL
    , @GeneralNo                    NVARCHAR(100)   = NULL
    , @buildingActionDecisionNo     NVARCHAR(1000)  = NULL
    , @buildingActionDecisionDate   NVARCHAR(1000)  = NULL
    , @Notes                        NVARCHAR(1000)  = NULL
    , @idaraID_FK                   NVARCHAR(10)    = NULL
    , @entryData                    NVARCHAR(20)    = NULL
    , @hostName                     NVARCHAR(200)   = NULL
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
    DECLARE @IdaraID_Old INT  
    set @IdaraID_Old =(select top(1) f.IdaraID 
    from Housing.V_GetFullResidentDetails f 
    where f.residentInfoID = @residentInfoID_FK 
    order by f.residentDetailsID desc);


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

            IF NULLIF(LTRIM(RTRIM(@ActionID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات سجل الانتظار - Action ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@residentInfoID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - resident ID', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - GN', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'يوجد خطأ بجلب بيانات المستفيد - @NationalID', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم القرار مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingActionDecisionDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ القرار مطلوب', 1;
            END

        

        ----------------------------------------------------------------
        -- MOVEWAITINGLISTREJECT
        ----------------------------------------------------------------
        IF @Action = N'MOVEWAITINGLISTREJECT'
         BEGIN

        
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.ActionID = @ActionID and w.LastActionID is null and w.ToIdaraID = @idaraID_FK
                  
            )
            BEGIN
                ;THROW 50001, N'تم اتخاذ اجراء للطلب مسبقا', 1;
            END

             INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  34
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , 1
                , @Notes
                , @ActionID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );
            
       

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في رفض الطلب', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في رفض الطلب - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 34), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                , N'REJECTWAITINGLIST'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- MOVEWAITINGLISTAPPROVE
        ----------------------------------------------------------------
        ELSE IF @Action = N'MOVEWAITINGLISTAPPROVE'
       BEGIN

        
            IF @ActionID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                 SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.ActionID = @ActionID
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


             IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.V_MoveWaitingList w
                WHERE w.ActionID = @ActionID and w.LastActionID is null and w.ToIdaraID = @idaraID_FK
                  
            )
            BEGIN
                ;THROW 50001, N'تم اتخاذ اجراء للطلب مسبقا', 1;
            END

            -- IF EXISTS
            --(
            --    SELECT 1
            --    FROM  Housing.V_MoveWaitingList w
            --    WHERE  w.ActionID = @ActionID and w.ActionStatus <> N'تحت الإجراء'
            --)
            --BEGIN
            --    ;THROW 50001, N'تم اتخاذ اجراء لهذا الطلب لايمكن الغائه', 1;
            --END


             INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
            
             VALUES
            (
                  33
                , @residentInfoID_FK
                , @GeneralNo
                , @buildingActionDecisionNo
                , @buildingActionDecisionDate
                , 1
                , @Notes
                , @ActionID
                , @IdaraID_INT
                , @entryData
                , @hostName
            );
            
            SET @NewID = SCOPE_IDENTITY();

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في قبول الطلب', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();

              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionExtraType1
                , buildingActionExtraType2
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
               select 
            w.ActionTypeID,
            w.residentInfoID,
            w.GeneralNo,
            w.ActionDecisionNo,
            w.ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingOrderTypeID,
            1,
            @Notes,
            w.ActionID,
            @idaraID_FK,
            @entryData,
            @hostName
            
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID_FK
            and (w.LastActionTypeID is null 
            or w.LastActionTypeID = 3 
            or w.LastActionTypeID = 36
            or w.LastActionTypeID = 42
            )
            and w.WaitingClassID in (1,2,3,4,11)

             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في قبول الطلب ونقل السجلات 1', 1; -- برمجي
            END

             if(select Count(*) from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID_FK
            AND (w.LastActionTypeID IN (3,36,42) OR w.LastActionTypeID IS NULL)
            and w.WaitingClassID not in (1,2,3,4,11)
            ) > 0

            BEGIN

              INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionDecisionNo
                , buildingActionDecisionDate
                , buildingActionExtraType1
                , buildingActionExtraType2
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
               select 
            36,
            w.residentInfoID,
            w.GeneralNo,
            w.ActionDecisionNo,
            w.ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingOrderTypeID,
            1,
            @Notes,
            w.ActionID,
            w.IdaraId,
            @entryData,
            @hostName
            
            from Housing.V_WaitingList w
            where w.residentInfoID = @residentInfoID_FK
            AND (w.LastActionTypeID IN (3,36,42) OR w.LastActionTypeID IS NULL)
            and w.WaitingClassID not in (1,2,3,4,11)



             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في قبول الطلب ونقل السجلات 2', 1; -- برمجي
            END
            END
            if(select Count(*) FROM Housing.V_WaitingList wl 
            where wl.residentInfoID = @residentInfoID_FK and wl.ActionTypeID = 7 
            ) > 0
            BEGIN
             INSERT INTO  Housing.BuildingAction
            (
                  buildingActionTypeID_FK
                , residentInfoID_FK
                , generalNo_FK
                , buildingActionActive
                , buildingActionNote
                , buildingActionParentID
                , IdaraId_FK
                , entryData
                , hostName
            )
               select 
            37,
            wl.residentInfoID,
            wl.GeneralNo,
            1,
            @Notes,
            wl.ActionID,
            wl.IdaraId,
            @entryData,
            @hostName
            

            FROM Housing.V_WaitingList wl 
            where wl.residentInfoID = @residentInfoID_FK and wl.ActionTypeID = 7 
            



             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في قبول الطلب ونقل السجلات 3', 1; -- برمجي
            END

            END

             declare @rd bigint 
            set @rd =(select top(1) rdd.residentDetailsID 
            from Housing.ResidentDetails rdd 
            where rdd.residentInfoID_FK = @residentInfoID_FK and rdd.residentDetailsActive = 1 order by rdd.residentDetailsID desc)


            update Housing.ResidentDetails set residentDetailsActive = 0 ,residentDetailsEndDate = GETDATE()
            where residentInfoID_FK = @residentInfoID_FK and residentDetailsActive = 1

             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N' حصل خطأ في قبول الطلب ونقل السجلات 4', 1; -- برمجي
            END

           

            Insert Into Housing.ResidentDetails
            (
            
            [residentInfoID_FK]
           ,[generalNo_FK]
           ,[rankID_FK]
           ,[militaryUnitID_FK]
           ,[martialStatusID_FK]
           ,[dependinceCounter]
           ,[nationalityID_FK]
           ,[genderID_FK]
           ,[firstName_A]
           ,[secondName_A]
           ,[thirdName_A]
           ,[lastName_A]
           ,[firstName_E]
           ,[secondName_E]
           ,[thirdName_E]
           ,[lastName_E]
           ,[note]
           ,[birthdate]
           ,[residentDetailsStartDate]
           ,[IdaraId_FK]
           ,[residentDetailsActive]
           ,[entryData]
           ,[hostName]
            )

            SELECT 
                     [residentInfoID_FK]
                    ,[generalNo_FK]
                    ,[rankID_FK]
                    ,[militaryUnitID_FK]
                    ,[martialStatusID_FK]
                    ,[dependinceCounter]
                    ,[nationalityID_FK]
                    ,[genderID_FK]
                    ,[firstName_A]
                    ,[secondName_A]
                    ,[thirdName_A]
                    ,[lastName_A]
                    ,[firstName_E]
                    ,[secondName_E]
                    ,[thirdName_E]
                    ,[lastName_E]
                    ,[note]
                    ,[birthdate]
                    ,GETDATE()
                    ,@idaraID_FK
                    ,1
                    ,@entryData
                    ,@hostName
                    FROM [DATACORE].[Housing].[ResidentDetails] rd 
                    where rd.residentDetailsID = @rd

              IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N' 5 حصل خطأ في قبول الطلب ونقل السجلات', 1; -- برمجي
            END

            update Housing.BuildingAction  
            set buildingActionActive = 0
            where residentInfoID_FK = @residentInfoID_FK
            and IdaraId_FK = @IdaraID_Old

             IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N' 6 حصل خطأ في قبول الطلب ونقل السجلات', 1; -- برمجي
            END
            
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في قبول الطلب ونقل السجلات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 33), '') + N'"'
                + N',"residentInfoID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @residentInfoID_FK), '') + N'"'
                + N',"generalNo_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"buildingActionDecisionNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionNo), '') + N'"'
                + N',"buildingActionDecisionDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @buildingActionDecisionDate), '') + N'"'
                + N',"buildingActionActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"buildingActionNote": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ActionID), '') + N'"'
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
                , N'REJECTWAITINGLIST'
                , @ActionID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم قبول الطلب بنجاح' AS Message_;
            RETURN;
        END

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