

CREATE   FUNCTION [dbo].[ft_UserAllPermissionsForAi]
(
      @UsersID     BigInt
    
)
RETURNS TABLE
AS
RETURN
(
    SELECT DISTINCT
        isnull(v.userID,@UsersID) as userID,
    v.menuName_E,
    v.menuName_A,
    v.permissionTypeName_E,
    v.permissionTypeName_A
    FROM  dbo.V_GetListUserPermission AS v
    INNER JOIN  dbo.Permission AS p
        ON v.permissionID = p.permissionID
    WHERE
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
        -- فلترة الصفحة
        -- فلترة التواريخ
        AND CAST(v.permissionStartDate AS DATE) <= CAST(GETDATE() AS DATE)
        AND (v.permissionEndDate IS NULL OR CAST(v.permissionEndDate AS DATE) > CAST(GETDATE() AS DATE))
);