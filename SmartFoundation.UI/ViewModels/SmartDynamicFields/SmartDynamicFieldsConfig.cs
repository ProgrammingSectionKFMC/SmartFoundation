namespace SmartFoundation.UI.ViewModels.SmartDynamicFields
{
    public enum SmartDynamicFieldType
    {
        Hidden,
        Text,
        Textarea,
        Number,
        Date,
        Select,
        Checkbox
    }

    public sealed class SmartDynamicFieldOption
    {
        public string Value { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
        public bool Disabled { get; set; }
    }

    public sealed class SmartDynamicFieldDefinition
    {
        public string Name { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public SmartDynamicFieldType Type { get; set; } = SmartDynamicFieldType.Text;
        public string? Placeholder { get; set; }
        public string? HelpText { get; set; }
        public string? ColCss { get; set; } = "col-span-12";
        public bool Required { get; set; }
        public bool Readonly { get; set; }
        public bool Disabled { get; set; }
        public int? Min { get; set; }
        public int? Max { get; set; }
        public int? MaxLength { get; set; }
        public List<SmartDynamicFieldOption> Options { get; set; } = new();
    }

    public sealed class SmartDynamicFieldsConfig
    {
        // Must be unique on the current HTML page, including modal content.
        public string Id { get; set; } = string.Empty;
        public string? FormId { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }

        // Optional hidden input receiving the canonical JSON row array.
        public string? OutputName { get; set; }
        public bool RenderOutputInput { get; set; } = true;
        public bool SyncOutputOnChange { get; set; } = true;
        public string? RowNumberProperty { get; set; }

        public int MinRows { get; set; } = 1;
        public int MaxRows { get; set; } = 16;
        public bool AllowAdd { get; set; } = true;
        public bool AllowRemove { get; set; } = true;
        public bool AllowReorder { get; set; }
        public bool Readonly { get; set; }
        public bool Disabled { get; set; }
        public string Direction { get; set; } = "rtl";

        public string AddButtonText { get; set; } = "إضافة";
        public string RemoveButtonText { get; set; } = "حذف";
        public string MoveUpText { get; set; } = "تحريك لأعلى";
        public string MoveDownText { get; set; } = "تحريك لأسفل";
        public string EmptyValidationMessage { get; set; } = "يجب إدخال صف واحد على الأقل";
        public string MaxRowsMessage { get; set; } = "تم الوصول إلى الحد الأقصى";

        public List<SmartDynamicFieldDefinition> Fields { get; set; } = new();
        public List<Dictionary<string, object?>> InitialRows { get; set; } = new();
    }
}
