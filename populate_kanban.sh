#!/usr/bin/env bash
# ============================================================================
# SmartFoundationTickets - COMPLETE Kanban Board Population Script
# Repository: Fahad1993/SmartFoundationTickets
# Project #3 | Owner: Fahad1993
# Board URL: https://github.com/users/Fahad1993/projects/3/views/1
# Generated: 2026-04-01
# ============================================================================

# set -e

OWNER="Fahad1993"
PROJECT=3

echo "========================================="
echo " Populating Kanban Board - Project #${PROJECT}"
echo " Owner: ${OWNER}"
echo "========================================="
echo ""

# ============================================================================
# SPEC 00: Project Setup & Schema (2 tasks)
# ============================================================================
echo ">>> SPEC 00: Project Setup & Schema"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-00] Create [Tickets] schema in MSSQL" --body "**Spec:** 00 - Project Setup
**Category:** DB-Structure
**Dependencies:** None

## Objective
Create the [Tickets] schema that will contain all ticketing system objects.

## Steps
1. Check if schema exists: SELECT * FROM sys.schemas WHERE name = 'Tickets'
2. If not, execute: CREATE SCHEMA [Tickets]
3. Verify the schema is accessible.

## Acceptance Criteria
- Schema [Tickets] exists in the database.
- All subsequent CREATE TABLE statements referencing [Tickets].* will succeed."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-00] Create Database directory structure in repository" --body "**Spec:** 00 - Project Setup
**Category:** Docs
**Dependencies:** None

## Objective
Set up the directory structure in the repo for all SQL scripts.

## Directories
- Database/Schema/
- Database/Tables/Lookups/
- Database/Tables/Master/
- Database/Tables/Transaction/
- Database/Tables/History/
- Database/Views/
- Database/StoredProcedures/SP/
- Database/StoredProcedures/DL/
- Database/Seeds/
- Database/Tests/
- Database/Docs/

## Acceptance Criteria
- All directories exist and are committed to the repo with a README."

# ============================================================================
# SPEC 01: Lookup Foundations (10 tasks)
# ============================================================================
echo ">>> SPEC 01: Lookup Foundations"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[TicketStatus] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- TicketStatusID INT IDENTITY(1,1) PK
- StatusCode NVARCHAR(50) NOT NULL UNIQUE
- StatusNameAR NVARCHAR(200) NULL
- StatusNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- CreatedBy BIGINT NULL
- CreatedDate DATETIME2(7) DEFAULT SYSUTCDATETIME()
- ModifiedBy BIGINT NULL
- ModifiedDate DATETIME2(7) NULL

## Acceptance Criteria
- Table exists with UNIQUE constraint on StatusCode."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[TicketClass] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- TicketClassID INT IDENTITY(1,1) PK
- ClassCode NVARCHAR(50) NOT NULL UNIQUE
- ClassNameAR NVARCHAR(200) NULL
- ClassNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists. ClassCode uniqueness enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[Priority] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- PriorityID INT IDENTITY(1,1) PK
- PriorityCode NVARCHAR(50) NOT NULL UNIQUE
- PriorityNameAR NVARCHAR(200) NULL
- PriorityNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists. PriorityCode uniqueness enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[RequesterType] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- RequesterTypeID INT IDENTITY(1,1) PK
- TypeCode NVARCHAR(50) NOT NULL UNIQUE
- TypeNameAR NVARCHAR(200) NULL
- TypeNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists. Supports BR-01 mutual exclusivity on Ticket table."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[PauseReason] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- PauseReasonID INT IDENTITY(1,1) PK
- ReasonCode NVARCHAR(50) NOT NULL UNIQUE
- ReasonNameAR NVARCHAR(200) NULL
- ReasonNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists with UNIQUE constraint on ReasonCode."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[ArbitrationReason] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- ArbitrationReasonID INT IDENTITY(1,1) PK
- ReasonCode NVARCHAR(50) NOT NULL UNIQUE
- ReasonNameAR NVARCHAR(200) NULL
- ReasonNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists with UNIQUE constraint."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[ClarificationReason] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- ClarificationReasonID INT IDENTITY(1,1) PK
- ReasonCode NVARCHAR(50) NOT NULL UNIQUE
- ReasonNameAR NVARCHAR(200) NULL
- ReasonNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists with UNIQUE constraint."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Create [Tickets].[QualityReviewResult] lookup table" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** Spec-00 (schema)

## Columns
- QualityReviewResultID INT IDENTITY(1,1) PK
- ResultCode NVARCHAR(50) NOT NULL UNIQUE
- ResultNameAR NVARCHAR(200) NULL
- ResultNameEN NVARCHAR(200) NULL
- SortOrder INT DEFAULT 0
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists with UNIQUE constraint."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Seed all lookup tables with initial values" --body "**Spec:** 01 - Lookup Foundations
**Category:** DB-Structure
**Dependencies:** All 8 lookup tables

## Seed Data
**TicketStatus:** NEW, OPEN, ASSIGNED, IN_PROGRESS, ON_HOLD, PENDING_CLARIFICATION, IN_ARBITRATION, RESOLVED, PENDING_QA, CLOSED, REOPENED, REJECTED, CANCELLED
**TicketClass:** INCIDENT, REQUEST, COMPLAINT, INQUIRY
**Priority:** CRITICAL, HIGH, MEDIUM, LOW
**RequesterType:** RESIDENT, INTERNAL
**PauseReason:** CHILD_DEPENDENCY, ARBITRATION, CLARIFICATION, WAREHOUSE_DELAY, APPROVAL_DELAY, EXTERNAL_DEPENDENCY
**ArbitrationReason:** WRONG_DEPARTMENT, WRONG_DIVISION, WRONG_SECTION, UNCLEAR_OWNERSHIP, OTHER
**ClarificationReason:** MISSING_LOCATION, MISSING_TECHNICAL, MISSING_APPROVAL, AMBIGUOUS_REQUEST, OTHER
**QualityReviewResult:** APPROVED, RETURNED, REJECTED

All with Arabic and English names.

## Acceptance Criteria
- All seed data inserted. SELECT COUNT(*) returns expected rows. No duplicate codes."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-01] Test lookup uniqueness and seed integrity" --body "**Spec:** 01 - Lookup Foundations
**Category:** Test
**Dependencies:** Seed script

## Tests
1. Verify each table has expected row count.
2. Attempt duplicate code inserts — confirm failure.
3. Verify IsActive defaults to 1.
4. Verify CreatedDate is auto-populated.

## Acceptance Criteria
- All tests pass. Duplicate codes rejected. Defaults work."

# ============================================================================
# SPEC 02: Service Catalogue Foundations (15 tasks)
# ============================================================================
echo ">>> SPEC 02: Service Catalogue Foundations"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[Service] master table" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-Structure
**Dependencies:** Spec-01 (TicketClass, Priority lookups)

## Columns
- ServiceID BIGINT IDENTITY(1,1) PK
- IdaraID_FK BIGINT NOT NULL
- ServiceCode NVARCHAR(50) NOT NULL
- ServiceNameAR NVARCHAR(500), ServiceNameEN NVARCHAR(500)
- ServiceDescriptionAR NVARCHAR(2000), ServiceDescriptionEN NVARCHAR(2000)
- TicketClassID_FK INT FK->TicketClass
- DefaultPriorityID_FK INT FK->Priority
- RequiresLocation BIT DEFAULT 0
- RequiresQualityReview BIT DEFAULT 0
- IsActive BIT DEFAULT 1, IsDeleted BIT DEFAULT 0
- Standard audit columns
- UNIQUE(ServiceCode, IdaraID_FK)

## Acceptance Criteria
- Table exists with FKs. Soft delete only (IsDeleted flag)."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[ServiceRoutingRule] master table" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-Structure
**Dependencies:** Spec-02 Service table

## Columns
- ServiceRoutingRuleID BIGINT IDENTITY(1,1) PK
- ServiceID_FK BIGINT FK->Service NOT NULL
- IdaraID_FK BIGINT NOT NULL
- TargetDSDID_FK BIGINT NOT NULL (BR-04: mandatory)
- QueueDistributorID_FK BIGINT NULL
- EffectiveFrom DATE NOT NULL, EffectiveTo DATE NULL
- ChangeReason NVARCHAR(1000), ApprovedBy BIGINT, ApprovedDate DATETIME2
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists. TargetDSDID_FK cannot be NULL. Effective dating supports historical rules."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[ServiceSLAPolicy] master table" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-Structure
**Dependencies:** Spec-02 Service table, Spec-01 Priority

## Columns
- ServiceSLAPolicyID BIGINT IDENTITY(1,1) PK
- ServiceID_FK BIGINT FK->Service, IdaraID_FK BIGINT
- PriorityID_FK INT FK->Priority NOT NULL
- FirstResponseTargetMinutes INT, AssignmentTargetMinutes INT
- OperationalCompletionTargetMinutes INT, FinalClosureTargetMinutes INT
- EffectiveFrom DATE, EffectiveTo DATE NULL
- IsActive BIT DEFAULT 1
- Standard audit columns

## Acceptance Criteria
- Table exists. Four SLA target columns present. FKs to Service and Priority."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[ServiceCatalogSuggestion] master table" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-Structure
**Dependencies:** Spec-02 Service table, Spec-01 Priority

