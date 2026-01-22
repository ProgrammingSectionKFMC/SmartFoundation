using Microsoft.AspNetCore.Mvc;

namespace SmartFoundation.Mvc.Services.AiAssistant;

public sealed class AiAssistantOptions
{
    public bool Enabled { get; set; } = true;
    public string Provider { get; set; } = "Ollama";
    public string BaseUrl { get; set; } = "http://localhost:11434";
    public string Model { get; set; } = "llama3.1:8b";
    public string KnowledgeBasePath { get; set; } = "AiDocs/UserHelp";
    public int RetrievalTopK { get; set; } = 5;
    public int MaxTokens { get; set; } = 512;
    public double Temperature { get; set; } = 0.2;
    public int ContextSize { get; set; } = 4096;
    public int Threads { get; set; } = 8;
    public int MaxParallelRequests { get; set; } = 2;
    public string ModelPath { get; set; } = "AiModels\\model.gguf";

}
