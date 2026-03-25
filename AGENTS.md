# AGENTS.md

## Purpose

This file is for coding agents working in `SmartFoundation`.

Use this as the practical source of truth for repository behavior. Several older docs describe a target architecture rather than the code that actually runs.

## Instruction Sources

- Primary instruction file: `.github/copilot-instructions.md`
- There are no Cursor rules in `.cursor/rules/` and no `.cursorrules`
- If guidance conflicts, trust compiling code, project wiring, and this file over older README-style docs

## Solution Map

This is a partially migrated ASP.NET Core 8 solution with Clean Architecture intentions but mixed implementation.

Projects in `SmartFoundation.sln`:

- `SmartFoundation.Mvc` - actual web app and composition root
- `SmartFoundation.Application` - business/application services
- `SmartFoundation.DataEngine` - Dapper-based stored procedure execution
- `SmartFoundation.UI` - reusable Razor class library and ViewComponents
- `SmartFoundation.Application.Tests` - xUnit tests for application services
- `SmartFoundation.Database` - database snapshot/reference only

Important runtime facts:

- Real entrypoint: `SmartFoundation.Mvc/Program.cs`
- Root `Program.cs` is empty/stale
- Prefer `SmartFoundation.Mvc` over root-level `Views/` and `wwwroot/`

## Database Snapshot Warning

`SmartFoundation.Database` is a snapshot/reference of the database project.

- It is not guaranteed current with the live development or production database
- It must not be treated as the source of truth
- Use it to understand intent, not as proof of current runtime behavior

When database details matter, verify against:

- `SmartFoundation.Application/Mapping/ProcedureMapper.cs`
- `SmartFoundation.DataEngine/Core/Services/SmartComponentService.cs`
- Current MVC/Application callers
- The actual database environment used by the team

## Restore, Build, Run

From repo root:

```powershell
dotnet restore SmartFoundation.sln
dotnet build SmartFoundation.sln
dotnet run --project SmartFoundation.Mvc/SmartFoundation.Mvc.csproj
```

Useful focused builds:

```powershell
dotnet build SmartFoundation.Mvc/SmartFoundation.Mvc.csproj
dotnet build SmartFoundation.Application/SmartFoundation.Application.csproj
```

Notes:

- Full solution build includes `SmartFoundation.Database.sqlproj` and may require SQL project tooling
- If the SQL project breaks solution build, build only the affected app/test project

## Test Commands

Run all tests:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj
```

List tests:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --list-tests
```

Run one test class:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --filter "FullyQualifiedName~EmployeeServiceTests"
```

Run one exact test:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --filter "FullyQualifiedName=SmartFoundation.Application.Tests.Services.EmployeeServiceTests.GetEmployeeList_WithValidParams_ReturnsSuccessJson"
```

Coverage:

```powershell
dotnet test SmartFoundation.Application.Tests/SmartFoundation.Application.Tests.csproj --collect:"XPlat Code Coverage"
```

Current reality:

- Only `SmartFoundation.Application.Tests` exists
- There is no MVC test project right now

## Frontend Commands

Frontend tooling lives in `SmartFoundation.Mvc`.

```powershell
npm install --prefix SmartFoundation.Mvc
npm --prefix SmartFoundation.Mvc run tw:watch
npm --prefix SmartFoundation.Mvc run tw:build
```

Asset facts:

- Input CSS: `SmartFoundation.Mvc/wwwroot/css/input.css`
- Output CSS: `SmartFoundation.Mvc/wwwroot/css/site.css`
- Tailwind config: `SmartFoundation.Mvc/tailwind.config.js`
- Tailwind scans MVC and `SmartFoundation.UI` Razor files

## Architecture Reality

Treat this repo as partially migrated, not fully cleanly layered.

Current practical patterns:

- MVC controllers and ViewComponents are the active UI surface
- `SmartFoundation.Application` contains both newer service patterns and older gateway-style orchestration
- `SmartFoundation.DataEngine` executes stored procedures through `SmartRequest` and `SmartResponse`
- `SmartFoundation.UI` provides reusable server-rendered UI components

