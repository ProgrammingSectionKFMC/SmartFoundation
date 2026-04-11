
/* =========================================================
   Description:
   إرجاع بيانات محضر تسليم/استلام جاهزة للطباعة (صف واحد) حسب vehicleHandoverID،
   وتشمل بيانات المحضر + الطلب/المركبة + بيانات الطرفين (من/إلى) من UserTemp والهيكل التنظيمي لكل طرف (إن وجد).
   + إضافة تحقق/فلتر الإدارة (IdaraID_FK) بمعيار BIGINT.
   Type: READ (PRINT/GET)
========================================================= */

CREATE   PROCEDURE [VIC].[Handover_Print_Get_DL]
(
      @vehicleHandoverID INT
    , @idaraID_FK        NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    BEGIN TRY

        IF @tc = 0 BEGIN TRAN;

        /* ===== Business Validation مثل المثال ===== */

        IF @vehicleHandoverID IS NULL OR @vehicleHandoverID <= 0
            THROW 50001, N'vehicleHandoverID مطلوب', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM VIC.VehicleHandover h
            WHERE h.VehicleHandoverID = @vehicleHandoverID
        )
            THROW 50001, N'المحضر غير موجود', 1;

        IF @IdaraID_BIG IS NOT NULL
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM VIC.VehicleHandover h
                WHERE h.VehicleHandoverID = @vehicleHandoverID
                  AND h.IdaraID_FK = @IdaraID_BIG
            )
                THROW 50001, N'المحضر لا يتبع نفس الإدارة', 1;
        END

        /* ===== Query ===== */

        SELECT
            /* (A) بيانات المحضر */
              h.VehicleHandoverID
            , h.handoverDate
            , h.note
            , h.IdaraID_FK
            , t.handOverTypeName_A
            , t.handOverTypeName_E

            /* (B) بيانات الطلب/المركبة */
            , r.RequestID
            , r.chassisNumber_FK
            , r.deptID_FK

            /* (C) بيانات الأطراف (UserTemp) */
            , r.fromUserID_FK AS FromUserID
            , CONCAT_WS(N' ', uf.fristName_A, uf.secondName_A, uf.thirdName_A, uf.lastName_A) AS FromUserName_A
            , uf.fno       AS FromFno
            , uf.mobileNo  AS FromMobileNo
            , uf.IDNumber  AS FromIDNumber

            , r.toUserID_FK AS ToUserID
            , CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS ToUserName_A
            , ut.fno       AS ToFno
            , ut.mobileNo  AS ToMobileNo
            , ut.IDNumber  AS ToIDNumber

            /* (D) بيانات تنظيمية اختيارية */
            , ff.OrganizationName AS From_OrganizationName
            , ff.DepartmentName   AS From_DepartmentName
            , ff.SectionName      AS From_SectionName

            , ft.OrganizationName AS To_OrganizationName
            , ft.DepartmentName   AS To_DepartmentName
            , ft.SectionName      AS To_SectionName
        FROM VIC.VehicleHandover AS h
        INNER JOIN VIC.VehicleTransferRequest AS r
            ON r.RequestID = h.RequestID_FK
        INNER JOIN VIC.HandoverType AS t
            ON t.handOverTypeID = h.handOverTypeID_FK
        LEFT JOIN DATACORE.dbo.UserTemp AS uf
            ON uf.userID_FK = r.fromUserID_FK
        LEFT JOIN DATACORE.dbo.UserTemp AS ut
            ON ut.userID_FK = r.toUserID_FK
        LEFT JOIN DATACORE.dbo.V_GetFullStructureForDSD AS ff
            ON ff.DSDID = uf.dsdID_FK
        LEFT JOIN DATACORE.dbo.V_GetFullStructureForDSD AS ft
            ON ft.DSDID = ut.dsdID_FK
        WHERE h.VehicleHandoverID = @vehicleHandoverID
          AND (@IdaraID_BIG IS NULL OR h.IdaraID_FK = @IdaraID_BIG);

        IF @tc = 0 COMMIT;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END