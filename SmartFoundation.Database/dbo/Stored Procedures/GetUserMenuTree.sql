CREATE   PROCEDURE [dbo].[GetUserMenuTree]
    @UsersID int
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH UserPermMenus AS
    (
        -- المنيوهات اللي للمستخدم عليها صلاحية فعلية
        SELECT DISTINCT
            mt.menuID
        FROM dbo.V_MenuTree AS mt
        LEFT JOIN dbo.MenuDistributor AS md
            ON md.menuID_FK = mt.menuID 
           AND md.menuDistributorActive = 1 

        LEFT JOIN dbo.Distributor AS d
            ON d.distributorID = md.distributorID_FK 
           AND d.distributorActive = 1

        INNER JOIN dbo.DistributorPermissionType dpt 
            ON d.distributorID = dpt.distributorID_FK 
           AND dpt.distributorPermissionTypeActive = 1 
           AND dpt.distributorPermissionTypeStartDate IS NOT NULL 
           AND CAST(dpt.distributorPermissionTypeStartDate AS date) <= CAST(GETDATE() AS date)
           AND (
                  dpt.distributorPermissionTypeEndDate IS NULL 
                  OR CAST(dpt.distributorPermissionTypeEndDate AS date) > CAST(GETDATE() AS date)
               )

        INNER JOIN dbo.Permission p 
            ON dpt.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
           AND p.permissionActive = 1 
           AND p.permissionStartDate IS NOT NULL 
           AND CAST(p.permissionStartDate AS date) <= CAST(GETDATE() AS date)
           AND (
                  p.permissionEndDate IS NULL 
                  OR CAST(p.permissionEndDate AS date) > CAST(GETDATE() AS date)
               )

        INNER JOIN dbo.PermissionType pt 
            ON dpt.permissionTypeID_FK = pt.permissionTypeID
           AND pt.permissionTypeActive = 1 

        LEFT JOIN dbo.V_GetListUsersInDSD dsd 
            ON dsd.usersID = p.UsersID_FK

        LEFT JOIN dbo.V_GetFullStructureForDSD f 
            ON dsd.DSDID = f.DSDID

       -- WHERE dsd.userID = @UserID

        WHERE
        (
           (p.UsersID_FK is not null)
           and
           (p.permissionActive = 1)

           AND

           (cast(p.permissionStartDate as date) <= cast(GETDATE() as date))

           AND

           ((cast(p.permissionEndDate as date) > cast(GETDATE() as date)) OR p.permissionEndDate IS NULL)

           AND

            (
            
                    (p.UsersID_FK = @UsersID)
        
                    OR
        
                    (p.RoleID_FK in 
                    (select d.roleID_FK 
                    from  dbo.UserDistributor ud 
                    inner join  dbo.Distributor d on ud.distributorID_FK = d.distributorID
                    where d.distributorActive = 1 and d.roleID_FK is not null and ud.UDActive = 1 
                    and cast(ud.UDStartDate as date) <= cast(GETDATE() as date) 
                    and ((cast(ud.UDEndDate as date) > cast(GETDATE() as date)) or (ud.UDEndDate is null))
                    and ud.userID_FK = @UsersID
                    ))
        
                    OR
                    (p.DSDID_FK in
                    (
                    select f.DSDID
                    from  dbo.V_GetListUsersInDSD d
                    inner join  dbo.V_GetFullStructureForDSD f on d.DSDID = f.DSDID
                    where d.usersID = @UsersID
                    )
                    )

                    OR
                    (p.distributorID_FK in
                    (
                    select d.distributorID 
                    from  dbo.UserDistributor ud 
                    inner join  dbo.Distributor d on ud.distributorID_FK = d.distributorID
                    where d.distributorActive = 1  and ud.UDActive = 1 
                    and cast(ud.UDStartDate as date) <= cast(GETDATE() as date) 
                    and ((cast(ud.UDEndDate as date) > cast(GETDATE() as date)) or (ud.UDEndDate is null))
                    and ud.userID_FK = @UsersID
                    )
                    )

                    OR
                    (
                    p.UsersID_FK IS NULL AND p.DSDID_FK IS NULL AND p.RoleID_FK IS NULL
                    )

            )
        
        )



    ),
    MenuHierarchy AS
    (
        -- المنيوهات المصرّح بها للمستخدم
        SELECT 
            mt.*
        FROM dbo.V_MenuTree AS mt
        INNER JOIN UserPermMenus AS up
            ON up.menuID = mt.menuID

        UNION ALL

        -- جميع الآباء فوقها
        SELECT 
            parent.*
        FROM dbo.V_MenuTree AS parent
        INNER JOIN MenuHierarchy AS child
            ON child.parentMenuID_FK = parent.menuID
    ),
    ProgramNodes AS
    (
        -- عقد البرامج كـ Level 1
        SELECT DISTINCT
            mh.programID,
            mh.programName_A,
            mh.programName_E,
            mh.programIcon,
            mh.programLink,
            mh.programSerial,

            CAST(NULL AS int)               AS menuID,
            CAST(NULL AS nvarchar(100))     AS menuName_A,
            CAST(NULL AS nvarchar(100))     AS menuName_E,
            CAST(NULL AS nvarchar(4000))    AS menuDescription,
            CAST(NULL AS nvarchar(1000))    AS menuLink,
            CAST(NULL AS int)               AS parentMenuID_FK,
            CAST(NULL AS int)               AS programID_FK,
            CAST(NULL AS int)               AS menuSerial,
            CAST(NULL AS bit)               AS menuActive,
            CAST(NULL AS bit)               AS isDashboard,
            CAST(1 AS int)                  AS LevelNo,     -- البرنامج = لفل 1
            mh.programName_A                AS PathName_A,
            mh.programName_E                AS PathName_E,
            CAST(
                RIGHT('0000' + CAST(ISNULL(mh.programSerial, mh.programID) AS varchar(4)), 4)
                AS varchar(500)
            ) AS SortKey,
            CAST(1 AS int)                  AS HasPermissionForUser,
            mh.programName_A                AS IndentedMenuName
        FROM MenuHierarchy AS mh
    ),
    MenuNodes AS
    (
        -- عقد المنيو من الشجرة مع رفع المستوى +1
        SELECT DISTINCT
            mh.programID,
            mh.programName_A,
            mh.programName_E,
            mh.programIcon,
            mh.programLink,
            mh.programSerial,

            mh.menuID,
            mh.menuName_A,
            mh.menuName_E,
            mh.menuDescription,
            mh.menuLink,
            mh.parentMenuID_FK,
            mh.programID_FK,
            mh.menuSerial,
            mh.menuActive,
            mh.isDashboard,
            mh.LevelNo + 1 AS LevelNo,         -- نرفع المستوى 1 عشان البرنامج يكون 1
            mh.PathName_A,
            mh.PathName_E,
            mh.SortKey,
            CASE 
                WHEN up.menuID IS NULL THEN 0 
                ELSE 1 
            END AS HasPermissionForUser,
            REPLICATE(N'   ', mh.LevelNo) + mh.menuName_A AS IndentedMenuName
        FROM MenuHierarchy AS mh
        LEFT JOIN UserPermMenus AS up
            ON up.menuID = mh.menuID
    )


    --select alls.MPID,alls.menuName_A,alls.MPSerial,alls.MPLink ,alls.parentMenuID_FK,alls.programID,isnull(parentMenuID_FK ,programID ) parents,alls.Levels, alls.MPIcon


    -- النتيجة النهائية: Program + Menus
    SELECT 

        programID as MPID, 
        programName_A AS menuName_A,
        programSerial as MPSerial,
        programLink MPLink,
        parentMenuID_FK,
        --programID_FK as programID,
        parentMenuID_FK  as parents,
        LevelNo as Levels,
        programIcon as MPIcon,


        programName_A AS MenuNameForView,
        LevelNo,
        menuLink,
        PathName_A,
        PathName_E,
        programID,
        programName_A,
        programName_E,
        programIcon,
        programLink,
        programSerial,
        menuID,
        --menuName_A,
        --menuName_E,
        --menuDescription,
        --parentMenuID_FK,
       -- programID_FK,
       -- menuSerial,
       -- menuActive,
       -- isDashboard,
        SortKey,
        HasPermissionForUser,
        IndentedMenuName
        
    FROM ProgramNodes

    UNION ALL

    SELECT 

        menuID as MPID, 
        menuName_A AS menuName_A,
        menuSerial as MPSerial,
        programLink MPLink,
        parentMenuID_FK,
        --programID_FK as programID,
        isnull(parentMenuID_FK ,programID ) as parents,
        LevelNo as Levels,
        --programIcon as MPIcon,
        null as MPIcon,

        menuName_A AS MenuNameForView,
        LevelNo,
        menuLink,
        PathName_A,
        PathName_E,
        programID,
        programName_A,
        programName_E,
        programIcon,
        programLink,
        programSerial,
       
        menuID,
       -- menuName_A,
        --menuName_E,
       -- menuDescription,
       -- parentMenuID_FK,
       -- programID_FK,
       -- menuSerial,
       -- menuActive,
       -- isDashboard,
        SortKey,
        HasPermissionForUser,
        IndentedMenuName
        
    FROM MenuNodes
    ORDER BY 
        SortKey, LevelNo
    OPTION (MAXRECURSION 50);
END
