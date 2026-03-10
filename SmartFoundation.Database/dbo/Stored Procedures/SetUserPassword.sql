CREATE   PROCEDURE [dbo].[SetUserPassword]
(
    @NationalID          NVARCHAR(20),     -- الرقم العام / رقم المستخدم
    @PlainPassword   NVARCHAR(200),    -- كلمة المرور الجديدة
    @entryData       NVARCHAR(20),     -- المستخدم الذي قام بالتعديل
    @hostName        NVARCHAR(200) = NULL,
    @IsSuccessful    BIT OUTPUT,
    @Message_        NVARCHAR(4000) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @IsSuccessful = 0;
    SET @Message_ = N'';

    DECLARE @usersID bigint;
    set @usersID = (
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

        ----------------------------------------------------
        -- 0) التحقق أن المستخدم موجود وفعال في جدول [User]
        ----------------------------------------------------
        IF NOT EXISTS (
            SELECT 1   
              from  dbo.Users u 
              where u.nationalID = @NationalID
              and u.usersActive = 1 
              and u.usersStartDate is not null 
              and cast(u.usersStartDate as date) <= cast(GETDATE() as date)
              and((cast(u.usersEndDate as date) > cast(GETDATE() as date)) OR u.usersEndDate is null)
             
        )
        BEGIN
           SET @IsSuccessful = 0;
SET @Message_ = N'المستخدم غير موجود أو غير فعّال في النظام.';
RETURN;

            
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
        SELECT TOP (1)
            @PrevSalt = PasswordSalt,
            @PrevHash = PasswordHash
        FROM dbo.usersPassword p
        WHERE p.usersID_FK = @UsersID
          AND ISNULL(userPasswordActive, 1) = 1
        ORDER BY userPasswordStartDate DESC, usersPasswordID DESC;

        IF @PrevHash IS NOT NULL
        BEGIN
            SET @Candidate = HASHBYTES(
                                'SHA2_256',
                                @PrevSalt + CAST(@PlainPassword AS VARBINARY(200))
                             );

            IF @Candidate = @PrevHash
            BEGIN
              
                      SET @IsSuccessful = 0;
                      SET @Message_ = N'لا يمكن استخدام نفس كلمة المرور السابقة. الرجاء اختيار كلمة مرور جديدة مختلفة.';
                RETURN;
            END
        END


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
                        @Salt + CAST(@PlainPassword AS VARBINARY(200))
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

        SET @IsSuccessful = 1;
        SET @Message_ = N'تم تحديث كلمة المرور / إنشاؤها بنجاح.';
        RETURN;



    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            SET @IsSuccessful = 0;
            SET @Message_ = N'حصل خطأ أثناء تنفيذ العملية: ' + ERROR_MESSAGE();
            RETURN;

        
    END CATCH
END
