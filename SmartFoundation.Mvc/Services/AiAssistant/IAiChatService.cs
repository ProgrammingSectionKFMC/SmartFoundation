namespace SmartFoundation.Mvc.Services.AiAssistant;

/// <summary>
/// Service interface for AI chat functionality.
/// </summary>
public interface IAiChatService
{
    /// <summary>
    /// Processes a chat message and returns AI response.
    /// </summary>
    Task<AiChatResult> ChatAsync(AiChatRequest request, CancellationToken ct);
}

/// <summary>
/// Request model for AI chat.
/// </summary>
public sealed record AiChatRequest
{
    public string Message { get; init; } = "";
    public string? PageTitle { get; init; }
    public string? PageUrl { get; init; }
    public string? PageName { get; init; }
    public string? Culture { get; init; }
    public string? UserId { get; init; }
    public string? ConversationId { get; init; }
    public string? ClientId { get; init; }
    public string? IpAddress { get; init; }
    public string? IdaraId { get; init; } // ✅ إضافة
}

/// <summary>
/// Result model for AI chat response.
/// </summary>
public sealed record AiChatResult
{
    public string Answer { get; init; } = "";
    public IReadOnlyList<KnowledgeChunk> Citations { get; init; } = Array.Empty<KnowledgeChunk>();
    public long ChatId { get; init; }
    public string? EntityKey { get; init; }
    public string? Intent { get; init; }
    
    public AiChatResult(string answer, IReadOnlyList<KnowledgeChunk> citations)
    {
        Answer = answer;
        Citations = citations;
    }
}

/// <summary>
/// Represents a knowledge chunk from the knowledge base.
/// </summary>
public sealed record KnowledgeChunk(string Source, string Text);