## Columns
- ServiceCatalogSuggestionID BIGINT IDENTITY(1,1) PK
- SourceTicketID_FK BIGINT NULL
- IdaraID_FK BIGINT NOT NULL
- ProposedServiceNameAR NVARCHAR(500), ProposedServiceNameEN NVARCHAR(500)
- ProposedDescription NVARCHAR(2000)
- ProposedTargetDSDID_FK BIGINT NULL, ProposedPriorityID_FK INT FK->Priority NULL
- ApprovalStatus NVARCHAR(50) DEFAULT 'PENDING'
- ApprovedBy BIGINT, ApprovedDate DATETIME2, RejectionReason NVARCHAR(1000)
- CreatedServiceID_FK BIGINT FK->Service NULL
- Standard audit columns

## Acceptance Criteria
- Table exists. ApprovalStatus defaults to PENDING."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Implement [Tickets].[ServiceSP] - service CRUD actions" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-SP
**Dependencies:** Service table

## Actions
- **INSERT_SERVICE:** validate inputs, insert into Service, write JSON audit to dbo.AuditLog, return ServiceID.
- **UPDATE_SERVICE:** update editable fields using ISNULL pattern, write audit.
- **DELETE_SERVICE:** soft delete (IsDeleted=1, IsActive=0), write audit.

## Standards
- Multiplexer @Action pattern
- BEGIN TRAN / COMMIT TRAN / SET XACT_ABORT ON
- THROW for validation errors
- JSON audit to dbo.AuditLog

## Acceptance Criteria
- Services created/updated/deleted only through this SP. Audit entries for every action."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Implement [Tickets].[ServiceSP] - routing rule actions" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-SP
**Dependencies:** ServiceRoutingRule table, CatalogRoutingChangeLog table

## Actions
- **INSERT_ROUTING_RULE:** validate TargetDSDID NOT NULL (BR-04), close existing active rule (EffectiveTo, IsActive=0), insert new rule, log to CatalogRoutingChangeLog, write audit.
- **CLOSE_ROUTING_RULE:** set EffectiveTo=today, IsActive=0, write audit.

## Business Rules
- BR-04: TargetDSDID_FK mandatory
- BR-18: Historical routing preserved, never overwritten silently

## Acceptance Criteria
- New rules auto-close old ones. NULL TargetDSDID rejected. Change logged to CatalogRoutingChangeLog."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Implement [Tickets].[ServiceSP] - SLA policy upsert action" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-SP
**Dependencies:** ServiceSLAPolicy table

## Actions
- **UPSERT_SLA_POLICY:** if active policy exists for ServiceID+PriorityID, UPDATE target minutes. If not, INSERT new policy. Write audit.

## Acceptance Criteria
- SLA policies retrievable per service+priority. Upsert logic correct."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Implement [Tickets].[ServiceSP] - suggestion approval/rejection" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-SP
**Dependencies:** ServiceCatalogSuggestion table

## Actions
- **APPROVE_SERVICE_SUGGESTION:** set ApprovalStatus=APPROVED, ApprovedBy, ApprovedDate. Write audit. (BR-19)
- **REJECT_SERVICE_SUGGESTION:** set ApprovalStatus=REJECTED, RejectionReason. Write audit.

## Acceptance Criteria
- Suggestions can be approved or rejected. Audit trail maintained."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[V_ServiceFullDefinition] view" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-DL-View
**Dependencies:** Service, TicketClass, Priority, ServiceRoutingRule tables

## Logic
- JOIN Service -> TicketClass, Priority, ServiceRoutingRule (active only, date-filtered)
- Filter out IsDeleted=1
- Return: ServiceID, codes, names, class, priority, RequiresLocation, RequiresQualityReview, IsActive, ActiveRoutingRuleID, TargetDSDID, QueueDistributorID, EffectiveFrom/To

## Acceptance Criteria
- View returns complete service definitions with active routing targets."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Create [Tickets].[ServiceDL] data layer procedure" --body "**Spec:** 02 - Service Catalogue
**Category:** DB-DL-View
**Dependencies:** V_ServiceFullDefinition, all Spec-02 tables

## Actions
- GET_SERVICE_CATALOGUE: list active services filtered by IdaraID
- GET_SERVICE_DETAIL: single service by ServiceID
- GET_ROUTING_RULES: routing history for a service
- GET_SLA_POLICIES: active policies per service
- GET_SLA_POLICY_FOR_SERVICE_PRIORITY: single lookup
- GET_SERVICE_SUGGESTIONS: filtered by IdaraID and ApprovalStatus

## Acceptance Criteria
- All read actions return correct data."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-02] Test service catalogue foundation flows" --body "**Spec:** 02 - Service Catalogue
**Category:** Test
**Dependencies:** All Spec-02 objects

## Tests
1. Create service via ServiceSP INSERT_SERVICE.
2. Add routing rule. Verify CatalogRoutingChangeLog entry.
3. Replace routing rule. Verify old closed, new active.
4. Add SLA policies for multiple priorities.
5. Query via ServiceDL and V_ServiceFullDefinition.
6. Create and approve a suggestion.
7. Verify all dbo.AuditLog entries.

## Acceptance Criteria
- All CRUD and routing operations work. Historical changes preserved."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-02] Build service catalogue admin list screen" --body "**Spec:** 02 - Service Catalogue
**Category:** UI
**Dependencies:** ServiceDL GET_SERVICE_CATALOGUE

## Requirements
- Data grid: ServiceCode, ServiceNameEN, ServiceNameAR, TicketClassName, DefaultPriority, IsActive, RoutingTarget
- Search/filter by name and IdaraID
- Action buttons: Edit, Deactivate, View Routing Rules
- Pagination

## Acceptance Criteria
- All active services listed. Filters work. Actions navigate correctly."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-02] Build service create/edit screen" --body "**Spec:** 02 - Service Catalogue
**Category:** UI
**Dependencies:** ServiceSP INSERT_SERVICE/UPDATE_SERVICE

## Form Fields
ServiceCode, ServiceNameAR, ServiceNameEN, DescriptionAR, DescriptionEN, TicketClass (dropdown), DefaultPriority (dropdown), RequiresLocation (checkbox), RequiresQualityReview (checkbox)

## Acceptance Criteria
- New services created. Existing services edited. Validation works."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-02] Build routing rule maintenance screen" --body "**Spec:** 02 - Service Catalogue
**Category:** UI
**Dependencies:** ServiceDL GET_ROUTING_RULES, ServiceSP routing actions

## Requirements
- Table: TargetDSDID, EffectiveFrom, EffectiveTo, IsActive, ChangeReason
- Add New Rule: form with TargetDSDID (org picker), EffectiveFrom, ChangeReason
- Close Rule button
- TargetDSDID mandatory

## Acceptance Criteria
- Rules displayed historically. New rules auto-close old ones."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-02] Build SLA policy maintenance and suggestion review screens" --body "**Spec:** 02 - Service Catalogue
**Category:** UI
**Dependencies:** ServiceSP UPSERT_SLA_POLICY, suggestion actions, ServiceDL

## SLA Policy Screen
- Grid per priority: FirstResponse, Assignment, OperationalCompletion, FinalClosure minutes
- Edit inline or via modal calling UPSERT_SLA_POLICY

## Suggestion Review Screen
- List pending suggestions: ProposedServiceName, Description, SourceTicket, Date
- Approve button (calls APPROVE_SERVICE_SUGGESTION)
- Reject button with reason modal (calls REJECT_SERVICE_SUGGESTION)

## Acceptance Criteria
- SLA targets viewable and updatable. Suggestions approvable/rejectable with audit."

# ============================================================================
# SPEC 03: Core Ticket Backbone (11 tasks)
# ============================================================================
echo ">>> SPEC 03: Core Ticket Backbone"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Create [Tickets].[Ticket] transaction table" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-Structure
**Dependencies:** Spec-01 lookups, Spec-02 Service

## Key Columns
- TicketID BIGINT IDENTITY PK, TicketNo NVARCHAR(50) UNIQUE
- IdaraID_FK BIGINT NOT NULL
- ParentTicketID_FK BIGINT FK->self NULL, RootTicketID_FK BIGINT FK->self NULL
- ServiceID_FK BIGINT FK->Service NULL (for Other tickets)
- TicketClassID_FK INT FK->TicketClass, RequesterTypeID_FK INT FK->RequesterType
- RequesterUserID_FK BIGINT NULL, RequesterResidentID_FK BIGINT NULL
- Title NVARCHAR(500) NOT NULL, Description NVARCHAR(4000)
- SuggestedPriorityID_FK INT FK->Priority, EffectivePriorityID_FK INT FK->Priority
- TicketStatusID_FK INT FK->TicketStatus NOT NULL
- CurrentDSDID_FK BIGINT, CurrentQueueDistributorID_FK BIGINT, AssignedUserID_FK BIGINT
- LocationBuilding, LocationFloor, LocationRoom, LocationNotes
- IsOtherService BIT DEFAULT 0, IsParentBlocked BIT DEFAULT 0, RequiresQualityReview BIT DEFAULT 0
- OperationalResolvedDate/By, FinalClosedDate/By
- Standard audit columns
- CHECK CK_Ticket_RequesterExclusivity: NOT(RequesterUserID IS NOT NULL AND RequesterResidentID IS NOT NULL) -- BR-01

