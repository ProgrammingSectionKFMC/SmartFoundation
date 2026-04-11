
/* =========================================================
   Description:
   إرجاع بيانات المستخدمين المؤهلين لطلب نقل مركبة محددة.

   النتيجة الأولى:
   - "من" = صاحب/أصحاب العهدة الحالية على المركبة المحددة
     (عمليًا غالبًا شخص واحد فقط endDate IS NULL)

   النتيجة الثانية:
   - "إلى" = موظفو نفس القسم ونفس الإدارة
     الذين لا يملكون عهدة نشطة حاليًا

   الغرض:
   استخدامه في مودال "طلب نقل المركبة"

   Type: READ (LOOKUP/LIST)
========================================================= */

CREATE     PROCEDURE [VIC].[TransferRequest_EligibleUsers_DL]
(
      @chassisNumber NVARCHAR(100)
    , @userID        INT
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) =
        NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    BEGIN TRY

        IF @tc = 0 BEGIN TRAN;

        /* ===== Validation ===== */

        IF @userID IS NULL OR @userID <= 0
            THROW 50001, N'userID مطلوب', 1;

        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        DECLARE
              @CurrentDeptID INT = NULL
            , @CurrentFromUserID BIGINT = NULL
            , @CurrentVehicleWithUsersID INT = NULL;

        /* =====================================================
           1) تحديد قسم المستخدم الحالي
        ===================================================== */
        SELECT TOP (1)
            @CurrentDeptID = TRY_CONVERT(INT, fs.DepartmentID)
        FROM DATACORE.dbo.UserTemp ut
        INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
            ON fs.DSDID = ut.dsdID_FK
        WHERE ut.userID_FK = @userID;

        IF @CurrentDeptID IS NULL
            THROW 50001, N'تعذر تحديد قسم المستخدم الحالي', 1;

        /* =====================================================
           2) التحقق من وجود عهدة نشطة حالية على المركبة
              وأنها ضمن نفس الإدارة ونفس القسم
        ===================================================== */
        SELECT TOP (1)
              @CurrentFromUserID = w.userID_FK
            , @CurrentVehicleWithUsersID = w.vehicleWithUsersID
        FROM VIC.vehicleWithUsers w
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = w.chassisNumber_FK
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NULL
          AND v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
          AND ISNULL(w.DeptID_Snapshot, -1) = @CurrentDeptID
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

        IF @CurrentFromUserID IS NULL
            THROW 50001, N'لا توجد عهدة نشطة لهذه المركبة ضمن نفس القسم والإدارة', 1;

        /* =====================================================
           النتيجة الأولى: FROM
           صاحب العهدة الحالية على المركبة
        ===================================================== */
        SELECT
              w.vehicleWithUsersID
            , w.chassisNumber_FK
            , w.userID_FK                     AS FromUserID
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
            , ut.IDNumber                    AS NationalID
            , ut.mobileNo                    AS MobileNo
            , CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS UserFullName_A
        FROM VIC.vehicleWithUsers w
        LEFT JOIN DATACORE.dbo.UserTemp ut
            ON ut.userID_FK = w.userID_FK
        WHERE w.vehicleWithUsersID = @CurrentVehicleWithUsersID;

        /* =====================================================
           النتيجة الثانية: TO
           موظفو نفس القسم ونفس الإدارة ممن لا يملكون عهدة نشطة
        ===================================================== */
        ;WITH DeptUsers AS
        (
            SELECT
                  ut.userID_FK
                , ut.dsdID_FK
                , ut.fno
                , ut.IDNumber
                , ut.mobileNo
                , CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS UserFullName_A
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
            FROM DATACORE.dbo.UserTemp ut
            INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
                ON fs.DSDID = ut.dsdID_FK
            WHERE fs.IdaraID = TRY_CONVERT(INT, @IdaraID_BIG)
              AND fs.DepartmentID = @CurrentDeptID
        )
        SELECT
              du.userID_FK                   AS ToUserID
            , du.UserFullName_A
            , du.fno                         AS GeneralNo
            , du.IDNumber                    AS NationalID
            , du.mobileNo                    AS MobileNo
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
        FROM DeptUsers du
        WHERE du.userID_FK <> @CurrentFromUserID
          AND NOT EXISTS
          (
              SELECT 1
              FROM VIC.vehicleWithUsers w2
              WHERE w2.userID_FK = du.userID_FK
                AND w2.endDate IS NULL
                AND ISNULL(w2.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
          )
        ORDER BY du.UserFullName_A ASC;

        IF @tc = 0 COMMIT;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END