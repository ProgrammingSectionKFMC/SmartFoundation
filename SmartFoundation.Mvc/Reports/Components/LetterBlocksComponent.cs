using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports
{
    public static class LetterBlocksComponent
    {
        public static void Compose(IContainer container, ReportResult report)
        {
            var blocks = report.LetterBlocks ?? new();

            container.PaddingHorizontal(10).Column(col =>
            {
                if (!string.IsNullOrWhiteSpace(report.LetterTitle))
                {
                    col.Item()
                        .PaddingBottom(10)
                        .AlignCenter()
                        .Text(report.LetterTitle)
                        .FontSize(report.LetterTitleFontSize)
                        .SemiBold();
                }

                foreach (var b in blocks)
                {
                    switch (b.Type)
                    {
                        case LetterBlockType.Text:
                            col.Item().Element(x => RenderTextBlock(x, b));
                            break;

                        case LetterBlockType.Table:
                            if (b.Table != null)
                                col.Item().Element(x => RenderTableBlock(x, b));
                            break;

                        case LetterBlockType.Spacer:
                            col.Item().Height(b.Height);
                            break;

                        case LetterBlockType.Divider:
                            col.Item()
                                .PaddingTop(b.PaddingTop)
                                .PaddingBottom(b.PaddingBottom)
                                .LineHorizontal(1f)
                                .LineColor("#555555");
                            break;
                    }
                }
            });
        }

        private static void RenderTextBlock(IContainer container, LetterBlock b)
        {
            var item = container
                .PaddingTop(b.PaddingTop)
                .PaddingBottom(b.PaddingBottom)
                .PaddingRight(b.PaddingRight)
                .PaddingLeft(b.PaddingLeft);

            item.Text(txt =>
            {
                txt.DefaultTextStyle(x => x.FontSize(b.FontSize));

                switch (b.Align)
                {
                    case TextAlign.Left:
                        txt.AlignLeft();
                        break;
                    case TextAlign.Center:
                        txt.AlignCenter();
                        break;
                    case TextAlign.Justify:
                        // بعض إصدارات QuestPDF لا تدعم AlignJustify
                        txt.AlignRight();
                        break;
                    default:
                        txt.AlignRight();
                        break;
                }

                var span = txt.Span(b.Text ?? "")
                              .DirectionFromRightToLeft();

                if (b.Bold)
                    span.SemiBold();

                if (b.Underline)
                    span.Underline();
            });
        }

        private static void RenderTableBlock(IContainer container, LetterBlock block)
        {
            var tableData = block.Table!;

            container
                .PaddingTop(block.PaddingTop)
                .PaddingBottom(block.PaddingBottom)
                .PaddingRight(block.PaddingRight)
                .PaddingLeft(block.PaddingLeft)
                .Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        foreach (var width in tableData.Columns)
                            columns.RelativeColumn(width);
                    });

                    foreach (var row in tableData.HeaderRows)
                    {
                        foreach (var cell in row.Cells)
                        {
                            table.Cell()
                                .ColumnSpan((uint)cell.ColumnSpan)
                                .RowSpan((uint)cell.RowSpan)
                                .Border(tableData.BorderWidth)
                                .BorderColor(tableData.BorderColor)
                                .Background(cell.BackgroundColor)
                                .Padding(tableData.CellPadding)
                                .AlignMiddle()
                                .Element(c => AlignCell(c, cell.Align))
                                .Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                        }
                    }

                    foreach (var row in tableData.Rows)
                    {
                        foreach (var cell in row.Cells)
                        {
                            table.Cell()
                                .ColumnSpan((uint)cell.ColumnSpan)
                                .RowSpan((uint)cell.RowSpan)
                                .Border(tableData.BorderWidth)
                                .BorderColor(tableData.BorderColor)
                                .Background(cell.BackgroundColor)
                                .Padding(tableData.CellPadding)
                                .AlignMiddle()
                                .Element(c => AlignCell(c, cell.Align))
                                .Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                        }
                    }
                });
        }

        private static IContainer AlignCell(IContainer container, TextAlign align)
        {
            return align switch
            {
                TextAlign.Left => container.AlignLeft(),
                TextAlign.Right => container.AlignRight(),
                _ => container.AlignCenter()
            };
        }
    }
}

