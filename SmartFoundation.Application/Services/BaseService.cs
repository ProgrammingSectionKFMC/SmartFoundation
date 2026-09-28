using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;
using SmartFoundation.Application.Mapping;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace SmartFoundation.Application.Services;

/// <summary>
/// Base class for all Application Layer services.
/// ALL services MUST inherit from this class - this is MANDATORY.
/// Provides common functionality for database operations, error handling, and logging.
/// </summary>
public abstract class BaseService
{
  protected readonly ISmartComponentService _dataEngine;
  protected readonly ILogger _logger;

  /// <summary>
  /// Constructor for base service.
  /// </summary>
  /// <param name="dataEngine">DataEngine service for database operations</param>
  /// <param name="logger">Logger instance</param>
  protected BaseService(ISmartComponentService dataEngine, ILogger logger)
  {
    _dataEngine = dataEngine ?? throw new ArgumentNullException(nameof(dataEngine));
    _logger = logger ?? throw new ArgumentNullException(nameof(logger));
  }

  /// <summary>
  /// Executes a stored procedure operation with standardized error handling and JSON response.
  /// This is the standard method all services should use.
  /// </summary>
  /// <param name="module">Module name (e.g., "employee", "menu")</param>
  /// <param name="operation">Operation name (e.g., "list", "insert")</param>
  /// <param name="parameters">Parameters to pass to stored procedure</param>
  /// <returns>JSON string with format: { success: bool, data: object, message: string }</returns>
  protected async Task<string> ExecuteOperation(
      string module,
      string operation,
      Dictionary<string, object?> parameters)
  {
        _logger.LogInformation(
        "{Module}:{Operation} called. ParamCount={ParamCount}",
        module,
        operation,
        parameters?.Count ?? 0);

        try
    {
      // Get SP name from mapper (no hard-coded SP names!)
      var spName = ProcedureMapper.GetProcedureName(module, operation);

      _logger.LogDebug("Resolved SP name: {SpName}", spName);

      // Create request
      var request = new SmartRequest
      {
        Operation = "sp",
        SpName = spName,
        Params = parameters
      };

      // Call DataEngine
      var response = await _dataEngine.ExecuteAsync(request);

      // Return standardized JSON
      var result = JsonSerializer.Serialize(new
      {
        success = response.Success,
        data = response.Data,
        message = response.Message ?? (response.Success ? "Operation completed successfully" : "Operation failed")
      });

      _logger.LogInformation("{Module}:{Operation} completed successfully", module, operation);

      return result;
    }
    catch (InvalidOperationException ex) when (ex.Message.Contains("No stored procedure mapping"))
    {
      // ProcedureMapper couldn't find the mapping
      _logger.LogError(ex, "Stored procedure mapping not found for {Module}:{Operation}", module, operation);

      return JsonSerializer.Serialize(new
      {
        success = false,
        data = (object?)null,
        message = "حدث خطأ في إعداد العملية. يرجى التواصل مع الدعم الفني."
      });
    }
    catch (Exception ex)
    {
      // Any other error
      _logger.LogError(ex, "Error executing {Module}:{Operation}", module, operation);

      return JsonSerializer.Serialize(new
      {
        success = false,
        data = (object?)null,
        message = "حدث خطأ أثناء تنفيذ العملية. يرجى المحاولة مرة أخرى."
      });
    }
  }
}
