
/* =========================================================
   Description:
   إرجاع المركبات التي تقع ضمن نفس قسم المستخدم ونفس الإدارة،
   بشرط وجود عهدة نشطة حالية على المركبة.

   الغرض:
   استخدامه في صفحة "طلب نقل المركبة" بحيث يرى المستخدم
   فقط سيارات قسمه التي يمكن رفع طلب نقل عليها.

   الإضافة:
   - ownerName
   - vehicleModelName
   - vehicleColorName
   - vehicleTypeName

   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[TransferRequest_Vehicles_ByUserDept_DL]
(
      @userID        INT
    , @idaraID_FK    NVARCHAR(10) = NULL
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
    , @chassisNumber NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @CH NVARCHAR(100) =
        NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    BEGIN TRY

        IF @tc = 0 BEGIN TRAN;

        /* ===== Business Validation ===== */

        IF @userID IS NULL OR @userID <= 0
            THROW 50001, N'userID مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF @pageNumber IS NULL OR @pageNumber < 1
            THROW 50001, N'pageNumber غير صحيح', 1;

        IF @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200
            THROW 50001, N'pageSize غير صحيح', 1;

        DECLARE @P INT  = @pageNumber;
        DECLARE @PS INT = @pageSize;
        DECLARE @Skip INT = (@P - 1) * @PS;

        DECLARE @CurrentDeptID INT = NULL;

        /* ===== جلب قسم المستخدم الحالي ===== */
        SELECT TOP (1)
            @CurrentDeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.UserTemp ut
        INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
            ON fs.DSDID = ut.dsdID_FK
        WHERE ut.userID_FK = @userID;

        IF @CurrentDeptID IS NULL
            THROW 50001, N'تعذر تحديد قسم المستخدم الحالي', 1;

        /* ===== القائمة ===== */
        SELECT
              v.chassisNumber
            , v.vehicleID
            , v.plateLetters
            , v.plateNumbers
            , v.armyNumber
            , v.vehicleStatusID_FK
            , v.IdaraID_FK

            /* الإضافات الجديدة */
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

            , ut.IDNumber              AS CurrentUserNationalID
            , ut.mobileNo              AS CurrentUserMobile
            , CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS CurrentUserName_A
        FROM VIC.Vehicles v
        INNER JOIN VIC.vehicleWithUsers w
            ON w.chassisNumber_FK = v.chassisNumber
           AND w.endDate IS NULL
        LEFT JOIN DATACORE.dbo.UserTemp ut
            ON ut.userID_FK = w.userID_FK

        /* الربط على TypesRoot */
        LEFT JOIN VIC.TypesRoot trOwner
            ON trOwner.typesID = v.ownerID_FK

        LEFT JOIN VIC.TypesRoot trModel
            ON trModel.typesID = v.vehicleModelID_FK

        LEFT JOIN VIC.TypesRoot trColor
            ON trColor.typesID = v.vehicleColorID_FK

        LEFT JOIN VIC.TypesRoot trType
            ON trType.typesID = v.vehicleTypeID_FK

        WHERE v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
          AND ISNULL(w.DeptID_Snapshot, -1) = @CurrentDeptID
          AND (@CH IS NULL OR v.chassisNumber = @CH)
        ORDER BY
              w.startDate DESC
            , v.chassisNumber ASC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        IF @tc = 0 COMMIT;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END