Important exceptions:

- Some endpoints still use `ISmartComponentService` directly, for example `SmartFoundation.Mvc/Controllers/SmartComponentController.cs`
- `MastersServies` is a real dependency in the current app; do not casually replace it
- Many MVC flows still use `DataSet` and `DataTable`, not typed DTOs

## Service and Data Access Rules

For new Application-layer work:

- Prefer new services in `SmartFoundation.Application/Services`
- New services should inherit from `BaseService`
- Register new services in `SmartFoundation.Application/Extensions/ServiceCollectionExtensions.cs`
- Prefer `ProcedureMapper` over hard-coded stored procedure names

For existing flows:

- Do not force migration from `MastersServies` unless the task requires it
- Preserve `DataSet`/`DataTable` behavior where callers depend on it
- Keep stored procedure parameter names aligned exactly with existing usage

Important DataEngine behavior:

- Whitelist enforcement only applies if configured; current appsettings leave it empty
- Paging/sort/filter metadata is added only when `SmartRequest.Operation == "select"`
- Many existing callers use `Operation = "sp"`

## Dependency Injection

- DI composition root is `SmartFoundation.Mvc/Program.cs`
- Most services are scoped
- `ConnectionFactory` is singleton
- `ISmartComponentService` is registered to `SmartComponentService`
- Existing code often injects concrete services instead of interfaces; follow local patterns unless intentionally refactoring

## C# Style Guidelines

- Preserve the style already used in the file you edit
- Keep `using` directives at the top and remove unused imports
- Use PascalCase for classes, methods, properties, and public members
- Use camelCase for locals, parameters, and private fields
- Prefer descriptive names over abbreviations
- Name new focused services `{Entity}Service`
- Name controllers `{Entity}Controller`
- Prefer `Dictionary<string, object?>` for dynamic parameter bags
- Preserve async APIs; do not add sync wrappers over async I/O
- Be careful with `JsonElement` values because `SmartComponentService` normalizes them

## Error Handling and Logging

- Use `ILogger<T>` in controllers and services
- `LogInformation` for normal flow
- `LogWarning` for handled unusual cases
- `LogError` for exceptions and failures
- Preserve existing JSON response contracts in services
- In MVC actions, prefer safe fallback behavior over leaking raw exceptions to the UI
- Never swallow exceptions silently

## Testing Conventions

- Framework: xUnit
- Mocking: Moq
- Use Arrange / Act / Assert comments
- Use descriptive `Method_Condition_ExpectedResult` test names
- Cover both success and error paths
- Existing service tests often assert JSON using `JsonDocument`; match nearby patterns unless there is a better local convention

## Documentation Rules

From `.github/copilot-instructions.md`:

- Add XML docs for public classes, methods, and properties when adding or substantially changing them
- In markdown, add blank lines around headings, lists, and fenced code blocks
- Always specify a language for fenced code blocks
- Do not use bare URLs
- Keep markdown concise and markdownlint-friendly

## Known Outdated Guidance

- `SmartFoundation.Application/README.md` is only partially accurate
- References to `MenuService` are outdated; current code uses `MastersServies`
- Some docs in `docs/` describe target-state migration, not current-state code
- Stored procedure mappings and the database snapshot may not fully match live runtime behavior

## Safe Agent Workflow

Before editing:

- Identify the real runtime path first
- Check whether the flow uses `BaseService`, `MastersServies`, or direct `ISmartComponentService`
- Confirm whether the change affects MVC, Application, DataEngine, UI, or only the database snapshot

When editing:

- Make the smallest change that fits the local pattern
- Trust running code over aspirational docs
- Avoid broad architectural rewrites unless explicitly requested
- For stored procedure work, inspect both runtime callers and `ProcedureMapper`

Before finishing:

- Build the smallest affected project, or the full solution when practical
- Run relevant tests, at minimum the affected test class when possible
- Keep markdown changes compliant with `.github/copilot-instructions.md`
