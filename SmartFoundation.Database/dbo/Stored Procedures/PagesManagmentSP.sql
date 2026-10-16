
CREATE PROCEDURE [dbo].[PagesManagmentSP] 
(
      @Action                                NVARCHAR(200)
    , @programID                               NVARCHAR(200)   = NULL
    , @programName_A                            NVARCHAR(200)   = NULL
    , @programName_E                             NVARCHAR(200)   = NULL
    , @programDescription                           NVARCHAR(200)   = NULL
    , @programActive                          NVARCHAR(200)   = NULL
    , @programLink                           NVARCHAR(200)   = NULL
    , @programIcon                           NVARCHAR(200)   = NULL
    , @programSerial                            NVARCHAR(200)   = NULL
    , @menuID                                NVARCHAR(200)   = NULL
    , @parentMenuID                          NVARCHAR(200)   = NULL
    , @isDashboard                           NVARCHAR(200)   = NULL
    , @PageLvl                               NVARCHAR(200)   = NULL
    , @permissionTypeID                      NVARCHAR(200)   = NULL
    , @permissionTypeName_A                  NVARCHAR(500)   = NULL
    , @permissionTypeName_E                  NVARCHAR(500)   = NULL
    , @permissionAuthLvl                     NVARCHAR(200)   = NULL
    , @distributorPermissionTypeID           NVARCHAR(200)   = NULL


    , @firstName_E                           NVARCHAR(200)   = NULL
    , @secondName_E                          NVARCHAR(200)   = NULL
    , @thirdName_E                           NVARCHAR(200)   = NULL
    , @forthName_E                           NVARCHAR(200)   = NULL
    , @lastName_E                            NVARCHAR(200)   = NULL
    , @UsersAuthTypeID                       NVARCHAR(200)   = NULL
    , @ActiveStatus                          NVARCHAR(200)   = NULL
    , @userTypeID_FK                         NVARCHAR(200)   = NULL
    , @IdaraID                               NVARCHAR(200)   = NULL
    , @nationalIDIssueDate                   NVARCHAR(200)   = NULL
    , @dateOfBirth                           NVARCHAR(200)   = NULL
    , @genderID_FK                           NVARCHAR(200)   = NULL
    , @nationalityID_FK                      NVARCHAR(200)   = NULL
    , @religionID_FK                         NVARCHAR(200)   = NULL
    , @maritalStatusID_FK                    NVARCHAR(200)   = NULL
    , @educationID_FK                        NVARCHAR(100)   = NULL
    , @userNote                              NVARCHAR(1000)  = NULL
    , @distributorID                         NVARCHAR(1000)  = NULL


    , @idaraID_FK                            NVARCHAR(10)    = NULL
    , @entryData                             NVARCHAR(20)    = NULL
    , @hostName                              NVARCHAR(200)   = NULL
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
    DECLARE @isAdmin INT = (select top(1) isnull(d.UsersAuthTypeID,3) from dbo.V_GetFullSystemUsersDetails d where d.usersID = @entryData and d.userActive = 1)
   


    DECLARE @nationalIDIssueDate_DT date,
        @dateOfBirth_DT date;

-- حاول التحويل (أفضل شيء توقع ISO: 2026-02-13)
SET @nationalIDIssueDate_DT = TRY_CONVERT(date, @nationalIDIssueDate, 23);
SET @dateOfBirth_DT         = TRY_CONVERT(date, @dateOfBirth, 23);




    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            THROW 50001, N'العملية مطلوبة', 1;
        END


         IF (@isAdmin <> 1)
        BEGIN
            THROW 50001, N'تم رصد دخول غير مصرح به انت لاتملك صلاحية للوصول الى هذه الصفحة', 1;
        END
        ----------------------------------------------------------------
        -- AddPorgram
        ----------------------------------------------------------------

        IF @Action = N'AddProgram'

            BEGIN
                IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programDescription)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programLink)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programIcon)), N'') IS NULL
                BEGIN
                    THROW 50001, N'الرجاء اكمال جميع الحقول المطلوبة', 1;
                END
            
                DECLARE @programActiveBit INT = 1;
            
            
                        IF EXISTS (
                    SELECT 1
                    FROM dbo.Program p
                    WHERE p.programName_A = LTRIM(RTRIM(@programName_A))
                      AND p.programActive = 1
                )
                 BEGIN
                    THROW 50001, N'الاسم العربي مستخدم مسبقاً', 1;
                 END
            
                IF EXISTS (
                    SELECT 1
                    FROM dbo.Program p
                    WHERE p.programName_E = LTRIM(RTRIM(@programName_E))
                      AND p.programActive = 1
                )
                 BEGIN
                    THROW 50001, N'الاسم الإنجليزي مستخدم مسبقاً', 1;
                 END
            
            Declare @ProgOrder int
            set @ProgOrder = ISNULL((select Top(1) programSerial + 1 from dbo.Program p order by p.programSerial desc ), 1)


            INSERT INTO  dbo.Program
            (
                [programName_A]
               ,[programName_E]
               ,[programDescription]
               ,[programActive]
               ,[programLink]
               ,[programIcon]
               ,[programSerial]
               ,[entryDate]
               ,[entryData]
               ,[hostName]
            )
            VALUES
            (
               @programName_A
              ,@programName_E      
              ,@programDescription 
              ,@programActiveBit
              ,@programLink        
              ,@programIcon        
              ,@ProgOrder      
              , GETDATE()
              ,@entryData
              ,@hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50002, N'حصل خطأ في اضافة البرنامج', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();

            
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                THROW 50002, N'حصل خطأ في اضافة البرنامج - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"usersID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"programName_A": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programName_A), '') + N'"'
                + N',"programName_E": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programName_E), '') + N'"'
                + N',"programDescription": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programDescription), '') + N'"'
                + N',"programActive": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programActiveBit), '') + N'"'
                + N',"programLink": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programLink), '') + N'"'
                + N',"programIcon": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programIcon), '') + N'"'
                + N',"programSerial": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @programSerial), '') + N'"'
                + N',"entryDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
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
                  N'[dbo].[Program]'
                , N'AddProgram'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );


            SELECT 1 AS IsSuccessful, N'تم اضافة البرنامج بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- EditProgram
        ----------------------------------------------------------------
            ELSE IF @Action = N'EditProgram'
                BEGIN
                    DECLARE @programID_Int INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programID)), N''));
                    IF @programID_Int IS NULL OR @programID_Int <= 0
                    BEGIN
                        THROW 50001, N'رقم البرنامج غير صحيح', 1;
                        END
                
                    -- تأكد موجود
                    IF NOT EXISTS (SELECT 1 FROM dbo.Program WHERE programID = @programID_Int)
                    BEGIN
                        THROW 50001, N'البرنامج غير موجود', 1;
                        END
                
                    -- لو أرسل Active تحقق أنه رقم (اختياري: 0/1 فقط)
                    IF NULLIF(LTRIM(RTRIM(@programActive)), N'') IS NOT NULL
                    BEGIN
                        DECLARE @programActive_Int INT = TRY_CONVERT(INT, @programActive);
                        IF @programActive_Int IS NULL OR @programActive_Int NOT IN (0,1)
                        BEGIN
                            THROW 50001, N'حالة البرنامج غير صحيحة (0 أو 1)', 1;
                        END
                    END
                
                    -- لو أرسل Serial تحقق أنه رقم > 0
                    IF NULLIF(LTRIM(RTRIM(@programSerial)), N'') IS NOT NULL
                    BEGIN
                        DECLARE @programSerial_Int INT = TRY_CONVERT(INT, @programSerial);
                        IF @programSerial_Int IS NULL OR @programSerial_Int <= 0
                        BEGIN
                            THROW 50001, N'الترقيم غير صحيح', 1;
                            END
                    END
                
                    -- (اختياري) فحص تكرار الاسم العربي/الانجليزي إذا تم تغييره
                    IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NOT NULL
                    BEGIN
                        IF EXISTS (
                            SELECT 1
                            FROM dbo.Program p
                            WHERE p.programID <> @programID_Int
                              AND p.programActive = 1
                              AND p.programName_A = LTRIM(RTRIM(@programName_A))
                        )
                        BEGIN
                            THROW 50001, N'الاسم العربي مستخدم مسبقاً', 1;
                            END
                    END
                
                    IF NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NOT NULL
                    BEGIN
                        IF EXISTS (
                            SELECT 1
                            FROM dbo.Program p
                            WHERE p.programID <> @programID_Int
                              AND p.programActive = 1
                              AND p.programName_E = LTRIM(RTRIM(@programName_E))
                        )
                        BEGIN
                            THROW 50001, N'الاسم الإنجليزي مستخدم مسبقاً', 1;
                            END
                    END
                
                    -- احفظ القديم للـ Audit
                    DECLARE
                        @Old_programName_A NVARCHAR(200),
                        @Old_programName_E NVARCHAR(200),
                        @Old_programDescription NVARCHAR(200),
                        @Old_programActive NVARCHAR(200),
                        @Old_programLink NVARCHAR(200),
                        @Old_programIcon NVARCHAR(200),
                        @Old_programSerial NVARCHAR(200);
                
                    SELECT
                        @Old_programName_A = programName_A,
                        @Old_programName_E = programName_E,
                        @Old_programDescription = programDescription,
                        @Old_programActive = CONVERT(NVARCHAR(200), programActive),
                        @Old_programLink = programLink,
                        @Old_programIcon = programIcon,
                        @Old_programSerial = CONVERT(NVARCHAR(200), programSerial)
                    FROM dbo.Program
                    WHERE programID = @programID_Int;
                
                    UPDATE dbo.Program
                    SET
                        programName_A      = COALESCE(NULLIF(LTRIM(RTRIM(@programName_A)), N''), programName_A),
                        programName_E      = COALESCE(NULLIF(LTRIM(RTRIM(@programName_E)), N''), programName_E),
                        programDescription = COALESCE(NULLIF(LTRIM(RTRIM(@programDescription)), N''), programDescription),
                        programActive      = COALESCE(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programActive)), N'')), programActive),
                        programLink        = COALESCE(NULLIF(LTRIM(RTRIM(@programLink)), N''), programLink),
                        programIcon        = COALESCE(NULLIF(LTRIM(RTRIM(@programIcon)), N''), programIcon),
                        programSerial      = COALESCE(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programSerial)), N'')), programSerial),
                        entryDate          = GETDATE(),
                        entryData          = @entryData,
                        hostName           = @hostName
                    WHERE programID = @programID_Int;
                
                    IF @@ROWCOUNT = 0
                    BEGIN
                        THROW 50002, N'لم يتم تعديل البرنامج', 1;
                        END
                
                    -- Audit Notes (قبل/بعد)
                    SET @Note = N'{'
                        + N'"programID": "' + CONVERT(NVARCHAR(MAX), @programID_Int) + N'"'
                        + N',"OLD": {'
                            + N'"programName_A": "' + ISNULL(@Old_programName_A, N'') + N'"'
                            + N',"programName_E": "' + ISNULL(@Old_programName_E, N'') + N'"'
                            + N',"programDescription": "' + ISNULL(@Old_programDescription, N'') + N'"'
                            + N',"programActive": "' + ISNULL(@Old_programActive, N'') + N'"'
                            + N',"programLink": "' + ISNULL(@Old_programLink, N'') + N'"'
                            + N',"programIcon": "' + ISNULL(@Old_programIcon, N'') + N'"'
                            + N',"programSerial": "' + ISNULL(@Old_programSerial, N'') + N'"'
                        + N'}'
                        + N',"NEW": {'
                            + N'"programName_A": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programName_A)), N''), @Old_programName_A) + N'"'
                            + N',"programName_E": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programName_E)), N''), @Old_programName_E) + N'"'
                            + N',"programDescription": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programDescription)), N''), @Old_programDescription) + N'"'
                            + N',"programActive": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programActive)), N''), @Old_programActive) + N'"'
                            + N',"programLink": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programLink)), N''), @Old_programLink) + N'"'
                            + N',"programIcon": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programIcon)), N''), @Old_programIcon) + N'"'
                            + N',"programSerial": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programSerial)), N''), @Old_programSerial) + N'"'
                        + N'}'
                        + N',"entryDate": "' + CONVERT(NVARCHAR(MAX), GETDATE(), 23) + N'"'
                        + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                        + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), N'') + N'"'
                        + N'}';
                
                    INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                    VALUES (N'[dbo].[Program]', N'EditProgram', @programID_Int, @entryData, @Note);
                
                    SELECT 1 AS IsSuccessful, N'تم تعديل البرنامج بنجاح' AS Message_;
                    RETURN;
                END


                 ----------------------------------------------------------------
        -- DeleteProgram
        ----------------------------------------------------------------
            ELSE IF @Action = N'DeleteProgram'
                BEGIN
                    DECLARE @programID_Int1 INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programID)), N''));
                    IF @programID_Int1 IS NULL OR @programID_Int1 <= 0
                    BEGIN
                        THROW 50001, N'رقم البرنامج غير صحيح', 1;
                        END
                
                    -- تأكد موجود
                    IF NOT EXISTS (SELECT 1 FROM dbo.Program WHERE programID = @programID_Int1)
                    BEGIN
                        THROW 50001, N'البرنامج غير موجود', 1;
                        END
                
                    -- لو أرسل Active تحقق أنه رقم (اختياري: 0/1 فقط)
                    IF NULLIF(LTRIM(RTRIM(@programActive)), N'') IS NOT NULL
                    BEGIN
                        DECLARE @programActive_Int1 INT = TRY_CONVERT(INT, @programActive);
                        IF @programActive_Int1 IS NULL OR @programActive_Int1 NOT IN (0,1)
                        BEGIN
                            THROW 50001, N'حالة البرنامج غير صحيحة (0 أو 1)', 1;
                        END
                    END
                
                    -- لو أرسل Serial تحقق أنه رقم > 0
                    IF NULLIF(LTRIM(RTRIM(@programSerial)), N'') IS NOT NULL
                    BEGIN
                        DECLARE @programSerial_Int1 INT = TRY_CONVERT(INT, @programSerial);
                        IF @programSerial_Int1 IS NULL OR @programSerial_Int1 <= 0
                        BEGIN
                            THROW 50001, N'الترقيم غير صحيح', 1;
                            END
                    END
                
                    -- (اختياري) فحص تكرار الاسم العربي/الانجليزي إذا تم تغييره
                    IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NOT NULL
                    BEGIN
                        IF EXISTS (
                            SELECT 1
                            FROM dbo.Program p
                            WHERE p.programID <> @programID_Int
                              AND p.programActive = 1
                              AND p.programName_A = LTRIM(RTRIM(@programName_A))
                        )
                        BEGIN
                            THROW 50001, N'الاسم العربي مستخدم مسبقاً', 1;
                            END
                    END
                
                    IF NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NOT NULL
                    BEGIN
                        IF EXISTS (
                            SELECT 1
                            FROM dbo.Program p
                            WHERE p.programID <> @programID_Int
                              AND p.programActive = 1
                              AND p.programName_E = LTRIM(RTRIM(@programName_E))
                        )
                        BEGIN
                            THROW 50001, N'الاسم الإنجليزي مستخدم مسبقاً', 1;
                            END
                    END
                
                    -- احفظ القديم للـ Audit
                    DECLARE
                        @Old_programName_A1 NVARCHAR(200),
                        @Old_programName_E1 NVARCHAR(200),
                        @Old_programDescription1 NVARCHAR(200),
                        @Old_programActive1 NVARCHAR(200),
                        @Old_programLink1 NVARCHAR(200),
                        @Old_programIcon1 NVARCHAR(200),
                        @Old_programSerial1 NVARCHAR(200);
                
                    SELECT
                        @Old_programName_A1 = programName_A,
                        @Old_programName_E1 = programName_E,
                        @Old_programDescription1 = programDescription,
                        @Old_programActive1 = CONVERT(NVARCHAR(200), programActive),
                        @Old_programLink1 = programLink,
                        @Old_programIcon1 = programIcon,
                        @Old_programSerial1 = CONVERT(NVARCHAR(200), programSerial)
                    FROM dbo.Program
                    WHERE programID = @programID_Int1;
                
                    UPDATE dbo.Program
                    SET
                        programName_A      = COALESCE(NULLIF(LTRIM(RTRIM(@programName_A)), N''), programName_A),
                        programName_E      = COALESCE(NULLIF(LTRIM(RTRIM(@programName_E)), N''), programName_E),
                        programDescription = COALESCE(NULLIF(LTRIM(RTRIM(@programDescription)), N''), programDescription),
                        programActive      = COALESCE(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programActive)), N'')), programActive),
                        programLink        = COALESCE(NULLIF(LTRIM(RTRIM(@programLink)), N''), programLink),
                        programIcon        = COALESCE(NULLIF(LTRIM(RTRIM(@programIcon)), N''), programIcon),
                        programSerial      = COALESCE(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programSerial)), N'')), programSerial),
                        entryDate          = GETDATE(),
                        entryData          = @entryData,
                        hostName           = @hostName
                    WHERE programID = @programID_Int1;
                
                    IF @@ROWCOUNT = 0
                    BEGIN
                        THROW 50002, N'لم يتم تعديل حالة البرنامج', 1;
                        END
                
                    -- Audit Notes (قبل/بعد)
                    SET @Note = N'{'
                        + N'"programID": "' + CONVERT(NVARCHAR(MAX), @programID_Int1) + N'"'
                        + N',"OLD": {'
                            + N'"programName_A": "' + ISNULL(@Old_programName_A, N'') + N'"'
                            + N',"programName_E": "' + ISNULL(@Old_programName_E, N'') + N'"'
                            + N',"programDescription": "' + ISNULL(@Old_programDescription, N'') + N'"'
                            + N',"programActive": "' + ISNULL(@Old_programActive, N'') + N'"'
                            + N',"programLink": "' + ISNULL(@Old_programLink, N'') + N'"'
                            + N',"programIcon": "' + ISNULL(@Old_programIcon, N'') + N'"'
                            + N',"programSerial": "' + ISNULL(@Old_programSerial, N'') + N'"'
                        + N'}'
                        + N',"NEW": {'
                            + N'"programName_A": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programName_A)), N''), @Old_programName_A1) + N'"'
                            + N',"programName_E": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programName_E)), N''), @Old_programName_E1) + N'"'
                            + N',"programDescription": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programDescription)), N''), @Old_programDescription1) + N'"'
                            + N',"programActive": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programActive)), N''), @Old_programActive1) + N'"'
                            + N',"programLink": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programLink)), N''), @Old_programLink1) + N'"'
                            + N',"programIcon": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programIcon)), N''), @Old_programIcon1) + N'"'
                            + N',"programSerial": "' + ISNULL(NULLIF(LTRIM(RTRIM(@programSerial)), N''), @Old_programSerial1) + N'"'
                        + N'}'
                        + N',"entryDate": "' + CONVERT(NVARCHAR(MAX), GETDATE(), 23) + N'"'
                        + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                        + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), N'') + N'"'
                        + N'}';
                
                    INSERT INTO  dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                    VALUES (N'[dbo].[Program]', N'DeleteProgram', @programID_Int1, @entryData, @Note);
                
                    SELECT 1 AS IsSuccessful, N'تم تعديل حالة البرنامج بنجاح' AS Message_;
                    RETURN;
                END



        ----------------------------------------------------------------
        -- AddPorgram
        ----------------------------------------------------------------

        IF @Action = N'AddMenuList'

            BEGIN
                IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NULL
                   OR NULLIF(LTRIM(RTRIM(@programDescription)), N'') IS NULL

                BEGIN
                    THROW 50001, N'الرجاء اكمال جميع الحقول المطلوبة', 1;
                END
            
               
            
            
                DECLARE @programSerialInt12 INT = TRY_CONVERT(INT, @programSerial);
                IF @programSerialInt12 IS NULL OR @programSerialInt12 <= 0
                BEGIN
                    THROW 50001, N'الترقيم غير 4صحيح', 1;
                END
            
                        IF EXISTS (
                    SELECT 1
                    FROM dbo.menu p
                    WHERE p.menuName_A = LTRIM(RTRIM(@programName_A))
                      AND p.menuActive = 1 
                )
                 BEGIN
                    THROW 50001, N'الاسم العربي مستخدم مسبقاً', 1;
                 END
            
                IF EXISTS (
                    SELECT 1
                    FROM dbo.menu p
                    WHERE p.menuName_E = LTRIM(RTRIM(@programName_E))
                      AND p.menuActive = 1 
                )
                 BEGIN
                    THROW 50001, N'الاسم الإنجليزي مستخدم مسبقاً', 1;
                 END
            



            INSERT INTO  dbo.Menu
            (
                [menuName_A]
               ,[menuName_E]
               ,[menuDescription]
               ,[programID_FK]
               ,[menuLink]
               ,[menuSerial]
               ,[menuActive]
               ,[PageLvl]

            )
            VALUES
            (
               @programName_A
              ,@programName_E      
              ,@programDescription 
              ,@programID            
              ,'MVC'
              ,@programSerial   
              ,1
              ,3
            
            );

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50002, N'حصل خطأ في اضافة القائمة الجانبية', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();

            
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                THROW 50002, N'حصل خطأ في اضافة القائمة الجانبية - Identity', 1; -- برمجي
            END
           SET @Note = N'{'
                          + N'"menuID": "'            + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), N'') + N'"'
                          + N',"menuName_A": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @programName_A), N'') + N'"'
                          + N',"menuName_E": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @programName_E), N'') + N'"'
                          + N',"menuDescription": "'  + ISNULL(CONVERT(NVARCHAR(MAX), @programDescription), N'') + N'"'
                          + N',"programID_FK": "'     + ISNULL(CONVERT(NVARCHAR(MAX), @programID), N'') + N'"'
                          + N',"menuSerial": "'       + ISNULL(CONVERT(NVARCHAR(MAX), @programSerial), N'') + N'"'
                          + N',"menuActive": "'       + N'1' + N'"'
                          + N',"PageLvl": "'          + N'3' + N'"'
                          + N',"entryDate": "'        + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(), 23), N'') + N'"'
                          + N',"entryData": "'        + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), N'') + N'"'
                          + N',"hostName": "'         + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), N'') + N'"'
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
                  N'[dbo].[menu]'
                , N'AddProgram'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );


            SELECT 1 AS IsSuccessful, N'تم اضافة القائمة الجانبية بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- EditMenuList
        ----------------------------------------------------------------
        ELSE IF @Action = N'EditMenuList'
        BEGIN
            DECLARE @menuID_EditMenuList BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@menuID)), N''));
            DECLARE @programID_EditMenuList INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programID)), N''));
            DECLARE @menuSerial_EditMenuList INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programSerial)), N''));

            IF @menuID_EditMenuList IS NULL OR @menuID_EditMenuList <= 0
                THROW 50001, N'معرف القائمة الجانبية غير صحيح', 1;

            IF @programID_EditMenuList IS NULL OR @programID_EditMenuList <= 0
                THROW 50001, N'البرنامج مطلوب', 1;

            IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@programDescription)), N'') IS NULL
               OR @menuSerial_EditMenuList IS NULL
                THROW 50001, N'الرجاء اكمال جميع الحقول المطلوبة', 1;

            UPDATE dbo.Menu
               SET menuName_A = LTRIM(RTRIM(@programName_A)),
                   menuName_E = LTRIM(RTRIM(@programName_E)),
                   menuDescription = LTRIM(RTRIM(@programDescription)),
                   programID_FK = @programID_EditMenuList,
                   parentMenuID_FK = NULL,
                   menuLink = 'MVC',
                   menuSerial = @menuSerial_EditMenuList,
                   PageLvl = 3
             WHERE menuID = @menuID_EditMenuList;

            SELECT 1 AS IsSuccessful, N'تم تعديل القائمة الجانبية بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DeleteMenuList
        ----------------------------------------------------------------
        ELSE IF @Action = N'DeleteMenuList'
        BEGIN
            DECLARE @menuID_DeleteMenuList BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@menuID)), N''));
            DECLARE @menuActive_DeleteMenuList BIT = TRY_CONVERT(BIT, NULLIF(LTRIM(RTRIM(@programActive)), N''));

            IF @menuID_DeleteMenuList IS NULL OR @menuID_DeleteMenuList <= 0
                THROW 50001, N'معرف القائمة الجانبية غير صحيح', 1;

            IF @menuActive_DeleteMenuList IS NULL
                THROW 50001, N'حالة القائمة الجانبية غير صحيحة', 1;

            UPDATE dbo.Menu
               SET menuActive = @menuActive_DeleteMenuList
             WHERE menuID = @menuID_DeleteMenuList;

            SELECT 1 AS IsSuccessful, N'تم تعديل حالة القائمة الجانبية بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- AddPage
        ----------------------------------------------------------------
        ELSE IF @Action = N'AddPage'
        BEGIN
            DECLARE @programID_AddPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programID)), N''));
            DECLARE @parentMenuID_AddPage BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@parentMenuID)), N''));
            DECLARE @menuSerial_AddPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programSerial)), N''));
            DECLARE @menuActive_AddPage BIT = 1;
            DECLARE @isDashboard_AddPage BIT = NULL;
            DECLARE @PageLvl_AddPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@PageLvl)), N''));

            IF @parentMenuID_AddPage IN (-1, -99999) SET @parentMenuID_AddPage = NULL;

            IF @programID_AddPage IS NULL OR @programID_AddPage <= 0
                THROW 50001, N'البرنامج مطلوب', 1;

            IF NULLIF(LTRIM(RTRIM(@programName_A)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@programName_E)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@programDescription)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@programLink)), N'') IS NULL
               OR @menuSerial_AddPage IS NULL
               OR @PageLvl_AddPage IS NULL
                THROW 50001, N'الرجاء اكمال جميع الحقول المطلوبة', 1;

            IF EXISTS (SELECT 1 FROM dbo.Menu WHERE menuName_A = LTRIM(RTRIM(@programName_A)) AND menuActive = 1)
                THROW 50001, N'اسم الصفحة العربي مستخدم مسبقاً', 1;

            IF EXISTS (SELECT 1 FROM dbo.Menu WHERE menuName_E = LTRIM(RTRIM(@programName_E)) AND menuActive = 1)
                THROW 50001, N'اسم الصفحة الإنجليزي مستخدم مسبقاً', 1;

            IF EXISTS (SELECT 1 FROM dbo.Menu WHERE menuLink = LTRIM(RTRIM(@programLink)) AND menuActive = 1)
                THROW 50001, N'رابط الصفحة مستخدم مسبقاً', 1;

            INSERT INTO dbo.Menu
            (
                menuName_A, menuName_E, menuDescription, parentMenuID_FK,
                menuLink, programID_FK, menuSerial, menuActive, isDashboard, PageLvl
            )
            VALUES
            (
                LTRIM(RTRIM(@programName_A)),
                LTRIM(RTRIM(@programName_E)),
                LTRIM(RTRIM(@programDescription)),
                @parentMenuID_AddPage,
                LTRIM(RTRIM(@programLink)),
                CASE WHEN @parentMenuID_AddPage IS NULL THEN @programID_AddPage ELSE NULL END,
                @menuSerial_AddPage,
                @menuActive_AddPage,
                @isDashboard_AddPage,
                @PageLvl_AddPage
            );

            SET @NewID = SCOPE_IDENTITY();

            INSERT INTO dbo.Distributor
            (
                distributorName_A, distributorName_E, distributorDescription,
                distributorActive, distributorType_FK, entryDate, entryData, hostName
            )
            VALUES
            (
                LTRIM(RTRIM(@programName_A)),
                LTRIM(RTRIM(@programName_E)),
                LTRIM(RTRIM(@programDescription)),
                
                @menuActive_AddPage,
                4,
                GETDATE(),
                @entryData,
                @hostName
            );

            DECLARE @NewDistributorID BIGINT = SCOPE_IDENTITY();

            INSERT INTO dbo.MenuDistributor
            (
                menuID_FK, distributorID_FK, isDenied, menuDistributorActive
            )
            VALUES
            (
                @NewID, @NewDistributorID, 0, @menuActive_AddPage
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة الصفحة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- EditPage
        ----------------------------------------------------------------
        ELSE IF @Action = N'EditPage'
        BEGIN
            DECLARE @menuID_EditPage BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@menuID)), N''));
            DECLARE @programID_EditPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programID)), N''));
            DECLARE @parentMenuID_EditPage BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@parentMenuID)), N''));
            DECLARE @menuSerial_EditPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@programSerial)), N''));
            DECLARE @PageLvl_EditPage INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@PageLvl)), N''));

            IF @parentMenuID_EditPage IN (-1, -99999) SET @parentMenuID_EditPage = NULL;

            IF @menuID_EditPage IS NULL OR @menuID_EditPage <= 0
                THROW 50001, N'معرف الصفحة غير صحيح', 1;

            IF @programID_EditPage IN (-1, -99999) SET @programID_EditPage = NULL;

            IF @programID_EditPage IS NULL AND @parentMenuID_EditPage IS NULL
                THROW 50001, N'البرنامج أو القائمة الجانبية مطلوبة', 1;

            UPDATE dbo.Menu
               SET menuName_A = LTRIM(RTRIM(@programName_A)),
                   menuName_E = LTRIM(RTRIM(@programName_E)),
                   menuDescription = LTRIM(RTRIM(@programDescription)),
                   parentMenuID_FK = @parentMenuID_EditPage,
                   menuLink = LTRIM(RTRIM(@programLink)),
                   programID_FK = CASE WHEN @parentMenuID_EditPage IS NULL THEN @programID_EditPage ELSE NULL END,
                   menuSerial = @menuSerial_EditPage,
                   PageLvl = @PageLvl_EditPage
             WHERE menuID = @menuID_EditPage;

            UPDATE d
               SET d.distributorName_A = LTRIM(RTRIM(@programName_A)),
                   d.distributorName_E = LTRIM(RTRIM(@programName_E)),
                   d.distributorDescription = LTRIM(RTRIM(@programDescription)),
                   d.distributorCode = LTRIM(RTRIM(@programName_E))
            FROM dbo.Distributor d
            INNER JOIN dbo.MenuDistributor md ON md.distributorID_FK = d.distributorID
            WHERE md.menuID_FK = @menuID_EditPage
              AND d.distributorType_FK = 4;

            SELECT 1 AS IsSuccessful, N'تم تعديل الصفحة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DeletePage
        ----------------------------------------------------------------
        ELSE IF @Action = N'DeletePage'
        BEGIN
            DECLARE @menuID_DeletePage BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@menuID)), N''));
            DECLARE @menuActive_DeletePage BIT = TRY_CONVERT(BIT, NULLIF(LTRIM(RTRIM(@programActive)), N''));

            IF @menuID_DeletePage IS NULL OR @menuID_DeletePage <= 0
                THROW 50001, N'معرف الصفحة غير صحيح', 1;

            IF @menuActive_DeletePage IS NULL
                THROW 50001, N'حالة الصفحة غير صحيحة', 1;

            UPDATE dbo.Menu
               SET menuActive = @menuActive_DeletePage
             WHERE menuID = @menuID_DeletePage;

            UPDATE dbo.MenuDistributor
               SET menuDistributorActive = @menuActive_DeletePage
             WHERE menuID_FK = @menuID_DeletePage;

            UPDATE d
               SET d.distributorActive = @menuActive_DeletePage
            FROM dbo.Distributor d
            INNER JOIN dbo.MenuDistributor md ON md.distributorID_FK = d.distributorID
            WHERE md.menuID_FK = @menuID_DeletePage
              AND d.distributorType_FK = 4;

            SELECT 1 AS IsSuccessful, N'تم تعديل حالة الصفحة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- AddPagePermission
        ----------------------------------------------------------------
        ELSE IF @Action = N'AddPagePermission'
        BEGIN
            DECLARE @menuID_AddPagePermission BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@menuID)), N''));
            DECLARE @permissionAuthLvl_Add INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@permissionAuthLvl)), N''));
            DECLARE @permissionActive_Add BIT = 1;
            DECLARE @distributorID_Add BIGINT;
            DECLARE @permissionTypeID_Add INT;

            IF NULLIF(LTRIM(RTRIM(@permissionTypeName_A)), N'') IS NULL
               OR NULLIF(LTRIM(RTRIM(@permissionTypeName_E)), N'') IS NULL
            BEGIN
                THROW 50001, N'اسم الصلاحية بالعربي والإنجليزي مطلوب', 1;
            END

            IF @permissionAuthLvl_Add IS NULL
            BEGIN
                THROW 50001, N'الرجاء اكمال جميع الحقول المطلوبة', 1;
            END

            IF EXISTS (
                SELECT 1
                FROM dbo.PermissionType pt
                WHERE pt.permissionTypeActive = 1
                  AND (
                        pt.permissionTypeName_A = LTRIM(RTRIM(@permissionTypeName_A))
                     OR pt.permissionTypeName_E = LTRIM(RTRIM(@permissionTypeName_E))
                  )
            )
            BEGIN
                THROW 50001, N'نوع الصلاحية مستخدم مسبقاً', 1;
            END

            INSERT INTO dbo.PermissionType
            (
                permissionTypeName_A,
                permissionTypeName_E,
                permissionTypeActive
            )
            VALUES
            (
                LTRIM(RTRIM(@permissionTypeName_A)),
                LTRIM(RTRIM(@permissionTypeName_E)),
                1
            );

            SET @permissionTypeID_Add = SCOPE_IDENTITY();

            SELECT TOP 1 @distributorID_Add = md.distributorID_FK
            FROM dbo.MenuDistributor md
            INNER JOIN dbo.Distributor d ON d.distributorID = md.distributorID_FK
            WHERE md.menuID_FK = @menuID_AddPagePermission
              AND d.distributorType_FK = 4;

            IF @distributorID_Add IS NULL
                THROW 50001, N'لم يتم العثور على موزع الصفحة', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.DistributorPermissionType dpt
                WHERE dpt.DistributorID_FK = @distributorID_Add
                  AND dpt.permissionTypeID_FK = @permissionTypeID_Add
                  AND dpt.distributorPermissionTypeActive = 1
            )
                THROW 50001, N'الصلاحية مضافة مسبقاً لهذه الصفحة', 1;

            INSERT INTO dbo.DistributorPermissionType
            (
                permissionTypeID_FK, DistributorID_FK,
                distributorPermissionTypeStartDate, distributorPermissionTypeEndDate,
                distributorPermissionTypeActive, permissionAuthLvl,
                entryDate, entryData, hostName
            )
            VALUES
            (
                @permissionTypeID_Add, @distributorID_Add,
                GETDATE(), NULL,
                @permissionActive_Add, @permissionAuthLvl_Add,
                GETDATE(), @entryData, @hostName
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة صلاحية الصفحة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- EditPagePermission
        ----------------------------------------------------------------
        ELSE IF @Action = N'EditPagePermission'
        BEGIN
            DECLARE @dptID_Edit BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@distributorPermissionTypeID)), N''));
            DECLARE @permissionTypeID_Edit INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@permissionTypeID)), N''));
            DECLARE @permissionAuthLvl_Edit INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@permissionAuthLvl)), N''));

            IF @dptID_Edit IS NULL OR @dptID_Edit <= 0
                THROW 50001, N'معرف صلاحية الصفحة غير صحيح', 1;

            UPDATE dbo.DistributorPermissionType
               SET permissionTypeID_FK = @permissionTypeID_Edit,
                   permissionAuthLvl = @permissionAuthLvl_Edit
             WHERE distributorPermissionTypeID = @dptID_Edit;


             UPDATE dbo.PermissionType
               SET permissionTypeName_A = @permissionTypeName_A,
                   permissionTypeName_E = @permissionTypeName_E
             WHERE permissionTypeID = (select top(1) t.permissionTypeID_FK from DistributorPermissionType t where distributorPermissionTypeID = @dptID_Edit order by t.distributorPermissionTypeID desc );


            SELECT 1 AS IsSuccessful, N'تم تعديل صلاحية الصفحة بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DeletePagePermission
        ----------------------------------------------------------------
        ELSE IF @Action = N'DeletePagePermission'
        BEGIN
            DECLARE @dptID_Delete BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@distributorPermissionTypeID)), N''));
            DECLARE @permissionActive_Delete BIT = TRY_CONVERT(BIT, NULLIF(LTRIM(RTRIM(@programActive)), N''));

            IF @dptID_Delete IS NULL OR @dptID_Delete <= 0
                THROW 50001, N'معرف صلاحية الصفحة غير صحيح', 1;

            IF @permissionActive_Delete IS NULL
                THROW 50001, N'حالة صلاحية الصفحة غير صحيحة', 1;

            UPDATE dbo.DistributorPermissionType
               SET distributorPermissionTypeActive = @permissionActive_Delete
             WHERE distributorPermissionTypeID = @dptID_Delete;

            SELECT 1 AS IsSuccessful, N'تم تعديل حالة صلاحية الصفحة بنجاح' AS Message_;
            RETURN;
        END


        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        THROW;
    END CATCH
END