using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartPrint;
//SmartFoundation\SmartFoundation.UI\ViewComponents\SmartPrint
namespace SmartFoundation.UI.ViewComponents.SmartPrint
{
    public class SmartPrintViewComponent : ViewComponent
    {
        public IViewComponentResult Invoke(SmartPrintConfig model) => View("Default", model);
    }
}
