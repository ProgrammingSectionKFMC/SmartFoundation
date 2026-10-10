
using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartDrawer;

namespace SmartFoundation.UI.ViewComponents.SmartDrawer
{
    public class SmartDrawerViewComponent : ViewComponent
    {
        public IViewComponentResult Invoke(SmartDrawerConfig model)
        {
            return View("Default", model);
        }
    }
}
