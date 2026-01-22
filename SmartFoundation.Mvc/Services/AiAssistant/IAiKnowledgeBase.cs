namespace SmartFoundation.Mvc.Services.AiAssistant
{
    public interface IAiKnowledgeBase
    {
        IReadOnlyList<KnowledgeChunk> Search(string query, int topK);

        string? GetDocumentBySource(string source);
    }
}
