# SmartFoundation

ASP.NET Core 8.0 application following Clean Architecture principles.

## Quick Start

### 1. Clone and Setup

```powershell
git clone <repository-url>
cd SmartFoundation
```

### 2. Build and Run the Project

```powershell
# Restore dependencies
dotnet restore

# Build solution
dotnet build

# Run the application
cd SmartFoundation.Mvc
dotnet run
```

Visit `https://localhost:5001` in your browser.

## Project Structure

```
SmartFoundation/
|- SmartFoundation.Mvc/         # Presentation Layer (ASP.NET Core MVC)
|- SmartFoundation.Application/ # Business Logic Layer
|- SmartFoundation.DataEngine/  # Data Access Layer
|- SmartFoundation.UI/          # Reusable UI Components
|- docs/                        # Project documentation
`- tools/                       # Development tools and scripts
```

## Architecture

This project follows Clean Architecture with clear separation of concerns:

- Presentation Layer (`SmartFoundation.Mvc`): Controllers, views, request handling
- Application Layer (`SmartFoundation.Application`): Business logic and services
- Data Access Layer (`SmartFoundation.DataEngine`): Database operations
- UI Components (`SmartFoundation.UI`): Reusable user interface components

See [GitHub Copilot Instructions](.github/copilot-instructions.md) for detailed architecture guidelines.

## Documentation

- [Project PRD](docs/PRD.md) - Product requirements document
- [Implementation Guide](docs/ImplementationGuide.md) - Development guidelines
- [GitHub Copilot Instructions](.github/copilot-instructions.md) - Coding standards

### UI Components

- [Dual Date Picker](docs/dual-date-picker.md) - Gregorian and Hijri synced date picker
- [Quick Reference](docs/dual-date-picker-quick-ref.md) - Dual date picker quick guide

## Development Tools

The `tools/` directory contains PowerShell scripts for:

- IIS traffic analysis
- Stored procedure extraction
- Migration priority ranking

## Contributing

1. Follow Clean Architecture principles (see [.github/copilot-instructions.md](.github/copilot-instructions.md))
2. Write XML documentation for all public APIs
3. Keep controllers thin and business logic in the Application Layer
4. Never hard-code stored procedure names (use ProcedureMapper)

## Security

- Never commit `.env` files
- Keep API keys in local environment files only
- Follow security guidelines in project documentation

## License

[Your License Here]

## Team

[Your Team Information Here]

---

Need help?

- Architecture: Read [`.github/copilot-instructions.md`](.github/copilot-instructions.md)
- Contact your team lead
