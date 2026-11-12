
/* ORIGINAL PROCEDURE VIC.TransferRequestDL */
CREATE PROCEDURE [VIC].[TransferRequestDL]
    @ActionType NVARCHAR(100)
    , @requestID INT = NULL
    , @vehicleID INT = NULL
    , @chassisNumber NVARCHAR(200) = NULL
    , @fromUserID BIGINT = NULL
    , @toUserID BIGINT = NULL
    , @userID BIGINT = NULL
    , @idaraID_FK NVARCHAR(10) = NULL
    , @pageNumber INT = 1
    , @pageSize INT = 50
    , @activeOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));
    DECLARE @P INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(200);
    DECLARE @VID INT;

    IF @vehicleID IS NOT NULL
    BEGIN
        SELECT
              @CH = v.chassisNumber
            , @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.vehicleID = @vehicleID;

        IF @CH IS NULL
        BEGIN
            THROW 50001, N'المركبة غير موجودة برقم المركبة الداخلي', 1;
            RETURN;
        END
    END
    ELSE IF @chassisNumber IS NOT NULL
    BEGIN
        SET @CH = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

        SELECT @VID = v.vehicleID
        FROM VIC.Vehicles v
        WHERE v.chassisNumber = @CH;
    END

    ----------------------------------------------------------------
    -- GET
    ----------------------------------------------------------------
    IF @ActionType = N'GET'
    BEGIN
        IF @requestID IS NULL OR @requestID <= 0
        BEGIN
            THROW 50001, N'رقم الطلب مطلوب', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.active
            , r.entryDate
            , r.entryData
            , r.hostName
            , r.IdaraID_FK
            , hLast.Status       AS LastStatus
            , hLast.ActionDate   AS LastActionDate
            , rt.VehicleTransferRequestTypeNameA
            , rt.VehicleTransferRequestTypeNameE
            , v.vehicleID
        FROM VIC.VehicleTransferRequest r
        OUTER APPLY
        (
            SELECT TOP (1)
                  h.Status
                , h.ActionDate
            FROM VIC.VehicleTransferRequestHistory h
            WHERE h.RequestID_FK = r.RequestID
            ORDER BY h.ActionDate DESC, h.HistoryID DESC
        ) hLast
        LEFT JOIN VIC.VehicleTransferRequestType rt
            ON rt.VehicleTransferRequestTypeID = r.RequestTypeID_FK
        LEFT JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        WHERE r.RequestID = @requestID
          AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG);

        RETURN;
    END

    ----------------------------------------------------------------
    -- PENDING
    ----------------------------------------------------------------
    IF @ActionType = N'PENDING'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @CurrentDeptID INT = NULL;

        SELECT TOP (1)
            @CurrentDeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.Users u
        INNER JOIN DATACORE.dbo.UsersDetails ud
            ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
        LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
            ON fs.DSDID = (
                SELECT TOP 1 ds.DSDID_FK
                FROM DATACORE.dbo.UserDistributor d2
                INNER JOIN DATACORE.dbo.Distributor ds
                    ON ds.distributorID = d2.distributorID_FK
                    AND ds.distributorActive = 1
                    AND ds.distributorType_FK = 1
                    AND ds.DSDID_FK IS NOT NULL
                WHERE d2.userID_FK = u.usersID
                  AND d2.UDActive = 1
                  AND d2.UDStartDate IS NOT NULL
                  AND d2.UDEndDate IS NULL
                ORDER BY d2.UDStartDate DESC
            )
        WHERE u.usersID = @userID;

        IF @CurrentDeptID IS NULL
        BEGIN
            THROW 50001, N'تعذر تحديد قسم المستخدم', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.entryDate
            , r.active

            , v.vehicleID
            , v.plateNumbers
            , v.plateLetters
            , v.armyNumber

            , f.UserFullName_Snapshot AS FromUserName

            , h.Status     AS LastStatus
            , h.ActionDate AS LastActionDate

            , t.UserFullName_A AS ToUserName
        FROM VIC.VehicleTransferRequest r
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        LEFT JOIN VIC.vehicleWithUsers f
            ON f.chassisNumber_FK = r.chassisNumber_FK
           AND f.userID_FK = r.fromUserID_FK
           AND f.endDate IS NULL
        CROSS APPLY
        (
            SELECT TOP (1)
                  h1.Status
                , h1.ActionDate
            FROM VIC.VehicleTransferRequestHistory h1
            WHERE h1.RequestID_FK = r.RequestID
            ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
        ) h
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', ud2.firstName_A, ud2.secondName_A, ud2.thirdName_A, ud2.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users u2
            INNER JOIN DATACORE.dbo.UsersDetails ud2
                ON ud2.usersID_FK = u2.usersID AND ISNULL(ud2.userActive, 0) = 1
            WHERE u2.usersID = r.toUserID_FK
        ) t
        WHERE r.IdaraID_FK = @IdaraID_BIG
          AND r.deptID_FK = @CurrentDeptID
          AND ISNULL(r.active, 0) = 1
          AND h.Status = N'Created'
          AND v.IdaraID_FK = @IdaraID_BIG
        ORDER BY r.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- APPROVED_LIST
    ----------------------------------------------------------------
    IF @ActionType = N'APPROVED_LIST'
    BEGIN
        ;WITH R AS
        (
            SELECT
                  r.RequestID
                , r.RequestTypeID_FK
                , r.chassisNumber_FK
                , r.fromUserID_FK
                , r.toUserID_FK
                , r.deptID_FK
                , r.CreateByUser
                , r.aproveNote
                , r.active
                , r.IdaraID_FK
                , r.entryDate
                , r.entryData
                , r.hostName
                , hLast.HistoryID   AS LastHistoryID
                , hLast.Status      AS LastStatus
                , hLast.ActionBy    AS LastActionBy
                , hLast.ActionDate  AS LastActionDate
                , hLast.Notes       AS LastNotes
            FROM VIC.VehicleTransferRequest r
            OUTER APPLY
            (
                SELECT TOP (1)
                      h.HistoryID
                    , h.Status
                    , h.ActionBy
                    , h.ActionDate
                    , h.Notes
                FROM VIC.VehicleTransferRequestHistory h
                WHERE h.RequestID_FK = r.RequestID
                ORDER BY h.ActionDate DESC, h.HistoryID DESC
            ) hLast
            WHERE 1 = 1
              AND (@requestID IS NULL OR r.RequestID = @requestID)
              AND (@CH IS NULL OR r.chassisNumber_FK = @CH)
              AND (@fromUserID IS NULL OR r.fromUserID_FK = @fromUserID)
              AND (@toUserID IS NULL OR r.toUserID_FK = @toUserID)
              AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)
        )
        SELECT
              R.RequestID
            , R.RequestTypeID_FK
            , T.VehicleTransferRequestTypeNameA AS RequestTypeNameA
            , T.VehicleTransferRequestTypeNameE AS RequestTypeNameE
            , R.chassisNumber_FK
            , R.fromUserID_FK
            , R.toUserID_FK
            , R.deptID_FK
            , R.CreateByUser
            , R.aproveNote
            , R.active
            , R.IdaraID_FK
            , R.entryDate
            , R.entryData
            , R.hostName
            , R.LastHistoryID
            , R.LastStatus
            , R.LastActionBy
            , R.LastActionDate
            , R.LastNotes
            , v.vehicleID
        FROM R
        LEFT JOIN VIC.VehicleTransferRequestType T
            ON T.VehicleTransferRequestTypeID = R.RequestTypeID_FK
        LEFT JOIN VIC.Vehicles v
            ON v.chassisNumber = R.chassisNumber_FK
        WHERE R.LastStatus = N'Approved'
          AND ISNULL(R.active, 0) = 1
          AND (@IdaraID_BIG IS NULL OR v.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
              R.LastActionDate DESC
            , R.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- VEHICLES
    ----------------------------------------------------------------
    IF @ActionType = N'VEHICLES'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @VehiclesDeptID INT = NULL;

        SELECT TOP (1)
            @VehiclesDeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.Users u
        INNER JOIN DATACORE.dbo.UsersDetails ud
            ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
        LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
            ON fs.DSDID = (
                SELECT TOP 1 ds.DSDID_FK
                FROM DATACORE.dbo.UserDistributor d2
                INNER JOIN DATACORE.dbo.Distributor ds
                    ON ds.distributorID = d2.distributorID_FK
                    AND ds.distributorActive = 1
                    AND ds.distributorType_FK = 1
                    AND ds.DSDID_FK IS NOT NULL
                WHERE d2.userID_FK = u.usersID
                  AND d2.UDActive = 1
                  AND d2.UDStartDate IS NOT NULL
                  AND d2.UDEndDate IS NULL
                ORDER BY d2.UDStartDate DESC
            )
        WHERE u.usersID = @userID;

        IF @VehiclesDeptID IS NULL
        BEGIN
            THROW 50001, N'تعذر تحديد قسم المستخدم', 1;
            RETURN;
        END

        SELECT
              v.chassisNumber
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.vehicleStatusID_FK
            , v.IdaraID_FK

            , trOwner.typesName_A AS ownerName
            , trModel.typesName_A AS vehicleModelName
            , trColor.typesName_A AS vehicleColorName
            , trType.typesName_A  AS vehicleTypeName

            , w.vehicleWithUsersID
            , w.userID_FK              AS CurrentUserID
            , w.startDate              AS CustodyStartDate
            , w.note                   AS CustodyNote
            , w.RequestID_FK
            , w.GeneralNo_Snapshot
            , w.UserFullName_Snapshot
            , w.DeptID_Snapshot
            , w.DeptName_Snapshot
            , w.SectionID_Snapshot
            , w.SectionName_Snapshot
            , w.OrganizationName_Snap
            , w.IdaraID_Snapshot
            , w.IdaraName_Snap

            , uCur.nationalID           AS CurrentUserNationalID
            , CONCAT_WS(N' ', udCur.firstName_A, udCur.secondName_A, udCur.thirdName_A, udCur.lastName_A) AS CurrentUserName_A
        FROM VIC.Vehicles v
        INNER JOIN VIC.vehicleWithUsers w
            ON w.chassisNumber_FK = v.chassisNumber
           AND w.endDate IS NULL
        LEFT JOIN DATACORE.dbo.Users uCur
            ON uCur.usersID = w.userID_FK
        LEFT JOIN DATACORE.dbo.UsersDetails udCur
            ON udCur.usersID_FK = uCur.usersID AND ISNULL(udCur.userActive, 0) = 1
        LEFT JOIN VIC.TypesRoot trOwner
            ON trOwner.typesID = v.ownerID_FK
        LEFT JOIN VIC.TypesRoot trModel
            ON trModel.typesID = v.vehicleModelID_FK
        LEFT JOIN VIC.TypesRoot trColor
            ON trColor.typesID = v.vehicleColorID_FK
        LEFT JOIN VIC.TypesRoot trType
            ON trType.typesID = v.vehicleTypeID_FK
        WHERE v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.DeptID_Snapshot, -1) = @VehiclesDeptID
          AND (@CH IS NULL OR v.chassisNumber = @CH)
        ORDER BY
              w.startDate DESC
            , v.chassisNumber ASC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- ELIGIBLE_USERS
    ----------------------------------------------------------------
    IF @ActionType = N'ELIGIBLE_USERS'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @CH IS NULL
        BEGIN
            THROW 50001, N'رقم الشاصي أو رقم المركبة مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @EligDeptID INT = NULL;
        DECLARE @CurrentFromUserID BIGINT = NULL;
        DECLARE @CurrentVehicleWithUsersID INT = NULL;

        SELECT TOP (1)
            @EligDeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.Users u
        INNER JOIN DATACORE.dbo.UsersDetails ud
            ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
        LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
            ON fs.DSDID = (
                SELECT TOP 1 ds.DSDID_FK
                FROM DATACORE.dbo.UserDistributor d2
                INNER JOIN DATACORE.dbo.Distributor ds
                    ON ds.distributorID = d2.distributorID_FK
                    AND ds.distributorActive = 1
                    AND ds.distributorType_FK = 1
                    AND ds.DSDID_FK IS NOT NULL
                WHERE d2.userID_FK = u.usersID
                  AND d2.UDActive = 1
                  AND d2.UDStartDate IS NOT NULL
                  AND d2.UDEndDate IS NULL
                ORDER BY d2.UDStartDate DESC
            )
        WHERE u.usersID = @userID;

        IF @EligDeptID IS NULL
        BEGIN
            THROW 50001, N'تعذر تحديد قسم المستخدم', 1;
            RETURN;
        END

        SELECT TOP (1)
              @CurrentFromUserID = w.userID_FK
            , @CurrentVehicleWithUsersID = w.vehicleWithUsersID
        FROM VIC.vehicleWithUsers w
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = w.chassisNumber_FK
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NULL
          AND v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.DeptID_Snapshot, -1) = @EligDeptID
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

        IF @CurrentFromUserID IS NULL
        BEGIN
            THROW 50001, N'لا توجد عهدة فعالة لهذه المركبة داخل قسمك', 1;
            RETURN;
        END

        SELECT
              w.vehicleWithUsersID
            , w.chassisNumber_FK
            , w.userID_FK             AS FromUserID
            , w.startDate
            , w.note
            , w.GeneralNo_Snapshot
            , w.UserFullName_Snapshot
            , w.DeptID_Snapshot
            , w.DeptName_Snapshot
            , w.SectionID_Snapshot
            , w.SectionName_Snapshot
            , w.OrganizationName_Snap
            , w.IdaraID_Snapshot
            , w.IdaraName_Snap
            , uF.nationalID             AS NationalID
            , CONCAT_WS(N' ', udF.firstName_A, udF.secondName_A, udF.thirdName_A, udF.lastName_A) AS UserFullName_A
            , ISNULL(@VID, v2.vehicleID) AS vehicleID
        FROM VIC.vehicleWithUsers w
        LEFT JOIN DATACORE.dbo.Users uF
            ON uF.usersID = w.userID_FK
        LEFT JOIN DATACORE.dbo.UsersDetails udF
            ON udF.usersID_FK = uF.usersID AND ISNULL(udF.userActive, 0) = 1
        LEFT JOIN VIC.Vehicles v2
            ON v2.chassisNumber = w.chassisNumber_FK
        WHERE w.vehicleWithUsersID = @CurrentVehicleWithUsersID;

        ;WITH DeptUsers AS
        (
            SELECT
                  u.usersID           AS userID_FK
                , ud.GeneralNo        AS fno
                , u.nationalID               AS IDNumber
                , CONCAT_WS(N' ', ud.firstName_A, ud.secondName_A, ud.thirdName_A, ud.lastName_A) AS UserFullName_A
                , fs.OrganizationID
                , fs.OrganizationName
                , fs.IdaraID
                , fs.IdaraName
                , fs.DepartmentID
                , fs.DepartmentName
                , fs.SectionID
                , fs.SectionName
                , fs.DivisonID
                , fs.DivisonName
            FROM DATACORE.dbo.Users u
            INNER JOIN DATACORE.dbo.UsersDetails ud
                ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
            LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
                ON fs.DSDID = (
                    SELECT TOP 1 ds.DSDID_FK
                    FROM DATACORE.dbo.UserDistributor d2
                    INNER JOIN DATACORE.dbo.Distributor ds
                        ON ds.distributorID = d2.distributorID_FK
                        AND ds.distributorActive = 1
                        AND ds.distributorType_FK = 1
                        AND ds.DSDID_FK IS NOT NULL
                    WHERE d2.userID_FK = u.usersID
                      AND d2.UDActive = 1
                      AND d2.UDStartDate IS NOT NULL
                      AND d2.UDEndDate IS NULL
                    ORDER BY d2.UDStartDate DESC
                )
            WHERE ud.IdaraID IS NOT NULL
              AND fs.IdaraID = TRY_CONVERT(INT, @IdaraID_BIG)
              AND fs.DepartmentID = @EligDeptID
        )
        SELECT
              du.userID_FK       AS ToUserID
            , du.UserFullName_A
            , du.fno             AS GeneralNo
            , du.IDNumber        AS NationalID
            , du.OrganizationID
            , du.OrganizationName
            , du.IdaraID
            , du.IdaraName
            , du.DepartmentID
            , du.DepartmentName
            , du.SectionID
            , du.SectionName
            , du.DivisonID
            , du.DivisonName
            , ISNULL(@VID, 0)    AS vehicleID
        FROM DeptUsers du
        WHERE du.userID_FK <> @CurrentFromUserID
          AND NOT EXISTS
          (
              SELECT 1
              FROM VIC.vehicleWithUsers w2
              INNER JOIN VIC.Vehicles v2
                  ON v2.chassisNumber = w2.chassisNumber_FK
              WHERE w2.userID_FK = du.userID_FK
                AND w2.endDate IS NULL
                AND v2.IdaraID_FK = @IdaraID_BIG
          )
        ORDER BY du.UserFullName_A ASC;

        RETURN;
    END

    ----------------------------------------------------------------
    -- HISTORY
    ----------------------------------------------------------------
    IF @ActionType = N'HISTORY'
    BEGIN
        IF @requestID IS NULL OR @requestID <= 0
        BEGIN
            THROW 50001, N'رقم الطلب مطلوب', 1;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequest r
            WHERE r.RequestID = @requestID
              AND (@IdaraID_BIG IS NULL OR r.IdaraID_FK = @IdaraID_BIG)
        )
        BEGIN
            THROW 50001, N'طلب النقل غير موجود', 1;
            RETURN;
        END

        SELECT
              h.HistoryID
            , h.RequestID_FK
            , h.Status
            , h.ActionBy
            , h.ActionDate
            , h.Notes
            , h.hostName
            , h.entryDate
            , h.entryData
            , v.vehicleID
            , r.chassisNumber_FK AS chassisNumber
        FROM VIC.VehicleTransferRequestHistory AS h
        INNER JOIN VIC.VehicleTransferRequest AS r
            ON r.RequestID = h.RequestID_FK
        LEFT JOIN VIC.Vehicles AS v
            ON v.chassisNumber = r.chassisNumber_FK
        WHERE h.RequestID_FK = @requestID
        ORDER BY h.ActionDate ASC, h.HistoryID ASC;

        RETURN;
    END

    ----------------------------------------------------------------
    -- REQUEST_TYPES
    ----------------------------------------------------------------
    IF @ActionType = N'REQUEST_TYPES'
    BEGIN
        SELECT
              t.VehicleTransferRequestTypeID
            , t.VehicleTransferRequestTypeNameA
            , t.VehicleTransferRequestTypeNameE
            , t.Active
            , CAST(NULL AS INT) AS vehicleID
        FROM VIC.VehicleTransferRequestType AS t
        WHERE (@activeOnly = 0 OR t.Active = 1)
        ORDER BY t.VehicleTransferRequestTypeNameA;

        RETURN;
    END

    ----------------------------------------------------------------
    -- MY_VEHICLES
    -- Returns only vehicles in active custody of @userID
    ----------------------------------------------------------------
    IF @ActionType = N'MY_VEHICLES'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        SELECT
              v.chassisNumber
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.vehicleStatusID_FK
            , v.IdaraID_FK

            , trOwner.typesName_A AS ownerName
            , trModel.typesName_A AS vehicleModelName
            , trColor.typesName_A AS vehicleColorName
            , trType.typesName_A  AS vehicleTypeName

            , w.vehicleWithUsersID
            , w.startDate            AS CustodyStartDate
            , w.note                 AS CustodyNote
            , w.RequestID_FK
        FROM VIC.vehicleWithUsers w
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = w.chassisNumber_FK
            AND v.IdaraID_FK = @IdaraID_BIG
        LEFT JOIN VIC.TypesRoot trOwner
            ON trOwner.typesID = v.ownerID_FK
        LEFT JOIN VIC.TypesRoot trModel
            ON trModel.typesID = v.vehicleModelID_FK
        LEFT JOIN VIC.TypesRoot trColor
            ON trColor.typesID = v.vehicleColorID_FK
        LEFT JOIN VIC.TypesRoot trType
            ON trType.typesID = v.vehicleTypeID_FK
        WHERE w.userID_FK = @userID
          AND w.endDate IS NULL
          AND v.vehicleStatusID_FK NOT IN (261, 262)
        ORDER BY
              w.startDate DESC
            , v.chassisNumber ASC;

        RETURN;
    END

    ----------------------------------------------------------------
    -- MY_REQUESTS
    -- Active requests created by @userID (Created status only)
    ----------------------------------------------------------------
    IF @ActionType = N'MY_REQUESTS'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.entryDate
            , r.active

            , v.vehicleID
            , v.plateNumbers
            , v.plateLetters
            , v.armyNumber

            , rt.VehicleTransferRequestTypeNameA AS RequestTypeNameA
            , rt.VehicleTransferRequestTypeNameE AS RequestTypeNameE

            , h.Status     AS LastStatus
            , h.ActionDate AS LastActionDate

            , t.UserFullName_A AS ToUserName
        FROM VIC.VehicleTransferRequest r
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        LEFT JOIN VIC.VehicleTransferRequestType rt
            ON rt.VehicleTransferRequestTypeID = r.RequestTypeID_FK
        CROSS APPLY
        (
            SELECT TOP (1)
                  h1.Status
                , h1.ActionDate
            FROM VIC.VehicleTransferRequestHistory h1
            WHERE h1.RequestID_FK = r.RequestID
            ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
        ) h
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', ud2.firstName_A, ud2.secondName_A, ud2.thirdName_A, ud2.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users u2
            INNER JOIN DATACORE.dbo.UsersDetails ud2
                ON ud2.usersID_FK = u2.usersID AND ISNULL(ud2.userActive, 0) = 1
            WHERE u2.usersID = r.toUserID_FK
        ) t
        WHERE r.fromUserID_FK = @userID
          AND r.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(r.active, 0) = 1
          AND h.Status = N'Created'
        ORDER BY r.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- MY_REQUEST_HISTORY
    -- All requests created by @userID (all statuses)
    ----------------------------------------------------------------
    IF @ActionType = N'MY_REQUEST_HISTORY'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.entryDate
            , r.active

            , v.vehicleID
            , v.plateNumbers
            , v.plateLetters
            , v.armyNumber

            , rt.VehicleTransferRequestTypeNameA AS RequestTypeNameA
            , rt.VehicleTransferRequestTypeNameE AS RequestTypeNameE

            , h.Status     AS LastStatus
            , h.ActionDate AS LastActionDate

            , t.UserFullName_A AS ToUserName
        FROM VIC.VehicleTransferRequest r
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        LEFT JOIN VIC.VehicleTransferRequestType rt
            ON rt.VehicleTransferRequestTypeID = r.RequestTypeID_FK
        CROSS APPLY
        (
            SELECT TOP (1)
                  h1.Status
                , h1.ActionDate
            FROM VIC.VehicleTransferRequestHistory h1
            WHERE h1.RequestID_FK = r.RequestID
            ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
        ) h
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', ud2.firstName_A, ud2.secondName_A, ud2.thirdName_A, ud2.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users u2
            INNER JOIN DATACORE.dbo.UsersDetails ud2
                ON ud2.usersID_FK = u2.usersID AND ISNULL(ud2.userActive, 0) = 1
            WHERE u2.usersID = r.toUserID_FK
        ) t
        WHERE r.fromUserID_FK = @userID
          AND r.IdaraID_FK = @IdaraID_BIG
        ORDER BY r.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- DEPT_APPROVED
    -- Approved transfer requests for a department (for Approval page)
    ----------------------------------------------------------------
    IF @ActionType = N'DEPT_APPROVED'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @DeptApproved_DeptID INT = NULL;

        SELECT TOP (1)
            @DeptApproved_DeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.Users u
        INNER JOIN DATACORE.dbo.UsersDetails ud
            ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
        LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
            ON fs.DSDID = (
                SELECT TOP 1 ds.DSDID_FK
                FROM DATACORE.dbo.UserDistributor d2
                INNER JOIN DATACORE.dbo.Distributor ds
                    ON ds.distributorID = d2.distributorID_FK
                    AND ds.distributorActive = 1
                    AND ds.distributorType_FK = 1
                    AND ds.DSDID_FK IS NOT NULL
                WHERE d2.userID_FK = u.usersID
                  AND d2.UDActive = 1
                  AND d2.UDStartDate IS NOT NULL
                  AND d2.UDEndDate IS NULL
                ORDER BY d2.UDStartDate DESC
            )
        WHERE u.usersID = @userID;

        IF @DeptApproved_DeptID IS NULL
        BEGIN
            THROW 50001, N'تعذر تحديد قسم المستخدم', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.active
            , r.IdaraID_FK
            , r.entryDate
            , r.entryData
            , r.hostName

            , rt.VehicleTransferRequestTypeNameA AS RequestTypeNameA
            , rt.VehicleTransferRequestTypeNameE AS RequestTypeNameE

            , v.vehicleID
            , v.plateNumbers
            , v.plateLetters
            , v.armyNumber

            , h.Status     AS LastStatus
            , h.ActionDate AS LastActionDate
            , h.Notes      AS LastNotes

            , fromU.UserFullName_A AS FromUserName
            , toU.UserFullName_A   AS ToUserName
        FROM VIC.VehicleTransferRequest r
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        LEFT JOIN VIC.VehicleTransferRequestType rt
            ON rt.VehicleTransferRequestTypeID = r.RequestTypeID_FK
        CROSS APPLY
        (
            SELECT TOP (1)
                  h1.Status
                , h1.ActionDate
                , h1.Notes
            FROM VIC.VehicleTransferRequestHistory h1
            WHERE h1.RequestID_FK = r.RequestID
            ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
        ) h
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', udF.firstName_A, udF.secondName_A, udF.thirdName_A, udF.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users uF
            INNER JOIN DATACORE.dbo.UsersDetails udF
                ON udF.usersID_FK = uF.usersID AND ISNULL(udF.userActive, 0) = 1
            WHERE uF.usersID = r.fromUserID_FK
        ) fromU
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', udT.firstName_A, udT.secondName_A, udT.thirdName_A, udT.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users uT
            INNER JOIN DATACORE.dbo.UsersDetails udT
                ON udT.usersID_FK = uT.usersID AND ISNULL(udT.userActive, 0) = 1
            WHERE uT.usersID = r.toUserID_FK
        ) toU
        WHERE r.IdaraID_FK = @IdaraID_BIG
          AND r.deptID_FK = @DeptApproved_DeptID
          AND h.Status = N'Approved'
          AND ISNULL(r.active, 0) = 1
        ORDER BY h.ActionDate DESC, r.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- DEPT_HISTORY
    -- All transfer requests for a department (all statuses)
    ----------------------------------------------------------------
    IF @ActionType = N'DEPT_HISTORY'
    BEGIN
        IF @userID IS NULL OR @userID <= 0
        BEGIN
            THROW 50001, N'رقم المستخدم مطلوب', 1;
            RETURN;
        END

        IF @IdaraID_BIG IS NULL
        BEGIN
            THROW 50001, N'الإدارة مطلوبة', 1;
            RETURN;
        END

        DECLARE @DeptHist_DeptID INT = NULL;

        SELECT TOP (1)
            @DeptHist_DeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.Users u
        INNER JOIN DATACORE.dbo.UsersDetails ud
            ON ud.usersID_FK = u.usersID AND ISNULL(ud.userActive, 0) = 1
        LEFT JOIN DATACORE.dbo.V_getFullStructureForDSD fs
            ON fs.DSDID = (
                SELECT TOP 1 ds.DSDID_FK
                FROM DATACORE.dbo.UserDistributor d2
                INNER JOIN DATACORE.dbo.Distributor ds
                    ON ds.distributorID = d2.distributorID_FK
                    AND ds.distributorActive = 1
                    AND ds.distributorType_FK = 1
                    AND ds.DSDID_FK IS NOT NULL
                WHERE d2.userID_FK = u.usersID
                  AND d2.UDActive = 1
                  AND d2.UDStartDate IS NOT NULL
                  AND d2.UDEndDate IS NULL
                ORDER BY d2.UDStartDate DESC
            )
        WHERE u.usersID = @userID;

        IF @DeptHist_DeptID IS NULL
        BEGIN
            THROW 50001, N'تعذر تحديد قسم المستخدم', 1;
            RETURN;
        END

        SELECT
              r.RequestID
            , r.RequestTypeID_FK
            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
            , r.CreateByUser
            , r.aproveNote
            , r.active
            , r.IdaraID_FK
            , r.entryDate
            , r.entryData
            , r.hostName

            , rt.VehicleTransferRequestTypeNameA AS RequestTypeNameA
            , rt.VehicleTransferRequestTypeNameE AS RequestTypeNameE

            , v.vehicleID
            , v.plateNumbers
            , v.plateLetters
            , v.armyNumber

            , h.Status     AS LastStatus
            , h.ActionDate AS LastActionDate
            , h.Notes      AS LastNotes

            , fromU.UserFullName_A AS FromUserName
            , toU.UserFullName_A   AS ToUserName
        FROM VIC.VehicleTransferRequest r
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = r.chassisNumber_FK
        LEFT JOIN VIC.VehicleTransferRequestType rt
            ON rt.VehicleTransferRequestTypeID = r.RequestTypeID_FK
        CROSS APPLY
        (
            SELECT TOP (1)
                  h1.Status
                , h1.ActionDate
                , h1.Notes
            FROM VIC.VehicleTransferRequestHistory h1
            WHERE h1.RequestID_FK = r.RequestID
            ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
        ) h
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', udF.firstName_A, udF.secondName_A, udF.thirdName_A, udF.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users uF
            INNER JOIN DATACORE.dbo.UsersDetails udF
                ON udF.usersID_FK = uF.usersID AND ISNULL(udF.userActive, 0) = 1
            WHERE uF.usersID = r.fromUserID_FK
        ) fromU
        OUTER APPLY
        (
            SELECT CONCAT_WS(N' ', udT.firstName_A, udT.secondName_A, udT.thirdName_A, udT.lastName_A) AS UserFullName_A
            FROM DATACORE.dbo.Users uT
            INNER JOIN DATACORE.dbo.UsersDetails udT
                ON udT.usersID_FK = uT.usersID AND ISNULL(udT.userActive, 0) = 1
            WHERE uT.usersID = r.toUserID_FK
        ) toU
        WHERE r.IdaraID_FK = @IdaraID_BIG
          AND r.deptID_FK = @DeptHist_DeptID
        ORDER BY r.RequestID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        RETURN;
    END

    ----------------------------------------------------------------
    -- Unknown ActionType
    ----------------------------------------------------------------
    ;THROW 50001, N'نوع العملية غير معروف في الإجراء TransferRequestDL', 1;
    RETURN;
END