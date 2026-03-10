

CREATE VIEW [dbo].[V_MVCProgramMenuTree_MenuDistributor] AS

with cte as (
SELECT        md.menuDistributorID, md.menuID_FK, md.menuDistributorActive, md.roleID_FK, md.distributorID_FK, d.distributorName_A, null as roleName_A,
case when md.distributorID_FK is null and md.roleID_FK is null then 1
END IsPuplic
FROM            MenuDistributor AS md 
left JOIN Distributor AS d ON md.distributorID_FK = d.distributorID 
--left JOIN [Role] AS r ON md.roleID_FK = r.roleID AND md.roleID_FK = r.roleID
WHERE        d.distributorActive = 1 

union all 

SELECT        md.menuDistributorID, md.menuID_FK, md.menuDistributorActive, md.roleID_FK, md.distributorID_FK, null as distributorName_A, r.roleName_A,
case when md.distributorID_FK is null and md.roleID_FK is null then 1
END IsPuplic
FROM            MenuDistributor AS md 
--left JOIN Distributor AS d ON md.distributorID_FK = d.distributorID 
left JOIN [Role] AS r ON md.roleID_FK = r.roleID AND md.roleID_FK = r.roleID

) 


select * from  dbo.V_MVCProgramMenuTree m 
left join cte c on c.menuID_FK = m.menuID

