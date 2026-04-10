using System.Text;
using System.Text.RegularExpressions;

namespace SmartFoundation.Mvc.Services.AiAssistant;

public static class ArabicTextNormalizer1
{
    private static readonly Regex MultiSpaceRegex = new(@"\s+", RegexOptions.Compiled);
    private static readonly Regex TashkeelRegex = new(
        @"[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]",
        RegexOptions.Compiled);

    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return string.Empty;

        text = text.Trim();

        text = TashkeelRegex.Replace(text, "");
        text = text.Replace("ـ", ""); // tatweel

        text = text
            .Replace('أ', 'ا')
            .Replace('إ', 'ا')
            .Replace('آ', 'ا')
            .Replace('ى', 'ي')
            .Replace('ؤ', 'و')
            .Replace('ئ', 'ي')
            .Replace('ة', 'ه');

        text = NormalizeEnglishDigits(text);
        text = RemoveNonLettersAndDigits(text);

        text = MultiSpaceRegex.Replace(text, " ").Trim();
        return text;
    }

    public static string[] Tokenize(string? text)
    {
        var normalized = Normalize(text);
        if (string.IsNullOrWhiteSpace(normalized))
            return Array.Empty<string>();

        return normalized
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string NormalizeEnglishDigits(string text)
    {
        var sb = new StringBuilder(text.Length);

        foreach (var ch in text)
        {
            sb.Append(ch switch
            {
                '٠' => '0',
                '١' => '1',
                '٢' => '2',
                '٣' => '3',
                '٤' => '4',
                '٥' => '5',
                '٦' => '6',
                '٧' => '7',
                '٨' => '8',
                '٩' => '9',
                _ => ch
            });
        }

        return sb.ToString();
    }

    private static string RemoveNonLettersAndDigits(string text)
    {
        var sb = new StringBuilder(text.Length);

        foreach (var ch in text)
        {
            if (char.IsLetterOrDigit(ch) || char.IsWhiteSpace(ch))
                sb.Append(ch);
            else
                sb.Append(' ');
        }

        return sb.ToString();
    }
}