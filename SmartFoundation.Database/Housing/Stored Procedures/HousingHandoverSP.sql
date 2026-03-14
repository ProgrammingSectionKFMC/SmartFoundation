
CREATE PROCEDURE [Housing].[HousingHandoverSP] 
(
      @Action                               NVARCHAR(200)
    , @buildingDetailsID                    NVARCHAR(100)   = NULL
    , @buildingDetailsNo                    NVARCHAR(100)   = NULL
    , @LastActionTypeID                     NVARCHAR(100)   = NULL
    , @NextActionTypeID                     NVARCHAR(1000)  = NULL
    , @LastActionID                         NVARCHAR(100)   = NULL
    , @Notes                                NVARCHAR(1000)  = NULL
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
        , @Note  NVARCHAR(MAX) = NULL
        , @Identity_insert bigint;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK, ''));
    DECLARE @buildingStatusID INT = (select b.buildingStatusID_FK from Housing.BuildingActionType b where b.buildingActionTypeID = @NextActionTypeID);
   
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


         IF @Action IN(N'HousingHandoverAction')
        BEGIN
         
            IF NULLIF(LTRIM(RTRIM(@buildingDetailsID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الرقم المرجعي للمبنى مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@buildingDetailsNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'رقم المبنى مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@LastActionTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الحالة الاخيرة مطلوبة', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@NextActionTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الحالة القادمة مطلوبة', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الملاحظات مطلوبة', 1;
            END

           
        END

        ----------------------------------------------------------------
        -- OPENASSIGNPERIOD
        ----------------------------------------------------------------
        IF @Action = N'HousingHandoverAction'
        BEGIN


          IF EXISTS
            (
                SELECT 1
                FROM  Housing.BuildingAction a
                WHERE a.buildingActionParentID = @LastActionID
                  
            )
            BEGIN
                ;THROW 50001, N'تم تنفيذ هذا الاجراء مسبقا', 1;
            END


            INSERT INTO [Housing].[BuildingAction]
            (
                 [buildingActionTypeID_FK]
                ,[buildingStatusID_FK]
                ,[buildingDetailsID_FK]
                ,[buildingDetailsNo]
                ,[buildingActionDate]
                ,[buildingActionNote]
                ,[buildingActionActive]
                ,[buildingActionParentID]
                ,[IdaraId_FK]
                ,[entryDate]
                ,[entryData]
                ,[hostName]
            )
            VALUES
            (
                  @NextActionTypeID
                , @buildingStatusID
                , @buildingDetailsID
                , @buildingDetailsNo
                , GETDATE()
                , @Notes
                , 1
                , @LastActionID
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اتخاذ الاجراء - BuildingAction', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingActionID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"buildingActionTypeID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NextActionTypeID), '') + N'"'
                + N',"buildingStatusID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingStatusID), '') + N'"'
                + N',"buildingDetailsID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsID), '') + N'"'
                + N',"buildingDetailsNo": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @buildingDetailsNo), '') + N'"'
                + N',"buildingActionDate": "'           + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"buildingActionNote": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @Notes), '') + N'"'
                + N',"buildingActionParentID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @LastActionID), '') + N'"'
                + N',"buildingActionActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"entryDate": "'                + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"hostName": "'                 + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
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
                , N'HousingHandoverAction'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            declare @msg NVARCHAR(1000) = 
            N'تم اتخاذ اجراء للمبنى رقم ' + ISNULL(CONVERT(NVARCHAR(100), @buildingDetailsNo), '') +N' بنجاح ';
            SELECT 1 AS IsSuccessful, @msg AS Message_;
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