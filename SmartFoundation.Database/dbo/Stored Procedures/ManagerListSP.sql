
CREATE PROCEDURE [dbo].[ManagerListSP] 
(
      @Action                   NVARCHAR(200)
    , @ManagerListID            BIGINT          = NULL
    , @ManagerListTypeID_FK     BIGINT          = NULL
    , @ManagerListName          NVARCHAR(2000)  = NULL
    , @ManagerListRank          NVARCHAR(2000)  = NULL
    , @ManagerListPosition      NVARCHAR(2000)  = NULL
    , @ManagerListDescription   NVARCHAR(2000)  = NULL
    , @idaraID_FK               NVARCHAR(10)    = NULL
    , @entryData                NVARCHAR(20)    = NULL
    , @hostName                 NVARCHAR(200)   = NULL
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
        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERTMANAGERLIST'
        BEGIN
        IF NULLIF(LTRIM(RTRIM(@ManagerListTypeID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'النوع مطلوبة', 1;
        END
        
        IF NULLIF(LTRIM(RTRIM(@ManagerListName)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الاسم مطلوبة', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@ManagerListRank)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الرتبة مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@ManagerListPosition)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'المنصب مطلوبة', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@ManagerListDescription)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الملاحظات مطلوبة', 1;
        END

            IF EXISTS
            (
                SELECT 1
                FROM  dbo.ManagerList c
                WHERE c.ManagerListName = @ManagerListName 
                  AND c.ManagerListActive = 1
                  AND (c.IdaraId_FK = @IdaraID_INT OR @IdaraID_INT IS NULL)
            )
            BEGIN
                ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            END


            UPDATE  dbo.ManagerList
            SET ManagerListActive = 0,ManagerListEndDate = DATEADD(day,-1,GETDATE())
            WHERE ManagerListTypeID_FK = @ManagerListTypeID_FK and IdaraID_FK = @IdaraID_INT;
                --  ManagerListTypeID_FK      = ISNULL(@ManagerListTypeID_FK, ManagerListTypeID_FK)
                --, ManagerListName      = ISNULL(@ManagerListName, ManagerListName)
                --, ManagerListRank = ISNULL(@ManagerListRank, ManagerListRank)
                --, ManagerListPosition = ISNULL(@ManagerListPosition, ManagerListPosition)
                --, ManagerListDescription = ISNULL(@ManagerListDescription, ManagerListDescription)
                --, IdaraId_FK               = ISNULL(@IdaraID_INT, IdaraId_FK)
                --, entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                --, hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
           

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم اضافة السجل - disactive old', 1; -- برمجي/غير متوقع
            END


            INSERT INTO  dbo.ManagerList
            (
                  [ManagerListTypeID_FK]
                 ,[ManagerListName]
                 ,[ManagerListRank]
                 ,[ManagerListPosition]
                 ,[ManagerListStartDate]
                 ,[ManagerListEndDate]
                 ,[ManagerListActive]
                 ,[ManagerListDescription]
                 ,[IdaraID_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @ManagerListTypeID_FK
                , @ManagerListName
                , @ManagerListRank
                , @ManagerListPosition
                , GETDATE()
                , NULL
                , 1
                , @ManagerListDescription
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"ManagerListID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"ManagerListTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListTypeID_FK), '') + N'"'
                + N',"ManagerListName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListName), '') + N'"'
                + N',"ManagerListRank": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListRank), '') + N'"'
                + N',"ManagerListPosition": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListPosition), '') + N'"'
                + N',"ManagerListStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"ManagerListDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListDescription), '') + N'"'
                + N',"ManagerListActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
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
                  N'[dbo].[ManagerList]'
                , N'INSERTMANAGERLIST'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATEMANAGERLIST'
        BEGIN
            IF @ManagerListID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  dbo.ManagerList
                WHERE ManagerListID = @ManagerListID
                  AND ManagerListActive = 1
            )
            BEGIN
                ;THROW 50001, N'السجل غير موجود', 1;
            END


            IF NULLIF(LTRIM(RTRIM(@ManagerListTypeID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'النوع مطلوبة', 1;
        END
        
        IF NULLIF(LTRIM(RTRIM(@ManagerListName)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الاسم مطلوبة', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@ManagerListRank)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الرتبة مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@ManagerListPosition)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'المنصب مطلوبة', 1;
        END

        IF NULLIF(LTRIM(RTRIM(@ManagerListDescription)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الملاحظات مطلوبة', 1;
        END


            UPDATE  dbo.ManagerList
            SET ManagerListActive = 0 ,ManagerListEndDate = DATEADD(day,-1,GETDATE())
            WHERE ManagerListID = @ManagerListID ;
                --  ManagerListTypeID_FK      = ISNULL(@ManagerListTypeID_FK, ManagerListTypeID_FK)
                --, ManagerListName      = ISNULL(@ManagerListName, ManagerListName)
                --, ManagerListRank = ISNULL(@ManagerListRank, ManagerListRank)
                --, ManagerListPosition = ISNULL(@ManagerListPosition, ManagerListPosition)
                --, ManagerListDescription = ISNULL(@ManagerListDescription, ManagerListDescription)
                --, IdaraId_FK               = ISNULL(@IdaraID_INT, IdaraId_FK)
                --, entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                --, hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
           

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'لم يتم تحديث أي سجل', 1; -- برمجي/غير متوقع
            END

             INSERT INTO  dbo.ManagerList
            (
                  [ManagerListTypeID_FK]
                 ,[ManagerListName]
                 ,[ManagerListRank]
                 ,[ManagerListPosition]
                 ,[ManagerListStartDate]
                 ,[ManagerListEndDate]
                 ,[ManagerListActive]
                 ,[ManagerListDescription]
                 ,[IdaraID_FK]
                 ,[entryDate]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @ManagerListTypeID_FK
                , @ManagerListName
                , @ManagerListRank
                , @ManagerListPosition
                , GETDATE()
                , NULL
                , 1
                , @ManagerListDescription
                , @IdaraID_INT
                , GETDATE()
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"buildingClassID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"ManagerListTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListTypeID_FK), '') + N'"'
                + N',"ManagerListName": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListName), '') + N'"'
                + N',"ManagerListRank": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListRank), '') + N'"'
                + N',"ManagerListPosition": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListPosition), '') + N'"'
                + N',"ManagerListStartDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE()), '') + N'"'
                + N',"ManagerListDescription": "' + ISNULL(CONVERT(NVARCHAR(MAX), @ManagerListDescription), '') + N'"'
                + N',"ManagerListActive": "1"'
                + N',"IdaraId_FK": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
                + N',"entryData": "'                + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
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
                  N'[dbo].[ManagerList]'
                , N'UPDATEBUILDINGCLASS'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تعديل البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        --ELSE IF @Action = N'DELETEBUILDINGCLASS'
        --BEGIN
        --    IF @buildingClassID IS NULL
        --    BEGIN
        --        ;THROW 50001, N'رقم السجل مطلوب للحذف', 1;
        --    END
        --    IF NOT EXISTS
        --    (
        --        SELECT 1
        --        FROM  Housing.BuildingClass
        --        WHERE BuildingClassID = @buildingClassID
        --          AND buildingClassActive = 1
        --    )
        --    BEGIN
        --        ;THROW 50001, N'السجل غير موجود', 1;
        --    END

        --    UPDATE  Housing.BuildingClass
        --    SET
        --          buildingClassActive = 0
        --        , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
        --        , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
        --    WHERE BuildingClassID = @buildingClassID;

        --    IF @@ROWCOUNT = 0
        --    BEGIN
        --        ;THROW 50002, N'لم يتم حذف أي سجل', 1; -- برمجي/غير متوقع
        --    END
        --    SET @Note = N'{'
        --        + N'"buildingClassID": "' + ISNULL(CONVERT(NVARCHAR(MAX), @buildingClassID), '') + N'"'
        --        + N',"entryData": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
        --        + N',"hostName": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
        --        + N'}';

        --    INSERT INTO  dbo.AuditLog
        --    (
        --          TableName
        --        , ActionType
        --        , RecordID
        --        , PerformedBy
        --        , Notes
        --    )
        --    VALUES
        --    (
        --          N'[Housing].[BuildingClass]'
        --        , N'DELETE'
        --        , @buildingClassID
        --        , @entryData
        --        , @Note
        --    );

        --    SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
        --    RETURN;
        --END

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

GO

