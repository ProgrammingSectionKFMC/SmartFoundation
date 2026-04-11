
/* =========================================================
   Description:
   إرجاع طلبات نقل المركبات الموافق عليها فقط من جدول
   VIC.VehicleTransferRequest بحيث تكون آخر حالة في
   VIC.VehicleTransferRequestHistory = Approved
   ولم يتم إغلاقها أو رفضها أو إلغاؤها.

   الغرض:
   استخدامه في صفحة تنفيذ نقل العهد، بحيث لا تظهر
   إلا الطلبات الموافق عليها والجاهزة للتنفيذ.

   Type: READ (LIST)
========================================================= */

CREATE         PROCEDURE [VIC].[TransferRequest_Approved_List_DL]
(
      @requestID      INT = NULL
    , @chassisNumber  NVARCHAR(100) = NULL
    , @fromUserID     INT = NULL
    , @toUserID       INT = NULL
    , @pageNumber     INT = 1
    , @pageSize       INT = 50
    , @idaraID_FK     NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

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

            , hLast.HistoryID       AS LastHistoryID
            , hLast.Status          AS LastStatus
            , hLast.ActionBy        AS LastActionBy
            , hLast.ActionDate      AS LastActionDate
            , hLast.Notes           AS LastNotes
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
    FROM R
    LEFT JOIN VIC.VehicleTransferRequestType T
        ON T.VehicleTransferRequestTypeID = R.RequestTypeID_FK
    WHERE R.LastStatus = N'Approved'
      AND ISNULL(R.active, 0) = 1
    ORDER BY
          R.LastActionDate DESC
        , R.RequestID DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END