## Acceptance Criteria
- Table with all FKs and requester exclusivity CHECK constraint."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Create [Tickets].[TicketHistory] history table" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-Structure
**Dependencies:** Ticket table, TicketStatus lookup

## Columns
- TicketHistoryID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket NOT NULL, IdaraID_FK BIGINT NOT NULL
- ActionTypeCode NVARCHAR(100) NOT NULL
- OldStatusID_FK INT FK->TicketStatus NULL, NewStatusID_FK INT FK->TicketStatus NULL
- OldDSDID_FK BIGINT NULL, NewDSDID_FK BIGINT NULL
- OldAssignedUserID_FK BIGINT NULL, NewAssignedUserID_FK BIGINT NULL
- PerformedByUserID_FK BIGINT NOT NULL
- Notes NVARCHAR(4000) NULL
- ActionDate DATETIME2(7) DEFAULT SYSUTCDATETIME()

## Rules
- IMMUTABLE: no UPDATE or DELETE ever. Insert-only.

## Acceptance Criteria
- Table exists. No soft delete. Records are permanent audit trail."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Implement INSERT_TICKET action in [Tickets].[TicketSP]" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-SP
**Dependencies:** Ticket, TicketHistory tables, ServiceRoutingRule

## Logic
1. Validate BR-01: RequesterUserID and RequesterResidentID not both non-null.
2. Validate BR-02: if IsOtherService=0, ServiceID required.
3. Generate TicketNo: TKT-000001 pattern.
4. If known service: resolve routing from active ServiceRoutingRule (TargetDSDID, QueueDistributorID).
5. Resolve EffectivePriority from service default if not provided.
6. Resolve RequiresQualityReview from Service.
7. Get NEW status ID.
8. INSERT Ticket. UPDATE RootTicketID_FK = self.
9. INSERT TicketHistory: TICKET_CREATED.
10. INSERT dbo.AuditLog JSON entry.
11. Return TicketID, TicketNo.

## Acceptance Criteria
- Known service tickets auto-routed. Other tickets work without ServiceID. History and audit logged. Root=self."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Implement requester type validation and root ticket initialization" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-SP
**Dependencies:** INSERT_TICKET action

## Requester Validation (BR-01)
- IF both RequesterUserID and RequesterResidentID non-null: THROW 50010
- Also enforced by table CHECK constraint CK_Ticket_RequesterExclusivity

## Root Ticket Init
- Top-level tickets: RootTicketID = self (UPDATE after INSERT)
- Child tickets: inherit parent's RootTicketID_FK

## Acceptance Criteria
- Both IDs set = error. Root set correctly for top-level and child tickets."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Create [Tickets].[V_TicketFullDetails] and [V_TicketLastAction] views" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-DL-View
**Dependencies:** Ticket, TicketHistory, all lookup tables

## V_TicketFullDetails
JOIN Ticket -> Service, TicketClass, RequesterType, Priority (suggested+effective), TicketStatus
Returns all core ticket fields with resolved names.

## V_TicketLastAction
Subquery MAX(TicketHistoryID) per TicketID_FK, join back for latest action details.

## Acceptance Criteria
- V_TicketFullDetails returns complete details. V_TicketLastAction returns one row per ticket."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Create [Tickets].[TicketDL] - basic detail and list actions" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** DB-DL-View
**Dependencies:** Views, Ticket, TicketHistory

## Actions
- GET_TICKET_DETAILS: query V_TicketFullDetails by TicketID
- GET_TICKETS_BY_STATUS: filter by IdaraID and StatusCode
- GET_TICKET_HISTORY: join TicketHistory+TicketStatus, ordered by ActionDate DESC
- GET_LAST_ACTION: query V_TicketLastAction

## Acceptance Criteria
- All read actions return correct data."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-03] Test core ticket creation flow" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** Test
**Dependencies:** All Spec-03 objects

## Tests
1. Create ticket for resident with known service — verify auto-routing.
2. Create ticket for internal user — verify requester type.
3. Create Other ticket without ServiceID — verify IsOtherService=1.
4. Attempt both RequesterIDs set — verify rejection (BR-01).
5. Verify TicketHistory has TICKET_CREATED.
6. Verify RootTicketID = self.
7. Query through V_TicketFullDetails and TicketDL.
8. Verify dbo.AuditLog.

## Acceptance Criteria
- All scenarios pass. Business rules enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-03] Build ticket creation screen" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** UI
**Dependencies:** TicketSP INSERT_TICKET, ServiceDL

## Form
- RequesterType (radio), Service (dropdown + Other option), Title, Description
- SuggestedPriority (dropdown), Location fields (conditional on RequiresLocation)
- If Other: hide service dropdown, show free-text

## Acceptance Criteria
- Both requester types work. Other flow works. TicketNo displayed on success."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-03] Build ticket details screen" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** UI
**Dependencies:** TicketDL GET_TICKET_DETAILS, GET_TICKET_HISTORY

## Display
- TicketNo, Title, Description, Status badge, Priority badge, Service, Requester info
- Current queue/DSD, Assigned user, Location, Dates, Flags
- Action history timeline (chronological)
- Action buttons based on status (placeholders for later specs)

## Acceptance Criteria
- All ticket data accurate. History timeline chronological."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-03] Build basic ticket list screen" --body "**Spec:** 03 - Core Ticket Backbone
**Category:** UI
**Dependencies:** TicketDL GET_TICKETS_BY_STATUS

## Display
- Data grid: TicketNo, Title, ServiceName, Status, Priority, CurrentDSD, AssignedUser, CreatedDate
- Filter dropdowns: Status, Priority, IdaraID
- Search by TicketNo or Title
- Pagination, sorting
- Row click -> ticket details

## Acceptance Criteria
- Tickets listed correctly. Filters work. Click navigates."

# ============================================================================
# SPEC 04: Assignment and Work Start (10 tasks)
# ============================================================================
echo ">>> SPEC 04: Assignment and Work Start"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Implement ASSIGN_TICKET in TicketSP" --body "**Spec:** 04 - Assignment and Work Start
**Category:** DB-SP
**Dependencies:** Spec-03 TicketSP, dbo.UserDistributor

## Logic
1. BR-06: validate AssignedUserID exists in dbo.UserDistributor for CurrentQueueDistributorID with IsActive=1. If not, THROW 50020.
2. Set status=ASSIGNED, AssignedUserID_FK.
3. TicketHistory: TICKET_ASSIGNED (old/new status, old/new user).
4. Audit log.

## Acceptance Criteria
- Only eligible users assigned. Status=ASSIGNED. History logged."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Implement MOVE_TO_IN_PROGRESS in TicketSP" --body "**Spec:** 04 - Assignment and Work Start
**Category:** DB-SP
**Dependencies:** ASSIGN_TICKET action

## Logic
1. Set status=IN_PROGRESS.
2. TicketHistory: MOVED_TO_IN_PROGRESS.
3. Audit log.

## Acceptance Criteria
- Status changes. History entry created."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Implement REJECT_TO_SUPERVISOR in TicketSP" --body "**Spec:** 04 - Assignment and Work Start
**Category:** DB-SP
**Dependencies:** Spec-03 TicketSP

## Logic (BR-07: executor rejects to supervisor, never directly to arbitration)
1. Set status=REJECTED, AssignedUserID_FK=NULL.
2. TicketHistory: REJECTED_TO_SUPERVISOR (log old assigned user).
3. Audit log.

## Acceptance Criteria
- Ticket unassigned. Status=REJECTED. No direct arbitration path."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Implement assignment eligibility validation" --body "**Spec:** 04 - Assignment and Work Start
**Category:** DB-SP
**Dependencies:** dbo.UserDistributor

## Logic
- Before assign: SELECT 1 FROM dbo.UserDistributor WHERE UserID=@AssignedUserID AND DistributorID=@CurrentQueueDistributorID AND IsActive=1
- If no rows: THROW 50020

## Tests
- Attempt ineligible user: confirm rejection.
- Assign eligible user: confirm success.

## Acceptance Criteria
- BR-06 enforced. Ineligible users rejected with error 50020."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Extend TicketDL for queue inbox reads" --body "**Spec:** 04 - Assignment and Work Start
**Category:** DB-DL-View
**Dependencies:** V_TicketInboxByScope (Spec-12 view, or inline query)

## Actions
- GET_INBOX_BY_SCOPE: open tickets filtered by IdaraID, CurrentDSDID, QueueDistributorID
- GET_INBOX_BY_ASSIGNEE: filtered by AssignedUserID_FK

## Acceptance Criteria
- Inbox returns correct tickets for organizational scope."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-04] Test assignment and work start flow" --body "**Spec:** 04 - Assignment and Work Start
**Category:** Test
**Dependencies:** All Spec-04 actions

## Tests
1. Create ticket, verify queue arrival.
2. Assign eligible user -> status=ASSIGNED.
3. Assign ineligible user -> rejection.
4. Move to IN_PROGRESS.
5. Reject to supervisor -> status=REJECTED, unassigned.
6. Re-assign, re-start -> full cycle.
7. Verify all TicketHistory and AuditLog.

