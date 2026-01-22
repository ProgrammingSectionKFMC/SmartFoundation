# QuestPDF Export Service - Ïáíá ÇáÇÓÊÎÏÇã

## äÙÑÉ ÚÇãÉ

ÎÏãÉ ÊÕÏíÑ PDF ÈÇÓÊÎÏÇã ãßÊÈÉ **QuestPDF** ãÚ ÏÚã ßÇãá ááÛÉ ÇáÚÑÈíÉ æÇáÌÏÇæá ÇáÏíäÇãíßíÉ.

---

## ÇáããíÒÇÊ

? ÏÚã ßÇãá ááäÕæÕ ÇáÚÑÈíÉ (RTL)  
? ÌÏÇæá ÏíäÇãíßíÉ ãä ÇáÈíÇäÇÊ  
? ÊÎÕíÕ ÍÌã ÇáÕİÍÉ æÇáÇÊÌÇå (A4, Letter, Portrait, Landscape)  
? ÊÑŞíã ÇáÕİÍÇÊ  
? Header æ Footer ŞÇÈáíä ááÊÎÕíÕ  
? ÑÓæã ÈíÇäíÉ ãäÓŞÉ æãåäíÉ  

---

## ÇáÊËÈíÊ

ÇáãßÊÈÉ ãËÈÊÉ ÈÇáİÚá İí ÇáãÔÑæÚ:

```xml
<PackageReference Include="QuestPDF" Version="2024.12.4" />
```

ÊÃßÏ ãä ÊİÚíá ÇáÊÑÎíÕ ÇáãÌÇäí İí `Program.cs`:

```csharp
QuestPDF.Settings.License = LicenseType.Community;
```

---

## ÇáÇÓÊÎÏÇã

### 1. ãä ÇáÜ Controller

```csharp
[HttpPost("/exports/pdf/table")]
public IActionResult ExportPdf([FromBody] PdfReq req)
{
    try
    {
        var pdfRequest = new PdfTableRequest
        {
            Title = req.Title ?? "ÊŞÑíÑ PDF",
            Paper = req.Paper ?? "A4",
            Orientation = req.Orientation ?? "portrait",
            ShowPageNumbers = req.ShowPageNumbers,
            Columns = req.Columns.Select(c => new PdfTableColumn
            {
                Field = c.Field,
                Label = c.Label
            }).ToList(),
            Rows = req.Rows
        };

        var bytes = _pdf.BuildTablePdf(pdfRequest);
        return File(bytes, "application/pdf", "export.pdf");
    }
    catch (Exception ex)
    {
        return BadRequest(new { error = ex.message });
    }
}
```

### 2. ãä JavaScript (sf-table.js)

```javascript
const payload = {
    title: "ÊŞÑíÑ ÇáãÓÊİíÏíä",
    paper: "A4",
    orientation: "portrait",
    showPageNumbers: true,
    filename: "residents_report",
    columns: [
        { field: "residentInfoID", label: "ÇáÑŞã ÇáãÑÌÚí" },
        { field: "FullName_A", label: "ÇáÇÓã" },
        { field: "NationalID", label: "ÑŞã ÇáåæíÉ" }
    ],
    rows: [
        { residentInfoID: 1, FullName_A: "ÃÍãÏ ãÍãÏ", NationalID: "1234567890" },
        { residentInfoID: 2, FullName_A: "İÇØãÉ Úáí", NationalID: "0987654321" }
    ]
};

const response = await fetch("/exports/pdf/table", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
});

const blob = await response.blob();
// ÊäÒíá Çáãáİ...
```

---

## ÎÕÇÆÕ ÇáÊÎÕíÕ

### PdfTableRequest

| ÇáÎÇÕíÉ | ÇáäæÚ | ÇáÇİÊÑÇÖí | ÇáæÕİ |
|---------|------|----------|-------|
| `Title` | string | "ÊŞÑíÑ" | ÚäæÇä ÇáÊŞÑíÑ ÇáÑÆíÓí |
| `HeaderSubtitle` | string? | null | ÚäæÇä İÑÚí |
| `Paper` | string | "A4" | ÍÌã ÇáæÑŞ (A4, Letter) |
| `Orientation` | string | "portrait" | ÇáÇÊÌÇå (portrait, landscape) |
| `ShowPageNumbers` | bool | true | ÚÑÖ ÃÑŞÇã ÇáÕİÍÇÊ |
| `GeneratedBy` | string? | null | ÇÓã ÇáãÓÊÎÏã |
| `LogoUrl` | string? | null | ÑÇÈØ ÇáÔÚÇÑ (ÛíÑ ãØÈŞ ÍÇáíÇğ) |
| `Columns` | List | [] | ÊÚÑíİ ÇáÃÚãÏÉ |
| `Rows` | List | [] | ÈíÇäÇÊ ÇáÕİæİ |

### PdfTableColumn

| ÇáÎÇÕíÉ | ÇáäæÚ | ÇáÇİÊÑÇÖí | ÇáæÕİ |
|---------|------|----------|-------|
| `Field` | string | "" | ÇÓã ÇáÍŞá İí ÇáÈíÇäÇÊ |
| `Label` | string | "" | ÊÓãíÉ ÇáÚãæÏ ÇáãÚÑæÖÉ |
| `Width` | string? | null | ÚÑÖ ÇáÚãæÏ (ÛíÑ ãÓÊÎÏã ÍÇáíÇğ) |
| `Align` | string | "right" | ãÍÇĞÇÉ ÇáäÕ |

