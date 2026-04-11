
CREATE   PROCEDURE [VIC].[Custody_Current_ByUser_DL]
(
      @userID     INT
    , @idaraID_FK NVARCHAR(10) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @userID IS NULL OR @userID <= 0
    BEGIN
        THROW 50001, N'userID مطلوب', 1;
    END

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
      AND vw.userID_FK = @userID
      AND (
            @IdaraID_BIG IS NULL
            OR vw.IdaraID_Snapshot = TRY_CONVERT(INT, @IdaraID_BIG)
          )
    ORDER BY vw.startDate DESC;
END