## Acceptance Criteria
- Full cycle works. Eligibility enforced. History complete."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-04] Build scope-based queue inbox screen" --body "**Spec:** 04 - Assignment and Work Start
**Category:** UI
**Dependencies:** TicketDL GET_INBOX_BY_SCOPE

## Display
- Grid: TicketNo, Title, ServiceName, Priority, Status, AssignedUser, CreatedDate
- Color-code by priority. Unassigned tickets prominent.
- Assign action button per row.
- Filter by status within inbox.

## Acceptance Criteria
- Users see only in-scope tickets. Unassigned highlighted."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-04] Build assignment action UI" --body "**Spec:** 04 - Assignment and Work Start
**Category:** UI
**Dependencies:** TicketSP ASSIGN_TICKET, UserDistributor

## Flow
- Assign button -> modal with eligible users (from UserDistributor for scope)
- Select assignee, confirm -> call ASSIGN_TICKET
- Success/error feedback, refresh.

## Acceptance Criteria
- Only eligible users shown. Assignment updates ticket. UI refreshes."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-04] Build start work action UI" --body "**Spec:** 04 - Assignment and Work Start
**Category:** UI
**Dependencies:** TicketSP MOVE_TO_IN_PROGRESS

## Flow
- Start Work button visible when status=ASSIGNED and viewer is assigned user.
- Click -> call MOVE_TO_IN_PROGRESS. Refresh status badge.

## Acceptance Criteria
- Button only for assigned user. Status updates to IN_PROGRESS."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-04] Build reject-to-supervisor action UI" --body "**Spec:** 04 - Assignment and Work Start
**Category:** UI
**Dependencies:** TicketSP REJECT_TO_SUPERVISOR

## Flow
- Reject button when status=ASSIGNED/IN_PROGRESS and viewer is assigned user.
- Modal: require rejection notes.
- Call REJECT_TO_SUPERVISOR. Ticket unassigned, status=REJECTED.

## Acceptance Criteria
- Rejection requires notes. No direct-to-arbitration path from executor (BR-07)."

# ============================================================================
# SPEC 05: Clarification Flow (8 tasks)
# ============================================================================
echo ">>> SPEC 05: Clarification Flow"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-05] Create [Tickets].[ClarificationRequest] transaction table" --body "**Spec:** 05 - Clarification Flow
**Category:** DB-Structure
**Dependencies:** Spec-03 Ticket table, Spec-01 ClarificationReason

## Columns
- ClarificationRequestID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket, IdaraID_FK BIGINT
- RequestedByUserID_FK BIGINT, RequestedFromUserID_FK BIGINT NULL, RequestedFromDSDID_FK BIGINT NULL
- ClarificationReasonID_FK INT FK->ClarificationReason
- RequestNotes NVARCHAR(4000), ResponseNotes NVARCHAR(4000)
- RequestDate DATETIME2 DEFAULT SYSUTCDATETIME(), ResponseDate DATETIME2 NULL
- RespondedByUserID_FK BIGINT NULL
- Status NVARCHAR(50) DEFAULT 'OPEN'
- Standard audit columns

## Acceptance Criteria
- Table exists. Separate from ArbitrationCase (BR-09)."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-05] Implement [Tickets].[ClarificationSP] - all actions" --body "**Spec:** 05 - Clarification Flow
**Category:** DB-SP
**Dependencies:** ClarificationRequest table

## Actions
- **OPEN_CLARIFICATION_REQUEST:** insert ClarificationRequest, ticket status->PENDING_CLARIFICATION, TicketHistory(CLARIFICATION_OPENED), audit.
- **RESPOND_TO_CLARIFICATION:** set ResponseNotes, ResponseDate, Status=RESPONDED. TicketHistory(CLARIFICATION_RESPONDED), audit.
- **CLOSE_CLARIFICATION_REQUEST:** Status=CLOSED, ticket->IN_PROGRESS. TicketHistory(CLARIFICATION_CLOSED), audit.

## Acceptance Criteria
- Full lifecycle works independently of arbitration (BR-09). Status transitions correct."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-05] Link blocking clarification to pause sessions" --body "**Spec:** 05 - Clarification Flow
**Category:** DB-SP
**Dependencies:** TicketPauseSession (Spec-08), ClarificationSP

## Logic
- On OPEN: create TicketPauseSession with PauseReason=CLARIFICATION, RelatedClarificationRequestID_FK set.
- On CLOSE: end pause session (PauseEndDate=now).
- Note: may be deferred until Spec-08 table exists.

## Acceptance Criteria
- Blocking clarification creates/closes pause session."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-05] Test clarification flow" --body "**Spec:** 05 - Clarification Flow
**Category:** Test

## Tests
1. Create ticket, assign.
2. Open clarification -> status=PENDING_CLARIFICATION, history logged.
3. Respond -> ClarificationRequest status=RESPONDED.
4. Close -> ticket returns to IN_PROGRESS.
5. Verify separate from arbitration (BR-09).
6. Check audit log.

## Acceptance Criteria
- Full cycle passes. No arbitration mixing."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-05] Build clarification request form" --body "**Spec:** 05 - Clarification Flow
**Category:** UI
**Dependencies:** ClarificationSP OPEN_CLARIFICATION_REQUEST

## Flow
- Button on ticket details when ASSIGNED/IN_PROGRESS.
- Modal: ClarificationReason dropdown, RequestNotes textarea, optional target user/DSD.
- Call OPEN_CLARIFICATION_REQUEST. Refresh to PENDING_CLARIFICATION.

## Acceptance Criteria
- Reason required. Notes captured. Status updates."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-05] Build clarification response form" --body "**Spec:** 05 - Clarification Flow
**Category:** UI
**Dependencies:** ClarificationSP RESPOND_TO_CLARIFICATION

## Flow
- Show open clarification requests on ticket details.
- Respond button: ResponseNotes textarea.
- Call RESPOND_TO_CLARIFICATION.

## Acceptance Criteria
- Response captured. Status updated."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-05] Show clarification state in ticket details" --body "**Spec:** 05 - Clarification Flow
**Category:** UI

## Display
- Active requests: prominent with status badge (OPEN/RESPONDED/CLOSED)
- Historical (closed): collapsible section
- Show reason, notes, response, dates.

## Acceptance Criteria
- Active clarifications visible. History accessible."

# ============================================================================
# SPEC 06: Arbitration Flow (8 tasks)
# ============================================================================
echo ">>> SPEC 06: Arbitration Flow"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-06] Create [Tickets].[ArbitrationCase] transaction table" --body "**Spec:** 06 - Arbitration Flow
**Category:** DB-Structure
**Dependencies:** Spec-03 Ticket, Spec-01 ArbitrationReason

## Columns
- ArbitrationCaseID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket, IdaraID_FK BIGINT
- RaisedByUserID_FK BIGINT, RaisedFromDSDID_FK BIGINT
- ArbitrationReasonID_FK INT FK->ArbitrationReason
- ArbitratorDistributorID_FK BIGINT NULL
- Status NVARCHAR(50) DEFAULT 'OPEN'
- DecisionType NVARCHAR(50) NULL, DecisionTargetDSDID_FK BIGINT NULL
- DecisionNotes NVARCHAR(2000), DecisionDate DATETIME2, DecisionBy BIGINT
- Standard audit columns

## Acceptance Criteria
- Table exists. Tracks decision type (REDIRECT/OVERRULE)."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-06] Implement [Tickets].[ArbitrationSP] - all actions" --body "**Spec:** 06 - Arbitration Flow
**Category:** DB-SP
**Dependencies:** ArbitrationCase table

## Actions
- **OPEN_ARBITRATION_CASE:** insert case, ticket->IN_ARBITRATION, history(ARBITRATION_OPENED), audit.
- **DECIDE_REDIRECT:** Status=DECIDED, DecisionType=REDIRECT, update ticket CurrentDSDID to new target, ticket->OPEN, unassign user, history(ARBITRATION_REDIRECT with old/new DSD), audit.
- **DECIDE_OVERRULE:** Status=DECIDED, DecisionType=OVERRULE, ticket->OPEN (same DSD), history(ARBITRATION_OVERRULED), audit.
- **CANCEL_ARBITRATION_CASE:** Status=CANCELLED, audit.

## Acceptance Criteria
- Redirect changes routing. Overrule keeps scope. All logged."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-06] Create [Tickets].[ArbitrationDL] data layer procedure" --body "**Spec:** 06 - Arbitration Flow
**Category:** DB-DL-View
**Dependencies:** ArbitrationCase, V_TicketArbitrationInbox

## Actions
- GET_OPEN_DISPUTES: open cases filtered by IdaraID, ArbitratorDistributorID
- GET_DISPUTE_HISTORY: case history filtered by TicketID, IdaraID, Status
- GET_ROUTING_CORRECTION_CANDIDATES: decided REDIRECT cases for non-Other tickets

## Acceptance Criteria
- All read actions return correct data."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-06] Test arbitration flow" --body "**Spec:** 06 - Arbitration Flow
**Category:** Test

