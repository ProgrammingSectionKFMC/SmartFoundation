

CREATE PROCEDURE [dbo].[GetSessionInfoForMVC]
    @NationalID NVARCHAR(20),
    @Password Nvarchar(200),
    @hostName Nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @usersID bigint;
    DECLARE @GeneralNo bigint;

    SET @usersID = (
        SELECT TOP(1) u.usersID
        FROM  dbo.Users u 
        WHERE u.nationalID = @NationalID
          AND u.usersActive = 1 
          AND u.usersStartDate IS NOT NULL 
          AND CAST(u.usersStartDate AS date) <= CAST(GETDATE() AS date)
          AND ((CAST(u.usersEndDate AS date) > CAST(GETDATE() AS date)) OR u.usersEndDate IS NULL)
        ORDER BY u.usersID DESC
    );

    -- ✅ تعديل ضروري: لو ما حصل مستخدم، اطلع مباشرة (بدون تكملة)
    IF @usersID IS NULL
    BEGIN
        SELECT
            0 AS userActive,
            N'عذرا لايوجد حساب نشط بالنظام لصاحب الهوية رقم : ' + CONVERT(nvarchar(20), @NationalID) AS Message_;
        RETURN;
    END

    DECLARE @Salt VARBINARY(32);
    DECLARE @StoredHash VARBINARY(64);
    DECLARE @PasswordResult int;

    -- هل يوجد كلمة مرور للمستخدم؟
    IF NOT EXISTS (
        SELECT 1 
        FROM  dbo.usersPassword us
        WHERE us.usersID_FK = @usersID AND us.userPasswordActive = 1
    )
    BEGIN
        SET @PasswordResult = 3;   -- لا يوجد كلمة مرور
    END
    ELSE
    BEGIN
        -- جلب الهاش والسولت
        SELECT TOP (1)
            @Salt = PasswordSalt,
            @StoredHash = PasswordHash
        FROM  dbo.usersPassword
        WHERE usersID_FK = @usersID
          AND userPasswordActive = 1
        ORDER BY entryDate DESC;

        -- فحص كلمة المرور
        IF @StoredHash = HASHBYTES('SHA2_256', @Salt + CAST(@Password AS VARBINARY(200)))
        BEGIN
            SET @PasswordResult = 1;  -- كلمة المرور صحيحة
        END
        ELSE
        BEGIN
            SET @PasswordResult = 0;  -- كلمة المرور خاطئة
        END
    END

    IF (SELECT COUNT(us.usersID) FROM  dbo.[Users] us WHERE us.usersID = @usersID) > 0
    BEGIN
        -- ✅ تعديل ضروري: TRY_CONVERT لتفادي تحويل NVARCHAR إلى BIGINT
        SET @GeneralNo = (
            SELECT TOP(1) TRY_CONVERT(bigint, LTRIM(RTRIM(ud.GeneralNo)))
            FROM  dbo.[Users] us 
            INNER JOIN  dbo.UsersDetails ud ON us.usersID = ud.usersID_FK
            WHERE us.usersID = @usersID
              AND us.usersActive = 1 
              AND us.usersStartDate IS NOT NULL 
              AND CAST(us.usersStartDate AS date) <= CAST(GETDATE() AS date)
              AND ((CAST(us.usersEndDate AS date) > CAST(GETDATE() AS date)) OR us.usersEndDate IS NULL)
            ORDER BY us.entryDate DESC
        );

        IF @GeneralNo IS NULL
            SET @GeneralNo = -99;
    END
    ELSE
    BEGIN
        SET @GeneralNo = -99;
    END

    -- Create a temporary table to store the department info
    DECLARE @DepartmentInfo TABLE (
        UserID bigINT,
        OrganizationName NVARCHAR(255),
        IdaraName NVARCHAR(255),
        DepartmentName NVARCHAR(255),
        SectionName NVARCHAR(255),
        DivisonName NVARCHAR(255),
        DeptCode nvarchar(20),
        OrganizationID INT,
        IdaraID INT,
        DepartmentID INT,
        SectionID INT,
        DivisonID INT
    );

    DECLARE @ThameInfo TABLE (
        UserID bigINT,
        ThameName NVARCHAR(255)
    );

    -- Get the department info first
    INSERT INTO @DepartmentInfo (UserID,OrganizationName,IdaraName, DepartmentName,SectionName,DivisonName, DeptCode,OrganizationID,IdaraID,DepartmentID,SectionID,DivisonID)
    SELECT TOP 1 
        udsd.usersID,
        dsd.OrganizationName,
        dsd.IdaraName,
        dsd.DepartmentName,
        dsd.SectionName,
        dsd.DivisonName,
        d.deptCode,
        dsd.OrganizationID,
        dsd.IdaraID,
        dsd.DepartmentID,
        dsd.SectionID,
        dsd.DivisonID
    FROM dbo.V_GetFullStructureForDSD dsd
    INNER JOIN dbo.V_GetListUsersInDSD udsd ON dsd.DSDID = udsd.DSDID
    left JOIN dbo.Department d ON dsd.DepartmentID = d.deptID
    WHERE udsd.usersID = @usersID;

    -- Combine the user and department information along with photo from Payroll database
    IF (@GeneralNo = -99)
    BEGIN
        SELECT
            0 AS userActive,
            -- ✅ تعديل ضروري: لا تجمع نص مع BIGINT مباشرة
            N'عذرا لايوجد حساب مسجل بالنظام لصاحب الهوية رقم : ' + CONVERT(nvarchar(20), @NationalID) AS Message_;
    END
    ELSE
    BEGIN
        IF (SELECT COUNT(*) 
        FROM  dbo.[Users] uu
        Left JOIN  dbo.UsersDetails ud ON uu.usersID = ud.usersID_FK
        left Join  dbo.UsersAuthType ua on ud.usersAuthTypeID_FK = ua.UsersAuthTypeID
        WHERE uu.usersID = @usersID 
        AND uu.usersActive = 1 and ud.userActive = 1) > 0
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM dbo.[Users] u
                LEFT JOIN @DepartmentInfo d ON u.usersID = d.UserID
                LEFT JOIN @ThameInfo t ON u.usersID = t.UserID
                WHERE u.usersID = @usersID
                  AND u.usersActive = 1
                  AND d.IdaraID IS NOT NULL
                  AND d.DepartmentName IS NOT NULL
            ) > 0
            BEGIN
                IF (@PasswordResult = 1)
                BEGIN
                    SELECT TOP(1)
                        CONCAT_WS(' ', ud.firstName_A, ud.secondName_A, ud.lastName_A) AS fullName, 
                        u.usersID,
                        d.OrganizationID,
                        d.OrganizationName,
                        d.IdaraID,
                        d.IdaraName,
                        d.DepartmentID,
                        d.DepartmentName,
                        d.SectionID,
                        d.SectionName,
                        d.DivisonID,
                        d.DivisonName,
                        (SELECT Photo FROM  dbo.UsersPhoto up WHERE up.usersID_FK = @usersID) AS Photo,
                        CASE WHEN t.ThameName IS NULL THEN 'default' ELSE t.ThameName END AS ThameName,
                        d.DeptCode,
                        u.nationalID,
                        u.usersActive,
                        isNULL(ud.usersAuthTypeID_FK,3) AdminTypeID,
                        isNULL(ua.UsersAuthTypeName_A,N'مستخدم عادي') AdminTypeName,
                        @GeneralNo AS GeneralNo,
                        N'مرحبا بك : ' + CONCAT_WS(' ', ud.firstName_A, ud.secondName_A, ud.lastName_A)
                        + N' تم تسجيل دخولك للنظام في ' + CONVERT(nvarchar(10), GETDATE(), 111)
                        + N' الساعة ' + CONVERT(nvarchar(8), GETDATE(), 108) AS Message_,
                        up.ChangedPassword
                    FROM dbo.[Users] u
                    Left JOIN  dbo.UsersDetails ud ON u.usersID = ud.usersID_FK
                    left Join  dbo.UsersAuthType ua on ud.usersAuthTypeID_FK = ua.UsersAuthTypeID
                    LEFT JOIN @DepartmentInfo d ON u.usersID = d.UserID
                    LEFT JOIN @ThameInfo t ON u.usersID = t.UserID
                    inner Join  dbo.UsersPassword up on u.usersID = up.usersID_FK and up.userPasswordActive = 1
                    WHERE u.usersID = @usersID AND u.usersActive = 1 And ud.userActive = 1
                    order by u.usersID desc
                    ;
                END
                ELSE IF (@PasswordResult = 0)
                BEGIN
                    SELECT
                        0 AS userActive,
                        N'عذرا اسم المستخدم او كلمة المرور غير صحيحة' AS Message_;
                END
                ELSE IF (@PasswordResult = 3)
                BEGIN
                    SELECT
                        0 AS userActive,
                        N'يجب اعادة ضبط كلمة المرور للمستخدم' AS Message_;
                END
            END
            ELSE
            BEGIN
                SELECT
                    0 AS userActive,
                    -- ✅ تعديل ضروري: استخدم الهوية، وتأكد التحويل النصي
                    N'عذرا يوجد خطأ بالهيكل الاداري لصاحب الهوية رقم : ' + CONVERT(nvarchar(20), @NationalID) AS Message_;
            END
        END
        ELSE
        BEGIN
            SELECT
                0 AS userActive,
                N'عذرا لايوجد حساب نشط بالنظام لصاحب الهوية رقم : ' + CONVERT(nvarchar(20), @NationalID) AS Message_;
        END
    END
END;
