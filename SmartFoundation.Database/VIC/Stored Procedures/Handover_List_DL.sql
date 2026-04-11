
/* =========================================================
   Description:
   إرجاع قائمة محاضر التسليم/الاستلام (Handover) مع Paging،
   مع فلاتر اختيارية حسب RequestID أو نوع المحضر أو نطاق تاريخ المحضر، وإظهار بيانات الطلب المرتبط ونوع المحضر.
   + إضافة فلتر الإدارة (IdaraID_FK) بمعيار BIGINT.
   + تحقق مدخلات Paging (pageNumber/pageSize) بأسلوب THROW.
   Type: READ (LIST)
========================================================= */

CREATE     PROCEDURE [VIC].[Handover_List_DL]
(
      @requestID      INT = NULL
    , @handoverTypeID INT = NULL
    , @fromDate       DATETIME = NULL
    , @toDate         DATETIME = NULL
    , @pageNumber     INT = 1
    , @pageSize       INT = 50
    , @idaraID_FK     NVARCHAR(10) = NULL
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
        IF @pageNumber IS NULL OR @pageNumber < 1
            THROW 50001, N'pageNumber غير صحيح', 1;

        IF @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200
            THROW 50001, N'pageSize غير صحيح', 1;

        DECLARE @P  INT = @pageNumber;
        DECLARE @PS INT = @pageSize;
        DECLARE @Skip INT = (@P - 1) * @PS;

        SELECT
              h.VehicleHandoverID
            , h.RequestID_FK
            , h.handOverTypeID_FK
            , h.handoverDate
            , h.note
            , h.entryDate
            , h.entryData
            , h.IdaraID_FK

            , t.handOverTypeName_A
            , t.handOverTypeName_E

            , r.chassisNumber_FK
            , r.fromUserID_FK
            , r.toUserID_FK
            , r.deptID_FK
        FROM VIC.VehicleHandover AS h
        INNER JOIN VIC.HandoverType AS t
            ON t.handOverTypeID = h.handOverTypeID_FK
        INNER JOIN VIC.VehicleTransferRequest AS r
            ON r.RequestID = h.RequestID_FK
        WHERE 1 = 1
          AND (@requestID IS NULL OR h.RequestID_FK = @requestID)
          AND (@handoverTypeID IS NULL OR h.handOverTypeID_FK = @handoverTypeID)
          AND (@fromDate IS NULL OR h.handoverDate >= @fromDate)
          AND (@toDate   IS NULL OR h.handoverDate <  DATEADD(DAY, 1, @toDate))
          AND (@IdaraID_BIG IS NULL OR h.IdaraID_FK = @IdaraID_BIG)
        ORDER BY
            h.handoverDate DESC,
            h.VehicleHandoverID DESC
        OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;

        IF @tc = 0 COMMIT;

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;
        THROW;
    END CATCH
END