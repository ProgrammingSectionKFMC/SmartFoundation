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
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
QuestPDF.Settings.License = LicenseType.Community;

var fontPath = Path.Combine(builder.Environment.WebRootPath, "fonts", "Tajawal-Regular.ttf");
using (var fs = File.OpenRead(fontPath))
{
    FontManager.RegisterFont(fs);
}

builder.Services.AddControllersWithViews()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });

builder.Services.AddRazorPages();

builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(o =>
{
    o.IdleTimeout = TimeSpan.FromMinutes(10);
    o.Cookie.HttpOnly = true;
    o.Cookie.IsEssential = true;
});

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

// ✅ الحل: تحميل LLM Model مرة واحدة كـ Singleton منفصل
builder.Services.AddSingleton<LLamaModelHolder>(sp =>
{
    var opt = sp.GetRequiredService<IOptions<AiAssistantOptions>>().Value;
    var env = sp.GetRequiredService<IWebHostEnvironment>();
    var log = sp.GetRequiredService<ILogger<LLamaModelHolder>>();
    
    return new LLamaModelHolder(opt, env, log);
});

// ✅ تغيير من Singleton إلى Scoped
builder.Services.AddScoped<IAiChatService, EmbeddedLlamaChatService>();

var app = builder.Build();

app.UseResponseCompression();
app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.UseSession();

app.MapRazorPages();
app.MapControllers();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Login}/{action=Index}/{id?}");
    //pattern: "{controller=Statistics}/{action=Index}/{id?}");

app.Run();