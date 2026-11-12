using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports
{
    public static class LetterBlocksComponent
    {
        public static void Compose(IContainer container, ReportResult report)
        {
            var blocks = report.LetterBlocks ?? new();

            var hasStretchTable = blocks.Any(b => b.Type == LetterBlockType.Table && b.Table?.ExtendVertical == true);

            var outer = container;
            if (hasStretchTable)
                outer = outer.ExtendVertical();

            outer.Column(col =>
            {
                if (!string.IsNullOrWhiteSpace(report.LetterTitle))
                {
                    col.Item()
                        .PaddingHorizontal(10)
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
                            col.Item().PaddingHorizontal(10).Element(x => RenderTextBlock(x, b));
                            break;

                        case LetterBlockType.Table:
                            if (b.Table != null)
                            {
                                var tableItem = col.Item().PaddingHorizontal(10);
                                if (b.Table.ExtendVertical)
                                    tableItem = tableItem.ExtendVertical();
                                tableItem.Element(x => RenderTableBlock(x, b));
                            }
                            break;

                        case LetterBlockType.Footer:
                            col.Item()
                                .PaddingTop(b.PaddingTop)
                                .PaddingBottom(b.PaddingBottom)
                                .Row(row =>
                                {
                                    row.RelativeItem().AlignRight().Text(b.FooterRight).FontSize(b.FooterFontSize).DirectionFromRightToLeft();
                                    row.RelativeItem().AlignCenter().Text(b.FooterCenter).FontSize(b.FooterFontSize).DirectionFromRightToLeft();
                                    row.RelativeItem().AlignLeft().Text(b.FooterLeft).FontSize(b.FooterFontSize);
                                });
                            break;

                        case LetterBlockType.Spacer:
                            col.Item().Height(b.Height);
                            break;

                        case LetterBlockType.Divider:
                            col.Item()
                                .PaddingHorizontal(10)
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

            var tc = container
                .PaddingTop(block.PaddingTop)
                .PaddingBottom(block.PaddingBottom)
                .PaddingRight(block.PaddingRight)
                .PaddingLeft(block.PaddingLeft);

            if (tableData.ExtendVertical)
                tc = tc.ExtendVertical();

            tc.Table(table =>
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
                        var isStretchRow = row.ExtendVertical;
                        var rowMinHeight = row.MinRowHeight > 0 ? row.MinRowHeight : tableData.MinRowHeight;

                        foreach (var cell in row.Cells)
                        {
                            var tableCell = table.Cell()
                                .ColumnSpan((uint)cell.ColumnSpan)
                                .RowSpan((uint)cell.RowSpan)
                                .Border(tableData.BorderWidth)
                                .BorderColor(tableData.BorderColor)
                                .Background(cell.BackgroundColor)
                                .Padding(tableData.CellPadding)
                                .AlignMiddle()
                                .Element(c => AlignCell(c, cell.Align));

                            if (isStretchRow && rowMinHeight > 0)
                            {
                                tableCell.MinHeight(rowMinHeight).Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                            }
                            else if (isStretchRow)
                            {
                                tableCell.ExtendVertical().Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                            }
                            else if (rowMinHeight > 0)
                            {
                                tableCell.MinHeight(rowMinHeight).Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                            }
                            else
                            {
                                tableCell.Text(t =>
                                {
                                    var span = t.Span(cell.Text ?? "")
                                        .FontSize(cell.FontSize)
                                        .DirectionFromRightToLeft();

                                    if (cell.Bold)
                                        span.SemiBold();
                                });
                            }
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

