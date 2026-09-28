
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Models;

namespace SmartFoundation.Mvc.Controllers
{
    [NonController]
    public class SmartComponentController(ISmartComponentService service) : ControllerBase
    {
        private readonly ISmartComponentService _service = service;

        public async Task<ActionResult<SmartResponse>> Execute(
            SmartRequest request,
            CancellationToken ct)
        {
            var result = await _service.ExecuteAsync(request, ct);
            return Ok(result);
        }
    }
}







//using Microsoft.AspNetCore.Mvc;
//using SmartFoundation.DataEngine.Core.Interfaces;
//using SmartFoundation.DataEngine.Core.Models;

//namespace SmartFoundation.Mvc.Controllers
//{
//    [ApiController]
//    [Route("smart")]
//    public class SmartComponentController(ISmartComponentService service) : ControllerBase
//    {
//        private readonly ISmartComponentService _service = service;

//        [HttpPost("execute")]
//        public async Task<ActionResult<SmartResponse>> Execute([FromBody] SmartRequest request, CancellationToken ct)
//        {
//            var result = await _service.ExecuteAsync(request, ct);
//            return Ok(result);
//        }
//    }
//}