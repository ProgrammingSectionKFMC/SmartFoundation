
/* =========================================================
   Description:
   إنشاء طلب نقل مركبة مع تحقق صارم من:
   - وجود عهدة نشطة حالية على المركبة
   - مطابقة fromUserID لصاحب العهدة الحالية
   - كون toUserID من نفس القسم ونفس الإدارة
   - عدم وجود عهدة نشطة على toUserID
   - عدم وجود طلب نقل نشط سابق لنفس المركبة
   Type: WRITE
========================================================= */

CREATE PROCEDURE [VIC].[TransferRequest_Create_SP]
(
      @requestTypeID INT
    , @chassisNumber NVARCHAR(100)
    , @fromUserID    INT
    , @toUserID      INT
    , @deptID        INT
    , @createByUser  NVARCHAR(200)
    , @note          NVARCHAR(400) = NULL
    , @idaraID_FK    NVARCHAR(10) = NULL
    , @entryData     NVARCHAR(40) = NULL
    , @hostName      NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    DECLARE @CB NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@createByUser)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE
          @CurrentCustodyUserID BIGINT = NULL
        , @CurrentCustodyDeptID INT = NULL
        , @FromDeptID INT = NULL
        , @ToDeptID INT = NULL
        , @FromIdaraID INT = NULL
        , @ToIdaraID INT = NULL;

    BEGIN TRY
        IF @requestTypeID IS NULL OR @requestTypeID <= 0
            THROW 50001, N'requestTypeID مطلوب', 1;

        IF @CH IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @fromUserID IS NULL OR @fromUserID <= 0
            THROW 50001, N'fromUserID مطلوب', 1;

        IF @toUserID IS NULL OR @toUserID <= 0
            THROW 50001, N'toUserID مطلوب', 1;

        IF @fromUserID = @toUserID
            THROW 50001, N'لا يمكن النقل لنفس المستخدم', 1;

        IF @deptID IS NULL OR @deptID <= 0
            THROW 50001, N'deptID مطلوب', 1;

        IF @CB IS NULL
            THROW 50001, N'createByUser مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH
              AND v.IdaraID_FK = @IdaraID_BIG
        )
            THROW 50001, N'المركبة غير موجودة أو لا تطابق الإدارة', 1;

        /* العهدة الحالية على المركبة */
        SELECT TOP (1)
              @CurrentCustodyUserID = w.userID_FK
            , @CurrentCustodyDeptID = w.DeptID_Snapshot
        FROM VIC.vehicleWithUsers w
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = w.chassisNumber_FK
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NULL
          AND v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

        IF @CurrentCustodyUserID IS NULL
            THROW 50001, N'لا توجد عهدة نشطة حالية على المركبة', 1;

        IF @CurrentCustodyUserID <> @fromUserID
            THROW 50001, N'fromUserID لا يطابق صاحب العهدة الحالية', 1;

        IF @CurrentCustodyDeptID IS NULL
            THROW 50001, N'تعذر تحديد قسم العهدة الحالية', 1;

        IF @deptID <> @CurrentCustodyDeptID
            THROW 50001, N'deptID لا يطابق قسم العهدة الحالية', 1;

        /* إدارة/قسم fromUserID */
        SELECT TOP (1)
              @FromDeptID = TRY_CONVERT(INT, fs.DepartmentID)
            , @FromIdaraID = TRY_CONVERT(INT, fs.IdaraID)
        FROM DATACORE.dbo.UserTemp ut
        INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
            ON fs.DSDID = ut.dsdID_FK
        WHERE ut.userID_FK = @fromUserID;

        IF @FromDeptID IS NULL OR @FromIdaraID IS NULL
            THROW 50001, N'تعذر تحديد بيانات المستخدم المنقول منه', 1;

        /* إدارة/قسم toUserID */
        SELECT TOP (1)
              @ToDeptID = TRY_CONVERT(INT, fs.DepartmentID)
            , @ToIdaraID = TRY_CONVERT(INT, fs.IdaraID)
        FROM DATACORE.dbo.UserTemp ut
        INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
            ON fs.DSDID = ut.dsdID_FK
        WHERE ut.userID_FK = @toUserID;

        IF @ToDeptID IS NULL OR @ToIdaraID IS NULL
            THROW 50001, N'تعذر تحديد بيانات المستخدم المنقول إليه', 1;

        IF @FromIdaraID <> TRY_CONVERT(INT, @IdaraID_BIG) OR @ToIdaraID <> TRY_CONVERT(INT, @IdaraID_BIG)
            THROW 50001, N'المستخدمون لا يتبعون نفس الإدارة', 1;

        IF @FromDeptID <> @deptID OR @ToDeptID <> @deptID
            THROW 50001, N'المستخدمون لا يتبعون نفس القسم', 1;

        /* منع إذا كان المنقول إليه عنده عهدة نشطة */
        IF EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            WHERE w.userID_FK = @toUserID
              AND w.endDate IS NULL
              AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
        )
            THROW 50001, N'المنقول إليه لديه عهدة نشطة بالفعل', 1;

        /* منع وجود طلب نقل نشط لنفس المركبة */
        IF EXISTS
        (
            SELECT 1
            FROM VIC.VehicleTransferRequest r
            WHERE r.chassisNumber_FK = @CH
              AND r.IdaraID_FK = @IdaraID_BIG
              AND ISNULL(r.active, 0) = 1
        )
            THROW 50001, N'يوجد طلب نقل نشط لهذه المركبة، أغلقه أولاً', 1;

        IF @tc = 0 BEGIN TRAN;

        INSERT INTO VIC.VehicleTransferRequest
        (
              RequestTypeID_FK
            , chassisNumber_FK
            , fromUserID_FK
            , toUserID_FK
            , deptID_FK
            , CreateByUser
            , aproveNote
            , active
            , IdaraID_FK
            , entryDate
            , entryData
            , hostName
        )
        VALUES
        (
              @requestTypeID
            , @CH
            , @fromUserID
            , @toUserID
            , @deptID
            , @CB
            , @note
            , 1
            , @IdaraID_BIG
            , GETDATE()
            , @entryData
            , @hostName
        );

        DECLARE @newRequestID INT = CONVERT(INT, SCOPE_IDENTITY());

        IF @newRequestID IS NULL OR @newRequestID <= 0
            THROW 50002, N'فشل إنشاء الطلب', 1;

        INSERT INTO VIC.VehicleTransferRequestHistory
        (
              RequestID_FK
            , Status
            , ActionBy
            , ActionDate
            , Notes
            , hostName
            , entryDate
            , entryData
        )
        VALUES
        (
              @newRequestID
            , N'Created'
            , @fromUserID
            , GETDATE()
            , @note
            , @hostName
            , GETDATE()
            , @entryData
        );

        IF @tc = 0 COMMIT;

        SELECT 1 AS IsSuccessful, N'تم رفع الطلب بنجاح' AS Message_, @newRequestID AS RequestID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END