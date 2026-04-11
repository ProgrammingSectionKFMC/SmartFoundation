
/* =========================================================
   Description:
   تنفيذ طلب نقل مركبة معاملة واحدة:
   - يتحقق أن الطلب Approved
   - يقفل العهدة الحالية
   - ينشئ عهدة جديدة للمنقول إليه
   - يغلق الطلب
   Type: WRITE
========================================================= */

CREATE     PROCEDURE [VIC].[TransferRequest_Execute_SP]
(
      @requestID      INT
    , @entryData      NVARCHAR(40)
    , @hostName       NVARCHAR(400)
    , @idaraID_FK     NVARCHAR(10)
    , @note           NVARCHAR(1000) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE
          @CH NVARCHAR(100)
        , @FromUserID BIGINT
        , @ToUserID BIGINT
        , @DeptID INT
        , @ReqActive BIT
        , @LastStatus NVARCHAR(100)
        , @CurrentVehicleWithUsersID INT
        , @CurrentCustodyUserID BIGINT
        , @CurrentCustodyDeptID INT
        , @NewVehicleWithUsersID INT
        , @Now DATETIME = GETDATE();

    BEGIN TRY
        IF @requestID IS NULL OR @requestID <= 0
            THROW 50001, N'requestID مطلوب', 1;

        IF NULLIF(LTRIM(RTRIM(@entryData)), N'') IS NULL
            THROW 50001, N'entryData مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        IF @tc = 0 BEGIN TRAN;

        /* ===== الطلب ===== */
        SELECT
              @CH = r.chassisNumber_FK
            , @FromUserID = r.fromUserID_FK
            , @ToUserID = r.toUserID_FK
            , @DeptID = r.deptID_FK
            , @ReqActive = r.active
        FROM VIC.VehicleTransferRequest r
        WHERE r.RequestID = @requestID
          AND r.IdaraID_FK = @IdaraID_BIG;

        IF @CH IS NULL
            THROW 50001, N'الطلب غير موجود أو لا يطابق الإدارة', 1;

        IF ISNULL(@ReqActive, 0) <> 1
            THROW 50001, N'الطلب غير نشط', 1;

        SELECT TOP (1)
            @LastStatus = h.Status
        FROM VIC.VehicleTransferRequestHistory h
        WHERE h.RequestID_FK = @requestID
        ORDER BY h.ActionDate DESC, h.HistoryID DESC;

        IF ISNULL(@LastStatus, N'') <> N'Approved'
            THROW 50001, N'لا يمكن تنفيذ الطلب إلا بعد الموافقة', 1;

        /* ===== العهدة الحالية ===== */
        SELECT TOP (1)
              @CurrentVehicleWithUsersID = w.vehicleWithUsersID
            , @CurrentCustodyUserID = w.userID_FK
            , @CurrentCustodyDeptID = w.DeptID_Snapshot
        FROM VIC.vehicleWithUsers w
        INNER JOIN VIC.Vehicles v
            ON v.chassisNumber = w.chassisNumber_FK
        WHERE w.chassisNumber_FK = @CH
          AND w.endDate IS NULL
          AND v.IdaraID_FK = @IdaraID_BIG
          AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
        ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC;

        IF @CurrentVehicleWithUsersID IS NULL
            THROW 50001, N'لا توجد عهدة نشطة حالية على المركبة', 1;

        IF @CurrentCustodyUserID <> @FromUserID
            THROW 50001, N'صاحب العهدة الحالية لا يطابق المستخدم المنقول منه في الطلب', 1;

        IF @CurrentCustodyDeptID <> @DeptID
            THROW 50001, N'قسم العهدة الحالية لا يطابق قسم الطلب', 1;

        /* ===== المنقول إليه يجب ألا يملك عهدة نشطة ===== */
        IF EXISTS
        (
            SELECT 1
            FROM VIC.vehicleWithUsers w
            WHERE w.userID_FK = @ToUserID
              AND w.endDate IS NULL
              AND ISNULL(w.IdaraID_Snapshot, -1) = TRY_CONVERT(INT, @IdaraID_BIG)
        )
            THROW 50001, N'المنقول إليه لديه عهدة نشطة بالفعل', 1;

        /* ===== إغلاق العهدة الحالية ===== */
        UPDATE VIC.vehicleWithUsers
        SET
              endDate = @Now
            , note = CASE
                        WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                            THEN ISNULL(note, N'') + N' | إغلاق تلقائي بسبب تنفيذ طلب نقل رقم ' + CONVERT(NVARCHAR(20), @requestID)
                        ELSE LEFT(@note, 2000)
                     END
            , entryDate = @Now
            , entryData = @entryData
            , hostName = @hostName
        WHERE vehicleWithUsersID = @CurrentVehicleWithUsersID
          AND endDate IS NULL;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل إغلاق العهدة الحالية', 1;

        /* ===== إنشاء العهدة الجديدة ===== */
        INSERT INTO VIC.vehicleWithUsers
        (
              userID_FK
            , RequestID_FK
            , startDate
            , endDate
            , note
            , entryDate
            , entryData
            , hostName
            , chassisNumber_FK
            , OrgSnapshotDate
            , IdaraID_Snapshot
            , DeptID_Snapshot
        )
        VALUES
        (
              @ToUserID
            , @requestID
            , @Now
            , NULL
            , CASE
                  WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                      THEN N'تم الإنشاء تلقائياً من تنفيذ طلب نقل رقم ' + CONVERT(NVARCHAR(20), @requestID)
                  ELSE LEFT(@note, 2000)
              END
            , @Now
            , @entryData
            , @hostName
            , @CH
            , @Now
            , TRY_CONVERT(INT, @IdaraID_BIG)
            , @DeptID
        );

        SET @NewVehicleWithUsersID = CONVERT(INT, SCOPE_IDENTITY());

        IF @NewVehicleWithUsersID IS NULL OR @NewVehicleWithUsersID <= 0
            THROW 50002, N'فشل إنشاء العهدة الجديدة', 1;

        /* ===== إغلاق الطلب ===== */
        UPDATE VIC.VehicleTransferRequest
        SET
              active = 0
            , aproveNote = CASE
                              WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                                  THEN ISNULL(aproveNote, N'') + N' | تم التنفيذ'
                              ELSE LEFT(@note, 400)
                           END
            , entryDate = @Now
            , entryData = @entryData
            , hostName = @hostName
        WHERE RequestID = @requestID
          AND IdaraID_FK = @IdaraID_BIG
          AND ISNULL(active, 0) = 1;

        IF @@ROWCOUNT <= 0
            THROW 50002, N'فشل إغلاق طلب النقل', 1;

        /* ===== History ===== */
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
              @requestID
            , N'Closed'
            , TRY_CONVERT(INT, @entryData)
            , @Now
            , CASE
                  WHEN NULLIF(LTRIM(RTRIM(@note)), N'') IS NULL
                      THEN N'تم تنفيذ الطلب وإنشاء عهدة جديدة'
                  ELSE @note
              END
            , @hostName
            , @Now
            , @entryData
        );

        IF @tc = 0 COMMIT;

        SELECT
              CAST(1 AS BIT) AS IsSuccessful
            , N'تم تنفيذ طلب النقل بنجاح' AS Message_
            , @NewVehicleWithUsersID AS vehicleWithUsersID;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END