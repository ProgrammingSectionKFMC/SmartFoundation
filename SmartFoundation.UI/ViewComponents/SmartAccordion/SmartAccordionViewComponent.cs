using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartAccordion;

namespace SmartFoundation.UI.ViewComponents.SmartAccordion
{
    public sealed class SmartAccordionViewComponent : ViewComponent
    {
        public IViewComponentResult Invoke(SmartAccordionConfig model)
        {
            model ??= new SmartAccordionConfig();
            model.Items ??= new();
            model.Actions ??= new();
            return View("Default", model);
        }
    }
}
