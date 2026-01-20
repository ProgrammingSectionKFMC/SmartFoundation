using Microsoft.AspNetCore.Mvc;
using SmartFoundation.Mvc.Services.AiAssistant;
using SmartFoundation.DataEngine.Core.Interfaces; // ✅ إضافة
using SmartFoundation.DataEngine.Core.Services;
using SmartFoundation.DataEngine.Core.Models;

namespace SmartFoundation.Mvc.Controllers.Api
{
    [ApiController]
    [Route("api/ai")]
    public sealed class AiController : ControllerBase
    {
        private readonly IAiChatService _chat;
        private readonly ISmartComponentService _dataEngine;
        private readonly ILogger<AiController> _log;

        public AiController(
            IAiChatService chat,
            ISmartComponentService dataEngine,
            ILogger<AiController> log)
        {
            _chat = chat;
            _dataEngine = dataEngine;
            _log = log;
        }

        [HttpPost("chat")]
        public async Task<IActionResult> Chat(
            [FromBody] AiChatRequest request,
            CancellationToken ct)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Message))
                return BadRequest("Message is required.");

            // ✅ استخراج IdaraId من Session
            var idaraIdStr = HttpContext.Session.GetString("IdaraId") ?? "1";

            var requestWithIp = request with 
            { 
                IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                IdaraId = idaraIdStr // ✅ إضافة
            };

            var result = await _chat.ChatAsync(requestWithIp, ct);
            
            return Ok(new
            {
                answer = result.Answer,
                citations = result.Citations.Select(c => new
                {
                    source = c.Source,
                    text = c.Text
                }),
                chatId = result.ChatId
            });
        }

        [HttpPost("feedback")]
        public async Task<IActionResult> Feedback([FromBody] AiFeedbackRequest request)
        {
            if (request.ChatId <= 0 || (request.Feedback != 1 && request.Feedback != -1))
                return BadRequest("Invalid feedback data");

            try
            {
                var parameters = new Dictionary<string, object>
                {
                    { "ChatId", request.ChatId },
                    { "UserFeedback", request.Feedback },
                    { "FeedbackComment", request.Comment ?? (object)DBNull.Value }
                };

                var spRequest = new SmartRequest
                {
                    Operation = "sp",
                    SpName = "dbo.sp_AiChat_SaveFeedback",
                    Params = parameters
                };

                var response = await _dataEngine.ExecuteAsync(spRequest);
                
                return Ok(new { success = response.Success, message = "شكراً على تقييمك!" });
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Failed to save feedback for ChatId={ChatId}", request.ChatId);
                return StatusCode(500, "فشل حفظ التقييم");
            }
        }
    }

    public sealed record AiFeedbackRequest(
        long ChatId, 
        int Feedback,
        string? Comment = null
    );
}
