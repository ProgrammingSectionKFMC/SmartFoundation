
CREATE PROCEDURE [dbo].[UsersSP] 
(
      @Action                                NVARCHAR(200)
    , @usersID                               NVARCHAR(200)   = NULL
    , @nationalID                            NVARCHAR(200)   = NULL
    , @GeneralNo                             NVARCHAR(200)   = NULL
    , @firstName_A                           NVARCHAR(200)   = NULL
    , @secondName_A                          NVARCHAR(200)   = NULL
    , @thirdName_A                           NVARCHAR(200)   = NULL
    , @forthName_A                           NVARCHAR(200)   = NULL
    , @lastName_A                            NVARCHAR(200)   = NULL
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

    DECLARE @martialStatusID_FK_INT    INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@maritalStatusID_FK)), ''));
    DECLARE @nationalityID_FK_INT BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@nationalityID_FK)), ''));
    DECLARE @genderID_FK_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@genderID_FK)), ''));

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
            ;THROW 50001, N'العملية مطلوبة', 1;
        END
        ----------------------------------------------------------------
        -- INSERTUSER
        ----------------------------------------------------------------
        IF @Action = N'INSERTUSERS'
        BEGIN

        IF @nationalIDIssueDate_DT IS NULL
BEGIN
    ;THROW 50001, N'صيغة تاريخ إصدار الهوية غير صحيحة. استخدم YYYY-MM-DD', 1;
END

IF @dateOfBirth_DT IS NULL
BEGIN
    ;THROW 50001, N'صيغة تاريخ الميلاد غير صحيحة. استخدم YYYY-MM-DD', 1;