## Tests
1. Create+assign ticket. Open arbitration -> IN_ARBITRATION.
2. REDIRECT to new DSD -> CurrentDSDID changed, OPEN, unassigned.
3. OVERRULE -> DSD unchanged, OPEN.
4. CANCEL case.
5. Verify all history and audit entries.
6. Query through ArbitrationDL.
7. Verify disputes separate from clarifications (BR-08/BR-09).

## Acceptance Criteria
- Full lifecycle works. Separate from clarifications."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-06] Build arbitration inbox screen" --body "**Spec:** 06 - Arbitration Flow
**Category:** UI
**Dependencies:** ArbitrationDL GET_OPEN_DISPUTES

## Display
- Grid: TicketNo, Title, ArbitrationReason, RaisedFrom, RaisedBy, DateOpened
- Filter by reason and IdaraID. Click -> decision screen.

## Acceptance Criteria
- Arbitrators see only their cases."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-06] Build arbitration decision screen" --body "**Spec:** 06 - Arbitration Flow
**Category:** UI
**Dependencies:** ArbitrationSP all actions

## Flow
- Show dispute info: reason, who raised, from which DSD.
- Decisions: Redirect (DSD picker), Overrule, Cancel. Notes required.
- Call appropriate ArbitrationSP action. Refresh.

## Acceptance Criteria
- All three decisions work. Routing updates for redirects."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-06] Show arbitration status in ticket details" --body "**Spec:** 06 - Arbitration Flow
**Category:** UI

## Display
- Active (OPEN) case: prominent section with case details.
- Historical (DECIDED/CANCELLED): collapsible list.

## Acceptance Criteria
- Arbitration context visible. Active vs historical distinguished."

# ============================================================================
# SPEC 07: Parent-Child Ticketing (6 tasks)
# ============================================================================
echo ">>> SPEC 07: Parent-Child Ticketing"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-07] Implement CREATE_CHILD_TICKET in TicketSP" --body "**Spec:** 07 - Parent-Child Ticketing
**Category:** DB-SP
**Dependencies:** Spec-03 TicketSP, Ticket table

## Logic
1. Receive @ParentTicketID. Resolve RootTicketID from parent.
2. Generate TicketNo. INSERT child with ParentTicketID_FK and RootTicketID_FK.
3. TicketHistory on child: CHILD_TICKET_CREATED.
4. TicketHistory on parent: CHILD_TICKET_LINKED.
5. Audit. Return TicketID, TicketNo.
6. BR-10: one parent only (FK design).

## Acceptance Criteria
- Child created with correct parent/root. Both get history entries."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-07] Implement parent/root inheritance logic and extend TicketDL for tree" --body "**Spec:** 07 - Parent-Child Ticketing
**Category:** DB-SP + DB-DL-View
**Dependencies:** CREATE_CHILD_TICKET

## Root Inheritance
- Parent has RootTicketID -> child inherits it.
- 3-level test: Root->Child->Grandchild all share same RootTicketID.

## TicketDL GET_TICKET_TREE
- Accept TicketID or RootTicketID.
- Return all tickets WHERE RootTicketID_FK = root, ordered by TicketID.

## Acceptance Criteria
- Multi-level tree works. Tree query returns entire hierarchy."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-07] Test parent-child ticket flow" --body "**Spec:** 07 - Parent-Child Ticketing
**Category:** Test

## Tests
1. Create parent (Root=self). Create child (correct Parent+Root).
2. Create grandchild (Root inherited from original root).
3. Load tree via GET_TICKET_TREE -> all 3 returned.
4. Verify history on parent and child.
5. Verify BR-10: one parent only.

## Acceptance Criteria
- Multi-level tree correct. Root inheritance verified."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-07] Build child ticket creation UI" --body "**Spec:** 07 - Parent-Child Ticketing
**Category:** UI
**Dependencies:** TicketSP CREATE_CHILD_TICKET

## Flow
- Button on ticket details when IN_PROGRESS/ASSIGNED.
- Form: Service/Other, Title, Description, Priority, Target DSD.
- Call CREATE_CHILD_TICKET. Show new TicketNo.

## Acceptance Criteria
- Child linked to parent. New ticket navigable."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-07] Build parent-child tree visualization" --body "**Spec:** 07 - Parent-Child Ticketing
**Category:** UI
**Dependencies:** TicketDL GET_TICKET_TREE

## Display
- Tree hierarchy: each node with TicketNo, Title, Status badge.
- Current ticket highlighted. Clickable nodes navigate.
- Parent link at top of details page.

## Acceptance Criteria
- Tree renders multi-level. Navigation works."

# ============================================================================
# SPEC 08: Blocking and Pause Sessions (8 tasks)
# ============================================================================
echo ">>> SPEC 08: Blocking and Pause Sessions"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-08] Create [Tickets].[TicketPauseSession] transaction table" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** DB-Structure
**Dependencies:** Spec-03 Ticket, Spec-06 ArbitrationCase, Spec-05 ClarificationRequest, Spec-01 PauseReason

## Columns
- TicketPauseSessionID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket, IdaraID_FK BIGINT
- PauseReasonID_FK INT FK->PauseReason
- RelatedChildTicketID_FK BIGINT FK->Ticket NULL
- RelatedArbitrationCaseID_FK BIGINT FK->ArbitrationCase NULL
- RelatedClarificationRequestID_FK BIGINT FK->ClarificationRequest NULL
- PauseStartDate DATETIME2 DEFAULT SYSUTCDATETIME(), PauseEndDate DATETIME2 NULL
- ShouldPauseSLA BIT DEFAULT 1
- Notes NVARCHAR(2000), Standard audit columns

## Acceptance Criteria
- Table exists with optional related references."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-08] Implement PAUSE_TICKET in TicketSP" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** DB-SP

## Logic
1. Set status=ON_HOLD. If child dependency: IsParentBlocked=1.
2. INSERT TicketPauseSession with reason and related references.
3. TicketHistory: TICKET_PAUSED. Audit.

## Acceptance Criteria
- Ticket paused with reason. Pause session recorded."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-08] Implement RESUME_TICKET in TicketSP" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** DB-SP

## Logic
1. Close open pause sessions: PauseEndDate=now.
2. Set status=IN_PROGRESS, IsParentBlocked=0.
3. TicketHistory: TICKET_RESUMED. Audit.

## Acceptance Criteria
- All pauses closed. Status=IN_PROGRESS. IsParentBlocked cleared."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-08] Implement parent blocking rules" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** DB-SP
**Dependencies:** Spec-07 child tickets

## Logic
- On child creation with dependency: auto PAUSE_TICKET on parent (CHILD_DEPENDENCY).
- On child CLOSED/RESOLVED: if no more open blocking children, auto RESUME_TICKET on parent.
- BR-12: parent cannot be finally closed while open children exist.

## Acceptance Criteria
- Parent auto-paused/resumed. BR-12 enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-08] Test pause and resume flow" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** Test

## Tests
1. Pause with WAREHOUSE_DELAY -> ON_HOLD, session created.
2. Resume -> IN_PROGRESS, PauseEndDate set.
3. Child dependency: parent paused, IsParentBlocked=1.
4. Close child: parent resumed, IsParentBlocked=0.
5. Attempt close parent with open child -> rejection (BR-12).
6. Verify history and audit.

## Acceptance Criteria
- Manual and child-blocking pause/resume work. BR-12 enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-08] Build pause and resume action UI" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** UI

## Pause
- Button when IN_PROGRESS/ASSIGNED. Modal: PauseReason dropdown, Notes.
- Call PAUSE_TICKET. Refresh to ON_HOLD.

## Resume
- Button when ON_HOLD. Confirm (optional notes).
- Call RESUME_TICKET. Refresh to IN_PROGRESS.

## Acceptance Criteria
- Pause reason required. Resume closes sessions."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-08] Display active blocking reason in ticket details" --body "**Spec:** 08 - Blocking and Pause Sessions
**Category:** UI

## Display
- Open TicketPauseSession: PauseReason, Notes, StartDate, related links.
- If IsParentBlocked=1: prominent banner with link to blocking child.

## Acceptance Criteria
- Blocking reason clearly visible. Related items clickable."

# ============================================================================
# SPEC 09: SLA Engine (9 tasks)
# ============================================================================
echo ">>> SPEC 09: SLA Engine"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Create [Tickets].[TicketSLA] transaction table" --body "**Spec:** 09 - SLA Engine
**Category:** DB-Structure
**Dependencies:** Spec-03 Ticket

## Columns
- TicketSLAID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket, IdaraID_FK BIGINT
- SLATypeCode NVARCHAR(50) NOT NULL (FIRST_RESPONSE, ASSIGNMENT, OPERATIONAL_COMPLETION, FINAL_CLOSURE)
- TargetMinutes INT NOT NULL, ElapsedMinutes INT DEFAULT 0, RemainingMinutes INT DEFAULT 0
- IsBreached BIT DEFAULT 0
- StartDate DATETIME2, StopDate DATETIME2, CompletionDate DATETIME2, LastCalculatedDate DATETIME2
- Standard audit columns
- UNIQUE(TicketID_FK, SLATypeCode)

