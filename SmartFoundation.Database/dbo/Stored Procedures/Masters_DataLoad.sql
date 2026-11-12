CREATE   PROCEDURE [dbo].[Masters_DataLoad]
      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @parameter_01   NVARCHAR(4000) = NULL
    , @parameter_02   NVARCHAR(4000) = NULL
    , @parameter_03   NVARCHAR(4000) = NULL
    , @parameter_04   NVARCHAR(4000) = NULL
    , @parameter_05   NVARCHAR(4000) = NULL
    , @parameter_06   NVARCHAR(4000) = NULL
    , @parameter_07   NVARCHAR(4000) = NULL
    , @parameter_08   NVARCHAR(4000) = NULL
    , @parameter_09   NVARCHAR(4000) = NULL
    , @parameter_10   NVARCHAR(4000) = NULL
    , @parameter_11   NVARCHAR(4000) = NULL
    , @parameter_12   NVARCHAR(4000) = NULL
    , @parameter_13   NVARCHAR(4000) = NULL
    , @parameter_14   NVARCHAR(4000) = NULL
    , @parameter_15   NVARCHAR(4000) = NULL
    , @parameter_16   NVARCHAR(4000) = NULL
    , @parameter_17   NVARCHAR(4000) = NULL
    , @parameter_18   NVARCHAR(4000) = NULL
    , @parameter_19   NVARCHAR(4000) = NULL
    , @parameter_20   NVARCHAR(4000) = NULL

AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------
    --                   START TRY BLOCK
    -------------------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;

        Declare @isAdmin int;
        Set @isAdmin =(select top(1) 
        
        isnull(ud.usersAuthTypeID_FK,3) 
        
        from dbo.Users s
        Left JOIN  dbo.UsersDetails ud ON s.usersID = ud.usersID_FK
        left Join  dbo.UsersAuthType ua on ud.usersAuthTypeID_FK = ua.UsersAuthTypeID
        
        where s.usersActive = 1 
        and s.usersID = @entrydata 
        and ud.userActive = 1
        order by s.usersID desc)

          -- User Permission
             SELECT permissionTypeName_E
            FROM dbo.ft_UserPagePermissions(@entrydata, @pageName_);

    -------------------------------------------------------------------
    --                     PAGE: Permission
    -------------------------------------------------------------------
        IF @pageName_ = 'Permission'
        BEGIN
          
            -- Permission Data


            Declare @DsdID bigint,@entryDataIdaraID int
            Set @entryDataIdaraID = (
            select distinct f.IdaraID 
            from dbo.V_GetListUsersInDSD u 
            inner join dbo.V_GetFullStructureForDSD f on u.DSDID = f.DSDID
            where u.usersID = @entrydata)

            --by user
            if(@parameter_01 = 1)
            BEGIN
            SELECT 
                  p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
           
            WHERE p.userID = @parameter_02
              AND p.distributorID_FK is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK is null
              AND p.DSDID_FK is null
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END
          

            --by Distributors
            else if (@parameter_01 = 2)
            Begin
            SELECT 
                  p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE  p.distributorID_FK = @parameter_03
               AND p.userID  is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK is null
              AND p.DSDID_FK is null
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END

              --by Roles
            else if(@parameter_01 = 3)
            Begin
            SELECT 
                 p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE p.userID is null
              AND p.distributorID_FK is null
              AND p.PermissionRoleID = @parameter_04
              AND p.IdaraID_FK is null
              AND p.DSDID_FK is null
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END
            
              --by idara
            else if(@parameter_01 = 4)
            Begin
            SELECT 
                 p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE p.userID is null
              AND p.distributorID_FK is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK = @parameter_05
              AND p.DSDID_FK is null
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END

            --by Depts
            else if(@parameter_01 = 5 and @parameter_06 is not null and @parameter_07 is null and @parameter_08 is null)
            Begin
            set @DsdID = (select Top(1) d.DSDID from dbo.DeptSecDiv d where d.idaraID_FK = @entryDataIdaraID and d.deptID_FK = @parameter_06 and d.secID_FK is null and d.divID_FK is null order by d.DSDID desc )
            SELECT 
                 p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE p.userID is null
              AND p.distributorID_FK is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK is null
              AND p.DSDID_FK = @DsdID
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END
           

            --by secs
            else if(@parameter_01 = 5 and @parameter_06 is not null and @parameter_07 is not null and @parameter_08 is null)
            Begin
            set @DsdID = (select Top(1) d.DSDID from dbo.DeptSecDiv d where d.idaraID_FK = @entryDataIdaraID and d.deptID_FK = @parameter_06 and d.secID_FK = @parameter_07 and d.divID_FK is null order by d.DSDID desc )
            SELECT 
                 p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE p.userID is null
              AND p.distributorID_FK is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK is null
              AND p.DSDID_FK = @DsdID
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END

             --by secs
            else if(@parameter_01 = 5 and @parameter_06 is not null and @parameter_07 is not null and @parameter_08 is not null)
            Begin
            set @DsdID = (select Top(1) d.DSDID from dbo.DeptSecDiv d where d.idaraID_FK = @entryDataIdaraID and d.deptID_FK = @parameter_06 and d.secID_FK = @parameter_07 and d.divID_FK = @parameter_08 order by d.DSDID desc )
            SELECT 
                 p.permissionID
                , p.userID
                ,p.distributorID_FK
                ,p.PermissionRoleID
                ,p.IdaraID_FK
                ,p.DSDID_FK
                ,P.deptID
                ,p.secID
                ,p.divID
                , p.menuName_A
                , p.permissionTypeName_A
                , CONVERT(NVARCHAR(50), p.permissionStartDate, 23) AS permissionStartDate
                , CONVERT(NVARCHAR(50), p.permissionEndDate, 23) AS permissionEndDate
                , p.permissionNote
            FROM  dbo.V_GetListUserPermission p
            WHERE p.userID is null
              AND p.distributorID_FK is null
              AND p.PermissionRoleID is null
              AND p.IdaraID_FK is null
              AND p.DSDID_FK = @DsdID
              --AND p.IdaraID_FK = @idaraID
            ORDER BY p.permissionID DESC;
            END

              ELSE
            BEGIN

            SELECT 
                  null permissionID
                , null userID
                ,  null menuName_A
                ,  null permissionTypeName_A
                ,null AS permissionStartDate
                , null AS permissionEndDate
                , null permissionNote
            

            END





            -- Users DDL
             if(@isAdmin = 1)
            BEGIN

            SELECT DISTINCT 
                  CAST(d.usersID AS BIGINT) AS userID_
                , CAST(d.nationalID AS NVARCHAR(20)) + ' - ' + d.FullName+' - ' + s.idaraLongName_A AS FullName
                , d.userTypeID
            FROM  dbo.V_GetFullStructureForDSD f
            INNER JOIN  dbo.V_GetListUsersInDSD d ON f.DSDID = d.DSDID
            inner join  dbo.V_GetFullSystemUsersDetails s on d.usersID = s.usersID
            WHERE  d.usersID IS NOT NULL
            ORDER BY d.userTypeID ASC;
            END

            else if(@isAdmin = 2)
            BEGIN
              SELECT DISTINCT 
                  CAST(d.usersID AS BIGINT) AS userID_
                , CAST(d.nationalID AS NVARCHAR(20)) + ' - ' + d.FullName AS FullName
                , d.userTypeID
            FROM  dbo.V_GetFullStructureForDSD f
            INNER JOIN  dbo.V_GetListUsersInDSD d ON f.DSDID = d.DSDID
            WHERE f.IdaraID = @idaraID 
              AND d.usersID IS NOT NULL
            ORDER BY d.userTypeID ASC;

            END
             else if(@isAdmin = 3)

             BEGIN
               SELECT DISTINCT 
                  CAST(d.usersID AS BIGINT) AS userID_
                , CAST(d.nationalID AS NVARCHAR(20)) + ' - ' + d.FullName AS FullName
                , d.userTypeID
            FROM  dbo.V_GetFullStructureForDSD f
            INNER JOIN  dbo.V_GetListUsersInDSD d ON f.DSDID = d.DSDID
            WHERE f.IdaraID = @idaraID 
              AND d.usersID IS NOT NULL
            ORDER BY d.userTypeID ASC;

             END

            -- Distributors DDL
            
            if(@isAdmin = 1)
            BEGIN

            SELECT d.distributorID, d.distributorName_A
            FROM  dbo.Distributor d
            INNER JOIN  dbo.MenuDistributor md ON d.distributorID = md.distributorID_FK
            inner join  dbo.Menu m on md.menuID_FK = m .menuID
            WHERE d.distributorActive = 1 
              AND md.menuDistributorActive = 1
              and m.PageLvl in (1,2,3);
             END
            else if(@isAdmin = 2)
            BEGIN

            SELECT d.distributorID, d.distributorName_A
            FROM  dbo.Distributor d
            INNER JOIN  dbo.MenuDistributor md ON d.distributorID = md.distributorID_FK
            inner join  dbo.Menu m on md.menuID_FK = m .menuID
            WHERE d.distributorActive = 1 
              AND md.menuDistributorActive = 1 
              and m.PageLvl in (2,3);
             END
              else if(@isAdmin = 3)
            BEGIN

            SELECT d.distributorID, d.distributorName_A
            FROM  dbo.Distributor d
            INNER JOIN  dbo.MenuDistributor md ON d.distributorID = md.distributorID_FK
            inner join  dbo.Menu m on md.menuID_FK = m .menuID
            WHERE d.distributorActive = 1 
              AND md.menuDistributorActive = 1 
              and m.PageLvl in (3);
             END
          

            -- Permission Types DDL
      
          

     if(@isAdmin = 1)
            BEGIN

          
            SELECT 
                  dpt.distributorPermissionTypeID
                , pt.permissionTypeName_A
                , dpt.distributorID_FK
            FROM  dbo.DistributorPermissionType dpt
            INNER JOIN  dbo.PermissionType pt ON dpt.permissionTypeID_FK = pt.permissionTypeID
            WHERE pt.permissionTypeActive = 1 
              AND dpt.distributorPermissionTypeActive = 1
              and dpt.permissionAuthLvl in (1,2,3);
              
             


             END
            else if(@isAdmin = 2) 
            BEGIN

          
            SELECT 
                  dpt.distributorPermissionTypeID
                , pt.permissionTypeName_A
                , dpt.distributorID_FK
            FROM  dbo.DistributorPermissionType dpt
            INNER JOIN  dbo.PermissionType pt ON dpt.permissionTypeID_FK = pt.permissionTypeID
            WHERE pt.permissionTypeActive = 1 
              AND dpt.distributorPermissionTypeActive = 1
              and dpt.permissionAuthLvl in (2,3);


             END
              else if(@isAdmin = 3) 
            BEGIN

          
            SELECT 
                  dpt.distributorPermissionTypeID
                , pt.permissionTypeName_A
                , dpt.distributorID_FK
            FROM  dbo.DistributorPermissionType dpt
            INNER JOIN  dbo.PermissionType pt ON dpt.permissionTypeID_FK = pt.permissionTypeID
            WHERE pt.permissionTypeActive = 1 
              AND dpt.distributorPermissionTypeActive = 1
              and dpt.permissionAuthLvl in (3);


             END



              -- IDara DDL
            SELECT distinct D.idaraID,D.idaraLongName_A 
            FROM  DBO.Idara D
            order by D.idaraID asc


               -- Dept DDL
            SELECT distinct D.deptID,D.deptName_A ,d.idaraID_FK
            FROM  DBO.Department D
            WHERE D.deptActive = 1 and d.idaraID_FK = @idaraID

            -- Section DDL
            SELECT distinct s.secID,s.secName_A,a.deptID
            FROM  DBO.Section s
            inner join  dbo.DeptSecDiv d on s.secID =d.secID_FK
            inner join  dbo.Department a on d.deptID_FK = a.deptID
            WHERE s.secActive = 1 and a.idaraID_FK = @idaraID

            
            -- Divison DDL
            SELECT distinct s.divID,s.divName_A,a.secID
            FROM  DBO.Divison s
            inner join  dbo.DeptSecDiv d on s.divID =d.divID_FK
             inner join  dbo.Section a on d.secID_FK= a.secID
             inner join  dbo.Department dd on d.deptID_FK = dd.deptID
            WHERE s.divActive = 1 AND dd.IdaraID_FK = @idaraID

            -- Role DDL
            select r.roleID,r.roleName_A 
            from  dbo.[Role] r
            
              -- Distributors To give permission DDL
            SELECT d.distributorID, d.distributorName_A
            FROM  dbo.Distributor d
            WHERE d.distributorActive = 1 and d.distributorType_FK = 2 
            and d.DSDID_FK in (select ds.DSDID from dbo.DeptSecDiv ds where ds.idaraID_FK = @entryDataIdaraID)

            -- Programs DDL
            SELECT DISTINCT
                   p.programID,
                   p.programName_A
            FROM dbo.Menu m
            LEFT JOIN dbo.Menu parentMenu
                ON parentMenu.menuID = m.parentMenuID_FK
            INNER JOIN dbo.Program p
                ON p.programID = COALESCE(m.programID_FK, parentMenu.programID_FK)
            INNER JOIN dbo.MenuDistributor md
                ON md.menuID_FK = m.menuID
               AND md.menuDistributorActive = 1
            INNER JOIN dbo.Distributor d
                ON d.distributorID = md.distributorID_FK
               AND d.distributorActive = 1
            WHERE p.programActive = 1
              AND m.menuActive = 1
              AND ISNULL(m.menuLink, '') <> 'MVC'
              AND (
                    (@isAdmin = 1 AND m.PageLvl IN (1, 2, 3))
                 OR (@isAdmin = 2 AND m.PageLvl IN (2, 3))
                 OR (@isAdmin = 3 AND m.PageLvl IN (3))
              )
            ORDER BY p.programName_A;

            -- Pages DDL
            SELECT DISTINCT
                   d.distributorID,
                   m.menuName_A,
                   COALESCE(m.programID_FK, parentMenu.programID_FK) AS programID_FK,
                   m.menuID,
                   m.PageLvl
            FROM dbo.Menu m
            LEFT JOIN dbo.Menu parentMenu
                ON parentMenu.menuID = m.parentMenuID_FK
            INNER JOIN dbo.MenuDistributor md
                ON md.menuID_FK = m.menuID
               AND md.menuDistributorActive = 1
            INNER JOIN dbo.Distributor d
                ON d.distributorID = md.distributorID_FK
               AND d.distributorActive = 1
            WHERE m.menuActive = 1
              AND m.menuLink IS NOT NULL
              AND ISNULL(m.menuLink, '') <> 'MVC'
              AND (
                    (@isAdmin = 1 AND m.PageLvl IN (1, 2, 3))
                 OR (@isAdmin = 2 AND m.PageLvl IN (2, 3))
                 OR (@isAdmin = 3 AND m.PageLvl IN (3))
              )
            ORDER BY m.menuName_A;
          
        END



    -------------------------------------------------------------------
    --                     PAGE: Users
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Users'
        BEGIN
       EXEC [dbo].[UsersDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    

        END  
    -------------------------------------------------------------------
    --                     PAGE: Home
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Home'
        BEGIN
            -- User Permission
           EXEC [dbo].[ChartsDL] 
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @UsersID                        = @parameter_01


          
           
        END


    -------------------------------------------------------------------
    --                     PAGE: ImportExcelForBuildingPayment
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'ImportExcelForBuildingPayment'
        BEGIN

          EXEC [Housing].[ImportExcelForBuildingPaymentDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName


        --   SELECT  [BillChargeTypeID]
        --          ,[BillChargeTypeName_A]
      
        --FROM [DATACORE].[Housing].[BillChargeType] 
        --where BillChargeTypeActive = 1 and BillChargeTypeID <> 5
        --order by BillChargeTypeID asc


        -- DECLARE @StartYear INT = 2017;
        --DECLARE @EndYear   INT = YEAR(GETDATE());
        
        --;WITH YearsCTE AS
        --(
        --    SELECT @StartYear AS Year_
        --    UNION ALL
        --    SELECT Year_ + 1
        --    FROM YearsCTE
        --    WHERE Year_ + 1 <= @EndYear
        --)
        --SELECT Year_
        --FROM YearsCTE
        --ORDER BY Year_
        --OPTION (MAXRECURSION 100);



        --DECLARE @StartDate DATE = '2017-01-01';
        --DECLARE @EndDate   DATE = EOMONTH(GETDATE());
        
        --;WITH MonthsCTE AS
        --(
        --    SELECT @StartDate AS MonthStart
        --    UNION ALL
        --    SELECT DATEADD(MONTH, 1, MonthStart)
        --    FROM MonthsCTE
        --    WHERE DATEADD(MONTH, 1, MonthStart) <= @EndDate
        --)
        --SELECT
        --    YEAR(MonthStart)  AS Year_,
        --    MONTH(MonthStart) AS MonthNumber,
        --    CASE MONTH(MonthStart)
        --        WHEN 1  THEN N'يناير'
        --        WHEN 2  THEN N'فبراير'
        --        WHEN 3  THEN N'مارس'
        --        WHEN 4  THEN N'أبريل'
        --        WHEN 5  THEN N'مايو'
        --        WHEN 6  THEN N'يونيو'
        --        WHEN 7  THEN N'يوليو'
        --        WHEN 8  THEN N'أغسطس'
        --        WHEN 9  THEN N'سبتمبر'
        --        WHEN 10 THEN N'أكتوبر'
        --        WHEN 11 THEN N'نوفمبر'
        --        WHEN 12 THEN N'ديسمبر'
        --    END AS ArabicMonthName
        --FROM MonthsCTE
        --ORDER BY MonthStart
        --OPTION (MAXRECURSION 1000);
           
           
        END



  -------------------------------------------------------------------
    --                     PAGE: PagesManagment
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'PagesManagment'
        BEGIN

        -- prgrams

            select 
            p.[programID]
           ,p.[programName_A]
           ,p.[programName_E]
           ,p.[programDescription]
           ,case 
           when p.[programActive] = 1 then N'نشط'
           when p.[programActive] = 0 then N'غير نشط'
           END programActive
           ,case 
           when p.[programActive] = 1 then N'1'
           when p.[programActive] = 0 then N'0'
           END programActiveBit
           ,p.[programLink]
           ,p.[programIcon]
           ,p.[programSerial]
           
            From dbo.Program p

            ORDER BY P.programID DESC
            --where programActive = 1



            --SubPrograms
            
              
            select 
          
            m.[menuID]
           ,p.programID
           ,p.programName_A
           ,m.[menuName_A]
           ,m.[menuName_E]
           ,m.[menuDescription]
           ,m.[parentMenuID_FK]
           ,m.[menuLink]
           ,m.[programID_FK]
           ,m.[menuSerial]
           ,m.[menuActive]
           ,m.[isDashboard]
           ,m.[PageLvl]

            from dbo.Menu m
            inner join dbo.Program p on m.programID_FK = p. programID
            where (m.menuLink is null OR m.menuLink = 'MVC') and m.menuID not in
            (select md.menuID_FK from dbo.MenuDistributor md
            inner join dbo.Distributor d on md.distributorID_FK = d.distributorID and d.distributorType_FK = 4
            where d.distributorType_FK = 4 and d.distributorActive = 1)
            order by m.menuID desc




         --Menus
            
              
            select 
            md.menuDistributorID
           , 
           m.[menuID]
           ,m.[menuName_A]
           , d.distributorID
           ,d.distributorName_A
           ,m.[menuName_E]
           ,m.[menuDescription]
           ,m.[parentMenuID_FK]
           ,m.[menuLink]
           ,COALESCE(m.[programID_FK], parentMenu.[programID_FK]) AS programID_FK
           ,m.[menuSerial]
           ,m.[menuActive]
           ,m.[isDashboard]
           ,m.[PageLvl]

            from dbo.Menu m
            left join dbo.Menu parentMenu on parentMenu.menuID = m.parentMenuID_FK
            left join dbo.MenuDistributor md on m.menuID = md.menuID_FK
            left join dbo.Distributor d on d.distributorID = md.distributorID_FK and d.distributorType_FK = 4
            where m.menuLink is not null and m.menuLink <> 'MVC'
            --where m.[menuActive] = 1 
            order by m.menuID desc

            --Permission

           
            SELECT 
       t.[distributorPermissionTypeID]
      ,t.[permissionTypeID_FK]
      ,t.[DistributorID_FK]
      ,CONVERT(nvarchar(10),t.[distributorPermissionTypeStartDate],23) distributorPermissionTypeStartDate
      ,CONVERT(nvarchar(10),t.[distributorPermissionTypeEndDate],23) distributorPermissionTypeEndDate
      ,t.[distributorPermissionTypeActive]
      ,t.[permissionAuthLvl]
      ,d.distributorName_A
      ,d.distributorType_FK
      ,pt.permissionTypeName_A
      ,pt.permissionTypeName_E
      ,pa.permissionAuthLvlName_A
    
    
  FROM [DATACORE].[dbo].[DistributorPermissionType] t 
  inner join dbo.Distributor d on d.distributorID = t.distributorID_FK and d.distributorActive = 1 and d.distributorType_FK = 4
  inner join dbo.MenuDistributor md on md.distributorID_FK = t.distributorID_FK and md.menuDistributorActive = 1
  inner join dbo.Menu m on m.menuID = md.menuID_FK and m.menuActive = 1
  inner join dbo.PermissionType pt on pt.permissionTypeID = t.permissionTypeID_FK
  inner join dbo.permissionAuthLvl pa on pa.permissionAuthLvlID = t.permissionAuthLvl and pa.permissionAuthLvlActive = 1
  --where t.distributorPermissionTypeActive = 1
  order by t.distributorPermissionTypeID desc
           
        

        
           select 

            p.[programID]
           ,p.[programName_A]

            From dbo.Program p

            
            where programActive = 1
            ORDER BY P.programID asc



            select u.UsersAuthTypeID,u.UsersAuthTypeName_A
            from dbo.UsersAuthType u
            where u.UsersAuthTypeActive = 1

            -- Side Menus DDL
            SELECT
                  m.menuID
                , m.menuName_A
                , m.programID_FK
            FROM dbo.Menu m
            WHERE m.menuActive = 1
              AND m.programID_FK IS NOT NULL
              AND (m.menuLink IS NULL OR m.menuLink = 'MVC')
            ORDER BY m.menuName_A;

            -- Pages DDL
            SELECT DISTINCT
                  m.menuID
                , m.menuName_A
                , COALESCE(m.programID_FK, parentMenu.programID_FK) AS programID_FK
            FROM dbo.Menu m
            LEFT JOIN dbo.Menu parentMenu
                ON parentMenu.menuID = m.parentMenuID_FK
            INNER JOIN dbo.MenuDistributor md
                ON md.menuID_FK = m.menuID
               AND md.menuDistributorActive = 1
            INNER JOIN dbo.Distributor d
                ON d.distributorID = md.distributorID_FK
               AND d.distributorActive = 1
               AND d.distributorType_FK = 4
            WHERE m.menuActive = 1
              AND m.menuLink IS NOT NULL
              AND m.menuLink <> 'MVC'
            ORDER BY m.menuName_A;

            -- Permission Types DDL
            SELECT
                  p.permissionTypeID
                , p.permissionTypeName_A
            FROM dbo.PermissionType p
            WHERE p.permissionTypeActive = 1
            ORDER BY p.permissionTypeName_A;

            -- Permission Auth Levels DDL
            SELECT
                  pa.permissionAuthLvlID
                , pa.permissionAuthLvlName_A
            FROM dbo.permissionAuthLvl pa
            WHERE pa.permissionAuthLvlActive = 1
            ORDER BY pa.permissionAuthLvlID;


END









         -------------------------------------------------------------------
    --                     DO NOT TOUCH ABOVE THIS LINE
    -------------------------------------------------------------------

    --

    --
     -------------------------------------------------------------------
    --                     PAGE: ManagerList
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'ManagerList'
        BEGIN

                EXEC [dbo].[ManagerListDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
          
        END
    --


    --

    --
    --

    -------------------------------------------------------------------
    --                     PAGE: BuildingType
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingType'
        BEGIN


            
                EXEC [Housing].[BuildingTypeDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
          
        END

    -------------------------------------------------------------------
    --                     PAGE: BuildingClass
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingClass'
        BEGIN


            -- Building Class Data
			  EXEC [Housing].[BuildingClassDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
         
        END

    -------------------------------------------------------------------
    --                     PAGE: buildingUtilityType
    -------------------------------------------------------------------
              

ELSE IF @pageName_ = 'buildingUtilityType'
        BEGIN



            -- Utility Type EXEC
           EXEC [Housing].[buildingUtilityTypeDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
        END


    -------------------------------------------------------------------
    --                     PAGE: BuildingType
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'MilitaryLocation'
        BEGIN


            -- MilitaryLocation Data
             EXEC [Housing].[MilitaryLocationDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
        END

    -------------------------------------------------------------------
    --                     PAGE: BuildingDetails
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingDetails'
        BEGIN


             EXEC [Housing].[BuildingDetailsDL]
                                           
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @buildingUtilityTypeID_FK       = @parameter_01


        END

         -------------------------------------------------------------------
    --                     PAGE: BuildingSpaces
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingSpaces'
        BEGIN


             EXEC [Housing].[BuildingSpacesDL]
                                           
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @buildingUtilityTypeID_FK       = @parameter_01
                    , @BuildingDetailsID_FK       = @parameter_02


        END



         -------------------------------------------------------------------
    --                     PAGE: Residents
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Residents'
        BEGIN



            -- Residents Data
           EXEC [Housing].[ResidentsDL] 
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
            



           


        END


    -------------------------------------------------------------------
    --                     PAGE: WaitingListByResident
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingListByResident'
        BEGIN


            -- One Resident Data

          EXEC [Housing].[WaitingListByResidentDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @NationalID                      =@parameter_01


           


        END


         -------------------------------------------------------------------
    --                     PAGE: WaitingListMoveList
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingListMoveList'
        BEGIN


            -- One Resident Data

           EXEC [Housing].[WaitingListMoveListDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName



        END

    -------------------------------------------------------------------
    --                     PAGE: WaitingList
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingList'
        BEGIN

			
                      EXEC [Housing].[WaitingListDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @WaitingClassID_nvar            = @parameter_01

                    


        END


    -------------------------------------------------------------------
    --                     PAGE: OtherWaitingList
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'OtherWaitingList'
        BEGIN

			
                      EXEC [Housing].[OtherWaitingListDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @WaitingClassID_nvar            = @parameter_01

                    


        END



   
    -------------------------------------------------------------------
    --                     PAGE: Assign
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Assign'
        BEGIN



            -- Assign Data

   EXEC [Housing].[AssignDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @WaitingClassID                 = @parameter_01
                    , @AssignPeriodID                 = @parameter_01


          

        END



   


   -------------------------------------------------------------------
    --                     PAGE: AssignStatus
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'AssignStatus'
        BEGIN



       
	     -- Assign Data

   EXEC [Housing].[AssignStatusDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @AssignPeriodID                  = @parameter_01



        END


      

    -------------------------------------------------------------------
    --                     PAGE: HousingResident
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingResident'
        BEGIN



            -- HousingResident Data

           EXEC [Housing].[HousingResidentDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                   
   

        END


    -------------------------------------------------------------------
    --                     PAGE: HousingHistoricalResident
    -------------------------------------------------------------------

        ELSE IF @pageName_ = N'HousingHistoricalResident'
        BEGIN
            EXEC [Housing].[HousingHistoricalResidentDL]
                  @pageName_          = @pageName_
                , @idaraID            = @idaraID
                , @entrydata          = @entrydata
                , @hostname           = @hostname
                , @WaitingClassID_nvar = @parameter_01;
        END


    -------------------------------------------------------------------
    --                     PAGE: HousingResident
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'MeterReadForOccubentAndExit'
        BEGIN



            -- MeterReadForOccubentAndExit Data

           EXEC [Housing].[MeterReadForOccubentAndExitDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @residentInfoID                  = @parameter_01

        END




    -------------------------------------------------------------------
    --                     PAGE: HousingExtend
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingExtend'
        BEGIN



            -- HousingExtend Data
			 EXEC [Housing].[HousingExtendDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                   



   

        END


            -------------------------------------------------------------------
    --                     PAGE: HousingExtendFollowUp
    -------------------------------------------------------------------
    ELSE IF @pageName_ = 'HousingExtendFollowUp'
    BEGIN
        EXEC [Housing].[HousingExtendFollowUpDL]
              @pageName_ = @pageName_
            , @idaraID = @idaraID
            , @entrydata = @entrydata
            , @hostname = @hostname;
    END


    -------------------------------------------------------------------
    --                     PAGE: FinancialAuditForUser
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'FinancialAuditForUser'
        BEGIN



      EXEC [Housing].[FinancialAuditForUserDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @NationalID                     = @parameter_01


        END



    -------------------------------------------------------------------
    --                     PAGE: FinancialAuditForExtendAndEvictions
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'FinancialAuditForExtendAndEvictions'
        BEGIN



      EXEC [Housing].[FinancialAuditForExtendAndEvictionsDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @residentInfoID                 = @parameter_01
                    , @buildingDetailsID              = @parameter_02


        END

            -------------------------------------------------------------------
    --                     PAGE: HousingExit
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingExit'
        BEGIN



            -- HousingExit Data

           EXEC [Housing].[HousingExitDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @NationalID                     = @parameter_01
     




   

        END





    -------------------------------------------------------------------
    --                     PAGE: Meters
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Meters'
        BEGIN

         EXEC [Housing].[MetersDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                   

     


        END




   -------------------------------------------------------------------
    --                     PAGE: AllMeterRead
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'AllMeterRead'
        BEGIN

         EXEC [Housing].[AllMeterReadDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @meterServiceTypeID_FK          = @parameter_01
                   

     


        END



          -------------------------------------------------------------------
    --                     PAGE: HousingHandover
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingHandover'
        BEGIN

         EXEC [Housing].[HousingHandoverDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @LastActionTypeID                 = @parameter_01
                   

     


        END





        
    -------------------------------------------------------------------
    --                     PAGE: RentExemption
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'RentExemption'
        BEGIN


            -- One Resident Data

          EXEC [Housing].[RentExemptionDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    , @NationalID                      =@parameter_01


           


        END


         -------------------------------------------------------------------
    --                     PAGE: RentExemption
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'OtherWaitingListManagment'
        BEGIN


            -- One Resident Data

          EXEC [Housing].[OtherWaitingListManagmentDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    

           


        END

    -------------------------------------------------------------------
    --                     PAGE: MeterServiceTypeFixedAmount
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'MeterServiceTypeFixedAmount'
        BEGIN


            -- One Resident Data

          EXEC [Housing].[MeterServiceTypeFixedAmountDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    


           


        END


         -------------------------------------------------------------------
    --                     PAGE: ExtendInsurance
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'ExtendInsurance'
        BEGIN


            -- One Resident Data

          EXEC [Housing].[ExtendInsuranceDL]
                      @pageName_                      = @pageName_
                    , @idaraID                        = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName
                    


           


        END




   

         -------------------------------------------------------------------
    --                     PAGE: MonthlyBillingMonitor
    -------------------------------------------------------------------

         ELSE IF @pageName_ = N'MonthlyBillingMonitor'
        BEGIN
            DECLARE @MonitorYear INT = TRY_CONVERT(INT, @parameter_01);
            DECLARE @MonitorMonth INT = TRY_CONVERT(INT, @parameter_02);
            DECLARE @MonitorIdaraID BIGINT = CASE
                WHEN @isAdmin = 1 THEN TRY_CONVERT(BIGINT, @parameter_03)
                ELSE @idaraID
            END;


            EXEC Housing.MonthlyBillingMonitorDL
                  @Year = @MonitorYear
                , @Month = @MonitorMonth
                , @IdaraID = @MonitorIdaraID;
        END



         -------------------------------------------------------------------
    --                     PAGE: DeductListReport
    -------------------------------------------------------------------

        ELSE IF @pageName_ = N'DeductListReport'
        BEGIN
           
            DECLARE @DeductReportID BIGINT=TRY_CONVERT(BIGINT,@parameter_03);

            EXEC Housing.DeductListReportDL
                  @pageName_                      = @pageName_
                , @idaraID                        = @idaraID
                , @entryData                      = @entrydata
                , @hostName                       = @hostName
                , @Year                           = @parameter_01
                , @Month                          = @parameter_02
                , @ReportID                       = @DeductReportID;
        END



          -------------------------------------------------------------------
    --                     نظام الدعم الفني للموقع
    -------------------------------------------------------------------

      -------------------------------------------------------------------
    --                     PAGE: SupportMyTickets
    -------------------------------------------------------------------


          ELSE IF @pageName_ = 'SupportMyTickets'
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N'SMT_ACCESS', N'SMT_SELECT')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'عفوا لاتملك صلاحية عرض هذه الصفحة' AS Message_;
            END
            ELSE
            BEGIN
                EXEC [support].[SupportMyTicketsDL]
                      @pageName_ = @pageName_
                    , @idaraID   = @idaraID
                    , @entryData = @entrydata
                    , @hostName  = @hostName;
            END
        END

         -------------------------------------------------------------------
    --                     PAGE: SupportPhoneTickets
    -------------------------------------------------------------------

ELSE IF @pageName_ = 'SupportPhoneTickets'
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N'SPT_ACCESS', N'SPT_SELECT')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'عفوا لاتملك صلاحية عرض هذه الصفحة' AS Message_;
            END
            ELSE
            BEGIN
                EXEC [support].[SupportPhoneTicketsDL]
                      @pageName_ = @pageName_
                    , @idaraID   = @idaraID
                    , @entryData = @entrydata
                    , @hostName  = @hostName
                    , @permissionUserID = @parameter_01;
            END
        END

ELSE IF @pageName_ = 'SupportTicketDetails'
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N'STD_ACCESS', N'STD_SELECT')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'عفوا لاتملك صلاحية عرض هذه الصفحة' AS Message_;
            END
            ELSE
            BEGIN
                EXEC [support].[SupportTicketDetailsDL]
                      @pageName_ = @pageName_
                    , @idaraID   = @idaraID
                    , @entryData = @entrydata
                    , @hostName  = @hostName
                    , @ticketID  = @parameter_01;
            END
        END

         -------------------------------------------------------------------
    --                     PAGE: SupportInbox
    -------------------------------------------------------------------

ELSE IF @pageName_ = 'SupportInbox'
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N'SIN_ACCESS', N'SIN_SELECT')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'عفوا لاتملك صلاحية عرض هذه الصفحة' AS Message_;
            END
            ELSE
            BEGIN
                EXEC [support].[SupportInboxDL]
                      @pageName_    = @pageName_
                    , @idaraID      = @idaraID
                    , @entryData    = @entrydata
                    , @hostName     = @hostName
                    , @statusID     = @parameter_01
                    , @priorityID   = @parameter_02
                    , @ticketTypeID = @parameter_03
                    , @assignedToID = @parameter_04
                    , @dateFrom     = @parameter_05
                    , @dateTo       = @parameter_06
                    , @searchText   = @parameter_07;
            END
        END

         -------------------------------------------------------------------
    --                     PAGE: SupportTeamManagement
    -------------------------------------------------------------------

ELSE IF @pageName_ = 'SupportTeamManagement'
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E IN (N'STM_ACCESS', N'STM_SELECT')
            )
            BEGIN
                SELECT 0 AS IsSuccessful, N'عفوا لاتملك صلاحية عرض هذه الصفحة' AS Message_;
            END
            ELSE
            BEGIN
                DECLARE @supportOnlyActive BIT = CASE WHEN @parameter_01 = '0' THEN 0 ELSE 1 END;

                EXEC [support].[SupportTeamManagementDL]
                      @pageName_  = @pageName_
                    , @idaraID    = @idaraID
                    , @entryData  = @entrydata
                    , @hostName   = @hostName
                    , @onlyActive = @supportOnlyActive;
            END
        END


                ---------------------------------------------------------------------
                --الطلبات
                ---------------------------------------------------------------------
                
                    -- ============================================================
                    --                       TICKETS MODULE
                    -- ============================================================
                
                     -------------------------------------------------------------------
                --                     PAGE: TicketAdmin
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'TicketAdmin'
                    BEGIN
                        
                        -- Handover Print Get Data
                        EXEC [Tickets].[TicketAdminDL]
                       @pageName_  = @pageName_
                        , @idaraID   = @idaraID
                        , @entryData  = @entrydata
                        , @hostName   = @hostname
                        , @filterServiceID  = @parameter_01
                        , @filterTicketClassID = @parameter_02
                    END
                     -------------------------------------------------------------------
                --                     PAGE: TicketList
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'TicketList'
                    BEGIN
                
                        EXEC [Tickets].[TicketListDL]
                              @pageName_        = @pageName_
                            , @idaraID          = @idaraID
                            , @entryData        = @entrydata
                            , @hostName         = @hostname
                            , @filterStatusID   = @parameter_03
                            , @filterServiceID  = @parameter_04
                            , @filterDSDID      = @parameter_06
                    END
                     -------------------------------------------------------------------
                --                     PAGE: TicketDrawer
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'TicketDrawer'
                    BEGIN
                
                        EXEC [Tickets].[TicketDrawerDL]
                              @pageName_   = @pageName_
                            , @idaraID     = @idaraID
                            , @entryData   = @entrydata
                            , @hostName    = @hostname
                            , @ticketID    = @parameter_01
                    END





                    ------------------------------------------------------------------
--                     PAGE: VehicleS
-------------------------------------------------------------------

                
                
                
                
                -------------------------------------------------------------------
                --                     PAGE: TypesRoot_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'TypesRoot_List'
                    BEGIN
                        EXEC [VIC].[TypesRoot_List_DL]
                              @parentID   = @parameter_01
                            , @activeOnly = @parameter_02
                            , @search     = @parameter_03;
                    END
                
                  -------------------------------------------------------------------
                --                     PAGE: Vehiclelist
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Vehiclelist'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType    = N'LIST'
                        , @idaraID_FK    = @idaraID
                        , @ownerID_FK    = @parameter_01
                        , @plateLetters  = @parameter_02
                        , @plateNumbers  = @parameter_03
                        , @hasCustody    = @parameter_04
                        , @pageNumber    = @parameter_05
                        , @pageSize      = @parameter_06;
                END
                -------------------------------------------------------------------
                --                     PAGE: Vehicle_Get
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Vehicle_Get'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType    = N'GET'
                        , @vehicleID     = @parameter_01
                        , @chassisNumber = @parameter_02;
                END
                -------------------------------------------------------------------
                --                     PAGE: Vehicle_Search
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Vehicle_AvailableForPeriodic'
                BEGIN
                    EXEC [VIC].[VehicleDL] 
                    @ActionType = N'AVAILABLE_FOR_PERIODIC', 
                    @idaraID_FK = @idaraID;
                END
                
                ELSE IF @pageName_ = 'Vehicle_Search'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType = N'SEARCH'
                        , @q          = @parameter_01
                        , @pageSize   = @parameter_02;
                END
                -------------------------------------------------------------------
                --                     PAGE: Vehicle_GetLookups
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Vehicle_GetLookups'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType = N'AVAILABLE_FOR_CUSTODY'
                        , @idaraID_FK = @idaraID;
                END
                
                -------------------------------------------------------------------
                --                     PAGE: Vehicle_Profile_Get
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Vehicle_Profile_Get'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType      = N'GET_PROFILE'
                        , @idaraID_FK      = @idaraID
                        , @chassisNumber   = @parameter_04
                        , @TopDocuments    = @parameter_05
                        , @TopInsurance    = @parameter_06
                        , @TopMaintenance  = @parameter_07
                        , @TopViolations   = @parameter_08;
                END
                -------------------------------------------------------------------
                --                     PAGE: VehicleDocument_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'VehicleDocument_List'
                    BEGIN
                        EXEC [VIC].[VehicleDL]
                              @ActionType = N'LIST_DOCUMENTS'
                            , @ActiveOnly = @parameter_01;
                    END
                
                    -------------------------------------------------------------------
                --                     PAGE: VehicleDocuments_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'VehicleDocuments_List'
                    BEGIN
                        EXEC [VIC].[VehicleDL]
                              @ActionType    = N'LIST_DOCUMENTS'
                            , @idaraID_FK    = @idaraID
                            , @chassisNumber = @parameter_01
                            , @pageNumber    = @parameter_02
                            , @pageSize      = @parameter_03;
                    END
                
                
                -------------------------------------------------------------------
                --                     PAGE: VehicleDocumentType_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'VehicleDocumentType_List'
                    BEGIN
                        EXEC [VIC].[VehicleDL]
                              @ActionType = N'LIST_DOCUMENT_TYPES'
                            , @ActiveOnly = @parameter_01;
                    END
                
                -------------------------------------------------------------------
                --                     PAGE: Admin_VehicleDocumentType
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'Admin_VehicleDocumentType'
                    BEGIN
                        EXEC [VIC].[VehicleDL]
                              @ActionType = N'LIST_DOCUMENT_TYPES'
                            , @ActiveOnly = 0;
                    END
                
                -------------------------------------------------------------------
                --                     PAGE: VehicleInsurance_List
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'VehicleInsurance_List'
                BEGIN
                    EXEC [VIC].[VehicleDL]
                          @ActionType      = N'LIST_INSURANCE'
                        , @idaraID_FK      = @idaraID
                        , @chassisNumber   = @parameter_01
                        , @active          = @parameter_02
                        , @InsuranceDays   = @parameter_03
                        , @IncludeExpired  = @parameter_04
                        , @pageNumber      = @parameter_07
                        , @pageSize        = @parameter_08;
                END
                
                
                -------------------------------------------------------------------
                -- VehicleUser_Get
                -------------------------------------------------------------------
                else IF @pageName_ = 'VehicleUser_Get'
                BEGIN
                    EXEC [VIC].[VehicleUserDL]
                          @ActionType    = 'GET'
                        , @vehicleUserID = @parameter_01
                        , @IdaraID_FK    = @idaraID;
                END
                
                -------------------------------------------------------------------
                -- VehicleUser_List
                -------------------------------------------------------------------
                else IF @pageName_ = 'VehicleUser_List'
                BEGIN
                    EXEC [VIC].[VehicleUserDL]
                          @ActionType    = 'LIST'
                        , @generalNo     = @parameter_01
                        , @nationalID    = @parameter_02
                        , @IdaraID_FK    = @idaraID
                        , @userActive    = @parameter_03
                        , @pageNumber    = @parameter_04
                        , @pageSize      = @parameter_05;
                END
                
                -------------------------------------------------------------------
                -- VehicleUser_Search (AJAX endpoint + select2)
                -------------------------------------------------------------------
                else IF @pageName_ = 'VehicleUser_Search'
                BEGIN
                    EXEC [VIC].[VehicleUserDL]
                          @ActionType    = 'SEARCH'
                        , @q             = @parameter_01
                        , @generalNo     = @parameter_02
                        , @IdaraID_FK    = @idaraID
                        , @top           = @parameter_03;
                END
                
                -------------------------------------------------------------------
                -- VehicleUser_DDL (DDL_RANK / DDL_GENDER / DDL_NATIONALITY)
                -------------------------------------------------------------------
                else IF @pageName_ = 'VehicleUser_DDL'
                BEGIN
                    EXEC [VIC].[VehicleUserDL]
                          @ActionType    = @parameter_01
                        , @IdaraID_FK    = @idaraID;
                END
                
                -------------------------------------------------------------------
                -- Custody (main page DataLoad — permissions + CURRENT_LIST)
                -------------------------------------------------------------------
                else IF @pageName_ = 'Custody'
                BEGIN
                    EXEC [VIC].[CustodyDL]
                          @ActionType    = 'CURRENT_LIST'
                        , @vehicleUserID = @parameter_01
                        , @generalNo     = @parameter_02
                        , @chassisNumber = @parameter_03
                        , @pageNumber    = @parameter_04
                        , @pageSize      = @parameter_05
                        , @idaraID_FK    = @idaraID;
                END
                
                -------------------------------------------------------------------
                -- Custody_HistoryList (combined vehicle + date + user filters)
                -------------------------------------------------------------------
                else IF @pageName_ = 'Custody_HistoryList'
                BEGIN
                    EXEC [VIC].[CustodyDL]
                          @ActionType    = 'HISTORY_LIST'
                        , @chassisNumber = @parameter_01
                        , @fromDate      = @parameter_02
                        , @toDate        = @parameter_03
                        , @generalNo     = @parameter_04
                        , @searchUser    = @parameter_05
                        , @pageNumber    = @parameter_06
                        , @pageSize      = @parameter_07
                        , @idaraID_FK    = @idaraID;
                END
                
                -------------------------------------------------------------------
                -- Custody_SearchUsers (select2 user search within custody forms)
                -------------------------------------------------------------------
                else IF @pageName_ = 'Custody_SearchUsers'
                BEGIN
                    EXEC [VIC].[CustodyDL]
                          @ActionType    = 'SEARCH_USERS'
                        , @chassisNumber = @parameter_01
                        , @generalNo     = @parameter_02
                        , @idaraID_FK    = @idaraID;
                        --, @top           = @parameter_03;
                END
                
                
                
                
                
                -------------------------------------------------------------------
                --                     PAGE: Handover_Get
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'Handover_Get'
                    BEGIN
                        EXEC [VIC].[CustodyDL]
                              @ActionType      = N'GET_HANDOVER'
                            , @vehicleHandoverID = @parameter_01;
                    END
                
                -------------------------------------------------------------------
                --                     PAGE: Handover_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'Handover_List'
                    BEGIN
                        EXEC [VIC].[CustodyDL]
                              @ActionType    = N'LIST_HANDOVER'
                            , @requestID     = @parameter_01
                            , @handoverTypeID = @parameter_02
                            , @pageNumber    = @parameter_03
                            , @pageSize      = @parameter_04
                            , @idaraID_FK    = @parameter_05;
                    END
                
                -------------------------------------------------------------------
                --                     PAGE: Handover_Print_Get
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'Handover_Print_Get'
                    BEGIN
                        EXEC [VIC].[CustodyDL]
                              @ActionType      = N'PRINT_HANDOVER'
                            , @vehicleHandoverID = @parameter_01;
                    END
                
                -------------------------------------------------------------------
                --                     PAGE: HandoverType_List
                -------------------------------------------------------------------
                    ELSE IF @pageName_ = 'HandoverType_List'
                    BEGIN
                        EXEC [VIC].[CustodyDL]
                              @ActionType = N'LIST_HANDOVER_TYPE'
                            , @activeOnly = @parameter_01;
                    END
                
                
                
                   ----------------------------------------------------------------
                -- Scrap
                ----------------------------------------------------------------
                ELSE IF @pageName_ = 'Scrap'
                BEGIN
                    EXEC [VIC].[ScrapDL]
                          @ActionType    = @parameter_01
                        , @scrapID       = @parameter_02
                        , @vehicleID     = @parameter_03
                        , @chassisNumber = @parameter_04
                        , @Status        = @parameter_05
                        , @DateFrom      = @parameter_06
                        , @DateTo        = @parameter_07
                        , @pageNumber    = @parameter_08
                        , @pageSize      = @parameter_09
                        , @idaraID_FK    = @idaraID;
                END
                -------------------------------------------------------------------
                --                 PAGE: Violation_GetLookups
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Violation_GetLookups'
                BEGIN
                
                    EXEC [VIC].[ViolationDL]
                          @ActionType   = @parameter_01
                        , @idaraID_FK   = @idaraID
                        , @ActiveOnly   = 1;
                
                END
                
                -------------------------------------------------------------------
                --                     PAGE: Violation
                -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Violation'
                BEGIN
                
                    EXEC [VIC].[ViolationDL]
                          @ActionType      = @parameter_01
                        , @violationID     = @parameter_02
                        , @chassisNumber   = @parameter_03
                        , @violationTypeID = @parameter_04
                        , @Paid            = @parameter_05
                        , @FromDate        = @parameter_06
                        , @ToDate          = @parameter_07
                        , @Page            = @parameter_08
                        , @PageSize        = @parameter_09
                        , @idaraID_FK      = @idaraID;
                
                END


                -------------------------------------------------------------------
            --                     PAGE: Dashboard
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Dashboard'
                BEGIN
                    EXEC [VIC].[DashboardDL]
                          @ActionType          = N'VEHICLE_STATUS'
                        , @idaraID_FK          = @idaraID
                        , @onlyHasCustody      = @parameter_01
                        , @onlyHasActiveInsurance = @parameter_02
                        , @onlyHasDocExpiry    = @parameter_03
                        , @onlyHasInsExpiry    = @parameter_04
                        , @daysAhead           = @parameter_05;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Dashboard_MaintenanceDue
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Dashboard_MaintenanceDue'
                BEGIN
                    EXEC [VIC].[DashboardDL]
                          @ActionType = N'MAINTENANCE_DUE'
                        , @idaraID_FK = @idaraID
                        , @daysAhead  = @parameter_01;
                END
            
                -------------------------------------------------------------------
            --                     PAGE: Report_DocumentsExpiring
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_DocumentsExpiring'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType = N'DOCUMENTS_EXPIRING'
                        , @idaraID_FK = @idaraID
                        , @days       = @parameter_01;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Report_InsuranceExpiring
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_InsuranceExpiring'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType    = N'INSURANCE_EXPIRING'
                        , @idaraID_FK    = @idaraID
                        , @days          = @parameter_01
                        , @includeExpired = @parameter_02;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Report_MaintenanceCostByVehicle
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_MaintenanceCostByVehicle'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType = N'MAINTENANCE_COST'
                        , @idaraID_FK = @idaraID
                        , @fromDate   = @parameter_01
                        , @toDate     = @parameter_02;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Report_UnpaidViolations
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_UnpaidViolations'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType = N'UNPAID_VIOLATIONS'
                        , @idaraID_FK = @idaraID
                        , @fromDate   = @parameter_01
                        , @toDate     = @parameter_02;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Report_VehiclesWithoutCustody
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_VehiclesWithoutCustody'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType       = N'VEHICLES_WITHOUT_CUSTODY'
                        , @idaraID_FK       = @idaraID
                        , @onlyActiveVehicles = @parameter_01;
                END
            
            -------------------------------------------------------------------
            --                     PAGE: Report_VehicleTimeline
            -------------------------------------------------------------------
                ELSE IF @pageName_ = 'Report_VehicleTimeline'
                BEGIN
                    EXEC [VIC].[ReportDL]
                          @ActionType   = N'VEHICLE_TIMELINE'
                        , @vehicleID    = @parameter_01
                        , @chassisNumber = @parameter_02;
                END
            
            ----------------------------------------------------------------
            -- Masters_DataLoad — Block 1: PeriodicMaintenance
            -- Paste into Masters_DataLoad
            ----------------------------------------------------------------
                ELSE IF @pageName_ = 'PeriodicMaintenance'
                BEGIN
                    IF @parameter_01 = 'LIST_MONITORING'
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType = @parameter_01
                            , @idaraID_FK = @idaraID
                            , @groupID    = @parameter_02;
                    END
                    ELSE IF @parameter_01 = 'LIST_HISTORY'
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType = @parameter_01
                            , @idaraID_FK = @idaraID
                            , @pageNumber = @parameter_02
                            , @pageSize   = @parameter_03;
                    END
                    ELSE IF @parameter_01 = 'LIST_GROUPS'
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType = @parameter_01;
                    END
                    ELSE IF @parameter_01 = 'LIST_DETAILS'
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType  = @parameter_01
                            , @idaraID_FK  = @idaraID
                            , @maintOrdID  = @parameter_02;
                    END
                    ELSE
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType        = @parameter_01
                            , @vehicleID         = @parameter_02
                            , @idaraID_FK        = @idaraID
                            , @maintOrdID        = @parameter_03
                            , @maintOrdTypeID_FK = @parameter_04
                            , @chassisNumber     = @parameter_05
                            , @active            = @parameter_06
                            , @fromDate          = @parameter_07
                            , @toDate            = @parameter_08
                            , @pageNumber        = @parameter_09
                            , @pageSize          = @parameter_10
                            , @maintDetailesID   = @parameter_11;
                    END
                END
            
            ----------------------------------------------------------------
            -- Masters_DataLoad — Block 2: GeneralMaintenance
            -- Paste into Masters_DataLoad
            ----------------------------------------------------------------
                ELSE IF @pageName_ = 'GeneralMaintenance'
                BEGIN
                    IF @parameter_01 = 'LIST_FAULTS'
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType  = @parameter_01
                            , @idaraID_FK  = @idaraID
                            , @maintOrdID  = @parameter_02;
                    END
            
            
            
                    ELSE
                    BEGIN
                        EXEC [VIC].[MaintenanceDL]
                              @ActionType        = @parameter_01
                            , @vehicleID         = @parameter_02
                            , @idaraID_FK        = @idaraID
                            , @maintOrdID        = @parameter_03
                            , @maintOrdTypeID_FK = @parameter_04
                            , @chassisNumber     = @parameter_05
                            , @active            = @parameter_06
                            , @fromDate          = @parameter_07
                            , @toDate            = @parameter_08
                            , @pageNumber        = @parameter_09
                            , @pageSize          = @parameter_10
                            , @maintDetailesID   = @parameter_11;
                    END
                END
                -------------------------------------------------------------------
            --                     PAGE: MaintenanceReport
            -------------------------------------------------------------------
                ELSE IF @pageName_ = N'MaintenanceReport'
                BEGIN
                    EXEC [VIC].[MaintenanceDL]
                          @ActionType        = @parameter_01
                        , @vehicleID         = @parameter_02
                        , @idaraID_FK        = @idaraID
                        , @maintOrdID        = @parameter_03
                        , @maintOrdTypeID_FK = @parameter_04
                        , @chassisNumber     = @parameter_05
                        , @active            = @parameter_06
                        , @fromDate          = @parameter_07
                        , @toDate            = @parameter_08
                        , @pageNumber        = @parameter_09
                        , @pageSize          = @parameter_10
                        , @maintDetailesID   = @parameter_11;
                END
            
            
            
            ----------------------------------------------------------------
            -- Masters_DataLoad — Block 3: PeriodicMaintenancePlan
            -- Paste into Masters_DataLoad
            ----------------------------------------------------------------
                ELSE IF @pageName_ = 'PeriodicMaintenancePlan'
                BEGIN
                    EXEC [VIC].[MaintenancePlanDL]
                          @ActionType        = @parameter_01
                        , @vehicleID         = @parameter_02
                        , @idaraID_FK        = @idaraID
                        , @planID            = @parameter_03
                        , @chassisNumber     = @parameter_04
                        , @active            = @parameter_05
                        , @pageNumber        = @parameter_06
                        , @pageSize          = @parameter_07
                        , @maintOrdTypeID_FK = @parameter_08;
                END
            
            
            
            

                
    -------------------------------------------------------------------
    --                     PLEASE PLEASE PLEASE
    --              DO NOT TOUCH DOWN THIS LINE PLEASE
    -------------------------------------------------------------------

-------------------------------------------------------------------
--             PAGE: الشاشه التفاعليه
-------------------------------------------------------------------
-------------------------------------------------------------------
--             PAGE: HousingCommandCenterDashboard
-------------------------------------------------------------------
ELSE IF @pageName_ = 'HousingCommandCenterDashboard'
BEGIN

    DECLARE @CommandCenterTargetIdaraID BIGINT =
        TRY_CONVERT
        (
            BIGINT,
            NULLIF
            (
                LTRIM(RTRIM(@parameter_01)),
                N''
            )
        );

    DECLARE @CommandCenterSection NVARCHAR(20) =
        NULLIF
        (
            LOWER(LTRIM(RTRIM(@parameter_02))),
            N''
        );

    DECLARE @CommandCenterStatus NVARCHAR(30) =
        NULLIF
        (
            UPPER(LTRIM(RTRIM(@parameter_03))),
            N''
        );

    DECLARE @CommandCenterSearchText NVARCHAR(4000) =
        NULLIF
        (
            LTRIM(RTRIM(@parameter_04)),
            N''
        );

    DECLARE @CommandCenterBillChargeTypeID INT =
        TRY_CONVERT
        (
            INT,
            NULLIF
            (
                LTRIM(RTRIM(@parameter_05)),
                N''
            )
        );

    DECLARE @CommandCenterSortKey NVARCHAR(30) =
        NULLIF
        (
            UPPER(LTRIM(RTRIM(@parameter_06))),
            N''
        );

    DECLARE @CommandCenterPageNumber INT =
        TRY_CONVERT
        (
            INT,
            NULLIF
            (
                LTRIM(RTRIM(@parameter_07)),
                N''
            )
        );

    DECLARE @CommandCenterPageSize INT =
        TRY_CONVERT
        (
            INT,
            NULLIF
            (
                LTRIM(RTRIM(@parameter_08)),
                N''
            )
        );

    DECLARE @CommandCenterResidentInfoID BIGINT =
        TRY_CONVERT
        (
            BIGINT,
            NULLIF
            (
                LTRIM(RTRIM(@parameter_09)),
                N''
            )
        );

    ---------------------------------------------------------------
    -- HEADER PERMISSION CHECK
    -- Skip dashboard data loading when checking header permission.
    -- The permission result is already returned by Masters_DataLoad.
    ---------------------------------------------------------------

            IF ISNULL(@parameter_20, N'') = N'DASHBOARD_SCOPE_ONLY'
        BEGIN
            SELECT
                  i.idaraID
                , v.IdaraID AS TrustedIdaraID
                , CAST(
                    CASE WHEN v.ShowFullDashboard = 1
                         THEN 1 ELSE 0 END
                    AS BIT
                  ) AS ShowFullDashboard
            FROM dbo.V_GetFullSystemUsersDetails v
            INNER JOIN dbo.Idara i
                ON i.idaraShowInCommandCenter = 1
               AND (
                    v.ShowFullDashboard = 1
                    OR i.idaraID = v.IdaraID
               )
            WHERE v.usersID = @entrydata
              AND v.userActive = 1
              AND v.IdaraID = @idaraID
            ORDER BY i.idaraID;
        END
        ELSE IF ISNULL(@parameter_20, N'')
            <> N'HEADER_PERMISSION_ONLY'
        BEGIN

        EXEC [Housing].[HousingCommandCenterDashboardDL]
              @pageName_        = @pageName_
            , @idaraID          = @idaraID
            , @entryData        = @entrydata
            , @hostName         = @hostName

            , @targetIdaraID    = @CommandCenterTargetIdaraID
            , @section          = @CommandCenterSection
            , @status           = @CommandCenterStatus

            , @searchText       = @CommandCenterSearchText
            , @billChargeTypeID = @CommandCenterBillChargeTypeID
            , @sortKey          = @CommandCenterSortKey
            , @pageNumber       = @CommandCenterPageNumber
            , @pageSize         = @CommandCenterPageSize
            , @residentInfoID   = @CommandCenterResidentInfoID;

    END;

END


    -------------------------------------------------------------------
    --                     PAGE NOT FOUND
    --            DO NOT TOUCH DOWN THIS LINE PLEASE
    -------------------------------------------------------------------
       
        ELSE
        BEGIN
            SELECT 0 AS IsSuccessful, N'الصفحة المرسلة مقيدة. PageName' AS Message_;
        END

        COMMIT TRANSACTION;
    END TRY

    -------------------------------------------------------------------
    --                     CATCH BLOCK
    -------------------------------------------------------------------
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000), @ErrSeverity INT, @ErrState INT, @IdentityCatchError INT;

        SELECT 
              @ErrMsg      = ERROR_MESSAGE(),
              @ErrSeverity = ERROR_SEVERITY(),
              @ErrState    = ERROR_STATE();

        INSERT INTO  dbo.ErrorLog
        (
              ERROR_MESSAGE_
            , ERROR_SEVERITY_
            , ERROR_STATE_
            , SP_NAME
            , entryData
            , hostName
        )
        VALUES
        (
              @ErrMsg
            , @ErrSeverity
            , @ErrState
            , N'[dbo].[Masters_DataLoad]'
            , @entrydata
            , @hostname
        );

        SET @IdentityCatchError = SCOPE_IDENTITY();

        SELECT 
              0 AS IsSuccessful,
              N'حصل خطأ غير معروف رمز الخطأ : ' + CAST(@IdentityCatchError AS NVARCHAR(200)) AS Message_;
    END CATCH
END

GO

