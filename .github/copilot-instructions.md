# AGENTS.md

## Purpose

This file tells coding agents how to work in `SmartFoundation`.

Use current Housing-era code as the baseline pattern for this repository. Older experiments exist, but the most reliable implementation style starts with `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`.

If documentation conflicts with active code, trust active code.

## Primary Sources

- Main repo instruction file: `.github/copilot-instructions.md`
- Primary implementation reference: `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`
- Shared Housing controller base: `SmartFoundation.Mvc/Controllers/Housing/HousingController.Base.cs`
- Generic CRUD contract: `SmartFoundation.Mvc/Controllers/CrudController.cs`
- Gateway application service: `SmartFoundation.Application/Services/MastersServies.cs`
- Gateway stored procedures: `SmartFoundation.Database/dbo/Stored Procedures/Masters_DataLoad.sql`, `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql`

## Solution Map

- `SmartFoundation.Mvc` - actual web app and composition root
- `SmartFoundation.Application` - application services and procedure mapping
- `SmartFoundation.DataEngine` - Dapper request/response execution layer
- `SmartFoundation.UI` - reusable ViewComponents and page/view models
- `SmartFoundation.Application.Tests` - current automated test project
- `SmartFoundation.Database` - database snapshot/reference only

Important:

- Real entrypoint: `SmartFoundation.Mvc/Program.cs`
- Root `Program.cs` is stale/empty and must not be treated as runtime code
- Root `Views/` and `wwwroot/` are not the main app surface; prefer `SmartFoundation.Mvc`

## Database Warning

`SmartFoundation.Database` is a snapshot/reference only.

- It is not guaranteed current
- It must not be treated as the source of truth
- Use it to understand intent and routing, not to prove live behavior

When database behavior matters, verify against:

- `SmartFoundation.Application/Mapping/ProcedureMapper.cs`
- `SmartFoundation.Application/Services/MastersServies.cs`
- `SmartFoundation.DataEngine/Core/Services/SmartComponentService.cs`
- Active MVC callers such as `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`

## Housing Is The Baseline Pattern

When in doubt, follow the implementation style used by `WaitingListByResident` first, unless the local feature clearly uses a different active pattern.

The reference execution path is:

- `HousingController.WaitingListByResident` reads session context and query parameters
- `HousingController.Base` provides `InitPageContext(...)` and `SplitDataSet(...)`
- controller calls `MastersServies.GetDataLoadDataSetAsync(...)`
- controller uses `_CrudController.GetDDLValues(...)` for lookup lists
- controller assembles `FormConfig`, `SmartTableDsModel`, and `SmartPageViewModel`
- view stays thin and renders `SmartRenderer`
- `Masters_DataLoad` routes by `@pageName_`
- downstream Housing procedure loads the page data
- CRUD posts go through `CrudController` -> `MastersServies.GetCrudDataSetAsync(...)`
- `Masters_CRUD` routes by `@pageName_` and `@ActionType`
- downstream Housing CRUD procedure performs business validation and business logic

Reference files:

