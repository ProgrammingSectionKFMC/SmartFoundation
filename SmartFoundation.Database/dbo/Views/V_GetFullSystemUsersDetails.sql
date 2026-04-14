CREATE VIEW [dbo].[V_GetFullSystemUsersDetails]
AS
WITH LastUserDetails AS
(
    SELECT
        ud.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY ud.usersID_FK
            ORDER BY ud.entryDate DESC, ud.usersDetailsID DESC
        ) AS rn
    FROM dbo.UsersDetails ud
),
LastEntryUserDetails AS
(
    SELECT
        eud.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY eud.usersID_FK
            ORDER BY eud.entryDate DESC, eud.usersDetailsID DESC
        ) AS rn
    FROM dbo.UsersDetails eud
),
LastInactiveDetails AS
(
    SELECT
        ud.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY ud.usersID_FK
            ORDER BY ud.entryDate DESC, ud.usersDetailsID DESC
        ) AS rn
    FROM dbo.UsersDetails ud
    WHERE ud.userActive = 0
)
SELECT
    u.usersID,
    u.nationalID,
    lud.GeneralNo,

    LTRIM(RTRIM(
        ISNULL(lud.firstName_A, N'') + N' ' +
        ISNULL(lud.secondName_A, N'') + N' ' +
        ISNULL(lud.thirdName_A, N'') + N' ' +
        ISNULL(lud.forthName_A, N'') + N' ' +
        ISNULL(lud.lastName_A, N'')
    )) AS FullName,

    -- الاسم عربي مفصل
    lud.firstName_A,
    lud.secondName_A,
    lud.thirdName_A,
    lud.forthName_A,
    lud.lastName_A,

    -- الاسم إنجليزي مفصل
    lud.firstName_E,
    lud.secondName_E,
    lud.thirdName_E,
    lud.forthName_E,
    lud.lastName_E,

    -- نوع المستخدم
    lud.userTypeID_FK,
    uty.userTypeName_A,

    -- نوع التفويض / الصلاحية
    lud.usersAuthTypeID_FK AS UsersAuthTypeID,
    ua.UsersAuthTypeName_A,

    -- الحالة الحالية
    lud.userActive,
    CASE
        WHEN lud.userActive = 1 THEN N'نشط'
        WHEN lud.userActive = 0 THEN N'معطل'
        ELSE N'غير محدد'
    END AS ActiveStatus,

    -- آخر سبب تعطيل للمستخدم
    NULLIF(LTRIM(RTRIM(lid.userNote)), N'') AS InactiveReason,

    -- ملاحظة آخر سجل حالي
    lud.userNote,

    -- بيانات آخر تعطيل
    lid.entryDate AS LastInactiveDate,
    CONVERT(nvarchar(10), lid.entryDate, 23) + N' ' + CONVERT(nvarchar(8), lid.entryDate, 108) AS LastInactiveDateText,

    -- الإدارة
    lud.IdaraID,
    id.idaraLongName_A,

    -- التواريخ والبيانات الإضافية
    lud.entryDate,
    CONVERT(nvarchar(10), lud.entryDate, 23) + N' ' + CONVERT(nvarchar(8), lud.entryDate, 108) AS entryDateText,
    lud.entryData,

    lud.nationalIDIssueDate,
    lud.dateOfBirth,
    lud.genderID_FK,
    lud.nationalityID_FK,
    lud.religionID_FK,
    lud.maritalStatusID_FK,
    lud.educationID_FK,

    -- اسم منفذ الإجراء
    LTRIM(RTRIM(
        ISNULL(leud.firstName_A, N'') + N' ' +
        ISNULL(leud.secondName_A, N'') + N' ' +
        ISNULL(leud.thirdName_A, N'') + N' ' +
        ISNULL(leud.forthName_A, N'') + N' ' +
        ISNULL(leud.lastName_A, N'')
    )) AS EntryFullName

FROM dbo.Users u
LEFT JOIN LastUserDetails lud
    ON u.usersID = lud.usersID_FK
   AND lud.rn = 1
LEFT JOIN LastInactiveDetails lid
    ON u.usersID = lid.usersID_FK
   AND lid.rn = 1
LEFT JOIN dbo.UsersAuthType ua
    ON lud.usersAuthTypeID_FK = ua.UsersAuthTypeID
LEFT JOIN dbo.UserType uty
    ON lud.userTypeID_FK = uty.userTypeID
LEFT JOIN dbo.Idara id
    ON lud.IdaraID = id.idaraID
LEFT JOIN dbo.Users eu
    ON lud.entryData = eu.usersID
LEFT JOIN LastEntryUserDetails leud
    ON eu.usersID = leud.usersID_FK
   AND leud.rn = 1;

GO



GO



GO
