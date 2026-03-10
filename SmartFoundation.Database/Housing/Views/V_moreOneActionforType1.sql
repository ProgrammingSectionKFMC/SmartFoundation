
create view housing.V_moreOneActionforType1
as
SELECT   count(*) as count_, generalNo_FK,buildingActionExtraType1
FROM            Housing.BuildingAction
WHERE        (buildingActionTypeID_FK = 1)
group by generalNo_FK,buildingActionExtraType1
having count(*) >1
--ORDER BY buildingActionID DESC