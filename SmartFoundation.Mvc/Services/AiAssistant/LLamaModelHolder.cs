using LLama;
using LLama.Common;

namespace SmartFoundation.Mvc.Services.AiAssistant;

/// <summary>
/// Singleton holder for LLama model to avoid loading it multiple times.
/// </summary>
public sealed class LLamaModelHolder : IDisposable
{
    public LLamaWeights Weights { get; }
    public string ModelPath { get; }
    public uint ContextSize { get; }
    public int Threads { get; }

    public LLamaModelHolder(
        AiAssistantOptions opt,
        IWebHostEnvironment env,
        ILogger<LLamaModelHolder> log)
    {
        ModelPath = opt.ModelPath ?? "AiModels\\model.gguf";
        if (!Path.IsPathRooted(ModelPath))
            ModelPath = Path.Combine(env.ContentRootPath, ModelPath);

        if (!File.Exists(ModelPath))
            throw new FileNotFoundException($"AI model not found: {ModelPath}");

        ContextSize = (uint)Math.Clamp(opt.ContextSize, 512, 8192);
        Threads = Math.Max(1, opt.Threads);

        var p = new ModelParams(ModelPath)
        {
            ContextSize = ContextSize,
            Threads = Threads,
        };

        Weights = LLamaWeights.LoadFromFile(p);

        log.LogInformation(
            "LLama Model loaded (Singleton): {Path} | ctx={Ctx} | threads={Threads}",
            ModelPath, ContextSize, Threads);
    }

    public void Dispose()
    {
        try { Weights?.Dispose(); } catch { }
    }
}