using System.Text;
using System.Text.RegularExpressions;

namespace SmartFoundation.Mvc.Services.AiAssistant.Core;

public static class ArabicTextNormalizer
{
    private static readonly Regex MultiSpaceRegex = new(@"\s+", RegexOptions.Compiled);

    private static readonly Regex TashkeelRegex = new(
        @"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]",
        RegexOptions.Compiled);

    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return string.Empty;

        text = text.Trim();

        // Remove tashkeel
        text = TashkeelRegex.Replace(text, string.Empty);

        // Remove tatweel
        text = text.Replace("ـ", string.Empty);

        // Normalize Arabic letters
        text = text
            .Replace('أ', 'ا')
            .Replace('إ', 'ا')
            .Replace('آ', 'ا')
            .Replace('ى', 'ي')
            .Replace('ؤ', 'و')
            .Replace('ئ', 'ي')
            .Replace('ة', 'ه');

        // Normalize Arabic digits to English digits
        text = NormalizeDigits(text);

        // Replace punctuation/symbols with spaces
        text = RemoveNonLettersAndDigits(text);

        // Normalize spaces
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

    public static bool Contains(string? source, string? value)
    {
        if (string.IsNullOrWhiteSpace(source) || string.IsNullOrWhiteSpace(value))
            return false;

        var normalizedSource = Normalize(source);
        var normalizedValue = Normalize(value);

        return normalizedSource.Contains(normalizedValue, StringComparison.Ordinal);
    }

    public static bool ContainsAny(string? source, params string[] values)
    {
        if (string.IsNullOrWhiteSpace(source) || values is null || values.Length == 0)
            return false;

        var normalizedSource = Normalize(source);

        foreach (var value in values)
        {
            if (string.IsNullOrWhiteSpace(value))
                continue;

            var normalizedValue = Normalize(value);
            if (normalizedSource.Contains(normalizedValue, StringComparison.Ordinal))
                return true;
        }

        return false;
    }

    public static int CountKeywordHits(string? source, IEnumerable<string>? values)
    {
        if (string.IsNullOrWhiteSpace(source) || values is null)
            return 0;

        var normalizedSource = Normalize(source);
        int count = 0;

        foreach (var value in values)
        {
            if (string.IsNullOrWhiteSpace(value))
                continue;

            var normalizedValue = Normalize(value);
            if (normalizedSource.Contains(normalizedValue, StringComparison.Ordinal))
                count++;
        }

        return count;
    }

    private static string NormalizeDigits(string text)
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