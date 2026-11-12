/*
    Tickets module - one permission page per screen (Housing pattern)
    -----------------------------------------------------------------
    Before: ticket actions lived on the hidden TicketDetails page and the service
    permissions on the hidden ServiceCatalogueList page, while the buttons were on
    TicketList and TicketAdmin.

    After:
      TicketList  owns every ticket action      (INSERT_TICKET, ROUTE_TICKET, START_WORK ...)
      TicketAdmin owns settings, services and arbitration decisions
                  (INSERTTICKETCLASS ..., INSERTSERVICE/UPDATESERVICE/DELETESERVICE,
                   DECIDE_ARBITRATION, CANCEL_ARBITRATION)
      Masters_CRUD checks: menuName_E = @pageName_ AND permissionTypeName_E = @ActionType.

    Steps (safe to run more than once, single transaction):
      1. Add the moved permission types to the TicketList / TicketAdmin distributors.
      2. Copy existing grants (users, roles, units...) from the old pages to the new ones.
      3. Deactivate the old grants, distributors, menu links and menus (nothing is deleted).

    Not carried over (no screen uses them): MANAGEROUTINGRULES, MANAGESLAPOLICIES,
    APPROVESERVICESUGGESTION.

    Run after Tickets_SeedData.sql and together with the matching Masters_CRUD change:
      sqlcmd -S <server> -d <database> -E -I -f 65001 -i Tickets_PermissionsConsolidation.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @map TABLE (fromCode NVARCHAR(50), toCode NVARCHAR(50), permissionTypeName_E NVARCHAR(200));
INSERT INTO @map (fromCode, toCode, permissionTypeName_E) VALUES
    -- ticket actions: TicketDetails -> TicketList
    (N'TKT-TDET', N'TKT-TLIST', N'INSERT_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'ROUTE_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'REJECT_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'ASSIGN_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'REASSIGN_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'UPDATE_PRIORITY'),
    (N'TKT-TDET', N'TKT-TLIST', N'START_WORK'),
    (N'TKT-TDET', N'TKT-TLIST', N'RESOLVE_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'PAUSE_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'RESUME_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'REQUEST_CLARIFICATION'),
    (N'TKT-TDET', N'TKT-TLIST', N'RESPOND_CLARIFICATION'),
    (N'TKT-TDET', N'TKT-TLIST', N'RAISE_ARBITRATION'),
    (N'TKT-TDET', N'TKT-TLIST', N'CREATE_CHILD_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'SUBMIT_QUALITY_REVIEW'),
    (N'TKT-TDET', N'TKT-TLIST', N'FINALIZE_QUALITY_REVIEW'),
    (N'TKT-TDET', N'TKT-TLIST', N'CLOSE_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'REOPEN_TICKET'),
    (N'TKT-TDET', N'TKT-TLIST', N'UPLOAD_ATTACHMENT'),
    (N'TKT-TDET', N'TKT-TLIST', N'DELETE_ATTACHMENT'),
    (N'TKT-TDET', N'TKT-TLIST', N'ACCESS'),
    -- arbitration decisions: TicketDetails -> TicketAdmin (the arbitration tab lives there)
    (N'TKT-TDET', N'TKT-TADM', N'DECIDE_ARBITRATION'),
    (N'TKT-TDET', N'TKT-TADM', N'CANCEL_ARBITRATION'),
    -- services: ServiceCatalogueList -> TicketAdmin (the services tab lives there)
    (N'TKT-SCAT', N'TKT-TADM', N'INSERTSERVICE'),
    (N'TKT-SCAT', N'TKT-TADM', N'UPDATESERVICE'),
    (N'TKT-SCAT', N'TKT-TADM', N'DELETESERVICE'),
    (N'TKT-SCAT', N'TKT-TADM', N'ACCESS');

---------------------------------------------------------------------------
-- 1. Permission types offered by the target pages
---------------------------------------------------------------------------
INSERT INTO dbo.DistributorPermissionType
    (permissionTypeID_FK, DistributorID_FK, distributorPermissionTypeStartDate, distributorPermissionTypeActive, permissionAuthLvl, entryDate)
SELECT DISTINCT pt.permissionTypeID, td.distributorID, GETDATE(), 1, 3, GETDATE()
FROM @map m
JOIN dbo.Distributor td ON td.distributorCode = m.toCode
JOIN dbo.PermissionType pt ON pt.permissionTypeName_E = m.permissionTypeName_E
WHERE NOT EXISTS (SELECT 1 FROM dbo.DistributorPermissionType x
                  WHERE x.DistributorID_FK = td.distributorID AND x.permissionTypeID_FK = pt.permissionTypeID);

UPDATE x SET distributorPermissionTypeActive = 1
FROM dbo.DistributorPermissionType x
JOIN dbo.Distributor td ON td.distributorID = x.DistributorID_FK
JOIN dbo.PermissionType pt ON pt.permissionTypeID = x.permissionTypeID_FK
JOIN @map m ON m.toCode = td.distributorCode AND m.permissionTypeName_E = pt.permissionTypeName_E
WHERE ISNULL(x.distributorPermissionTypeActive, 0) = 0;

PRINT N'1. permission types ready on TicketList/TicketAdmin';

---------------------------------------------------------------------------
-- 2. Copy grants from the old pages to the new ones (same grantee, same dates)
---------------------------------------------------------------------------
INSERT INTO dbo.Permission
    (DistributorPermissionTypeID_FK, UsersID_FK, RoleID_FK, distributorID_FK, IdaraID_FK, DSDID_FK,
     permissionStartDate, permissionEndDate, permissionActive, permissionNote, InIdaraID, entryDate, entryData, hostName)
SELECT DISTINCT
    tx.distributorPermissionTypeID, p.UsersID_FK, p.RoleID_FK, p.distributorID_FK, p.IdaraID_FK, p.DSDID_FK,
    p.permissionStartDate, p.permissionEndDate, 1, N'Moved from ' + m.fromCode, p.InIdaraID, GETDATE(), N'tickets-migration', HOST_NAME()
FROM dbo.Permission p
JOIN dbo.DistributorPermissionType fx ON fx.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
JOIN dbo.Distributor fd ON fd.distributorID = fx.DistributorID_FK
JOIN dbo.PermissionType pt ON pt.permissionTypeID = fx.permissionTypeID_FK
JOIN @map m ON m.fromCode = fd.distributorCode AND m.permissionTypeName_E = pt.permissionTypeName_E
JOIN dbo.Distributor td ON td.distributorCode = m.toCode
JOIN dbo.DistributorPermissionType tx ON tx.DistributorID_FK = td.distributorID AND tx.permissionTypeID_FK = pt.permissionTypeID
WHERE p.permissionActive = 1
  AND NOT EXISTS (
        SELECT 1 FROM dbo.Permission q
        WHERE q.DistributorPermissionTypeID_FK = tx.distributorPermissionTypeID
          AND q.permissionActive = 1
          AND ISNULL(q.UsersID_FK, -1)       = ISNULL(p.UsersID_FK, -1)
          AND ISNULL(q.RoleID_FK, -1)        = ISNULL(p.RoleID_FK, -1)
          AND ISNULL(q.distributorID_FK, -1) = ISNULL(p.distributorID_FK, -1)
          AND ISNULL(q.IdaraID_FK, -1)       = ISNULL(p.IdaraID_FK, -1)
          AND ISNULL(q.DSDID_FK, -1)         = ISNULL(p.DSDID_FK, -1));

PRINT CONCAT(N'2. grants copied: ', @@ROWCOUNT);

---------------------------------------------------------------------------
-- 3. Retire the old permission pages (deactivate only)
---------------------------------------------------------------------------
UPDATE p SET permissionActive = 0, permissionNote = ISNULL(p.permissionNote + N' | ', N'') + N'Moved to TicketList/TicketAdmin'
FROM dbo.Permission p
JOIN dbo.DistributorPermissionType fx ON fx.distributorPermissionTypeID = p.DistributorPermissionTypeID_FK
JOIN dbo.Distributor fd ON fd.distributorID = fx.DistributorID_FK
WHERE fd.distributorCode IN (N'TKT-TDET', N'TKT-SCAT') AND p.permissionActive = 1;
PRINT CONCAT(N'3a. old grants deactivated: ', @@ROWCOUNT);

UPDATE dbo.Distributor SET distributorActive = 0
WHERE distributorCode IN (N'TKT-TDET', N'TKT-SCAT') AND distributorActive = 1;

UPDATE md SET menuDistributorActive = 0
FROM dbo.MenuDistributor md
JOIN dbo.Menu mn ON mn.menuID = md.menuID_FK
JOIN dbo.Program pr ON pr.programID = mn.programID_FK AND pr.programName_E = N'Tickets'
WHERE mn.menuName_E IN (N'TicketDetails', N'ServiceCatalogueList') AND md.menuDistributorActive = 1;

UPDATE mn SET menuActive = 0
FROM dbo.Menu mn
JOIN dbo.Program pr ON pr.programID = mn.programID_FK AND pr.programName_E = N'Tickets'
WHERE mn.menuName_E IN (N'TicketDetails', N'ServiceCatalogueList') AND mn.menuActive = 1;
PRINT N'3b. TicketDetails / ServiceCatalogueList pages retired';

COMMIT TRANSACTION;
PRINT N'Tickets permissions consolidation: done.';