- `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`
- `SmartFoundation.Mvc/Views/Housing/WaitingList/WaitingListByResident.cshtml`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentDL.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentSP.sql`

## Controller Pattern To Preserve

For Housing-style pages, controllers commonly do the following:

- call `InitPageContext(out redirectResult)` early
- read shared session-backed fields like `usersId`, `IdaraId`, and `HostName`
- set `ControllerName` and `PageName`
- build positional stored procedure argument arrays
- call a `MastersServies` DataSet method
- split the result using `SplitDataSet(...)`
- treat the first table as permissions
- use later tables as feature data (`dt1`, `dt2`, `dt3`, `dt4`, ...)
- build server-side UI config objects instead of pushing logic into the Razor view

Reference files:

- `SmartFoundation.Mvc/Controllers/Housing/HousingController.Base.cs`
- `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`

## MVC To Database Contract

Housing-style pages depend on exact parameter names and shapes. Do not rename them casually.

Core fields used repeatedly:

- `pageName_`
- `ActionType`
- `idaraID`
- `entrydata`
- `hostname`

Additional values are packed as:

- `parameter_01` ... `parameter_50`

Rules:

- preserve casing and spelling exactly
- do not add `@` to parameter names in application code
- do not replace these names with cleaner aliases unless you are intentionally changing the whole DB contract

Reference files:

- `SmartFoundation.Application/Services/MastersServies.cs`
- `SmartFoundation.Mvc/Controllers/CrudController.cs`
- `SmartFoundation.DataEngine/Core/Services/SmartComponentService.cs`

## Generic CRUD Contract

`CrudController` is not incidental plumbing. Many pages depend on it.

Pattern:

- form fields usually bind as `p01` ... `p50`
- `CrudController` converts them to `parameter_01` ... `parameter_50`
- hidden context fields like `pageName_`, `ActionType`, `idaraID`, `entrydata`, `hostname`, `redirectAction`, and `redirectController` are part of the expected contract
- CRUD actions post to `/crud/insert`, `/crud/update`, or `/crud/delete`
- feedback is sent through Toastr-style `TempData` buckets: `Success`, `Warning`, `Error`, `Info`

Do not remove or redesign this contract unless the task explicitly requires it.

Reference file:

- `SmartFoundation.Mvc/Controllers/CrudController.cs`

## DataSet Pattern

In active Housing code, `DataSet` is a real team pattern, not something an agent should auto-refactor away.

Typical meaning of returned tables:

- table 0 = permissions
- later tables = resident data, feature lists, letters, move requests, and DDL sources

Controllers commonly:

- map `DataTable.Columns` to `TableColumn`
- convert `DataRow` objects to `Dictionary<string, object?>`
- add `p01`, `p02`, ... aliases for modal forms and CRUD posts
- keep multiple `rowsList_*` and `dynamicColumns_*` collections per returned table

Reference files:

- `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`
- `SmartFoundation.Mvc/Controllers/Housing/HousingController.Base.cs`

## Permission Pattern

Housing pages derive permissions from the first returned table, usually using `permissionTypeName_E`.

These permissions directly control UI actions such as:

- insert waiting list
- insert occupent letter
- update waiting list
- update occupent letter
- move waiting list
- delete waiting list
- delete move request

Agents should preserve this server-side permission gating pattern when changing Housing-style pages.

Reference file:

- `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`

## UI Composition Pattern

Housing views are intentionally thin.

Pattern:

- controller builds `FormConfig`, `FieldConfig`, `SmartTableDsModel`, toolbar actions, and `SmartPageViewModel`
- view usually does little more than invoke `SmartRenderer`
- `SmartRenderer` dispatches to nested ViewComponents based on the page model

Reference files:

- `SmartFoundation.Mvc/Views/Housing/WaitingList/WaitingListByResident.cshtml`
- `SmartFoundation.UI/ViewModels/SmartPage/SmartPageViewModel.cs`
- `SmartFoundation.UI/ViewComponents/SmartRenderer/SmartRendererViewComponent.cs`

## ProcedureMapper Rule

This repository should use `ProcedureMapper` for entry procedures exposed to the app layer, not for every downstream business-logic stored procedure.

Important rule:

- map gateway/entry procedures in the application layer
- do not fill `ProcedureMapper` with every feature-specific downstream SP if the gateway SP already routes to it

For Housing-style flows, the intended architecture is:

- application code reaches an entry procedure
- the entry procedure routes by `@pageName_` and sometimes `@ActionType`
- the downstream feature procedure contains the business logic and validations

Reference files:

- `SmartFoundation.Application/Mapping/ProcedureMapper.cs`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_DataLoad.sql`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql`

## Gateway Stored Procedure Architecture

The Housing `WaitingListByResident` flow is the canonical example.

Read path:

- app code reaches `Masters_DataLoad`
- `Masters_DataLoad` checks `@pageName_ = 'WaitingListByResident'`
- `Masters_DataLoad` executes `[Housing].[WaitingListByResidentDL]`

Write path:

- app code reaches `Masters_CRUD`
- `Masters_CRUD` checks `@pageName_ = 'WaitingListByResident'`
- `Masters_CRUD` checks permissions using `@ActionType`
- `Masters_CRUD` executes `[Housing].[WaitingListByResidentSP]`

Meaning:

- `ProcedureMapper` should point to the entry/gateway procedures
- downstream procedures like `[Housing].[WaitingListByResidentSP]` hold business validations and business logic
- agents should preserve this separation instead of flattening it

Reference files:

- `SmartFoundation.Database/dbo/Stored Procedures/Masters_DataLoad.sql:1068`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql:1017`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentDL.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentSP.sql`

## Gateway And Feature Procedure Patterns

There are shared SQL patterns across `dbo` gateway procedures and downstream Housing procedures. Agents should preserve these patterns when changing app code or SQL-related behavior.

Gateway read pattern in `Masters_DataLoad`:

- gateway procedures accept shared context first, then generic positional parameters
- `Masters_DataLoad` selects `permissionTypeName_E` from `dbo.ft_UserPagePermissions(@entrydata, @pageName_)` before page-specific resultsets
- page-specific routing is typically a large `IF / ELSE IF` block on `@pageName_`
- downstream `DL` procedures usually return the main feature dataset first, then one or more DDL/lookup datasets

Gateway write pattern in `Masters_CRUD`:

- `Masters_CRUD` routes by both `@pageName_` and `@ActionType`
- it performs permission checks before calling downstream write procedures
- it captures downstream results using the shared `IsSuccessful` / `Message_` contract
- it can trigger notification outbox behavior through `dbo.Notifications_Create`
- business errors are returned to the caller directly; unexpected errors are logged to `dbo.ErrorLog`

Downstream Housing `DL` pattern:

- shared parameters usually start with `@pageName_`, `@idaraID`, `@entrydata`, and `@hostname`
- some pages add one or more feature-specific filters after the shared parameters
- the first feature resultset is the primary page data
- later resultsets are often DDL sources used to populate selects in MVC forms
- many filters follow the active-record pattern such as `...Active = 1`
- many Housing lookups are scoped by Idara with conditions like `(IdaraId_FK is null or IdaraId_FK = @idaraID)`

Downstream Housing `SP` pattern:

- write procedures typically use `SET NOCOUNT ON` and `SET XACT_ABORT ON`
- they usually guard transactions with `@@TRANCOUNT`
- they use `BEGIN TRY / BEGIN CATCH`
- business validation errors commonly use `THROW 50001`
- unexpected/programmatic failures commonly use `THROW 50002`
- successful branches usually end with `SELECT 1 AS IsSuccessful, N'...' AS Message_` followed by `RETURN`
- delete behavior is often a soft delete using an `...Active = 0` update, not a physical delete
- many procedures append `entryData` and `hostName` instead of replacing them
- writes commonly insert an audit row into `dbo.AuditLog`

Important error-handling rule:

- in `Masters_CRUD`, errors in the `50001` to `50999` range are treated as business/user-facing errors
- unexpected errors are logged to `dbo.ErrorLog` and converted into a generic failure message

Reference files:

- `SmartFoundation.Database/dbo/Stored Procedures/Masters_DataLoad.sql:40`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql:65`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql:3133`
- `SmartFoundation.Database/dbo/Stored Procedures/Masters_CRUD.sql:3182`
- `SmartFoundation.Database/Housing/Stored Procedures/BuildingTypeDL.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/BuildingTypeSP.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/BuildingDetailsDL.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/BuildingDetailsSP.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentDL.sql`
- `SmartFoundation.Database/Housing/Stored Procedures/WaitingListByResidentSP.sql`

## Application Layer Guidance

Current reality:

- `MastersServies` is an active gateway service and should be respected in existing flows
- `BaseService` is still the right pattern for new narrow JSON-style services
- not every feature should be migrated away from `MastersServies` unless explicitly requested

For new focused services:

- inherit from `BaseService`
- use `ProcedureMapper` for entry procedure resolution
- register the service in `SmartFoundation.Application/Extensions/ServiceCollectionExtensions.cs`

For existing Housing-style flows:

- preserve `MastersServies`
- preserve `DataSet` and `DataTable` behavior
- preserve the existing page/action gateway contract

Reference files:

- `SmartFoundation.Application/Services/MastersServies.cs`
- `SmartFoundation.Application/Services/BaseService.cs`
- `SmartFoundation.Application/Extensions/ServiceCollectionExtensions.cs`

## DataEngine Rules

`SmartComponentService` is the execution engine behind these flows.

Important behavior:

- it receives `SmartRequest` with `Operation`, `SpName`, and `Params`
- it adds `@` prefixes internally when creating Dapper parameters
- it uses `QueryMultipleAsync` first and falls back to `QueryAsync`
- paging/sort/filter helpers only apply when `Operation == "select"`
- many active app flows use `Operation = "sp"`

Reference files:

- `SmartFoundation.DataEngine/Core/Models/SmartRequest.cs`
- `SmartFoundation.DataEngine/Core/Models/SmartResponse.cs`
- `SmartFoundation.DataEngine/Core/Services/SmartComponentService.cs`

## Dependency Injection

- Composition root is `SmartFoundation.Mvc/Program.cs`
- `ConnectionFactory` is singleton
- `ISmartComponentService` maps to `SmartComponentService`
- app services are mostly scoped
- concrete service injection is common in active code
- `CrudController` itself is registered and injected as a service in current runtime wiring

Reference files:

- `SmartFoundation.Mvc/Program.cs`
- `SmartFoundation.Application/Extensions/ServiceCollectionExtensions.cs`

## Build, Run, Test

From repo root:

```powershell
dotnet restore SmartFoundation.sln
dotnet build SmartFoundation.sln
dotnet run --project SmartFoundation.Mvc/SmartFoundation.Mvc.csproj
```

Focused build:

```powershell
dotnet build SmartFoundation.Mvc/SmartFoundation.Mvc.csproj
dotnet build SmartFoundation.Application/SmartFoundation.Application.csproj
```

Tests:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --list-tests
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --filter "FullyQualifiedName~EmployeeServiceTests"
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --filter "FullyQualifiedName=SmartFoundation.Application.Tests.Services.EmployeeServiceTests.GetEmployeeList_WithValidParams_ReturnsSuccessJson"
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --collect:"XPlat Code Coverage"
```