## Acceptance Criteria
- One SLA record per type per ticket enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Create [Tickets].[TicketSLAHistory] history table" --body "**Spec:** 09 - SLA Engine
**Category:** DB-Structure
**Dependencies:** TicketSLA table

## Columns
- TicketSLAHistoryID BIGINT IDENTITY PK
- TicketSLAID_FK BIGINT FK->TicketSLA, IdaraID_FK BIGINT
- SLAEventTypeCode NVARCHAR(100) (INITIALIZED, PAUSED, RESUMED, BREACHED, COMPLETED)
- EventDate DATETIME2 DEFAULT SYSUTCDATETIME()
- Notes NVARCHAR(2000), PerformedByUserID_FK BIGINT NULL
- IMMUTABLE: insert-only.

## Acceptance Criteria
- Table exists. Events are insert-only."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Implement [Tickets].[TicketSLASP] - all actions" --body "**Spec:** 09 - SLA Engine
**Category:** DB-SP
**Dependencies:** TicketSLA, TicketSLAHistory tables

## Actions
- **INITIALIZE_SLA:** insert TicketSLA with TargetMinutes, RemainingMinutes=Target, StartDate=now. History: INITIALIZED.
- **PAUSE_SLA:** calculate elapsed, set StopDate. History: PAUSED.
- **RESUME_SLA:** reset StartDate=now, clear StopDate. History: RESUMED.
- **CHECK_BREACH:** calculate real-time elapsed. If >= target and not breached: set IsBreached=1. History: BREACHED.
- **COMPLETE_SLA:** set CompletionDate, StopDate. History: COMPLETED.

## Acceptance Criteria
- Full SLA lifecycle. History for every event."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Implement SLA initialization from ServiceSLAPolicy" --body "**Spec:** 09 - SLA Engine
**Category:** DB-SP
**Dependencies:** TicketSLASP, ServiceSLAPolicy

## Logic
- On INSERT_TICKET: look up ServiceSLAPolicy for ServiceID + EffectivePriorityID.
- For each non-null SLA target: call INITIALIZE_SLA.
- Creates up to 4 SLA clocks per ticket.

## Acceptance Criteria
- SLA clocks auto-created. Targets match policy."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Implement SLA pause/resume integration with ticket pausing" --body "**Spec:** 09 - SLA Engine
**Category:** DB-SP
**Dependencies:** TicketSLASP, TicketSP PAUSE/RESUME

## Logic (BR-15)
- On PAUSE_TICKET (ShouldPauseSLA=1): for each active TicketSLA -> PAUSE_SLA.
- On RESUME_TICKET: for each stopped TicketSLA -> RESUME_SLA.

## Acceptance Criteria
- SLA pauses during blocking. Resumes correctly. Elapsed preserved."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Create [Tickets].[V_TicketCurrentSLA] view" --body "**Spec:** 09 - SLA Engine
**Category:** DB-DL-View

## Logic
- JOIN TicketSLA -> Ticket. Return SLA state with ticket context.

## Acceptance Criteria
- View returns SLA data joinable with tickets."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-09] Test SLA engine" --body "**Spec:** 09 - SLA Engine
**Category:** Test

## Tests
1. Create service with SLA policy. Create ticket -> verify 4 SLA clocks.
2. Pause ticket -> SLA stopped. Check elapsed.
3. Resume -> SLA restarted.
4. Simulate breach (low target) -> IsBreached=1, BREACHED history.
5. Resolve -> OPERATIONAL_COMPLETION completed.
6. Close -> FINAL_CLOSURE completed.
7. Query V_TicketCurrentSLA.

## Acceptance Criteria
- Full lifecycle. Pause/resume preserves elapsed. Breaches detected."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-09] Show SLA timers and breach markers in ticket UI" --body "**Spec:** 09 - SLA Engine
**Category:** UI

## Display
- Per SLA type: progress bar with target, elapsed, remaining.
- Colors: green (less than 75%), yellow (75-99%), red (breached).
- Breach badge if IsBreached=1.
- Completion date if completed.

## Acceptance Criteria
- SLA timers accurate and visual. Breaches prominently shown."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-09] Show SLA state in queue list screens" --body "**Spec:** 09 - SLA Engine
**Category:** UI

## Display
- In inbox/list grids: SLA column with worst-state icon (green/yellow/red).
- Breach icon if any SLA breached.
- Sort option by SLA urgency.

## Acceptance Criteria
- SLA state visible in lists. Breach tickets easily identifiable."

# ============================================================================
# SPEC 10: Quality Review and Final Closure (10 tasks)
# ============================================================================
echo ">>> SPEC 10: Quality Review and Final Closure"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Create [Tickets].[QualityReview] transaction table" --body "**Spec:** 10 - Quality Review
**Category:** DB-Structure
**Dependencies:** Spec-03 Ticket, Spec-01 QualityReviewResult

## Columns
- QualityReviewID BIGINT IDENTITY PK
- TicketID_FK BIGINT FK->Ticket, IdaraID_FK BIGINT
- ReviewerUserID_FK BIGINT NULL
- ReviewScope NVARCHAR(500) NULL
- QualityReviewResultID_FK INT FK->QualityReviewResult NULL
- ReviewNotes NVARCHAR(4000), ReviewDate DATETIME2 NULL
- ReturnToUserID_FK BIGINT NULL
- IsFinalized BIT DEFAULT 0
- Standard audit columns

## Acceptance Criteria
- Table exists. IsFinalized defaults to 0. Result nullable until decision."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Implement RESOLVE_OPERATIONALLY in TicketSP" --body "**Spec:** 10 - Quality Review
**Category:** DB-SP
**Dependencies:** Spec-03 TicketSP

## Logic
1. BR-12: check no open child tickets. If found THROW 50030.
2. Set status=RESOLVED, OperationalResolvedDate=now, OperationalResolvedBy.
3. TicketHistory: RESOLVED_OPERATIONALLY. Audit.

## Acceptance Criteria
- Resolution blocked if open children exist. Status=RESOLVED. Dates set."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Implement [Tickets].[QualityReviewSP] - all actions" --body "**Spec:** 10 - Quality Review
**Category:** DB-SP
**Dependencies:** QualityReview table, QualityReviewResult lookup

## Actions
- **OPEN_QUALITY_REVIEW:** BR-14 (ticket must be RESOLVED/PENDING_QA or THROW 50040). Insert QualityReview, ticket->PENDING_QA. History(QUALITY_REVIEW_OPENED). Audit.
- **APPROVE_FINAL_CLOSURE:** result=APPROVED, IsFinalized=1. Ticket->CLOSED, FinalClosedDate set. History(FINAL_CLOSURE_APPROVED). Audit.
- **RETURN_FOR_CORRECTION:** result=RETURNED, IsFinalized=1. Ticket->IN_PROGRESS, clear OperationalResolvedDate, optionally re-assign ReturnToUserID. History(RETURNED_FOR_CORRECTION). Audit.
- **REJECT_CLOSURE:** result=REJECTED, IsFinalized=1. Ticket->REOPENED, clear resolved dates. History(CLOSURE_REJECTED). Audit.

## Business Rules
- BR-13: Two-stage closure (operational then final)
- BR-14: QR only after resolution

## Acceptance Criteria
- All 3 outcomes work. Two-stage closure enforced."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Implement CLOSE_TICKET and REOPEN_TICKET in TicketSP" --body "**Spec:** 10 - Quality Review
**Category:** DB-SP

## CLOSE_TICKET (direct path for non-QR tickets)
- Set status=CLOSED, FinalClosedDate/By. History(TICKET_CLOSED). Audit.

## REOPEN_TICKET
- Set status=REOPENED, clear FinalClosedDate/By and OperationalResolvedDate/By.
- History(TICKET_REOPENED). Audit.

## Acceptance Criteria
- Non-QR tickets close directly after resolution. Reopen clears dates."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Implement final closure validation logic" --body "**Spec:** 10 - Quality Review
**Category:** DB-SP

## Logic
- If RequiresQualityReview=1: final closure only through QualityReviewSP APPROVE_FINAL_CLOSURE.
- If RequiresQualityReview=0: CLOSE_TICKET can be called directly after RESOLVED status.
- Test both paths.

## Acceptance Criteria
- QR-required tickets must pass review. Non-QR tickets close directly."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-10] Test quality review and final closure flow" --body "**Spec:** 10 - Quality Review
**Category:** Test

## Tests
1. Create QR-required ticket. Work to RESOLVED.
2. Open QR -> PENDING_QA.
3. Approve -> CLOSED, FinalClosedDate set.
4. Test RETURN -> IN_PROGRESS, resolved dates cleared.
5. Test REJECT -> REOPENED.
6. BR-14: QR before resolution -> rejection.
7. Non-QR ticket: close directly after resolution.

## Acceptance Criteria
- All 3 QR outcomes work. BR-13/BR-14 enforced. Both closure paths tested."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-10] Build quality review inbox screen" --body "**Spec:** 10 - Quality Review
**Category:** UI
**Dependencies:** V_TicketQualityInbox

## Display
- Grid: TicketNo, Title, OperationalResolvedDate, Reviewer, ReviewScope.
- Filter by IdaraID. Only unfinalized reviews.
- Click -> review decision UI.

