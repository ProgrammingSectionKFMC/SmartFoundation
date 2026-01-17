using SmartFoundation.Application.Extensions;
using SmartFoundation.Application.Services;
using SmartFoundation.DataEngine.Core.Interfaces;
using SmartFoundation.DataEngine.Core.Services;
using SmartFoundation.DataEngine.Core.Utilities;
using SmartFoundation.Mvc.Controllers;
using System.Text.Json;
using QuestPDF.Infrastructure;
using QuestPDF.Drawing;
using SmartFoundation.Mvc.Services.Exports.Pdf;
using SmartFoundation.Mvc.Services.AiAssistant;




var builder = WebApplication.CreateBuilder(args);
QuestPDF.Settings.License = LicenseType.Community;

//For report generation
QuestPDF.Settings.License = LicenseType.Community;

var fontPath = Path.Combine(builder.Environment.WebRootPath, "fonts", "Tajawal-Regular.ttf");
using (var fs = File.OpenRead(fontPath))
{
    FontManager.RegisterFont(fs);
}

// MVC controllers + views
builder.Services.AddControllersWithViews()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });

// Razor Pages (required for @page pages and ViewComponents in Layout)
builder.Services.AddRazorPages();

// Session + cache
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(o =>
{
    o.IdleTimeout = TimeSpan.FromMinutes(10);
    o.Cookie.HttpOnly = true;
    o.Cookie.IsEssential = true;
});

// Compression
builder.Services.AddResponseCompression();

// DataEngine + DI
builder.Services.AddSingleton<ConnectionFactory>();
builder.Services.AddScoped<ISmartComponentService, SmartComponentService>();
builder.Services.AddScoped<CrudController>();
builder.Services.AddScoped<IPdfExportService, QuestPdfExportService>();


// Application Layer
builder.Services.AddApplicationServices();

// AI Assistant (offline/on-prem)
builder.Services.Configure<AiAssistantOptions>(builder.Configuration.GetSection("AiAssistant"));
builder.Services.AddSingleton<IAiKnowledgeBase, FileAiKnowledgeBase>();

// Select provider
builder.Services.AddSingleton<IAiChatService>(sp =>
{
    var opt = sp.GetRequiredService<Microsoft.Extensions.Options.IOptions<AiAssistantOptions>>().Value;
    if (string.Equals(opt.Provider, "EmbeddedLlama", StringComparison.OrdinalIgnoreCase))
    {
        return ActivatorUtilities.CreateInstance<EmbeddedLlamaChatService>(sp);
    }

    // fallback: keep old Ollama if you want (optional)
    return ActivatorUtilities.CreateInstance<OllamaChatService>(sp);
});



var app = builder.Build();

app.UseResponseCompression();
app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication(); // if you have authentication; safe to keep or remove
app.UseAuthorization();

app.UseSession(); // MUST be before endpoints; only call once

// Map Razor Pages first (Layout renders a ViewComponent that is fine in both)
app.MapRazorPages();

// Also map controllers and a default route for MVC controllers
app.MapControllers();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Login}/{action=Index}/{id?}");

app.Run();
