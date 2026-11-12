CREATE   PROCEDURE VIC.VehicleUserDL
(
      @ActionType    NVARCHAR(100)
    , @vehicleUserID INT            = NULL
    , @generalNo     BIGINT         = NULL
    , @nationalID    NVARCHAR(20)   = NULL
    , @IdaraID_FK    NVARCHAR(10)   = NULL
    , @userActive    BIT            = NULL
    , @pageNumber    INT            = 1
    , @pageSize      INT            = 50
    , @q             NVARCHAR(200)  = NULL
    , @top           INT            = 20
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@IdaraID_FK)), N''));
    SET @q = NULLIF(LTRIM(RTRIM(@q)), N'');

    IF @ActionType = 'GET'
    BEGIN
        IF @vehicleUserID IS NULL OR @vehicleUserID <= 0
        BEGIN THROW 50001, N'معرف مستخدم المركبة مطلوب', 1; RETURN; END

        SELECT
              u.vehicleUserID, u.generalNo, u.nationalID, u.mobileNo
            , u.IdaraID_FK, u.userActive, u.entryDate, u.entryData, u.hostName
            , ud.vehicleUserDetailsID, ud.generalNo_Snapshot
            , ud.rankID_FK, r.rankName_A, r.rankName_E
            , ud.nationalityID_FK, n.nationalityName_A, n.nationalityName_E
            , ud.genderID_FK, g.genderName_A, g.genderName_E
            , ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A
            , ud.firstName_E, ud.secondName_E, ud.thirdName_E, ud.lastName_E
            , ud.note, ud.detailsStartDate, ud.detailsEndDate, ud.detailsActive
        FROM VIC.VehicleUser u
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        LEFT JOIN VIC.VehicleNationality n ON n.nationalityID = ud.nationalityID_FK
        LEFT JOIN VIC.VehicleGender g ON g.genderID = ud.genderID_FK
        WHERE u.vehicleUserID = @vehicleUserID;
        RETURN;
    END

    IF @ActionType = 'LIST'
    BEGIN
        SELECT
              u.vehicleUserID, u.generalNo, u.nationalID, u.mobileNo
            , u.IdaraID_FK, u.userActive, u.entryDate
            , ud.rankID_FK, r.rankName_A
            , ud.nationalityID_FK, n.nationalityName_A
            , ud.genderID_FK, g.genderName_A
            , ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A
        FROM VIC.VehicleUser u
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        LEFT JOIN VIC.VehicleNationality n ON n.nationalityID = ud.nationalityID_FK
        LEFT JOIN VIC.VehicleGender g ON g.genderID = ud.genderID_FK
        WHERE 1 = 1
          AND (@IdaraID_BIG IS NULL OR u.IdaraID_FK = @IdaraID_BIG)
          AND (@generalNo IS NULL OR u.generalNo = @generalNo)
          AND (@nationalID IS NULL OR u.nationalID = @nationalID)
          AND (@userActive IS NULL OR u.userActive = @userActive)
        ORDER BY u.generalNo
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    IF @ActionType = 'SEARCH'
    BEGIN
        IF @IdaraID_BIG IS NULL
        BEGIN THROW 50001, N'معرف الإدارة مطلوب للبحث عن المستخدم', 1; RETURN; END
        IF @q IS NULL AND @generalNo IS NULL
        BEGIN SELECT CAST(0 AS INT) AS dummy; RETURN; END

        DECLARE @TopN INT = CASE WHEN @top IS NULL OR @top < 1 OR @top > 100 THEN 20 ELSE @top END;

        SELECT TOP (@TopN)
              u.vehicleUserID, u.generalNo, u.nationalID, u.mobileNo
            , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS UserFullName_A
            , r.rankName_A
            , ud.rankID_FK, ud.nationalityID_FK, ud.genderID_FK
            , ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A
        FROM VIC.VehicleUser u
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        WHERE u.IdaraID_FK = @IdaraID_BIG AND u.userActive = 1
          AND (
                (@generalNo IS NOT NULL AND u.generalNo = @generalNo)
             OR (@q IS NOT NULL AND (
                    CAST(u.generalNo AS NVARCHAR(50)) LIKE N'%' + @q + N'%'
                 OR u.nationalID LIKE N'%' + @q + N'%'
                 OR CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) LIKE N'%' + @q + N'%'
                ))
          )
        ORDER BY u.generalNo;
        RETURN;
    END

    IF @ActionType = 'DDL_RANK'
    BEGIN
        SELECT rankID AS [Value], rankName_A AS [Text]
        FROM VIC.VehicleRank WHERE rankActive = 1 ORDER BY rankName_A;
        RETURN;
    END

    IF @ActionType = 'DDL_GENDER'
    BEGIN
        SELECT genderID AS [Value], genderName_A AS [Text]
        FROM VIC.VehicleGender ORDER BY genderName_A;
        RETURN;
    END

    IF @ActionType = 'DDL_NATIONALITY'
    BEGIN
        SELECT nationalityID AS [Value], nationalityName_A AS [Text]
        FROM VIC.VehicleNationality WHERE nationalityActive = 1 ORDER BY nationalityName_A;
        RETURN;
    END

    BEGIN THROW 50001, N'نوع العملية غير معروف في إجراء بيانات مستخدمي المركبات', 1; RETURN; END
END

GO