## Acceptance Criteria
- Pending reviews listed correctly."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-10] Build final closure approval and return-for-correction UI" --body "**Spec:** 10 - Quality Review
**Category:** UI
**Dependencies:** QualityReviewSP all actions

## Approval Flow
- Show ticket summary and resolution details.
- Three buttons: Approve Final Closure, Return for Correction, Reject Closure.
- All require ReviewNotes. Return requires ReturnToUser selection (optional).
- Call appropriate QualityReviewSP action.

## Acceptance Criteria
- All three decisions work. Notes captured. Status updates."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-10] Display two-stage closure state in ticket details" --body "**Spec:** 10 - Quality Review
**Category:** UI

## Display
- Two distinct indicators: Operational Status (Resolved/Not) and Final Status (Closed/Pending QA/Open).
- Show dates: OperationalResolvedDate, FinalClosedDate.
- If RequiresQualityReview=1: QR status badge.
- Timeline shows both resolution and closure events.

## Acceptance Criteria
- Users clearly see where ticket is in two-stage closure process."

# ============================================================================
# SPEC 11: Catalogue Learning and Routing Correction (7 tasks)
# ============================================================================
echo ">>> SPEC 11: Catalogue Learning and Routing Correction"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-11] Create [Tickets].[CatalogRoutingChangeLog] history table" --body "**Spec:** 11 - Catalogue Learning
**Category:** DB-Structure
**Dependencies:** Spec-02 Service, ServiceRoutingRule, Spec-06 ArbitrationCase

## Columns
- CatalogRoutingChangeLogID BIGINT IDENTITY PK
- ServiceID_FK BIGINT FK->Service, IdaraID_FK BIGINT
- OldRoutingRuleID_FK BIGINT FK->ServiceRoutingRule NULL
- NewRoutingRuleID_FK BIGINT FK->ServiceRoutingRule NULL
- ChangeReason NVARCHAR(1000)
- SourceArbitrationCaseID_FK BIGINT FK->ArbitrationCase NULL
- ApprovedByUserID_FK BIGINT
- EffectiveFromDate DATE NOT NULL
- LoggedDate DATETIME2 DEFAULT SYSUTCDATETIME()

## Acceptance Criteria
- Table exists. Links old/new rules and optional arbitration source."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-11] Implement suggestion-to-service creation flow" --body "**Spec:** 11 - Catalogue Learning
**Category:** DB-SP
**Dependencies:** ServiceSP APPROVE_SERVICE_SUGGESTION

## Logic
- After approval: optionally create real service via INSERT_SERVICE logic.
- Update ServiceCatalogSuggestion.CreatedServiceID_FK with new ServiceID.
- Optionally create initial routing rule for new service.

## Acceptance Criteria
- Approved suggestions produce real services. Link maintained."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-11] Log routing corrections from arbitration historically" --body "**Spec:** 11 - Catalogue Learning
**Category:** DB-SP
**Dependencies:** ServiceSP INSERT_ROUTING_RULE, CatalogRoutingChangeLog

## Logic
- INSERT_ROUTING_RULE accepts optional SourceArbitrationCaseID.
- Included in CatalogRoutingChangeLog entry.
- Connects disputes to catalogue improvements. BR-18: never overwrite silently.

## Acceptance Criteria
- Corrections traceable to originating arbitration cases."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-11] Test catalogue learning and routing correction" --body "**Spec:** 11 - Catalogue Learning
**Category:** Test

## Tests
1. Create Other ticket. Arbitrate and redirect.
2. Create suggestion from arbitration.
3. Approve suggestion -> new service created.
4. Add routing rule. Verify CatalogRoutingChangeLog.
5. Replace routing rule. Verify old closed, new active, change logged.
6. Query change history.

## Acceptance Criteria
- Full learning cycle works. Historical routing preserved."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-11] Build service suggestion approval UI" --body "**Spec:** 11 - Catalogue Learning
**Category:** UI

## Flow
- Load pending suggestions. Show details.
- Approve: pre-fill new service form. Create service.
- Reject: require rejection reason.

## Acceptance Criteria
- Suggestions approved (creating services) or rejected with reasons."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-11] Build routing correction review UI" --body "**Spec:** 11 - Catalogue Learning
**Category:** UI
**Dependencies:** ArbitrationDL GET_ROUTING_CORRECTION_CANDIDATES

## Flow
- Show: TicketNo, Service, Current Routing, Suggested Target, Arbitration Decision.
- Apply Correction: creates new routing rule with SourceArbitrationCaseID.

## Acceptance Criteria
- Corrections reviewable and applicable. Audit maintained."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-11] Show routing change history for a service" --body "**Spec:** 11 - Catalogue Learning
**Category:** UI

## Display
- Timeline: Date, OldTarget, NewTarget, ChangeReason, Arbitration link, ApprovedBy.
- Alongside current active routing rule on service detail page.

## Acceptance Criteria
- Full routing history visible. Changes traceable."

# ============================================================================
# SPEC 12: Reporting and Dashboards (8 tasks)
# ============================================================================
echo ">>> SPEC 12: Reporting and Dashboards"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-12] Create [Tickets].[V_TicketInboxByScope] view" --body "**Spec:** 12 - Reporting
**Category:** DB-DL-View
**Dependencies:** Ticket, TicketStatus, Priority, Service

## Logic
- JOIN Ticket -> TicketStatus, Priority, Service.
- Filter: status NOT IN (CLOSED, CANCELLED).
- Return: TicketID, TicketNo, Title, IdaraID, CurrentDSDID, QueueDistributorID, AssignedUserID, StatusCode, PriorityCode, IsParentBlocked, CreatedDate, ServiceNameEN.

## Acceptance Criteria
- Returns open tickets filterable by org scope."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-12] Create [Tickets].[V_TicketArbitrationInbox] and [V_TicketQualityInbox] views" --body "**Spec:** 12 - Reporting
**Category:** DB-DL-View

## V_TicketArbitrationInbox
- JOIN ArbitrationCase -> Ticket, ArbitrationReason. Filter: Status=OPEN.
- Return: CaseID, TicketNo, Title, IdaraID, RaisedBy, Reason, Arbitrator, Date.

## V_TicketQualityInbox
- JOIN QualityReview -> Ticket. Filter: IsFinalized=0.
- Return: ReviewID, TicketNo, Title, IdaraID, Reviewer, Scope, Date.

## Acceptance Criteria
- Arbitration inbox shows only open cases. QR inbox shows only pending reviews."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-12] Create [Tickets].[DashboardDL] data layer procedure" --body "**Spec:** 12 - Reporting
**Category:** DB-DL-View
**Dependencies:** All views and tables

## Actions (all accept @IdaraID, optionally @DSDID)
- **GET_COUNTS_BY_STATUS:** GROUP BY TicketStatus -> StatusCode, StatusNameEN, Count.
- **GET_SLA_BREACHES:** TicketSLA WHERE IsBreached=1 with ticket details.
- **GET_ARBITRATION_LOAD:** COUNT open ArbitrationCase per ArbitratorDistributorID.
- **GET_CLARIFICATION_LOAD:** COUNT open ClarificationRequest per DSD.
- **GET_SERVICE_FREQUENCY:** COUNT tickets per Service, ranked DESC.
- **GET_OVERDUE_OPERATIONAL:** SLA OPERATIONAL_COMPLETION breached, ticket not closed.
- **GET_OVERDUE_FINAL_CLOSURE:** SLA FINAL_CLOSURE breached, ticket not closed.

## Acceptance Criteria
- All 7 actions return correct aggregated data. Scope filtering works."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-12] Test dashboard and reporting queries" --body "**Spec:** 12 - Reporting
**Category:** Test

## Tests
1. Seed test data across statuses, SLA breaches, open arbs, open clarifications.
2. GET_COUNTS_BY_STATUS -> verify counts.
3. GET_SLA_BREACHES -> only breached returned.
4. GET_ARBITRATION_LOAD -> counts per arbitrator.
5. GET_CLARIFICATION_LOAD -> counts per DSD.
6. GET_SERVICE_FREQUENCY -> correct ranking.
7. GET_OVERDUE_OPERATIONAL and GET_OVERDUE_FINAL_CLOSURE.
8. Scope filtering with different IdaraIDs.
9. Test all 3 inbox views.

## Acceptance Criteria
- All queries correct. Scope filtering works."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-12] Build organizational leadership dashboard" --body "**Spec:** 12 - Reporting
**Category:** UI
**Dependencies:** DashboardDL all actions

## Widgets
- Card widgets or donut chart: ticket counts by status.
- SLA breaches: count badge + top 5 list.
- Service frequency: bar chart top 10.
- Overdue operational: count + list link.
- Scope selector: IdaraID, DSDID.
- Auto-refresh. Clickable widgets navigate to details.

## Acceptance Criteria
- Dashboard loads with correct data. Widgets interactive. Scope filtering works."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-12] Build quality and monitoring dashboard widgets" --body "**Spec:** 12 - Reporting
**Category:** UI

## Widgets
1. Pending QR count (from V_TicketQualityInbox). Click -> QR inbox.
2. SLA breach breakdown by type (First Response, Assignment, Operational, Final).
3. Overdue final closures: count + top 5.
4. Arbitration load: bar chart per arbitrator.
5. Clarification load: pending per unit.
- All filterable by IdaraID.