Frontend:

```powershell
npm install --prefix SmartFoundation.Mvc
npm --prefix SmartFoundation.Mvc run tw:watch
npm --prefix SmartFoundation.Mvc run tw:build
```

Notes:

- Full solution build includes `SmartFoundation.Database.sqlproj` and may require SQL project tooling
- Only `SmartFoundation.Application.Tests` exists today

## Coding Conventions

- Preserve the local style of the file you edit
- Keep `using` directives at the top and remove unused ones
- Use PascalCase for classes, methods, properties, and public members
- Use camelCase for locals, parameters, and private fields
- Prefer `Dictionary<string, object?>` for dynamic parameter bags
- Preserve async I/O patterns
- Keep XML docs on public members when adding or substantially changing them
- In markdown, follow `.github/copilot-instructions.md` formatting rules

## Anti-Patterns To Avoid

- Do not use root `Program.cs` as the runtime source of truth
- Do not assume old experiments represent current team standards
- Do not auto-refactor Housing pages away from `MastersServies` + `DataSet`
- Do not rename `pageName_`, `ActionType`, `idaraID`, `entrydata`, `hostname`, `p01..p50`, or `parameter_01..parameter_50` casually
- Do not map every downstream business SP into `ProcedureMapper`
- Do not treat `SmartFoundation.Database` as authoritative proof of the live database
- Do not remove `CrudController` plumbing unless the task explicitly replaces the whole contract

## Final Rule

If you are working on a feature that looks like Housing, copy the Housing style first.

The safest reference path in this repository is:

- `SmartFoundation.Mvc/Controllers/Housing/WaitingList/HousingController.WaitingListByResident.cs`
- then `SmartFoundation.Mvc/Controllers/Housing/HousingController.Base.cs`
- then `SmartFoundation.Mvc/Controllers/CrudController.cs`
- then `SmartFoundation.Application/Services/MastersServies.cs`
- then the gateway and downstream procedures involved in that page
