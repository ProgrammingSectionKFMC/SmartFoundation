using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace SmartFoundation.MVC.Reports;

public static class HeaderFactory
{
    public static void Compose(IContainer container, ReportResult report)
    {
        switch (report.HeaderType)
        {
            case ReportHeaderType.LetterOfficial:
                OfficialLetterHeaderComponent.Compose(container, report);
                break;

            //case ReportHeaderType.WithLogoRight:
            //    LogoHeaderComponent.Compose(container, report, logoOnRight: true);
            //    break;

            default:
                StandardHeaderComponent.Compose(container, report);
                break;
        }
    }
}