## Acceptance Criteria
- All widgets display real-time data. Navigation works."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-12] Build overdue tickets report screen" --body "**Spec:** 12 - Reporting
**Category:** UI

## Display
- Two tabs: Overdue Operational, Overdue Final Closure.
- Grid: TicketNo, Title, Status, SLA Target, Elapsed, Breach Duration.
- Filters: IdaraID, DSDID, Priority. Sort by breach duration.
- Row click -> ticket details. Export CSV/Excel.

## Acceptance Criteria
- Both overdue categories shown. Sort by severity. Export works."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-12] Build service frequency and workload report" --body "**Spec:** 12 - Reporting
**Category:** UI

## Display
- Service frequency: sortable table + bar chart (ServiceName, Count, Percentage).
- Workload by DSD: table + chart.
- Filters: IdaraID, date range, Priority. Time period selector.
- Export CSV/Excel.

## Acceptance Criteria
- Ranking accurate. Date filtering works. Export works."

# ============================================================================
# SPEC 13: Cross-Cutting Testing (4 tasks)
# ============================================================================
echo ">>> SPEC 13: Cross-Cutting Testing"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-13] Create structural integrity test suite" --body "**Spec:** 13 - Testing
**Category:** Test

## Tests
1. PK existence on all 21 tables.
2. FK relationships: orphan inserts rejected.
3. UNIQUE constraints: duplicate codes rejected.
4. CHECK constraint CK_Ticket_RequesterExclusivity.
5. Default values: IsActive, IsDeleted, CreatedDate, Status defaults.

## Acceptance Criteria
- All constraints verified. Document shows pass/fail per test."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-13] Create business scenario test suite (10 scenarios)" --body "**Spec:** 13 - Testing
**Category:** Test

## Scenarios
1. Known service direct routing.
2. Other service arbitration routing.
3. Division-level direct assignment.
4. Section-level routing then assignment.
5. Wrong-scope dispute and redirect.
6. Missing-info clarification and resume.
7. Child ticket with parent blocking.
8. Parent resume after child completion.
9. Operational closure then quality approval.
10. Quality rejection returning work.

## Acceptance Criteria
- All 10 scenarios pass with setup, execution, assertions."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-13] Create SLA-specific test suite" --body "**Spec:** 13 - Testing
**Category:** Test

## Tests
1. SLA initialization from policy.
2. Pause on arbitration/clarification/child.
3. Resume on dependency removal.
4. Breach detection when elapsed exceeds target.
5. Final closure SLA completion.
6. Verify TicketSLAHistory for every event.

## Acceptance Criteria
- All SLA tests pass. Elapsed accurate. Breach detection works."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-13] Create reporting validation test suite" --body "**Spec:** 13 - Testing
**Category:** Test

## Tests
1. Inbox visibility by scope (different DSDs).
2. Dashboard counts vs seeded data.
3. Service frequency ranking.
4. Overdue list correctness.
5. Audit trace completeness for full lifecycle ticket.

## Acceptance Criteria
- Scope filtering isolates data. Counts match. Audit complete."

# ============================================================================
# SPEC 14: Documentation (5 tasks)
# ============================================================================
echo ">>> SPEC 14: Documentation"

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-14] Create master deployment script (Deploy_All.sql)" --body "**Spec:** 14 - Documentation
**Category:** Docs

## Order
1. Create schema [Tickets]
2. Lookup tables (8)
3. Seed values
4. Master tables (4)
5. Transaction tables (6)
6. History tables (3)
7. Views (7)
8. DL procedures (4)
9. SP procedures (6)
10. Print completion

## Standards
- Idempotent (IF NOT EXISTS, CREATE OR ALTER). Rollback notes as comments.

## Acceptance Criteria
- Clean DB deploy succeeds. Re-run does not error."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-14] Create rollback script (Rollback_All.sql)" --body "**Spec:** 14 - Documentation
**Category:** Docs

## Order (reverse dependency)
SPs -> DLs -> Views -> History -> Transaction -> Master -> Lookup -> Schema.
IF EXISTS before each DROP. Safety warning comment.

## Acceptance Criteria
- Clean removal. No orphan references."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-14] Document stored procedure API reference" --body "**Spec:** 14 - Documentation
**Category:** Docs

## Content
For each SP (ServiceSP, TicketSP, ArbitrationSP, ClarificationSP, QualityReviewSP, TicketSLASP):
- All @Action values, required/optional params, return values, business rules, error codes.
For each DL (ServiceDL, TicketDL, ArbitrationDL, DashboardDL):
- All @Action values, params, result sets.

## Acceptance Criteria
- Complete reference. Usable as API contract."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-14] Document business rule matrix (BR-01 to BR-20)" --body "**Spec:** 14 - Documentation
**Category:** Docs

## Format
Rule ID | Description | Enforcement Location(s) | Test Reference

## Acceptance Criteria
- All 20 rules documented with enforcement and test references."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-14] Create UI page map, navigation structure, and component library specs" --body "**Spec:** 14 - Documentation
**Category:** Docs

## Page Map
- Settings/Admin screens, Core Operation screens, Workflow screens, Quality screens, Reporting screens.
- Per page: API calls, navigation links, permissions.

## Component Library
- StatusBadge, PriorityBadge, SLATimer, BreachIndicator, OrgPicker, UserPicker
- TicketCard, TimelineEntry, TreeNode, ActionModal
- Per component: props, states, usage locations.

## Acceptance Criteria
- All pages documented. Components specified for consistent implementation."

# ============================================================================
# SPEC 15: Frontend Infrastructure (3 tasks)
# ============================================================================
echo ">>> SPEC 15: Frontend Infrastructure"

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-15] Set up frontend project scaffolding and configuration" --body "**Spec:** 15 - Frontend Infrastructure
**Category:** Setup

## Structure
- pages/, components/, services/, utils/, styles/, constants/
- API base URL and environment config.
- Constants mapping: TicketStatus codes, Priority codes, SLA types.
- Routing/navigation structure.
- Build and dev scripts. .gitignore and README.

## Acceptance Criteria
- Project builds and runs. Constants match DB seed values."

gh project item-create ${PROJECT} --owner "@me" --title "[Frontend][Spec-15] Implement API service layer for all backend endpoints" --body "**Spec:** 15 - Frontend Infrastructure
**Category:** Setup

## Files
- services/ServiceApi: CRUD, routing, SLA, suggestions + reads
- services/TicketApi: create, assign, progress, reject, child, pause, resume, resolve, close, reopen + reads
- services/ArbitrationApi: open, redirect, overrule, cancel + reads
- services/ClarificationApi: open, respond, close
- services/QualityReviewApi: open, approve, return, reject
- services/DashboardApi: all 7 dashboard actions
- services/LookupApi: all 8 lookup reads

## Acceptance Criteria
- All API functions match SP/DL contract. Error handling included."

gh project item-create ${PROJECT} --owner "@me" --title "[Backend][Spec-15] Create API endpoint layer and DB connection utility" --body "**Spec:** 15 - Backend Infrastructure
**Category:** Setup

## API Endpoints
- POST/GET /api/services, /api/tickets, /api/arbitration, /api/clarification, /api/quality-review, /api/dashboard, /api/lookups/:type

## DB Utility
- Connection config (env variables), connection pooling.
- Generic SP executor function.
- SQL THROW -> HTTP status mapping.
- Health check: GET /api/health.

## Acceptance Criteria
- All endpoints callable. Error mapping works. Health check responds."

# ============================================================================
# DONE
# ============================================================================
echo ""
echo "========================================="
echo " KANBAN BOARD POPULATION COMPLETE"
echo "========================================="
echo ""
echo " Total tasks: ~96"
echo ""
echo " Spec 00: Project Setup         -  2 tasks"
echo " Spec 01: Lookup Foundations     - 10 tasks"
echo " Spec 02: Service Catalogue     - 15 tasks"
echo " Spec 03: Core Ticket Backbone  - 11 tasks"
echo " Spec 04: Assignment & Work     - 10 tasks"
echo " Spec 05: Clarification Flow    -  8 tasks"
echo " Spec 06: Arbitration Flow      -  8 tasks"
echo " Spec 07: Parent-Child Tickets  -  5 tasks"
echo " Spec 08: Pause Sessions        -  8 tasks"
echo " Spec 09: SLA Engine            -  9 tasks"
echo " Spec 10: Quality Review        - 10 tasks"
echo " Spec 11: Catalogue Learning    -  7 tasks"
echo " Spec 12: Reporting Dashboards  -  8 tasks"
echo " Spec 13: Cross-Cutting Tests   -  4 tasks"
echo " Spec 14: Documentation         -  5 tasks"
echo " Spec 15: Infrastructure        -  3 tasks"
echo ""
echo " Board: https://github.com/users/Fahad1993/projects/3/views/1"
echo ""
echo " Dependency Order:"
echo " Spec 00 -> 01 -> 02 -> 03 -> 04 -> 05/06 (parallel) -> 07 -> 08 -> 09 -> 10 -> 11 -> 12"
echo " Spec 13/14/15 can run in parallel with implementation specs."
echo ""
echo "========================================="