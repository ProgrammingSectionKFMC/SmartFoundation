using SmartFoundation.DataEngine.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace SmartFoundation.Application.Services
{
    public class VehicleService : BaseService
    {
        public VehicleService(
            ISmartComponentService dataEngine,
            ILogger<VehicleService> logger)
            : base(dataEngine, logger)
        {
        }

        public async Task<string> GetVehicleList(Dictionary<string, object?> parameters)
        {
            return await ExecuteOperation("vehicle", "list", parameters);
        }
    }
}