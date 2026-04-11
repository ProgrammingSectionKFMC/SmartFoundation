
/* =========================================================
   Description:
   قائمة طلبات نقل المركبات لمدير القسم
   - نفس الإدارة
   - نفس القسم
   - فقط الطلبات التي آخر حالتها = Created
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[TransferRequest_Pending_ByDept_DL]
(
      @userID        INT
    , @idaraID_FK    NVARCHAR(10)
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdaraID INT =
        TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    DECLARE @CurrentDeptID INT;

    /* ===== قسم المستخدم ===== */
    SELECT TOP 1
        @CurrentDeptID = fs.DepartmentID
    FROM DATACORE.dbo.UserTemp ut
    INNER JOIN DATACORE.dbo.V_GetFullStructureForDSD fs
        ON fs.DSDID = ut.dsdID_FK
    WHERE ut.userID_FK = @userID;

    IF @CurrentDeptID IS NULL
        THROW 50001, N'تعذر تحديد قسم المستخدم', 1;

    DECLARE @Skip INT = (@pageNumber - 1) * @pageSize;

    /* ===== القائمة ===== */
    SELECT
          r.RequestID
        , r.chassisNumber_FK
        , r.fromUserID_FK
        , r.toUserID_FK
        , r.deptID_FK
        , r.entryDate
        , r.aproveNote

        , v.plateNumbers
        , v.plateLetters
        , v.armyNumber

        , f.UserFullName_Snapshot AS FromUserName
        , t.UserFullName_A        AS ToUserName

        , h.Status
        , h.ActionDate

    FROM VIC.VehicleTransferRequest r

    INNER JOIN VIC.Vehicles v
        ON v.chassisNumber = r.chassisNumber_FK

    /* من */
    LEFT JOIN VIC.vehicleWithUsers f
        ON f.chassisNumber_FK = r.chassisNumber_FK
       AND f.userID_FK = r.fromUserID_FK

    /* إلى */
    LEFT JOIN DATACORE.dbo.UserTemp ut2
        ON ut2.userID_FK = r.toUserID_FK

    LEFT JOIN DATACORE.dbo.V_GetFullStructureForDSD fs2
        ON fs2.DSDID = ut2.dsdID_FK

    CROSS APPLY
    (
        SELECT TOP 1
              h1.Status
            , h1.ActionDate
        FROM VIC.VehicleTransferRequestHistory h1
        WHERE h1.RequestID_FK = r.RequestID
        ORDER BY h1.ActionDate DESC, h1.HistoryID DESC
    ) h

    OUTER APPLY
    (
        SELECT CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS UserFullName_A
        FROM DATACORE.dbo.UserTemp ut
        WHERE ut.userID_FK = r.toUserID_FK
    ) t

    WHERE r.IdaraID_FK = @IdaraID
      AND r.deptID_FK = @CurrentDeptID
      AND ISNULL(r.active, 0) = 1
      AND h.Status = N'PENDING'

    ORDER BY r.RequestID DESC
    OFFSET @Skip ROWS FETCH NEXT @pageSize ROWS ONLY;

END