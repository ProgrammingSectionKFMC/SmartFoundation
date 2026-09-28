using Microsoft.Extensions.DependencyInjection;
using SmartFoundation.Application.Services;

namespace SmartFoundation.Application.Extensions;

/// <summary>
/// Extension methods for registering Application Layer services with the DI container.
/// </summary>
public static class ServiceCollectionExtensions
{
  /// <summary>
  /// Registers all Application Layer services with the dependency injection container.
  /// Call this method in Program.cs: builder.Services.AddApplicationServices();
  /// </summary>
  /// <param name="services">The service collection</param>
  /// <returns>The service collection for chaining</returns>
  public static IServiceCollection AddApplicationServices(this IServiceCollection services)
  {
    // Register all service classes here
    // Use Scoped lifetime for services that depend on per-request data

    // TODO: Uncomment these lines when the concrete service classes are created:
    services.AddScoped<EmployeeService>();
    services.AddScoped<DashboardService>();
    services.AddScoped<MastersServies>();
    services.AddScoped<AuthenticationAuditService>();


        // Add more services as they are created:
        // services.AddScoped<YourNewService>();

        return services;
  }
}
