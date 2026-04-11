

CREATE VIEW [dbo].[V_GetFullPermissionDetails]
AS
WITH BasePermission AS
(
    SELECT
          pr.permissionID
        , d.DistributorID_FK                         AS distributorID
        , md.menuID_FK                               AS menuID
        , p.permissionTypeID
        , dd.distributorName_A
        , p.permissionTypeName_A
        , m.menuName_A
        , pr.DistributorPermissionTypeID_FK

        , CASE
            WHEN pr.UsersID_FK       IS NOT NULL THEN udir.FullName
            WHEN pr.RoleID_FK        IS NOT NULL THEN r.roleName_A
            WHEN pr.DSDID_FK         IS NOT NULL THEN
                CASE
                    WHEN dsd.DivisonName    IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '') + N'-' + ISNULL(dsd.SectionName, '') + N'-' + ISNULL(dsd.DivisonName, '')
                    WHEN dsd.SectionName    IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '') + N'-' + ISNULL(dsd.SectionName, '')
                    WHEN dsd.DepartmentName IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '')
                    ELSE ISNULL(dsd.IdaraName, '')
                END
            WHEN pr.IdaraID_FK       IS NOT NULL THEN da.idaraLongName_A
            WHEN pr.distributorID_FK IS NOT NULL THEN ds.distributorName_A
            ELSE NULL
          END                                         AS PermissionHolderName

        , CASE
            WHEN pr.UsersID_FK       IS NOT NULL THEN pr.UsersID_FK
            WHEN pr.RoleID_FK        IS NOT NULL THEN pr.RoleID_FK
            WHEN pr.DSDID_FK         IS NOT NULL THEN pr.DSDID_FK
            WHEN pr.IdaraID_FK       IS NOT NULL THEN pr.IdaraID_FK
            WHEN pr.distributorID_FK IS NOT NULL THEN pr.distributorID_FK
            ELSE NULL
          END                                         AS PermissionHolderID

        , CASE
            WHEN pr.UsersID_FK       IS NOT NULL THEN N'User'
            WHEN pr.RoleID_FK        IS NOT NULL THEN N'Role'
            WHEN pr.DSDID_FK         IS NOT NULL THEN N'DSD'
            WHEN pr.IdaraID_FK       IS NOT NULL THEN N'Idara'
            WHEN pr.distributorID_FK IS NOT NULL THEN N'Distributor'
            ELSE N'Unknown'
          END                                         AS PermissionHolderType

        , CASE
            WHEN pr.UsersID_FK       IS NOT NULL THEN 1
            WHEN pr.distributorID_FK IS NOT NULL THEN 2
            WHEN pr.RoleID_FK        IS NOT NULL THEN 3
            WHEN pr.IdaraID_FK       IS NOT NULL THEN 4
            WHEN pr.DSDID_FK         IS NOT NULL THEN 5
            ELSE 0
          END                                         AS PermissionHolderTypeID

        , pr.UsersID_FK
        , udir.FullName                               AS UserFullName
        , pr.RoleID_FK
        , r.roleName_A                                AS RoleName
        , pr.distributorID_FK
        , ds.distributorName_A                        AS DistributorName
        , pr.DSDID_FK
        , CASE
            WHEN pr.DSDID_FK IS NOT NULL THEN
                CASE
                    WHEN dsd.DivisonName    IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '') + N'-' + ISNULL(dsd.SectionName, '') + N'-' + ISNULL(dsd.DivisonName, '')
                    WHEN dsd.SectionName    IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '') + N'-' + ISNULL(dsd.SectionName, '')
                    WHEN dsd.DepartmentName IS NOT NULL THEN ISNULL(dsd.IdaraName, '') + N'-' + ISNULL(dsd.DepartmentName, '')
                    WHEN dsd.IdaraName      IS NOT NULL THEN ISNULL(dsd.IdaraName, '')
                    ELSE NULL
                END
            ELSE NULL
          END                                         AS DSDName
        , pr.IdaraID_FK
        , da.idaraLongName_A                          AS IdaraName
        , pr.permissionStartDate
        , pr.permissionEndDate
        , pr.permissionNote
        , pr.InIdaraID
        ,pr.entryData                                  AS GrantedByRaw
        ,TRY_CONVERT(BIGINT, pr.entryData)             AS GrantedByUserID
        ,grantor.FullName                              AS GrantedByUserName
        ,pr.entryDate                                  AS GrantedAt
        , pr.hostName
        , pr.permissionActive
        , d.distributorPermissionTypeActive
        , dd.distributorActive
        , p.permissionTypeActive
        , ISNULL(udir.userActive, 1)                  AS userActive
        , md.menuDistributorActive
        , m.menuActive
    FROM dbo.Permission pr
    INNER JOIN dbo.DistributorPermissionType d
        ON d.distributorPermissionTypeID = pr.DistributorPermissionTypeID_FK
    INNER JOIN dbo.PermissionType p
        ON p.permissionTypeID = d.permissionTypeID_FK
    INNER JOIN dbo.Distributor dd
        ON dd.distributorID = d.DistributorID_FK
    LEFT JOIN dbo.V_GetFullSystemUsersDetails udir
        ON udir.usersID = pr.UsersID_FK
    LEFT JOIN dbo.V_GetFullSystemUsersDetails grantor
        ON grantor.usersID = TRY_CONVERT(BIGINT, pr.entryData)
    LEFT JOIN dbo.Role r
        ON r.roleID = pr.RoleID_FK
    LEFT JOIN dbo.Distributor ds
        ON ds.distributorID = pr.distributorID_FK
    LEFT JOIN dbo.V_GetFullStructureForDSD dsd
        ON dsd.DSDID = pr.DSDID_FK
    LEFT JOIN dbo.Idara da
        ON da.idaraID = pr.IdaraID_FK
    LEFT JOIN dbo.MenuDistributor md
        ON md.distributorID_FK = d.DistributorID_FK
       AND ISNULL(md.menuDistributorActive, 1) = 1
    LEFT JOIN dbo.Menu m
        ON m.menuID = md.menuID_FK
       AND ISNULL(m.menuActive, 1) = 1
),
ResolvedUsers AS
(
    /* 1) صلاحية مباشرة على مستخدم */
    SELECT
          bp.permissionID
        , bp.menuID
        , bp.permissionTypeID
        , bp.distributorID
        , bp.UsersID_FK                               AS EffectiveUserID
        , N'DirectUser'                               AS EffectiveBy
    FROM BasePermission bp
    WHERE bp.UsersID_FK IS NOT NULL

    UNION ALL

    /* 2) صلاحية على إدارة => كل مستخدمي الإدارة */
    SELECT
          bp.permissionID
        , bp.menuID
        , bp.permissionTypeID
        , bp.distributorID
        , ud.usersID_FK                               AS EffectiveUserID
        , N'Idara'                                    AS EffectiveBy
    FROM BasePermission bp
    INNER JOIN dbo.UsersDetails ud
        ON ud.IdaraID = bp.IdaraID_FK
       AND ud.userActive = 1
    WHERE bp.IdaraID_FK IS NOT NULL

    UNION ALL

    /* 3) صلاحية على DSD => كل مستخدمي DSD */
    SELECT
          bp.permissionID
        , bp.menuID
        , bp.permissionTypeID
        , bp.distributorID
        , v.usersID                                   AS EffectiveUserID
        , N'DSD'                                      AS EffectiveBy
    FROM BasePermission bp
    INNER JOIN dbo.V_GetListUsersInDSD v
        ON v.DSDID = bp.DSDID_FK
    WHERE bp.DSDID_FK IS NOT NULL

    UNION ALL

    /* 4) صلاحية على Role => المستخدمون المرتبطون بموزعين هذا الدور */
    SELECT
          bp.permissionID
        , bp.menuID
        , bp.permissionTypeID
        , bp.distributorID
        , ud.userID_FK                                AS EffectiveUserID
        , N'Role'                                     AS EffectiveBy
    FROM BasePermission bp
    INNER JOIN dbo.Distributor drole
        ON drole.roleID_FK = bp.RoleID_FK
       AND ISNULL(drole.distributorActive, 1) = 1
    INNER JOIN dbo.UserDistributor ud
        ON ud.distributorID_FK = drole.distributorID
       AND ISNULL(ud.UDActive, 1) = 1
    WHERE bp.RoleID_FK IS NOT NULL

    UNION ALL

    /* 5) صلاحية على موزع => المستخدمون المرتبطون بهذا الموزع */
    SELECT
          bp.permissionID
        , bp.menuID
        , bp.permissionTypeID
        , bp.distributorID
        , ud.userID_FK                                AS EffectiveUserID
        , N'Distributor'                              AS EffectiveBy
    FROM BasePermission bp
    INNER JOIN dbo.UserDistributor ud
        ON ud.distributorID_FK = bp.distributorID_FK
       AND ISNULL(ud.UDActive, 1) = 1
    WHERE bp.distributorID_FK IS NOT NULL
)
SELECT DISTINCT
      bp.permissionID
    , bp.distributorID
    , bp.menuID
    , bp.permissionTypeID
    , bp.distributorName_A
    , bp.permissionTypeName_A
    , bp.menuName_A
    , bp.DistributorPermissionTypeID_FK
    , bp.PermissionHolderName
    , bp.PermissionHolderID
    , bp.PermissionHolderType
    , bp.PermissionHolderTypeID
    , bp.UsersID_FK
    , bp.UserFullName
    , bp.RoleID_FK
    , bp.RoleName
    , bp.distributorID_FK
    , bp.DistributorName
    , bp.DSDID_FK
    , bp.DSDName
    , bp.IdaraID_FK
    , bp.IdaraName
    , bp.permissionStartDate
    , bp.permissionEndDate
    , bp.permissionNote
    , bp.InIdaraID
    , bp.GrantedByRaw
    , bp.GrantedByUserID
    , bp.GrantedByUserName
    , bp.GrantedAt
    , bp.hostName
    , bp.permissionActive
    , bp.distributorPermissionTypeActive
    , bp.distributorActive
    , bp.permissionTypeActive
    , bp.userActive
    , bp.menuDistributorActive
    , bp.menuActive

    /* أعمدة جديدة للبحث الفعلي */
    , ru.EffectiveUserID
    , eff.FullName                                   AS EffectiveUserFullName
    , eff.GeneralNo                                  AS EffectiveUserGeneralNo
    , eff.IdaraID                                    AS EffectiveUserIdaraID
    , eff.idaraLongName_A                                  AS EffectiveUserIdaraName
    , ru.EffectiveBy
FROM BasePermission bp
LEFT JOIN ResolvedUsers ru
    ON ru.permissionID = bp.permissionID
   AND ISNULL(ru.menuID, -1) = ISNULL(bp.menuID, -1)
LEFT JOIN dbo.V_GetFullSystemUsersDetails eff
    ON eff.usersID = ru.EffectiveUserID;

GO



GO



GO