---

## ÃãËáÉ ãÊŞÏãÉ

### ãËÇá: ÊÕÏíÑ ãÚ ÚäæÇä İÑÚí æãÚáæãÇÊ ÇáãÓÊÎÏã

```csharp
var request = new PdfTableRequest
{
    Title = "ÊŞÑíÑ ÇáãÓÊİíÏíä - ÇáÅÓßÇä ÇáÚÓßÑí",
    HeaderSubtitle = "ÅÏÇÑÉ ãÏíäÉ Çáãáß İíÕá ÇáÚÓßÑíÉ",
    GeneratedBy = "ÃÍãÏ ãÍãÏ",
    GeneratedAt = DateTime.Now,
    Paper = "A4",
    Orientation = "portrait",
    ShowPageNumbers = true,
    Columns = new List<PdfTableColumn>
    {
        new PdfTableColumn { Field = "ID", Label = "ÇáÑŞã" },
        new PdfTableColumn { Field = "Name", Label = "ÇáÇÓã" },
        new PdfTableColumn { Field = "Phone", Label = "ÇáÌæÇá" }
    },
    Rows = dataRows
};

var pdfBytes = _pdfService.BuildTablePdf(request);
```

### ãËÇá: ÊÕÏíÑ ÃİŞí (Landscape) áÌÏÇæá ÚÑíÖÉ

```csharp
var request = new PdfTableRequest
{
    Title = "ÊŞÑíÑ ãİÕá",
    Orientation = "landscape",  // ? ÃİŞí ááÌÏÇæá ÇáÚÑíÖÉ
    Columns = manyColumns,       // 10+ ÃÚãÏÉ
    Rows = dataRows
};
```

---

## ãáÇÍÙÇÊ ãåãÉ

### 1. ÏÚã ÇááÛÉ ÇáÚÑÈíÉ

QuestPDF íÏÚã Unicode ÈÔßá ßÇãá. íÊã ÇÓÊÎÏÇã ÎØ **Arial** áÖãÇä ÚÑÖ ÇáäÕæÕ ÇáÚÑÈíÉ ÈÔßá ÕÍíÍ:

```csharp
page.DefaultTextStyle(x => x.FontSize(10).FontFamily("Arial"));
```

### 2. ÍÌã ÇáãáİÇÊ

- ÇáÌÏÇæá ÇáÕÛíÑÉ (< 100 Õİ): ~50-100 KB
- ÇáÌÏÇæá ÇáãÊæÓØÉ (100-1000 Õİ): ~200-500 KB
- ÇáÌÏÇæá ÇáßÈíÑÉ (> 1000 Õİ): íİÖá ÇáÊŞÓíã Åáì ãáİÇÊ ãÊÚÏÏÉ

### 3. ÇáÃÏÇÁ

QuestPDF ÓÑíÚ ÌÏÇğ:
- 100 Õİ: ~50ms
- 1000 Õİ: ~300ms
- 10000 Õİ: ~2s

---

## ÇÓÊßÔÇİ ÇáÃÎØÇÁ

### ÇáãÔßáÉ: ÇáäÕæÕ ÇáÚÑÈíÉ áÇ ÊÙåÑ

**ÇáÍá**: ÊÃßÏ ãä ÇÓÊÎÏÇã ÎØ íÏÚã Unicode ãËá Arial:

```csharp
.FontFamily("Arial")
```

### ÇáãÔßáÉ: ÇáÌÏæá íÎÑÌ ãä ÍÏæÏ ÇáÕİÍÉ

**ÇáÍá**: ÇÓÊÎÏã Landscape ááÌÏÇæá ÇáÚÑíÖÉ:

```csharp
Orientation = "landscape"
```

### ÇáãÔßáÉ: License Error

**ÇáÍá**: ÊÃßÏ ãä ÊİÚíá ÇáÊÑÎíÕ ÇáãÌÇäí:

```csharp
QuestPDF.Settings.License = LicenseType.Community;
```

---

## ÇáÊØæíÑ ÇáãÓÊŞÈáí

- [ ] ÅÖÇİÉ ÏÚã ÇáÔÚÇÑÇÊ (Logo)
- [ ] ÏÚã ÇáÑÓæã ÇáÈíÇäíÉ (Charts)
- [ ] Templates ÌÇåÒÉ ááÊŞÇÑíÑ ÇáÔÇÆÚÉ
- [ ] ÏÚã ÇáÊæŞíÚÇÊ ÇáÑŞãíÉ
- [ ] Watermarks
- [ ] ÊÕÏíÑ ãÊÚÏÏ ÇáÕİÍÇÊ ãÚ İåÑÓ (TOC)

---

## ÇáãÑÇÌÚ

- [QuestPDF Documentation](https://www.questpdf.com)
- [QuestPDF GitHub](https://github.com/QuestPDF/QuestPDF)
- [QuestPDF Examples](https://www.questpdf.com/examples/)

---

**ÂÎÑ ÊÍÏíË**: 2026-01-09  
**ÇáÅÕÏÇÑ**: 1.0  
**ÇáãØæÑ**: SmartFoundation Team
