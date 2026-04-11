
CREATE   PROCEDURE [VIC].[CustodyCurrentListDL]
(
      @userID        INT = NULL
    , @generalNo     NVARCHAR(100) = NULL
    , @chassisNumber NVARCHAR(100) = NULL
    , @pageNumber    INT = 1
    , @pageSize      INT = 50
    , @idaraID_FK    NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @P  INT = CASE WHEN @pageNumber IS NULL OR @pageNumber < 1 THEN 1 ELSE @pageNumber END;
    DECLARE @PS INT = CASE WHEN @pageSize IS NULL OR @pageSize < 1 OR @pageSize > 200 THEN 50 ELSE @pageSize END;
    DECLARE @Skip INT = (@P - 1) * @PS;

    DECLARE @GN NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@generalNo)), N'');
    DECLARE @CH NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @IdaraID_BIG BIGINT = TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

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
        , vw.IdaraID_Snapshot

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
    WHERE vw.endDate IS NULL
      AND (@userID IS NULL OR vw.userID_FK = @userID)
      AND (@CH IS NULL OR vw.chassisNumber_FK = @CH)
      AND (@GN IS NULL OR ut.fno = @GN OR vw.GeneralNo_Snapshot = @GN)
      AND (
            @IdaraID_BIG IS NULL
            OR vw.IdaraID_Snapshot = TRY_CONVERT(INT, @IdaraID_BIG)
          )
    ORDER BY vw.startDate DESC
    OFFSET @Skip ROWS FETCH NEXT @PS ROWS ONLY;
END