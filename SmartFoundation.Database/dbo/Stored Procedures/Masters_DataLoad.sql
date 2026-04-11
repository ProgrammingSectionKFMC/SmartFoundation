CREATE PROCEDURE [dbo].[Masters_DataLoad]
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
          
        END



    -------------------------------------------------------------------
    --                     PAGE: Users
    -------------------------------------------------------------------
        ELSE IF @pageName_ = 'Users'
        BEGIN
        if(@isAdmin = 1)
        Begin
            -- Users
           select d.usersID,
           d.nationalID,
           d.GeneralNo,
           d.FullName,
           ud.firstName_A,
           ud.secondName_A,
           ud.thirdName_A,
           ud.lastName_A,
           ud.firstName_E,
           ud.secondName_E,
           ud.thirdName_E,
           ud.lastName_E,
           d.UsersAuthTypeID,
           d.UsersAuthTypeName_A,
           case 
           when d.userActive = 1 then N'نشط'
           when d.userActive = 0 then N'معطل'
           End ActiveStatus,
           d.userTypeName_A,
           d.userTypeID_FK,

           d.userActive,
           d.IdaraID,
           d.idaraLongName_A,
           r1.distributorName_A,
           d.EntryFullName,
           convert(nvarchar(10),d.entryDate,23)+' '+convert(nvarchar(10),d.entryDate,8) entryDate,
           ud.nationalIDIssueDate,
               ud.dateOfBirth,
               ud.genderID_FK,
               ud.nationalityID_FK,
               ud.religionID_FK,
               ud.maritalStatusID_FK,
               ud.educationID_FK,
              
               r1.distributorID

           from [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
           inner join dbo.UsersDetails ud on d.usersID = ud.usersID_FK and ud.userActive = 1 and d.userActive = 1
           left join dbo.UserDistributor ui on ud.usersID_FK = ui.userID_FK and ui.UDActive = 1
           left join dbo.Distributor r on ui.distributorID_FK = r.distributorID
           left join dbo.V_GetFullStructureForDSD dd on dd.DSDID = r.DSDID_FK and r.distributorType_FK = 1
           left join dbo.DeptSecDiv ds on dd.DepartmentID = ds.deptID_FK and ds.secID_FK is null and ds.divID_FK is null
           left join dbo.Distributor r1 on ds.DSDID = r1.DSDID_FK and r1.distributorType_FK = 1
           -- and dd.DSDLevel = 3
          -- where dd.DepartmentID is not null --and dd.IdaraID = @idaraID


          order by d.usersID desc


          END 

         ELSE if(@isAdmin = 2)
        Begin
            -- Users
           select d.usersID,
           d.nationalID,
           d.GeneralNo,
           d.FullName,
           ud.firstName_A,
           ud.secondName_A,
           ud.thirdName_A,
           ud.lastName_A,
           ud.firstName_E,
           ud.secondName_E,
           ud.thirdName_E,
           ud.lastName_E,
           d.UsersAuthTypeID,
           d.UsersAuthTypeName_A,
           case 
           when d.userActive = 1 then N'نشط'
           when d.userActive = 0 then N'معطل'
           End ActiveStatus,
           d.userTypeName_A,
           d.userTypeID_FK,

           d.userActive,
           d.IdaraID,
           d.idaraLongName_A,
           r1.distributorName_A,
           d.EntryFullName,
           convert(nvarchar(10),d.entryDate,23)+' '+convert(nvarchar(10),d.entryDate,8) entryDate,
           ud.nationalIDIssueDate,
               ud.dateOfBirth,
               ud.genderID_FK,
               ud.nationalityID_FK,
               ud.religionID_FK,
               ud.maritalStatusID_FK,
               ud.educationID_FK,
          
               r1.distributorID

           from [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
           inner join dbo.UsersDetails ud on d.usersID = ud.usersID_FK and ud.userActive = 1 and d.userActive = 1
           left join dbo.UserDistributor ui on ud.usersID_FK = ui.userID_FK and ui.UDActive = 1
           left join dbo.Distributor r on ui.distributorID_FK = r.distributorID
           left join dbo.V_GetFullStructureForDSD dd on dd.DSDID = r.DSDID_FK and r.distributorType_FK = 1
           left join dbo.DeptSecDiv ds on dd.DepartmentID = ds.deptID_FK and ds.secID_FK is null and ds.divID_FK is null
           left join dbo.Distributor r1 on ds.DSDID = r1.DSDID_FK and r1.distributorType_FK = 1
           where d.IdaraID = @idaraID
           order by d.usersID desc
          END 

          if(@isAdmin = 3)
            Begin
                -- Users
               select d.usersID,
               d.nationalID,
               d.GeneralNo,
               d.FullName,
               ud.firstName_A,
               ud.secondName_A,
               ud.thirdName_A,
               ud.lastName_A,
               ud.firstName_E,
               ud.secondName_E,
               ud.thirdName_E,
               ud.lastName_E,
               d.UsersAuthTypeID,
               d.UsersAuthTypeName_A , 
               case 
           when d.userActive = 1 then N'نشط'
           when d.userActive = 0 then N'معطل'
           End ActiveStatus,
               d.userTypeName_A,
               d.userTypeID_FK,
               d.userActive,
               d.IdaraID,
               d.idaraLongName_A,
               r1.distributorName_A,
               d.EntryFullName,
           convert(nvarchar(10),d.entryDate,23)+' '+convert(nvarchar(10),d.entryDate,8) entryDate,
               ud.nationalIDIssueDate,
               ud.dateOfBirth,
               ud.genderID_FK,
               ud.nationalityID_FK,
               ud.religionID_FK,
               ud.maritalStatusID_FK,
               ud.educationID_FK,
              
              
               r1.distributorID

           from [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
           inner join dbo.UsersDetails ud on d.usersID = ud.usersID_FK and ud.userActive = 1 and d.userActive = 1
           left join dbo.UserDistributor ui on ud.usersID_FK = ui.userID_FK and ui.UDActive = 1
           left join dbo.Distributor r on ui.distributorID_FK = r.distributorID
           left join dbo.V_GetFullStructureForDSD dd on dd.DSDID = r.DSDID_FK and r.distributorType_FK = 1
           left join dbo.DeptSecDiv ds on dd.DepartmentID = ds.deptID_FK and ds.secID_FK is null and ds.divID_FK is null
           left join dbo.Distributor r1 on ds.DSDID = r1.DSDID_FK and r1.distributorType_FK = 1
             
               
               where d.IdaraID = @idaraID
               order by d.usersID desc
              END 
           



            if(@isAdmin = 1)
        Begin
          Select i.idaraID,i.idaraLongName_A from dbo.Idara i
        END

        ELSE if(@isAdmin = 2)
        Begin
            Select i.idaraID,i.idaraLongName_A from dbo.Idara i
           where  i.IdaraID = @idaraID
        END

         ELSE if(@isAdmin = 3)
        Begin
            Select i.idaraID,i.idaraLongName_A from dbo.Idara i
           where  i.IdaraID = @idaraID
        END
           



           
            if(@isAdmin = 1)
        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1

           END
           else if(@isAdmin = 2)
        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1 and ua.UsersAuthTypeID in (2,3)

           END
           else if(@isAdmin = 3)

        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1 and ua.UsersAuthTypeID in (2,3)

           END


           select t.userTypeID,t.userTypeName_A from dbo.UserType t where t.userTypeActive =1


           select g.genderID,g.genderName_A from dbo.Gender g 

           select n.nationalityID,n.nationalityName_A from dbo.Nationality n where n.nationalityActive = 1

           select n.religionID,n.religionName_A from dbo.Religion n where n.religionActive = 1

           select n.maritalStatusID,n.maritalStatusName_A from dbo.MaritalStatus n where n.maritalStatusActive = 1

           select n.educationID,n.educationName_A from dbo.Education n where n.educationActive = 1

           select @isAdmin isAdmin

            if(@isAdmin = 1)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null 
        END

        ELSE if(@isAdmin = 2)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null and d.IdaraID = @idaraID
        END

         ELSE if(@isAdmin = 3)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null and d.IdaraID = @idaraID
        END


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


          SELECT    v.userID,
                    v.menuName_E,
                    v.menuName_A,
                    v.permissionTypeName_E,
                    v.permissionTypeName_A 
          FROM [dbo].[ft_UserAllPermissionsForAi](@entrydata) v
           
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
            where m.menuLink is null and m.menuID not in 
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
           ,m.[programID_FK]
           ,m.[menuSerial]
           ,m.[menuActive]
           ,m.[isDashboard]
           ,m.[PageLvl]

            from dbo.Menu m
            inner join dbo.MenuDistributor md on m.menuID = md.menuID_FK and md.menuDistributorActive = 1 
            inner join dbo.Distributor d on d.distributorID = md.distributorID_FK and d.distributorActive = 1 and d.distributorType_FK = 4
            --where m.[menuActive] = 1 
            order by m.menuID desc

            --Permission

           
            SELECT 
       t.[distributorPermissionTypeID]
      ,t.[permissionTypeID_FK]
      ,t.[DistributorID_FK]
      ,t.[distributorPermissionTypeStartDate]
      ,t.[distributorPermissionTypeEndDate]
      ,t.[distributorPermissionTypeActive]
      ,t.[permissionAuthLvl]
      ,d.distributorName_A
      ,d.distributorType_FK
    
    
  FROM [DATACORE].[dbo].[DistributorPermissionType] t 
  inner join dbo.Distributor d on d.distributorID = t.distributorID_FK and d.distributorActive = 1 and d.distributorType_FK = 4
  inner join dbo.MenuDistributor md on md.distributorID_FK = t.distributorID_FK and md.menuDistributorActive = 1
  inner join dbo.Menu m on m.menuID = md.menuID_FK and m.menuActive = 1
  inner join dbo.Permission p 
  on p.DistributorPermissionTypeID_FK = t.distributorPermissionTypeID 
  and p.permissionActive = 1 
  and p.permissionStartDate is not null 
  and cast(p.permissionStartDate as date) <= cast(getdate() as date) 
  and (p.permissionEndDate is null or cast(p.permissionEndDate as date) > cast(getdate() as date))

  inner join dbo.permissionAuthLvl pa on pa.permissionAuthLvlID = t.permissionAuthLvl and pa.permissionAuthLvlActive = 1
  where t.distributorPermissionTypeActive = 1
           
        

        
           select 

            p.[programID]
           ,p.[programName_A]

            From dbo.Program p

            
            where programActive = 1
            ORDER BY P.programID asc



            select u.UsersAuthTypeID,u.UsersAuthTypeName_A
            from dbo.UsersAuthType u
            where u.UsersAuthTypeActive = 1


END


-------------------------------------------------------------------
--                     PAGE: RealChartsDemo
-------------------------------------------------------------------
        
        ELSE IF @pageName_ = 'RealChartsDemo'
        BEGIN



            -- Pie3D Data (Table 1) من جدول الديمو
            SELECT
                SegmentKey     AS [Key],
                SegmentLabel_A AS [Label],
                SegmentValue   AS [Value],
                SegmentHref    AS [Href],
                SegmentHint    AS [Hint]
            FROM Demo.Demo_Pie3D_UnitDistribution
            WHERE IsActive = 1
              AND (@idaraID IS NULL OR IdaraId_FK IS NULL OR IdaraId_FK = @idaraID)
            ORDER BY SortOrder;
        END






         -------------------------------------------------------------------
    --                     DO NOT TOUCH ABOVE THIS LINE
    -------------------------------------------------------------------

    --

    --

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
    --                     PAGE: AllMeterRead
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











        ------------------------------------------------------------------
--                     PAGE: VehicleS
-------------------------------------------------------------------




        -------------------------------------------------------------------
--                     PAGE: Admin_VehicleDocumentType
--DECLARE @ActiveOnly BIT;

--SET @ActiveOnly =
--    CASE
--        WHEN @parameter_01 IN ('1','0') THEN CAST(@parameter_01 AS BIT)
--        ELSE NULL
--    END;

--EXEC [VIC].[Admin_VehicleDocumentType_List_DL]
--     @ActiveOnly = @ActiveOnly;
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Admin_VehicleDocumentType'
    BEGIN
        

        EXEC [VIC].[Admin_VehicleDocumentType_List_DL]
    @ActiveOnly = @parameter_01;

    END
    -------------------------------------------------------------------
--                     PAGE: Custody_Current_ByUser
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Custody_Current_ByUser'
    BEGIN
        

        -- Current Custody By User Data
       EXEC [VIC].[Custody_Current_ByUser_DL]
      @userID     = @parameter_01
    , @idaraID_FK = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: Custody
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Custody'
    BEGIN
        

        -- Current Custody List Data
       EXEC [VIC].[CustodyCurrentListDL]
      @userID        = @parameter_01
    , @generalNo     = @parameter_02
    , @chassisNumber = @parameter_03
    , @pageNumber    = @parameter_04
    , @pageSize      = @parameter_05
    , @idaraID_FK    = @parameter_06;
    END

    -------------------------------------------------------------------
--                     PAGE: Custody_History_ByUser
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Custody_History_ByUser'
    BEGIN
        
        -- Custody History By User Data
        EXEC [VIC].[Custody_History_ByUser_DL]
      @userID     = @parameter_01
    , @fromDate   = @parameter_02
    , @toDate     = @parameter_03
    , @pageNumber = @parameter_04
    , @pageSize   = @parameter_05
    , @idaraID_FK = @parameter_06;
    END

    -------------------------------------------------------------------
--                     PAGE: Custody_History_ByVehicle
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Custody_History_ByVehicle'
    BEGIN
        

        -- Custody History By Vehicle Data
        EXEC [VIC].[Custody_History_ByVehicle_DL]
      @chassisNumber = @parameter_01
    , @fromDate      = @parameter_02
    , @toDate        = @parameter_03
    , @pageNumber    = @parameter_04
    , @pageSize      = @parameter_05;
    END

    -------------------------------------------------------------------
--                     PAGE: Dashboard
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Dashboard'
    BEGIN
        

        -- Dashboard Data
        EXEC [VIC].[Dashboard_Get_DL]
      @onlyHasCustody         = @parameter_01
    , @onlyHasActiveInsurance = @parameter_02
    , @onlyHasDocExpiry       = @parameter_03
    , @onlyHasInsExpiry       = @parameter_04
    , @idaraID_FK             = @parameter_05;
    END

    -------------------------------------------------------------------
--                     PAGE: Handover_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Handover_Get'
    BEGIN
        

        -- Handover Get Data
       EXEC [VIC].[Handover_Get_DL]
      @vehicleHandoverID = @parameter_01
    , @idaraID_FK        = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: Handover_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Handover_List'
    BEGIN
        

        -- Handover List Data
        EXEC [VIC].[Handover_List_DL]
      @requestID      = @parameter_01
    , @handoverTypeID = @parameter_02
    , @fromDate       = @parameter_03
    , @toDate         = @parameter_04
    , @pageNumber     = @parameter_05
    , @pageSize       = @parameter_06
    , @idaraID_FK      = @parameter_07;
    END

    -------------------------------------------------------------------
--                     PAGE: Handover_Print_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Handover_Print_Get'
    BEGIN
        
        -- Handover Print Get Data
        EXEC [VIC].[Handover_Print_Get_DL]
      @vehicleHandoverID = @parameter_01
    , @idaraID_FK        = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: HandoverType
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'HandoverType'
    BEGIN
        

        -- Handover Type Data
        EXEC [VIC].[HandoverType_List_DL]
              @activeOnly =  @parameter_01;
    END

    -------------------------------------------------------------------
--                     PAGE: MaintenanceDetails_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'MaintenanceDetails_List'
    BEGIN
        

        -- Maintenance Details List Data
        EXEC [VIC].[MaintenanceDetails_List_DL]
      @maintOrdID = @parameter_01
    , @idaraID_FK = @parameter_02;
    END

    -------------------------------------------------------------------
--                     MaintenanceTemplate_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'MaintenanceTemplate_List'
BEGIN
    

    EXEC [VIC].[MaintenanceTemplate_List_DL]
          @MaintOrdTypeID_FK = @parameter_01
        , @active            = @parameter_02;
END
    -------------------------------------------------------------------
--                     PAGE: MaintenanceOrder_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'MaintenanceOrder_Get'
    BEGIN
        

        -- Maintenance Order Get Data
        EXEC [VIC].[MaintenanceOrder_Get_DL]
      @maintOrdID = @parameter_01
    , @idaraID_FK = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: MaintenanceOrder_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'MaintenanceOrder_List'
    BEGIN
        

        -- Maintenance Order List Data
        EXEC [VIC].[MaintenanceOrder_List_DL]
      @chassisNumber  = @parameter_01
    , @maintOrdTypeID = @parameter_02
    , @active         = @parameter_03
    , @fromDate       = @parameter_04
    , @toDate         = @parameter_05
    , @pageNumber     = @parameter_06
    , @pageSize       = @parameter_07
    , @idaraID_FK      = @parameter_08;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_DocumentsExpiring
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_DocumentsExpiring'
    BEGIN
       

        -- Documents Expiring Report
        EXEC [VIC].[Report_DocumentsExpiring_DL]
      @days           = @parameter_01
    , @includeExpired = @parameter_02
    , @idaraID_FK     = @parameter_03;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_InsuranceExpiring
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_InsuranceExpiring'
    BEGIN
       

        -- Insurance Expiring Report
        EXEC [VIC].[Report_InsuranceExpiring_DL]
      @days           = @parameter_01
    , @includeExpired = @parameter_02
    , @activeOnly     = @parameter_03
    , @idaraID_FK      = @parameter_04;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_MaintenanceCostByVehicle
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_MaintenanceCostByVehicle'
    BEGIN
        

        -- Maintenance Cost By Vehicle Report
        EXEC [VIC].[Report_MaintenanceCostByVehicle_DL]
      @fromDate   = @parameter_01
    , @toDate     = @parameter_02
    , @idaraID_FK = @parameter_03;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_UnpaidViolations
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_UnpaidViolations'
    BEGIN
        

        -- Unpaid Violations Report
        EXEC [VIC].[Report_UnpaidViolations_DL]
      @chassisNumber = @parameter_01
    , @fromDate      = @parameter_02
    , @toDate        = @parameter_03
    , @idaraID_FK     = @parameter_04;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_VehiclesWithoutCustody
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_VehiclesWithoutCustody'
    BEGIN
        

        -- Vehicles Without Custody Report
        EXEC [VIC].[Report_VehiclesWithoutCustody_DL]
      @onlyActiveVehicles = @parameter_01
    , @idaraID_FK         = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: Report_VehicleTimeline
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Report_VehicleTimeline'
    BEGIN
        

        -- Vehicle Timeline Report
        EXEC [VIC].[Report_VehicleTimeline_DL]
      @chassisNumber = @parameter_01
    , @fromDate      = @parameter_02
    , @toDate        = @parameter_03
    , @idaraID_FK     = @parameter_04;
    END

    -------------------------------------------------------------------
--                     PAGE: TransferRequest_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'TransferRequest_Get'
    BEGIN
        

        -- Transfer Request Get Data
        EXEC [VIC].[TransferRequest_Get_DL]
      @requestID  = @parameter_01
    , @idaraID_FK = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: TransferRequestHistory_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'TransferRequestHistory_List'
    BEGIN
        

        -- Transfer Request History List Data
        EXEC [VIC].[TransferRequestHistory_List_DL]
      @requestID  = @parameter_01
    , @idaraID_FK = @parameter_02;
    END

    -------------------------------------------------------------------
--                     PAGE: TransferRequest_Vehicles_ByUserDept
-------------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Vehicles_ByUserDept'
BEGIN
    

    EXEC [VIC].[TransferRequest_Vehicles_ByUserDept_DL]
          @userID        = @parameter_01
        , @idaraID_FK    = @parameter_02
        , @pageNumber    = @parameter_03
        , @pageSize      = @parameter_04
        , @chassisNumber = @parameter_05;
END

-------------------------------------------------------------------
--                     PAGE: TransferRequest_EligibleUsers
-------------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_EligibleUsers'
BEGIN
    

    EXEC [VIC].[TransferRequest_EligibleUsers_DL]
          @chassisNumber = @parameter_01
        , @userID        = @parameter_02
        , @idaraID_FK    = @parameter_03;
END

-------------------------------------------------------------------
--                     PAGE: TransferRequest_Pending_ByDept
-------------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Pending_ByDept'
BEGIN
    

    EXEC [VIC].[TransferRequest_Pending_ByDept_DL]
          @userID        = @parameter_01
        , @idaraID_FK    = @parameter_02
        , @pageNumber    = @parameter_03
        , @pageSize      = @parameter_04;
END

-------------------------------------------------------------------
--                     PAGE: TransferRequest_Approved_List
-------------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Approved_List'
BEGIN
    

    EXEC [VIC].[TransferRequest_Approved_List_DL]
          @requestID      = @parameter_01
        , @chassisNumber  = @parameter_02
        , @fromUserID     = @parameter_03
        , @toUserID       = @parameter_04
        , @pageNumber     = @parameter_05
        , @pageSize       = @parameter_06
        , @idaraID_FK     = @parameter_07;
END
---------------------------------------------------------------------
--وش يسوي؟

--يرجع:
--?? خطة وحدة فقط

--تستخدمه في:
--شاشة التعديل
--لما تضغط “Edit”
-------------------------------------------------------------------

ELSE IF @pageName_ = 'MaintenancePlan_Get'
BEGIN
    

    EXEC [VIC].[MaintenancePlan_Get_DL]
          @planID      = @parameter_01
        , @idaraID_FK  = @idaraID;
END

----------------------------------------------------------------
-- MaintenanceDetails_Get
----------------------------------------------------------------
-- Description:
-- جلب بند صيانة واحد من جدول VIC.MaintenanceDetails حسب MaintDetailesID
-- مع التحقق من وجود السجل ومطابقة الإدارة عبر أمر الصيانة المرتبط (VehicleMaintenance).
--
-- Parameters:
-- @parameter_01 = MaintDetailesID
--
-- Notes:
-- - يستخدم في شاشة التعديل أو عرض تفاصيل بند صيانة واحد.
-- - يعتمد على idaraID لضمان أن البيانات ضمن نفس الإدارة.
----------------------------------------------------------------

ELSE IF @pageName_ = 'MaintenanceDetails_Get'
BEGIN
    

    EXEC [VIC].[MaintenanceDetails_Get_DL]
          @maintDetailesID = @parameter_01
        , @idaraID_FK      = @idaraID;
END
-------------------------------------------------------------------
--                  يرجع لك:
--?? كل خطط الصيانة الدورية

--مع معلومات إضافية:

--رقم اللوحة
--كل كم شهر
--متى الموعد القادم
--هل الخطة مفعلة أو لا
--تستخدمه في:
--صفحة عرض الخطط (Grid)
--الفلترة (حسب مركبة / مفعلة)
-------------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenancePlan_List'
BEGIN
    

    EXEC [VIC].[MaintenancePlan_List_DL]
          @chassisNumber = @parameter_01
        , @active        = @parameter_02
        , @pageNumber    = @parameter_03
        , @pageSize      = @parameter_04
        , @idaraID_FK    = @idaraID;
END

-------------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenancePlan_Get'
BEGIN

    EXEC [VIC].[MaintenancePlan_Get_DL]
          @planID     = @parameter_01
        , @idaraID_FK = @idaraID;
END
-------------------------------------------------------------------
--                    داش بورد الصيانه الدوريه
-------------------------------------------------------------------

ELSE IF @pageName_ = 'Dashboard_MaintenanceDue'
BEGIN
    

    EXEC [VIC].[Dashboard_MaintenanceDue_DL]
          @daysAhead  = @parameter_01
        , @idaraID_FK = @idaraID;
END
    -------------------------------------------------------------------
--                     PAGE: TransferRequestType_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'TransferRequestType_List'
    BEGIN
        

        -- Transfer Request Type Lookup
        EXEC [VIC].[TransferRequestType_List_DL]
    @activeOnly = @parameter_01;
    END

    -------------------------------------------------------------------
--                     PAGE: TypesRoot_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'TypesRoot_List'
    BEGIN
        

        -- Types Root Lookup / List
        EXEC [VIC].[TypesRoot_List_DL]
      @parentID   = @parameter_01
    , @activeOnly = @parameter_02
    , @search     = @parameter_03;
    END
    -------------------------------------------------------------------
--                     PAGE: Scrap
-------------------------------------------------------------------
ELSE IF @pageName_ = 'Scrap'
BEGIN

    -- Scrap List / Get / Print
    EXEC [VIC].[ScrapDL]
          @scrapID       = @parameter_01
        , @chassisNumber = @parameter_02
        , @Status        = @parameter_03
        , @DateFrom      = @parameter_04
        , @DateTo        = @parameter_05
        , @pageNumber    = @parameter_06
        , @pageSize      = @parameter_07
        , @idaraID_FK    = @idaraID;
END
    -------------------------------------------------------------------
--                     PAGE: Vehicle_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehicle_Get'
    BEGIN
        

        -- Vehicle Get Data
        EXEC [VIC].[Vehicle_Get_DL]
      @UsersID        = @parameter_01
    , @MenuLink       = @parameter_02
    , @SkipPermission = @parameter_03
    , @chassisNumber  = @parameter_04
    , @idaraID_FK      = @parameter_05;
    END

    -------------------------------------------------------------------
--                     PAGE: Vehicle_GetLookups
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehicle_GetLookups'
    BEGIN
        

        -- Vehicle Lookups Data
        EXEC [VIC].[Vehicle_GetLookups_DL]
      @UsersID            = @parameter_01
    , @MenuLink           = @parameter_02
    , @SkipPermission     = @parameter_03
    , @TypesRoot_ParentID = @parameter_04;
    END

    -------------------------------------------------------------------
--                     PAGE: Vehicle_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehiclelist'
    BEGIN
        

        -- Vehicle List Data
        EXEC [VIC].[Vehicle_List_DL]
      @ownerID_FK   = @parameter_01
    , @plateLetters = @parameter_02
    , @plateNumbers = @parameter_03
    , @hasCustody   = @parameter_04
    , @pageNumber   = @parameter_05
    , @pageSize     = @parameter_06
    , @idaraID_FK     = @parameter_07;
    END

    -------------------------------------------------------------------
--                     PAGE: Vehicle_List_EXT
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehicle_List_EXT'
    BEGIN
       

        -- Vehicle List EXT Data
        EXEC [VIC].[Vehicle_List_EXT_DL]
      @UsersID          = @parameter_01
    , @MenuLink         = @parameter_02
    , @SkipPermission   = @parameter_03
    , @q                = @parameter_04
    , @ownerID_FK       = @parameter_05
    , @plateLetters     = @parameter_06
    , @plateNumbers     = @parameter_07
    , @HasCustody       = @parameter_08
    , @HasActiveRequest = @parameter_09
    , @PageNumber       = @parameter_10
    , @PageSize         = @parameter_11
    , @idaraID_FK        = @parameter_12;
    END


    -------------------------------------------------------------------
--                     PAGE: Vehicle_Profile_Get
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehicle_Profile_Get'
    BEGIN
        

        -- Vehicle Profile (multiple result-sets)
        EXEC [VIC].[Vehicle_Profile_Get_DL]
      @UsersID        = @parameter_01
    , @MenuLink       = @parameter_02
    , @SkipPermission = @parameter_03
    , @chassisNumber  = @parameter_04
    , @TopDocuments   = @parameter_05
    , @TopInsurance   = @parameter_06
    , @TopMaintenance = @parameter_07
    , @TopViolations  = @parameter_08
    , @idaraID_FK      = @parameter_09;
    END
-------------------------------------------------------------------
--                     PAGE: Vehicles
-------------------------------------------------------------------
ELSE IF @pageName_ = 'Vehicles'
BEGIN

    -- Vehicle List Data
    EXEC [VIC].[Vehicle_List_DL]
          @ownerID_FK   = @parameter_01
        , @plateLetters = @parameter_02
        , @plateNumbers = @parameter_03
        , @hasCustody   = @parameter_04
        , @pageNumber   = @parameter_05
        , @pageSize     = @parameter_06
        , @idaraID_FK   = @parameter_07;
END
    -------------------------------------------------------------------
--                     PAGE: Vehicle_Search
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Vehicle_Search'
    BEGIN
       

        -- Vehicle Search (fast by plate OR general q)
        EXEC [VIC].[Vehicle_Search_DL]
      @q            = @parameter_01
    , @plateLetters = @parameter_02
    , @plateNumbers = @parameter_03
    , @Top          = @parameter_04
    , @idaraID_FK     = @parameter_05;
    END

    -------------------------------------------------------------------
--                     PAGE: VehicleDocument_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'VehicleDocument_List'
    BEGIN
        

        -- Vehicle Documents List (normal list OR expiring mode)
        EXEC [VIC].[VehicleDocument_List_DL]
      @chassisNumber         = @parameter_01
    , @vehicleDocumentTypeID = @parameter_02
    , @DocumentNo            = @parameter_03
    , @OnlyActiveNow         = @parameter_04
    , @Page                  = @parameter_05
    , @PageSize              = @parameter_06
    , @ExpireDays            = @parameter_07
    , @IncludeExpired        = @parameter_08
    , @idaraID_FK            = @parameter_09;
    END

    -------------------------------------------------------------------
--                     PAGE: VehicleDocumentType_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'VehicleDocumentType_List'
    BEGIN
        

        -- Vehicle Document Types (Lookup/Dropdown)
        EXEC [VIC].[VehicleDocumentType_List_DL]
    @ActiveOnly = @parameter_01;
    END

    -------------------------------------------------------------------
--                     PAGE: VehicleInsurance_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'VehicleInsurance_List'
    BEGIN
        

        -- Vehicle Insurance List (filters + optional expiring)
       EXEC [VIC].[VehicleInsurance_List_DL]
      @chassisNumber   = @parameter_01
    , @InsuranceTypeID = @parameter_02
    , @OperationTypeID = @parameter_03
    , @Active          = @parameter_04
    , @FromDate        = @parameter_05
    , @ToDate          = @parameter_06
    , @Page            = @parameter_07
    , @PageSize        = @parameter_08
    , @Days            = @parameter_09
    , @IncludeExpired  = @parameter_10;
    END

    -------------------------------------------------------------------
--                     PAGE: Violation_GetLookups
-------------------------------------------------------------------
   ----------------------------------------------------------------
-- Violation_GetLookups
----------------------------------------------------------------
ELSE IF @pageName_ = 'Violation_GetLookups'
BEGIN
    EXEC [VIC].[Violation_GetLookups_DL]
          @ActiveOnly = @parameter_01;
END

    -------------------------------------------------------------------
--                     PAGE: Violation_List
-------------------------------------------------------------------
    ELSE IF @pageName_ = 'Violation_List'
    BEGIN
        

        -- Violations List (filters + paging)
        EXEC [VIC].[Violation_List_DL]
      @chassisNumber   = @parameter_01
    , @violationTypeID = @parameter_02
    , @Paid            = @parameter_03
    , @FromDate        = @parameter_04
    , @ToDate          = @parameter_05
    , @Page            = @parameter_06
    , @PageSize        = @parameter_07
    , @idaraID_FK       = @parameter_08;
    END
     -------------------------------------------------------------------
--                    Violation_Get
-------------------------------------------------------------------

    ELSE IF @pageName_ = 'Violation_Get'
BEGIN
    EXEC [VIC].[Violation_Get_DL]
          @violationID = @parameter_01
        , @idaraID_FK  = @parameter_02;
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

        DECLARE @ErrMsg NVARCHAR(4000), @ErrSeverity INT, @ErrState INT, @ErrNumber INT, @IdentityCatchError INT;

        SELECT 
              @ErrMsg      = ERROR_MESSAGE(),
              @ErrNumber   = ERROR_NUMBER(),
              @ErrSeverity = ERROR_SEVERITY(),
              @ErrState    = ERROR_STATE();

        -- أخطاء الأعمال/المستخدم لا تسجل في ErrorLog
        -- 50000: غالباً ناتج RAISERROR برسالة مخصصة
        -- 50001-50999: نطاق أخطاء الأعمال المعتمد في النظام
        IF @ErrNumber BETWEEN 50000 AND 50999
        BEGIN
            SELECT 0 AS IsSuccessful, @ErrMsg AS Message_;
            RETURN;
        END

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
