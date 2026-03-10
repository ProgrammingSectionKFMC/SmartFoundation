
CREATE   FUNCTION [dbo].[funcGetDepartmentDistID] (@departmentID INT)
RETURNS INT
AS
BEGIN
    DECLARE @distributorID INT

    SELECT @distributorID = D.distributorID
    FROM DeptSecDiv DSD
    INNER JOIN  dbo.Distributor D ON DSD.DSDID = D.DSDID_FK
    INNER JOIN  dbo.DistributorType DT ON D.distributorType_FK = DT.distributorTypeID
    INNER JOIN  dbo.Department Dep ON Dep.deptID = DSD.deptID_FK
    WHERE DT.distributorTypeID = 1 AND DSD.divID_FK IS NULL AND DSD.secID_FK IS NULL AND Dep.deptID = @departmentID

    RETURN @distributorID
END
