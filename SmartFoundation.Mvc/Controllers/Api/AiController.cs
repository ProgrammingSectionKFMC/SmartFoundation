using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.AiAssistant;

namespace SmartFoundation.Mvc.Controllers.Api
{
    [ApiController]
    [Route("api/ai")]
    public sealed class AiController : ControllerBase
    {
        private readonly IAiChatService _chat;

        public AiController(IAiChatService chat)
        {
            _chat = chat;
        }

        [HttpPost("chat")]
        public async Task<IActionResult> Chat(
            [FromBody] AiChatRequest request,
            CancellationToken ct)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Message))
                return BadRequest("Message is required.");

            var result = await _chat.ChatAsync(request, ct);
            return Ok(result);
        }
    }
}
