CREATE   PROCEDURE [dbo].[ReSetUserPassword]
(
    @Action              NVARCHAR(200),
    @usersID             NVARCHAR(200) = NULL,
    @NationalID          NVARCHAR(20) = NULL,     
    @PlainPassword       NVARCHAR(200) = NULL,
    @OldPassword         NVARCHAR(200) = NULL,
    @idaraID_FK          NVARCHAR(200) = NULL,
    @entryData           NVARCHAR(20) = NULL,     
    @hostName            NVARCHAR(200) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;



    DECLARE @usersIDs bigint;
    set @usersIDs = (
    select TOP(1) u.usersID
    from  dbo.Users u 
    where u.nationalID = @NationalID
    and u.usersActive = 1 
    and u.usersStartDate is not null 
    and cast(u.usersStartDate as date) <= cast(GETDATE() as date)
    and((cast(u.usersEndDate as date) > cast(GETDATE() as date)) OR u.usersEndDate is null)
    order by u.usersID desc
    )

    DECLARE @Salt       VARBINARY(32);
    DECLARE @Hash       VARBINARY(64);

    DECLARE @PrevSalt   VARBINARY(32);
    DECLARE @PrevHash   VARBINARY(64);
    DECLARE @Candidate  VARBINARY(64);

    BEGIN TRY

    IF @tc = 0
            BEGIN TRAN;


              IF @Action IN(N'RESETUSERPASSWORD')
        BEGIN

        DECLARE @DefualtPlainPassword       NVARCHAR(200)
        SET @DefualtPlainPassword =N'Aa123456'


         
            --IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
            --BEGIN
            --    ;THROW 50001, N'يجب كتابة وصف لمحضر التخصيص', 1;
            --END

             ----------------------------------------------------
        -- 0) التحقق أن المستخدم موجود وفعال في جدول [User]
        ----------------------------------------------------
        IF NOT EXISTS (
            SELECT 1   
              from  dbo.Users u 
              where u.usersID = @usersID
              and u.usersActive = 1 
              and u.usersStartDate is not null 
              and cast(u.usersStartDate as date) <= cast(GETDATE() as date)
              and((cast(u.usersEndDate as date) > cast(GETDATE() as date)) OR u.usersEndDate is null)
             
        )
        
            BEGIN
                ;THROW 50001, N'المستخدم غير موجود بالنظام', 1;
            END

            
       


        ----------------------------------------------------
        -- 1) التحقق من تعقيد كلمة المرور الجديدة
        ----------------------------------------------------
        --IF LEN(@PlainPassword) < 8
        --   OR @PlainPassword NOT LIKE '%[0-9]%'      -- لا تحتوي رقم
        --   OR @PlainPassword NOT LIKE '%[A-Za-z]%'   -- لا تحتوي حرف إنجليزي
        --BEGIN
        --    SELECT 0 AS IsSuccessful,
        --           N'كلمة المرور غير مقبولة. يجب أن لا تقل عن 8 خانات وتحتوي على حروف إنجليزية وأرقام.' AS Message_;
        --    RETURN;
        --END


        ----------------------------------------------------
        -- 2) التأكد أن كلمة المرور الجديدة ليست نفسها القديمة
        ----------------------------------------------------
        --SELECT TOP (1)
        --    @PrevSalt = PasswordSalt,
        --    @PrevHash = PasswordHash
        --FROM dbo.usersPassword p
        --WHERE p.usersID_FK = @UsersID
        --  AND ISNULL(userPasswordActive, 1) = 1
        --ORDER BY userPasswordStartDate DESC, usersPasswordID DESC;

        --IF @PrevHash IS NOT NULL
        --BEGIN
        --    SET @Candidate = HASHBYTES(
        --                        'SHA2_256',
        --                        @PrevSalt + CAST(@PlainPassword AS VARBINARY(200))
        --                     );

        --    IF @Candidate = @PrevHash
        --    BEGIN
        --        ;THROW 50001, N'لا يمكن استخدام نفس كلمة المرور السابقة. الرجاء اختيار كلمة مرور جديدة مختلفة.', 1;
        --    END
                    
        --END


        ----------------------------------------------------
        -- 3) البدء في المعاملة
        ----------------------------------------------------
        BEGIN TRANSACTION;

        -- تعطيل كل كلمات المرور السابقة
        UPDATE dbo.usersPassword
        SET 
            userPasswordActive  = 0,
            userPasswordEndDate = CAST(GETDATE() AS DATE)
        WHERE usersID_FK = @UsersID
          AND ISNULL(userPasswordActive, 1) = 1;


        ----------------------------------------------------
        -- 4) إنشاء Salt جديد + Hash جديد
        ----------------------------------------------------
        SET @Salt = CRYPT_GEN_RANDOM(32);

        SET @Hash = HASHBYTES(
                        'SHA2_256',
                        @Salt + CAST(@DefualtPlainPassword AS VARBINARY(200))
                    );


        ----------------------------------------------------
        -- 5) إدخال كلمة المرور الجديدة
        ----------------------------------------------------
        INSERT INTO dbo.usersPassword
        (
            usersID_FK,
            PasswordHash,
            PasswordSalt,
            HashAlgorithm,
            userPasswordStartDate,
            userPasswordActive,
            ChangedPassword,
            entryDate,
            entryData,
            hostName
        )
        VALUES
        (
            @UsersID,
            @Hash,
            @Salt,
            'SHA2_256',
            CAST(GETDATE() AS DATE),
            1,
            0,
            GETDATE(),
            @entryData,
            ISNULL(@hostName, HOST_NAME())
        );

        COMMIT TRANSACTION;

         SELECT 1 AS IsSuccessful, N'تم اعادة ضبط كلمة المرور بنجاح.' AS Message_;
            RETURN;

           
        END


        ELSE IF @Action = N'CHANGEUSERPASSWORD'
        BEGIN
            ----------------------------------------------------
            -- 0) Verify user exists and is active
            ----------------------------------------------------
            IF NOT EXISTS (
                SELECT 1   
                FROM  dbo.Users u 
                WHERE u.usersID = @usersID
                  AND u.usersActive = 1 
                  AND u.usersStartDate IS NOT NULL 
                  AND CAST(u.usersStartDate AS DATE) <= CAST(GETDATE() AS DATE)
                  AND (CAST(u.usersEndDate AS DATE) > CAST(GETDATE() AS DATE) OR u.usersEndDate IS NULL)
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'المستخدم غير موجود أو غير نشط' AS Message_;
                RETURN;
            END

            ----------------------------------------------------
            -- 1) Verify old password matches
            ----------------------------------------------------
            SELECT TOP (1)
                @PrevSalt = PasswordSalt,
                @PrevHash = PasswordHash
            FROM dbo.usersPassword p
            WHERE p.usersID_FK = @usersID
              AND ISNULL(userPasswordActive, 1) = 1
            ORDER BY userPasswordStartDate DESC, usersPasswordID DESC;

            IF @PrevHash IS NULL
            BEGIN
                SELECT 0 AS IsSuccessful, N'لم يتم العثور على كلمة المرور الحالية' AS Message_;
                RETURN;
            END

            -- Hash the provided old password and compare
            SET @Candidate = HASHBYTES(
                                'SHA2_256',
                                @PrevSalt + CAST(@OldPassword AS VARBINARY(200))
                             );

            IF @Candidate != @PrevHash
            BEGIN
                SELECT 0 AS IsSuccessful, N'كلمة المرور الحالية غير صحيحة' AS Message_;
                RETURN;
            END

            ----------------------------------------------------
            -- 2) Validate new password complexity
            ----------------------------------------------------
             IF LEN(@PlainPassword) < 8
           OR @PlainPassword NOT LIKE '%[0-9]%'      -- لا تحتوي رقم
           OR @PlainPassword NOT LIKE '%[A-Za-z]%'   -- لا تحتوي حرف إنجليزي
        BEGIN
            SELECT 0 AS IsSuccessful,
                   N'كلمة المرور غير مقبولة. يجب أن لا تقل عن 8 خانات وتحتوي على حروف إنجليزية وأرقام.' AS Message_;
            RETURN;
        END

            ----------------------------------------------------
            -- 3) Ensure new password is different from old
            ----------------------------------------------------
            SET @Candidate = HASHBYTES(
                                'SHA2_256',
                                @PrevSalt + CAST(@PlainPassword AS VARBINARY(200))
                             );

            IF @Candidate = @PrevHash
            BEGIN
                SELECT 0 AS IsSuccessful, N'كلمة المرور الجديدة يجب أن تختلف عن الحالية' AS Message_;
                RETURN;
            END

            ----------------------------------------------------
            -- 4) Deactivate old passwords
            ----------------------------------------------------
            UPDATE dbo.usersPassword
            SET 
                userPasswordActive  = 0,
                userPasswordEndDate = CAST(GETDATE() AS DATE)
            WHERE usersID_FK = @usersID
              AND ISNULL(userPasswordActive, 1) = 1;

            ----------------------------------------------------
            -- 5) Create new Salt and Hash
            ----------------------------------------------------
            SET @Salt = CRYPT_GEN_RANDOM(32);
            SET @Hash = HASHBYTES(
                            'SHA2_256',
                            @Salt + CAST(@PlainPassword AS VARBINARY(200))
                        );

            ----------------------------------------------------
            -- 6) Insert new password
            ----------------------------------------------------
            INSERT INTO dbo.usersPassword
            (
                usersID_FK,
                PasswordHash,
                PasswordSalt,
                HashAlgorithm,
                userPasswordStartDate,
                userPasswordActive,
                ChangedPassword,
                entryDate,
                entryData,
                hostName
            )
            VALUES
            (
                @usersID,
                @Hash,
                @Salt,
                'SHA2_256',
                CAST(GETDATE() AS DATE),
                1,
                1,  -- User changed their own password
                GETDATE(),
                @entryData,
                ISNULL(@hostName, HOST_NAME())
            );

            SELECT 1 AS IsSuccessful, N'تم تغيير كلمة المرور بنجاح' AS Message_;
            
            IF @tc = 0
                COMMIT TRAN;
                
            RETURN;
        END


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
