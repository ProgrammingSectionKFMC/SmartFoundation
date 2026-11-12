using Microsoft.AspNetCore.Mvc;
using SmartFoundation.UI.ViewModels.SmartDynamicFields;

namespace SmartFoundation.UI.ViewComponents.SmartDynamicFields
{
    public sealed class SmartDynamicFieldsViewComponent : ViewComponent
    {
        public IViewComponentResult Invoke(SmartDynamicFieldsConfig model)
        {
            ArgumentNullException.ThrowIfNull(model);

            model.Id = model.Id?.Trim() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(model.Id))
                throw new ArgumentException("SmartDynamicFields requires a non-empty Id.", nameof(model));

            if (model.MinRows < 0)
                throw new ArgumentOutOfRangeException(nameof(model), "MinRows cannot be negative.");

            if (model.MaxRows < 1 || model.MaxRows < model.MinRows)
                throw new ArgumentOutOfRangeException(nameof(model), "MaxRows must be at least one and not less than MinRows.");

            model.Fields ??= new();
            model.InitialRows ??= new();

            if (model.Fields.Count == 0)
                throw new ArgumentException("SmartDynamicFields requires at least one field definition.", nameof(model));

            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var field in model.Fields)
            {
                field.Name = field.Name?.Trim() ?? string.Empty;
                field.Label = field.Label?.Trim() ?? string.Empty;
                field.Options ??= new();

                if (string.IsNullOrWhiteSpace(field.Name))
                    throw new ArgumentException("Every SmartDynamicFields field requires a name.", nameof(model));

                if (!names.Add(field.Name))
                    throw new ArgumentException($"Duplicate SmartDynamicFields field name: {field.Name}", nameof(model));

                if (field.MaxLength is <= 0)
                    throw new ArgumentOutOfRangeException(nameof(model), $"MaxLength for field '{field.Name}' must be positive.");
            }

            if (model.InitialRows.Count > model.MaxRows)
                throw new ArgumentException("InitialRows cannot exceed MaxRows.", nameof(model));

            model.Direction = string.Equals(model.Direction, "ltr", StringComparison.OrdinalIgnoreCase)
                ? "ltr"
                : "rtl";

            return View("Default", model);
        }
    }
}
