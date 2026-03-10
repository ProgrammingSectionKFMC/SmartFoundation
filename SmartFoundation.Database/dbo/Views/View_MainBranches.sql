
CREATE VIEW [dbo].[View_MainBranches] AS
SELECT
    mb.branchID          AS BranchID,
    mb.branchName_A      AS BranchName_A,
    mb.branchName_E      AS BranchName_E,
    mb.branchStartDate   AS BranchStartDate,
    mb.branchEndDate     AS BranchEndDate,
    mb.branchDescription AS BranchDescription,
    mb.branchActive      AS BranchActive,
    mb.adminID_FK        AS AdminID_FK,
    la.adminName_A       AS AdminName_A_FK
FROM MainBranches mb
LEFT JOIN LocalAdministrations la ON mb.adminID_FK = la.adminID;
