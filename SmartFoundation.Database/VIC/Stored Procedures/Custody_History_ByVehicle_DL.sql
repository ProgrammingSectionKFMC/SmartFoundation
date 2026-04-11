
/* =========================================================
   Description:
   إرجاع تاريخ العهد (الحالية والسابقة) لمركبة محددة حسب chassisNumber مع Paging،
   مع إمكانية فلترة النتائج بتاريخ البداية (From/To)، وإظهار Snapshot + البيانات الحالية للمستخدم والهيكل التنظيمي.
   Type: READ (LIST)
========================================================= */

CREATE   PROCEDURE [VIC].[Custody_History_ByVehicle_DL]
(
      @chassisNumber NVARCHAR(100)
    , @fromDate      DATETIME = NULL
    , @toDate        DATETIME = NULL
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');
    IF @CH IS NULL
    BEGIN
        THROW 50001, N'chassisNumber مطلوب', 1;
    END

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    SELECT
          vw.vehicleWithUsersID
        , vw.chassisNumber_FK
        , vw.userID_FK
        , vw.RequestID_FK
        , vw.startDate
        , vw.endDate
        , vw.note
        , vw.entryDate
        , vw.entryData
        , vw.hostName

        /* Snapshot */
        , vw.GeneralNo_Snapshot
        , vw.UserFullName_Snapshot
        , vw.DSDID_Snapshot
        , vw.OrganizationName_Snap
        , vw.IdaraName_Snap
        , vw.DeptID_Snapshot
        , vw.DeptName_Snapshot
        , vw.SectionID_Snapshot
        , vw.SectionName_Snapshot
        , vw.DivisonName_Snap
        , vw.OrgSnapshotDate

        /* Current User */
        , ut.fno           AS GeneralNo_Current
        , ut.IDNumber      AS NationalID_Current
        , ut.mobileNo      AS MobileNo_Current
        , CONCAT_WS(N' ', ut.fristName_A, ut.secondName_A, ut.thirdName_A, ut.lastName_A) AS UserFullName_A_Current
        , CONCAT_WS(N' ', ut.fristName_E, ut.secondName_E, ut.thirdName_E, ut.lastName_E) AS UserFullName_E_Current
        , ut.dsdID_FK      AS DSDID_Current

        /* Current Org */
        , fs.OrganizationName AS OrganizationName_Current
        , fs.IdaraName        AS IdaraName_Current
        , fs.DepartmentName   AS DepartmentName_Current
        , fs.SectionName      AS SectionName_Current
        , fs.DivisonName      AS DivisonName_Current
    FROM VIC.vehicleWithUsers AS vw
    LEFT JOIN DATACORE.dbo.UserTemp AS ut
        ON ut.userID_FK = vw.userID_FK
    LEFT JOIN DATACORE.dbo.V_GetFullStructureForDSD AS fs
        ON fs.DSDID = ut.dsdID_FK
    WHERE vw.chassisNumber_FK = @CH
      AND (@fromDate IS NULL OR vw.startDate >= @fromDate)
      AND (@toDate   IS NULL OR vw.startDate <  DATEADD(DAY, 1, @toDate))
    ORDER BY
        vw.startDate DESC,
        vw.entryDate DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END