END


            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية مطلوب', 1;
        END

                      IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الرقم العام مطلوب', 1;
            END




         IF (select count(*) 
                from dbo.Users ri
                where ri.usersActive = 1 AND RI.nationalID = @nationalID
                ) > 0
        BEGIN
            ;THROW 50001, N'رقم الهوية مستخدم مسبقا', 1;
        END


          IF (select count(*) 
                from dbo.Users ri
                inner join dbo.UsersDetails rd on ri.usersID = rd.usersID_FK
                where ri.usersActive = 1 and rd.userActive = 1 and rd.GeneralNo = @generalNo
                ) > 0
        BEGIN
            ;THROW 50001, N'الرقم العام مستخدم مسبقا', 1;
        END


        if(@nationalityID_FK_INT = 1)
        Begin
        IF TRY_CONVERT(BIGINT, @NationalID) IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون أرقام فقط', 1;
        END

        IF LEN(@NationalID) <> 10
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون 10 أرقام', 1;
        END
        
        IF LEFT(@NationalID, 1) <> N'1'
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يبدأ بالرقم 1', 1;
        END
        END



         IF (
            (NULLIF(LTRIM(RTRIM(@firstName_A)), N'') IS NULL) 
         OR (NULLIF(LTRIM(RTRIM(@secondName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@thirdName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@lastName_A)), N'') IS NULL)
         )
        BEGIN
            ;THROW 50001, N'الاسم العربي الرباعي مطلوب', 1;
        END





              IF NULLIF(LTRIM(RTRIM(@UsersAuthTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصلاحية مطلوب', 1;
            END




              IF NULLIF(LTRIM(RTRIM(@userTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع المستخدم مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@IdaraID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم الادارة مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@nationalIDIssueDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ اصدار الهوية مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@dateOfBirth)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ الميلاد مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@genderID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الجنس مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@religionID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الديانة مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@maritalStatusID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الحالة الاجتماعية مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@educationID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الدرجة العلمية مطلوب', 1;
            END


            IF EXISTS
            (
                SELECT 1
                FROM  dbo.Users c
                WHERE c.nationalID = @nationalID
                  AND c.usersActive = 1
            )
            BEGIN
                ;THROW 50001, N'المستخدم مضاف مسبقا', 1;
            END


            INSERT INTO  dbo.Users
            (
                  nationalID
                , nationalIDTypeID_FK
                , usersStartDate
                , usersActive
                , entryData
                , hostName
            )
            VALUES
            (
                  @nationalID
                , 1
                , GETDATE()
                , 1
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة المستفيد', 1; -- برمجي
            END
            SET @NewID = SCOPE_IDENTITY();

            
            IF @NewID IS NULL OR @NewID <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note = N'{'
                + N'"usersID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N'"nationalID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @nationalID), '') + N'"'
                + N',"nationalIDTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"usersStartDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
                + N',"usersActive": "1"'
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
                  N'[dbo].[UsersSP]'
                , N'INSERTUSER'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );



            INSERT INTO  dbo.UsersDetails
            (
                 [usersID_FK]
                ,[GeneralNo]
                ,[userTypeID_FK]
                ,[firstName_A]
                ,[secondName_A]
                ,[thirdName_A]
                ,[forthName_A]
                ,[lastName_A]
                ,[firstName_E]
                ,[secondName_E]
                ,[thirdName_E]
                ,[forthName_E]
                ,[lastName_E]
                ,[nationalIDIssueDate]
                ,[dateOfBirth]
                ,[genderID_FK]
                ,[nationalityID_FK]
                ,[religionID_FK]
                ,[maritalStatusID_FK]
                ,[educationID_FK]
                ,[userActive]
                ,[userNote]
                ,[usersAuthTypeID_FK]
                ,[IdaraID]
                ,[entryData]
                ,hostName
            )
            VALUES
            (
                  @NewID
                , @GeneralNo
                , @userTypeID_FK 
                , @firstName_A                
                , @secondName_A               
                , @thirdName_A                
                , @forthName_A                
                , @lastName_A                 
                , @firstName_E                
                , @secondName_E               
                , @thirdName_E                
                , @forthName_E                
                , @lastName_E  
                , @nationalIDIssueDate_DT               
                , @dateOfBirth_DT                
                , @genderID_FK                
                , @nationalityID_FK           
                , @religionID_FK              
                , @maritalStatusID_FK         
                , @educationID_FK   
                , 1
                , @userNote                   
                , @UsersAuthTypeID                               
                , @IdaraID
                , @entryData
                , @hostName
            );

             

            DECLARE @NewID1 BIGINT,@Note1 NVARCHAR(MAX)
            SET @NewID1 = SCOPE_IDENTITY();
            IF @NewID1 IS NULL OR @NewID1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - NewID1', 1; -- برمجي
            END
            SET @Note1 = N'{'
                + N'"usersID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"GeneralNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"userTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @userTypeID_FK), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"forthName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"forthName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"nationalIDIssueDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalIDIssueDate), '') + N'"'
                + N',"dateOfBirth": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dateOfBirth), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK), '') + N'"'
                + N',"religionID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @religionID_FK), '') + N'"'
                + N',"maritalStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @maritalStatusID_FK), '') + N'"'
                + N',"educationID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @educationID_FK), '') + N'"'
                + N',"userActive": "1"'
                + N',"userNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @userNote), '') + N'"'
                + N',"usersAuthTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @UsersAuthTypeID), '') + N'"'
                + N',"IdaraID": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
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
                  N'[dbo].[UsersSP]'
                , N'INSERTUSER'
                , ISNULL(@NewID1, 0)
                , @entryData
                , @Note1
            );


            UPDATE ud
                SET ud.UDActive = 0,ud.UDEndDate = GETDATE(),ud.CanceldBy = cast(@entryData as nvarchar(50))+','+convert(nvarchar(10),GETDATE(),23)
                FROM dbo.Distributor d
                INNER JOIN dbo.UserDistributor ud 
                    ON ud.distributorID_FK = d.distributorID
                   AND d.distributorType_FK = 1
                WHERE ud.userID_FK = @usersID;


                
            
            INSERT INTO  dbo.UserDistributor
            (
                  userID_FK
                , distributorID_FK
                , UDStartDate
                , UDActive
                , entryData
                , hostName
            )
            VALUES
            (
                  @NewID
                , @distributorID
                , GETDATE()
                , 1
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة المستفيد', 1; -- برمجي
            END

            DECLARE @NewID20 BIGINT,@Note20 NVARCHAR(MAX)
            SET @NewID20 = SCOPE_IDENTITY();

            
            IF @NewID20 IS NULL OR @NewID20 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - Identity', 1; -- برمجي
            END
            SET @Note20 = N'{'
                + N'"userID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N'"distributorID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @nationalID), '') + N'"'
                + N',"UDStartDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
                + N',"usersActive": "1"'
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
                  N'[dbo].[UsersSP]'
                , N'INSERTUSER'
                , ISNULL(@NewID20, 0)
                , @entryData
                , @Note20
            );


            ---------------------------------------------------------
-- تعيين كلمة المرور الافتراضية بعد اكتمال الإدخال
---------------------------------------------------------
           DECLARE @PwdOK BIT, @PwdMsg NVARCHAR(4000);

EXEC dbo.SetUserPassword
      @NationalID    = @NationalID
    , @PlainPassword = N'Aa123456'
    , @entryData     = @entryData
    , @hostName      = @hostName
    , @IsSuccessful  = @PwdOK OUTPUT
    , @Message_      = @PwdMsg OUTPUT;

IF ISNULL(@PwdOK, 0) = 0
BEGIN
    SET @PwdMsg = ISNULL(@PwdMsg, N'فشل تعيين كلمة المرور الافتراضية');
    ;THROW 50002, @PwdMsg, 1;
END


            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
                    IF @Action = N'UPDATEUSERS'
                BEGIN
            
                    IF @nationalIDIssueDate_DT IS NULL
            BEGIN
                ;THROW 50001, N'صيغة تاريخ إصدار الهوية غير صحيحة. استخدم YYYY-MM-DD', 1;
            END
            
            IF @dateOfBirth_DT IS NULL
            BEGIN
                ;THROW 50001, N'صيغة تاريخ الميلاد غير صحيحة. استخدم YYYY-MM-DD', 1;
            END


            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية مطلوب', 1;
        END

                      IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الرقم العام مطلوب', 1;
            END




         IF (select count(*) 
                from dbo.Users ri
                where ri.usersActive = 1 AND RI.nationalID = @nationalID AND RI.usersID <> @usersID
                ) > 0
        BEGIN
            ;THROW 50001, N'رقم الهوية مستخدم مسبقا', 1;
        END


          IF (select count(*) 
                from dbo.Users ri
                inner join dbo.UsersDetails rd on ri.usersID = rd.usersID_FK
                where ri.usersActive = 1 and rd.userActive = 1 and rd.GeneralNo = @generalNo AND RI.usersID <> @usersID
                ) > 0
        BEGIN
            ;THROW 50001, N'الرقم العام مستخدم مسبقا', 1;
        END


        if(@nationalityID_FK_INT = 1)
        Begin
        IF TRY_CONVERT(BIGINT, @NationalID) IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون أرقام فقط', 1;
        END

        IF LEN(@NationalID) <> 10
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون 10 أرقام', 1;
        END
        
        IF LEFT(@NationalID, 1) <> N'1'
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يبدأ بالرقم 1', 1;
        END
        END



         IF (
            (NULLIF(LTRIM(RTRIM(@firstName_A)), N'') IS NULL) 
         OR (NULLIF(LTRIM(RTRIM(@secondName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@thirdName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@lastName_A)), N'') IS NULL)
         )
        BEGIN
            ;THROW 50001, N'الاسم العربي الرباعي مطلوب', 1;
        END





              IF NULLIF(LTRIM(RTRIM(@UsersAuthTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصلاحية مطلوب', 1;
            END




              IF NULLIF(LTRIM(RTRIM(@userTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع المستخدم مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@IdaraID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم الادارة مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@nationalIDIssueDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ اصدار الهوية مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@dateOfBirth)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ الميلاد مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@genderID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الجنس مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@religionID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الديانة مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@maritalStatusID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الحالة الاجتماعية مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@educationID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الدرجة العلمية مطلوب', 1;
            END


            IF EXISTS
            (
                SELECT 1
                FROM  dbo.Users c
                WHERE c.nationalID = @nationalID
                  AND c.usersActive = 1 and c.usersID <> @usersID
            )
            BEGIN
                ;THROW 50001, N'المستخدم مضاف مسبقا', 1;
            END


            UPDATE  dbo.Users SET 
            
                  nationalID = @nationalID,
                  updatedby = updatedby +','+cast(@entryData as nvarchar),
                  updatedDate = updatedDate+','+cast(GETDATE() as nvarchar)

                  where usersID = @usersID
               

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل المستفيد', 1; -- برمجي
            END
           
            SET @Note = N'{'
                + N'"usersID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @usersID), '') + N'"'
                + N'"nationalID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @nationalID), '') + N'"'
                + N',"nationalIDTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"usersStartDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
                + N',"usersActive": "1"'
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
                  N'[dbo].[UsersSP]'
                , N'UPDATEUSERS'
                , ISNULL(@usersID, 0)
                , @entryData
                , @Note
            );



            
            UPDATE  dbo.UsersDetails SET 
            
                  userActive = 0
                  where usersID_FK = @usersID
               

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل المستفيد', 1; -- برمجي
            END


            INSERT INTO  dbo.UsersDetails
            (
                 [usersID_FK]
                ,[GeneralNo]
                ,[userTypeID_FK]
                ,[firstName_A]
                ,[secondName_A]
                ,[thirdName_A]
                ,[forthName_A]
                ,[lastName_A]
                ,[firstName_E]
                ,[secondName_E]
                ,[thirdName_E]
                ,[forthName_E]
                ,[lastName_E]
                ,[nationalIDIssueDate]
                ,[dateOfBirth]
                ,[genderID_FK]
                ,[nationalityID_FK]
                ,[religionID_FK]
                ,[maritalStatusID_FK]
                ,[educationID_FK]
                ,[userActive]
                ,[userNote]
                ,[usersAuthTypeID_FK]
                ,[IdaraID]
                ,[entryData]
                ,hostName
            )
            VALUES
            (
                  @usersID
                , @GeneralNo
                , @userTypeID_FK 
                , @firstName_A                
                , @secondName_A               
                , @thirdName_A                
                , @forthName_A                
                , @lastName_A                 
                , @firstName_E                
                , @secondName_E               
                , @thirdName_E                
                , @forthName_E                
                , @lastName_E  
                , @nationalIDIssueDate_DT               
                , @dateOfBirth_DT                
                , @genderID_FK                
                , @nationalityID_FK           
                , @religionID_FK              
                , @maritalStatusID_FK         
                , @educationID_FK   
                , 1
                , @userNote                   
                , @UsersAuthTypeID                               
                , @IdaraID
                , @entryData
                , @hostName
            );

             

            DECLARE @NewID2 BIGINT,@Note2 NVARCHAR(MAX)
            SET @NewID2 = SCOPE_IDENTITY();
            IF @NewID2 IS NULL OR @NewID1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل البيانات - NewID2', 1; -- برمجي
            END
            SET @Note2 = N'{'
                + N'"usersID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"GeneralNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"userTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @userTypeID_FK), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"forthName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"forthName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"nationalIDIssueDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalIDIssueDate), '') + N'"'
                + N',"dateOfBirth": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dateOfBirth), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK), '') + N'"'
                + N',"religionID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @religionID_FK), '') + N'"'
                + N',"maritalStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @maritalStatusID_FK), '') + N'"'
                + N',"educationID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @educationID_FK), '') + N'"'
                + N',"userActive": "1"'
                + N',"userNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @userNote), '') + N'"'
                + N',"usersAuthTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @UsersAuthTypeID), '') + N'"'
                + N',"IdaraID": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
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
                  N'[dbo].[UsersSP]'
                , N'UPDATEUSERS'
                , ISNULL(@NewID2, 0)
                , @entryData
                , @Note2
            );




              UPDATE ud
                SET ud.UDActive = 0,ud.UDEndDate = GETDATE(),ud.CanceldBy = cast(@entryData as nvarchar(50))+','+convert(nvarchar(10),GETDATE(),23)
                FROM dbo.Distributor d
                INNER JOIN dbo.UserDistributor ud 
                    ON ud.distributorID_FK = d.distributorID
                   AND d.distributorType_FK = 1
                WHERE ud.userID_FK = @usersID;


                
            
            INSERT INTO  dbo.UserDistributor
            (
                  userID_FK
                , distributorID_FK
                , UDStartDate
                , UDActive
                , entryData
                , hostName
            )
            VALUES
            (
                  @usersID
                , @distributorID
                , GETDATE()
                , 1
                , @entryData
                , @hostName
            );

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل المستفيد', 1; -- برمجي
            END

            DECLARE @NewID200 BIGINT,@Note200 NVARCHAR(MAX)
            SET @NewID200 = SCOPE_IDENTITY();

            
            IF @NewID200 IS NULL OR @NewID200 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعديل البيانات - Identity', 1; -- برمجي
            END
            SET @Note200 = N'{'
                + N'"userID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N'"distributorID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @nationalID), '') + N'"'
                + N',"UDStartDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
                + N',"usersActive": "1"'
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
                  N'[dbo].[UsersSP]'
                , N'INSERTUSER'
                , ISNULL(@NewID200, 0)
                , @entryData
                , @Note200
            );

            SELECT 1 AS IsSuccessful, N'تم تعديل البيانات بنجاح' AS Message_;
            RETURN;
        END


          ----------------------------------------------------------------
        -- DELETEUSERS
        ----------------------------------------------------------------
                    IF @Action = N'DELETEUSERS'
                BEGIN
            
                    IF @nationalIDIssueDate_DT IS NULL
            BEGIN
                ;THROW 50001, N'صيغة تاريخ إصدار الهوية غير صحيحة. استخدم YYYY-MM-DD', 1;
            END
            
            IF @dateOfBirth_DT IS NULL
            BEGIN
                ;THROW 50001, N'صيغة تاريخ الميلاد غير صحيحة. استخدم YYYY-MM-DD', 1;
            END


            IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية مطلوب', 1;
        END

                      IF NULLIF(LTRIM(RTRIM(@GeneralNo)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'الرقم العام مطلوب', 1;
            END




         IF (select count(*) 
                from dbo.Users ri
                where ri.usersActive = 1 AND RI.nationalID = @nationalID AND RI.usersID <> @usersID
                ) > 0
        BEGIN
            ;THROW 50001, N'رقم الهوية مستخدم مسبقا', 1;
        END


          IF (select count(*) 
                from dbo.Users ri
                inner join dbo.UsersDetails rd on ri.usersID = rd.usersID_FK
                where ri.usersActive = 1 and rd.userActive = 1 and rd.GeneralNo = @generalNo AND RI.usersID <> @usersID
                ) > 0
        BEGIN
            ;THROW 50001, N'الرقم العام مستخدم مسبقا', 1;
        END


        if(@nationalityID_FK_INT = 1)
        Begin
        IF TRY_CONVERT(BIGINT, @NationalID) IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون أرقام فقط', 1;
        END

        IF LEN(@NationalID) <> 10
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون 10 أرقام', 1;
        END
        
        IF LEFT(@NationalID, 1) <> N'1'
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يبدأ بالرقم 1', 1;
        END
        END



         IF (
            (NULLIF(LTRIM(RTRIM(@firstName_A)), N'') IS NULL) 
         OR (NULLIF(LTRIM(RTRIM(@secondName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@thirdName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@lastName_A)), N'') IS NULL)
         )
        BEGIN
            ;THROW 50001, N'الاسم العربي الرباعي مطلوب', 1;
        END





              IF NULLIF(LTRIM(RTRIM(@UsersAuthTypeID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الصلاحية مطلوب', 1;
            END




              IF NULLIF(LTRIM(RTRIM(@userTypeID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع المستخدم مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@IdaraID)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'اسم الادارة مطلوب', 1;
            END

              IF NULLIF(LTRIM(RTRIM(@nationalIDIssueDate)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ اصدار الهوية مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@dateOfBirth)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'تاريخ الميلاد مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@genderID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الجنس مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@religionID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الديانة مطلوب', 1;
            END

             IF NULLIF(LTRIM(RTRIM(@maritalStatusID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الحالة الاجتماعية مطلوب', 1;
            END

            IF NULLIF(LTRIM(RTRIM(@educationID_FK)), N'') IS NULL
            BEGIN
                ;THROW 50001, N'نوع الدرجة العلمية مطلوب', 1;
            END



            UPDATE  dbo.Users SET 
            
                  usersActive = 0,
                  updatedby = updatedby +','+cast(@entryData as nvarchar),
                  updatedDate = updatedDate+','+cast(GETDATE() as nvarchar)

                  where usersID = @usersID
               

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعطيل المستفيد', 1; -- برمجي
            END
           
            SET @Note = N'{'
                + N'"usersID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @usersID), '') + N'"'
                + N'"nationalID": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @nationalID), '') + N'"'
                + N',"nationalIDTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), 1), '') + N'"'
                + N',"usersStartDate": "'      + ISNULL(CONVERT(NVARCHAR(MAX), GETDATE(),23), '') + N'"'
                + N',"usersActive": "1"'
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
                  N'[dbo].[UsersSP]'
                , N'DELETEUSERS'
                , ISNULL(@usersID, 0)
                , @entryData
                , @Note
            );






            
            UPDATE  dbo.UsersDetails SET 
            
                  userActive = 0
                  where usersID_FK = @usersID
               

            IF @@ROWCOUNT = 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعطيل المستفيد', 1; -- برمجي
            END


            DECLARE @NewID3 BIGINT,@Note3 NVARCHAR(MAX)
            SET @NewID3 = SCOPE_IDENTITY();
            IF @NewID3 IS NULL OR @NewID1 <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في تعطيل البيانات - NewID2', 1; -- برمجي
            END
            SET @Note3 = N'{'
                + N'"usersID_FK": "'           + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"GeneralNo": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @GeneralNo), '') + N'"'
                + N',"userTypeID_FK": "'      + ISNULL(CONVERT(NVARCHAR(MAX), @userTypeID_FK), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"forthName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"forthName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @forthName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"nationalIDIssueDate": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalIDIssueDate), '') + N'"'
                + N',"dateOfBirth": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dateOfBirth), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK), '') + N'"'
                + N',"religionID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @religionID_FK), '') + N'"'
                + N',"maritalStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @maritalStatusID_FK), '') + N'"'
                + N',"educationID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @educationID_FK), '') + N'"'
                + N',"userActive": "1"'
                + N',"userNote": "' + ISNULL(CONVERT(NVARCHAR(MAX), @userNote), '') + N'"'
                + N',"usersAuthTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @UsersAuthTypeID), '') + N'"'
                + N',"IdaraID": "'               + ISNULL(CONVERT(NVARCHAR(MAX), @idaraID_FK), '') + N'"'
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
                  N'[dbo].[UsersSP]'
                , N'DELETEUSERS'
                , ISNULL(@NewID3, 0)
                , @entryData
                , @Note3
            );




             UPDATE ud
                SET ud.UDActive = 0,ud.UDEndDate = GETDATE(),ud.CanceldBy = cast(@entryData as nvarchar(50))+','+convert(nvarchar(10),GETDATE(),23)
                FROM dbo.Distributor d
                INNER JOIN dbo.UserDistributor ud 
                    ON ud.distributorID_FK = d.distributorID
                   AND d.distributorType_FK = 1
                WHERE ud.userID_FK = @usersID;


            SELECT 1 AS IsSuccessful, N'تم تعطيل المستخدم بنجاح' AS Message_;
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
