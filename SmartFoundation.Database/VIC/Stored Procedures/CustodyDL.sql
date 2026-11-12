CREATE   PROCEDURE VIC.CustodyDL
(
      @ActionType        NVARCHAR(100)
    , @vehicleID         INT            = NULL
    , @vehicleUserID     INT            = NULL
    , @generalNo         BIGINT         = NULL
    , @chassisNumber     NVARCHAR(200)  = NULL
    , @fromDate          DATETIME       = NULL
    , @toDate            DATETIME       = NULL
    , @pageNumber        INT            = 1
    , @pageSize          INT            = 50
    , @idaraID_FK        NVARCHAR(10)   = NULL
    , @vehicleHandoverID INT            = NULL
    , @handoverTypeID    INT            = NULL
    , @activeOnly        BIT            = 0
    , @searchUser        NVARCHAR(200)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
        SELECT @CH = v.chassisNumber, @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.vehicleID = @vehicleID;
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        SELECT @VID = v.vehicleID FROM VIC.Vehicles v WHERE v.chassisNumber = @CH;
    END

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;
    DECLARE @GN BIGINT = @generalNo;
    DECLARE @top INT = 20;
    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @SU NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@searchUser)), N'');

    IF @ActionType = 'CURRENT_LIST'
    BEGIN
        SELECT
              vw.vehicleWithUsersID, vw.vehicleUserID_FK, vw.vehicleID_FK, vw.chassisNumber_FK
            , vw.startDate, vw.endDate, vw.note, vw.entryDate, vw.entryData, vw.hostName
            , v.vehicleID, v.plateLetters, v.plateNumbers, v.armyNumber, v.yearModel, v.vehicleStatusID_FK
            , vw.GeneralNo_Snapshot, vw.UserFullName_Snapshot, vw.RankName_Snapshot, vw.MilitaryUnitName_Snapshot
            , u.generalNo AS GeneralNo_Current, u.nationalID AS NationalID_Current, u.mobileNo AS MobileNo_Current
            , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS UserFullName_A_Current
            , r.rankName_A AS RankName_Current
        FROM VIC.vehicleWithUsers vw
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = vw.chassisNumber_FK
        LEFT JOIN VIC.VehicleUser u ON u.vehicleUserID = vw.vehicleUserID_FK
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        WHERE vw.endDate IS NULL
          AND (@vehicleUserID IS NULL OR vw.vehicleUserID_FK = @vehicleUserID)
          AND (@CH IS NULL OR vw.chassisNumber_FK = @CH)
          AND (@GN IS NULL OR u.generalNo = @GN OR vw.GeneralNo_Snapshot = CAST(@GN AS NVARCHAR(50)))
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        ORDER BY vw.startDate DESC OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    IF @ActionType = 'HISTORY_LIST'
    BEGIN
        SELECT
              vw.vehicleWithUsersID, vw.vehicleUserID_FK, vw.vehicleID_FK, vw.chassisNumber_FK
            , vw.startDate, vw.endDate, vw.note, vw.entryDate, vw.entryData, vw.hostName
            , v.vehicleID, v.plateLetters, v.plateNumbers, v.armyNumber, v.yearModel
            , vw.GeneralNo_Snapshot, vw.UserFullName_Snapshot, vw.RankName_Snapshot, vw.MilitaryUnitName_Snapshot
            , u.generalNo AS GeneralNo_Current, u.nationalID AS NationalID_Current, u.mobileNo AS MobileNo_Current
            , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS UserFullName_A_Current
            , r.rankName_A AS RankName_Current
            , CASE WHEN vw.endDate IS NULL THEN N'نشطة' ELSE N'مغلقة' END AS CustodyStatusText
        FROM VIC.vehicleWithUsers vw
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = vw.chassisNumber_FK
        LEFT JOIN VIC.VehicleUser u ON u.vehicleUserID = vw.vehicleUserID_FK
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        WHERE 1 = 1
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
          AND (@CH IS NULL OR vw.chassisNumber_FK = @CH)
          AND (@fromDate IS NULL OR vw.startDate >= @fromDate)
          AND (@toDate   IS NULL OR vw.startDate <  DATEADD(DAY, 1, @toDate))
          AND (@GN IS NULL OR u.generalNo = @GN OR vw.GeneralNo_Snapshot = CAST(@GN AS NVARCHAR(50)))
          AND (@SU IS NULL
               OR u.generalNo LIKE N'%' + @SU + N'%'
               OR vw.GeneralNo_Snapshot LIKE N'%' + @SU + N'%'
               OR vw.UserFullName_Snapshot LIKE N'%' + @SU + N'%'
               OR CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) LIKE N'%' + @SU + N'%')
        ORDER BY vw.startDate DESC, vw.entryDate DESC OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    IF @ActionType = 'GET_HANDOVER'
    BEGIN
        IF @vehicleHandoverID IS NULL OR @vehicleHandoverID <= 0 BEGIN THROW 50001, N'معرف محضر التسليم والاستلام مطلوب', 1; RETURN; END
        SELECT h.VehicleHandoverID, h.handOverTypeID_FK, h.handoverDate, h.note, h.entryDate, h.entryData, h.hostName, h.IdaraID_FK, h.chassisNumber_FK, h.vehicleID_FK, h.vehicleUserID_FK
             , v.vehicleID, v.plateLetters, v.plateNumbers
             , t.handOverTypeName_A, t.handOverTypeName_E
             , u.generalNo AS CustodianGeneralNo
             , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS CustodianFullName_A
        FROM VIC.VehicleHandover h
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = h.chassisNumber_FK
        INNER JOIN VIC.HandoverType t ON t.handOverTypeID = h.handOverTypeID_FK
        LEFT JOIN VIC.VehicleUser u ON u.vehicleUserID = h.vehicleUserID_FK
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        WHERE h.VehicleHandoverID = @vehicleHandoverID AND (@IdaraID_BIG IS NULL OR h.IdaraID_FK = @IdaraID_BIG);
        RETURN;
    END

    IF @ActionType = 'LIST_HANDOVER'
    BEGIN
        SELECT h.VehicleHandoverID, h.handOverTypeID_FK, h.handoverDate, h.note, h.entryDate, h.entryData, h.hostName, h.IdaraID_FK, h.chassisNumber_FK, h.vehicleID_FK, h.vehicleUserID_FK
             , v.vehicleID, v.plateLetters, v.plateNumbers
             , t.handOverTypeName_A, t.handOverTypeName_E
             , u.generalNo AS CustodianGeneralNo
             , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS CustodianFullName_A
        FROM VIC.VehicleHandover h
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = h.chassisNumber_FK
        INNER JOIN VIC.HandoverType t ON t.handOverTypeID = h.handOverTypeID_FK
        LEFT JOIN VIC.VehicleUser u ON u.vehicleUserID = h.vehicleUserID_FK
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        WHERE 1 = 1
          AND (@handoverTypeID IS NULL OR h.handOverTypeID_FK = @handoverTypeID)
          AND (@fromDate IS NULL OR h.handoverDate >= @fromDate)
          AND (@toDate   IS NULL OR h.handoverDate <  DATEADD(DAY, 1, @toDate))
          AND (@IdaraID_BIG IS NULL OR h.IdaraID_FK = @IdaraID_BIG)
        ORDER BY h.handoverDate DESC, h.VehicleHandoverID DESC OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
        RETURN;
    END

    IF @ActionType = 'PRINT_HANDOVER'
    BEGIN
        IF @vehicleHandoverID IS NULL OR @vehicleHandoverID <= 0 BEGIN THROW 50001, N'معرف محضر التسليم والاستلام مطلوب', 1; RETURN; END
        SELECT h.VehicleHandoverID, h.handoverDate, h.note, h.IdaraID_FK, h.chassisNumber_FK
             , t.handOverTypeName_A, t.handOverTypeName_E
             , v.vehicleID, v.plateLetters, v.plateNumbers, v.armyNumber, v.yearModel
             , u.generalNo AS CustodianGeneralNo, u.nationalID AS CustodianNationalID, u.mobileNo AS CustodianMobileNo
             , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS CustodianFullName_A
             , r.rankName_A AS CustodianRankName
        FROM VIC.VehicleHandover h
        INNER JOIN VIC.HandoverType t ON t.handOverTypeID = h.handOverTypeID_FK
        INNER JOIN VIC.Vehicles v ON v.chassisNumber = h.chassisNumber_FK
        LEFT JOIN VIC.VehicleUser u ON u.vehicleUserID = h.vehicleUserID_FK
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        WHERE h.VehicleHandoverID = @vehicleHandoverID AND (@IdaraID_BIG IS NULL OR h.IdaraID_FK = @IdaraID_BIG);
        RETURN;
    END

    IF @ActionType = 'LIST_HANDOVER_TYPE'
    BEGIN
        SELECT ht.handOverTypeID, ht.handOverTypeName_A, ht.handOverTypeName_E, ht.active
        FROM VIC.HandoverType ht WHERE (@activeOnly = 0 OR ISNULL(ht.active, 1) = 1) ORDER BY ht.handOverTypeName_A;
        RETURN;
    END

    IF @ActionType = 'SEARCH_USERS'
    BEGIN
        DECLARE @Q NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
        IF @IdaraID_BIG IS NULL BEGIN THROW 50001, N'معرف الإدارة مطلوب للبحث عن المستخدم', 1; RETURN; END
        IF @Q IS NULL AND @GN IS NULL BEGIN SELECT CAST(0 AS INT) AS dummy; RETURN; END

        SELECT TOP (ISNULL(@top, 20))
              u.vehicleUserID, u.generalNo, u.nationalID, u.mobileNo
            , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS UserFullName_A
            , r.rankName_A
            , ud.rankID_FK, ud.nationalityID_FK, ud.genderID_FK
            , ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A
        FROM VIC.VehicleUser u
        LEFT JOIN VIC.VehicleUserDetails ud ON ud.vehicleUserID_FK = u.vehicleUserID AND ud.detailsActive = 1
        LEFT JOIN VIC.VehicleRank r ON r.rankID = ud.rankID_FK
        WHERE u.IdaraID_FK = @IdaraID_BIG AND u.userActive = 1
          AND ((@GN IS NOT NULL AND u.generalNo = @GN)
            OR (@Q IS NOT NULL AND (CAST(u.generalNo AS NVARCHAR(50)) LIKE N'%' + @Q + N'%'
                 OR u.nationalID LIKE N'%' + @Q + N'%'
                 OR CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) LIKE N'%' + @Q + N'%')))
        ORDER BY u.generalNo;
        RETURN;
    END

    BEGIN THROW 50001, N'نوع العملية غير معروف في إجراء بيانات العهد', 1; RETURN; END
END

GO

