param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$workspaceFullPath = [System.IO.Path]::GetFullPath($WorkspaceRoot)

$code = @'
#:package ClosedXML@0.105.0
#:package HtmlAgilityPack@1.11.71

using System.Globalization;
using System.Text;
using ClosedXML.Excel;
using HtmlAgilityPack;

return Run(args);

static int Run(string[] args)
{
    if (args.Length == 0)
    {
        Console.Error.WriteLine("Workspace path is required.");
        return 1;
    }

    var root = Path.GetFullPath(args[0]);
    var jobs = new[]
    {
        new WorkbookJob(
            "07_Design/01_BasicDesign/html",
            "07_Design/01_BasicDesign/基本設計書.xlsx",
            "基本設計書"),
        new WorkbookJob(
            "07_Design/02_DetailDesign/html",
            "07_Design/02_DetailDesign/詳細設計書.xlsx",
            "詳細設計書")
    };

    foreach (var job in jobs)
    {
        BuildWorkbook(root, job);
    }

    return 0;
}

static void BuildWorkbook(string root, WorkbookJob job)
{
    var sourceDirectory = Path.Combine(root, job.SourceDirectory.Replace('/', Path.DirectorySeparatorChar));
    var outputPath = Path.Combine(root, job.OutputPath.Replace('/', Path.DirectorySeparatorChar));

    if (!Directory.Exists(sourceDirectory))
    {
        throw new DirectoryNotFoundException($"Source directory was not found: {sourceDirectory}");
    }

    var htmlFiles = Directory.GetFiles(sourceDirectory, "*.html", SearchOption.AllDirectories)
        .OrderBy(path => Path.GetFileName(path).Equals("index.html", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
        .ThenBy(path => path, StringComparer.OrdinalIgnoreCase)
        .ToList();

    using var workbook = new XLWorkbook();
    var tocSheet = workbook.AddWorksheet("00_目次");
    var textSheet = workbook.AddWorksheet("01_本文");
    var diagramSheet = workbook.AddWorksheet("02_図一覧");

    ConfigureSummarySheet(tocSheet, new[] { "ファイル", "タイトル", "表数", "本文件数", "図数", "出力シート" });
    ConfigureSummarySheet(textSheet, new[] { "ファイル", "タイトル", "セクション", "サブセクション", "種別", "本文" });
    ConfigureSummarySheet(diagramSheet, new[] { "ファイル", "タイトル", "セクション", "サブセクション", "画像", "代替テキスト" });

    tocSheet.Cell("A1").Value = job.DisplayName;
    tocSheet.Cell("A1").Style.Font.Bold = true;
    tocSheet.Cell("A2").Value = $"出力日: {DateTime.Now:yyyy-MM-dd HH:mm:ss}";
    tocSheet.Cell("A3").Value = $"対象ディレクトリ: {NormalizePath(root, sourceDirectory)}";
    WriteHeaderRow(tocSheet, 5, new[] { "ファイル", "タイトル", "表数", "本文件数", "図数", "出力シート" });

    var tocRow = 6;
    var textRow = 2;
    var diagramRow = 2;
    var sheetIndex = 3;
    var usedSheetNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        tocSheet.Name,
        textSheet.Name,
        diagramSheet.Name
    };

    foreach (var htmlFile in htmlFiles)
    {
        var doc = new HtmlDocument();
        doc.OptionFixNestedTags = true;
        doc.Load(htmlFile, Encoding.UTF8);

        var title = CleanText(doc.DocumentNode.SelectSingleNode("//title")?.InnerText) ?? Path.GetFileName(htmlFile);
        var relativePath = NormalizePath(root, htmlFile);
        var tables = doc.DocumentNode.SelectNodes("//table")?.ToList() ?? new List<HtmlNode>();
        var textItems = ExtractTextItems(doc, root, htmlFile, title);
        var diagramItems = ExtractDiagramItems(doc, root, htmlFile, title);
        var outputSheets = new List<string>();

        foreach (var textItem in textItems)
        {
            textSheet.Cell(textRow, 1).Value = textItem.File;
            textSheet.Cell(textRow, 2).Value = textItem.Title;
            textSheet.Cell(textRow, 3).Value = textItem.Section;
            textSheet.Cell(textRow, 4).Value = textItem.Subsection;
            textSheet.Cell(textRow, 5).Value = textItem.Kind;
            textSheet.Cell(textRow, 6).Value = textItem.Text;
            textRow++;
        }

        foreach (var diagramItem in diagramItems)
        {
            diagramSheet.Cell(diagramRow, 1).Value = diagramItem.File;
            diagramSheet.Cell(diagramRow, 2).Value = diagramItem.Title;
            diagramSheet.Cell(diagramRow, 3).Value = diagramItem.Section;
            diagramSheet.Cell(diagramRow, 4).Value = diagramItem.Subsection;
            diagramSheet.Cell(diagramRow, 5).Value = diagramItem.Image;
            diagramSheet.Cell(diagramRow, 6).Value = diagramItem.Alt;
            diagramRow++;
        }

        var tableCounter = 1;
        foreach (var table in tables)
        {
            var context = GetContext(table);
            var contextLabel = FirstNonEmpty(context.Subsection, context.Section, $"表{tableCounter}");
            var rawSheetName = $"{sheetIndex:00}_{Path.GetFileNameWithoutExtension(htmlFile)}_{contextLabel}";
            var sheetName = ToUniqueSheetName(rawSheetName, usedSheetNames);
            usedSheetNames.Add(sheetName);
            outputSheets.Add(sheetName);

            var sheet = workbook.AddWorksheet(sheetName);
            sheet.Cell("A1").Value = "文書タイトル";
            sheet.Cell("B1").Value = title;
            sheet.Cell("A2").Value = "ソース";
            sheet.Cell("B2").Value = relativePath;
            sheet.Cell("A3").Value = "セクション";
            sheet.Cell("B3").Value = context.Section;
            sheet.Cell("A4").Value = "サブセクション";
            sheet.Cell("B4").Value = context.Subsection;

            ApplyMetaRowStyle(sheet.Range("A1:B4"));

            var tableStartRow = 6;
            var rows = ParseTable(table);
            if (rows.Count == 0)
            {
                sheet.Cell(tableStartRow, 1).Value = "表データなし";
            }
            else
            {
                for (var rowIndex = 0; rowIndex < rows.Count; rowIndex++)
                {
                    for (var columnIndex = 0; columnIndex < rows[rowIndex].Count; columnIndex++)
                    {
                        sheet.Cell(tableStartRow + rowIndex, columnIndex + 1).Value = rows[rowIndex][columnIndex];
                    }
                }

                var headerRange = sheet.Range(tableStartRow, 1, tableStartRow, rows[0].Count);
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Fill.BackgroundColor = XLColor.FromHtml("#DDEBF7");
                headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                headerRange.Style.Border.BottomBorder = XLBorderStyleValues.Thin;
            }

            FormatDataSheet(sheet);
            tableCounter++;
            sheetIndex++;
        }

        tocSheet.Cell(tocRow, 1).Value = relativePath;
        tocSheet.Cell(tocRow, 2).Value = title;
        tocSheet.Cell(tocRow, 3).Value = tables.Count;
        tocSheet.Cell(tocRow, 4).Value = textItems.Count;
        tocSheet.Cell(tocRow, 5).Value = diagramItems.Count;
        tocSheet.Cell(tocRow, 6).Value = string.Join(", ", outputSheets);
        tocRow++;
    }

    FinalizeSheet(tocSheet, 5);
    FinalizeSheet(textSheet, 1);
    FinalizeSheet(diagramSheet, 1);

    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    workbook.SaveAs(outputPath);
    Console.WriteLine($"Created: {NormalizePath(root, outputPath)}");
}

static void ConfigureSummarySheet(IXLWorksheet sheet, IReadOnlyList<string> headers)
{
    sheet.Style.Alignment.Vertical = XLAlignmentVerticalValues.Top;
    sheet.Style.Alignment.WrapText = true;
    WriteHeaderRow(sheet, 1, headers);
}

static void WriteHeaderRow(IXLWorksheet sheet, int rowNumber, IReadOnlyList<string> headers)
{
    for (var index = 0; index < headers.Count; index++)
    {
        sheet.Cell(rowNumber, index + 1).Value = headers[index];
    }

    var headerRange = sheet.Range(rowNumber, 1, rowNumber, headers.Count);
    headerRange.Style.Font.Bold = true;
    headerRange.Style.Fill.BackgroundColor = XLColor.FromHtml("#1F4E78");
    headerRange.Style.Font.FontColor = XLColor.White;
    headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
    headerRange.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;
}

static void FinalizeSheet(IXLWorksheet sheet, int headerRow)
{
    sheet.SheetView.FreezeRows(headerRow);
    sheet.Columns().AdjustToContents();
    foreach (var column in sheet.ColumnsUsed())
    {
        if (column.Width > 60)
        {
            column.Width = 60;
        }
    }
}

static void FormatDataSheet(IXLWorksheet sheet)
{
    sheet.Style.Alignment.Vertical = XLAlignmentVerticalValues.Top;
    sheet.Style.Alignment.WrapText = true;

    var usedRange = sheet.RangeUsed();
    if (usedRange != null)
    {
        usedRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        usedRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
    }

    sheet.SheetView.FreezeRows(6);
    sheet.Columns().AdjustToContents();
    foreach (var column in sheet.ColumnsUsed())
    {
        if (column.Width > 60)
        {
            column.Width = 60;
        }
    }
}

static void ApplyMetaRowStyle(IXLRange range)
{
    range.Style.Font.Bold = true;
    range.Style.Fill.BackgroundColor = XLColor.FromHtml("#F3F6FA");
    range.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
    range.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
}

static List<List<string>> ParseTable(HtmlNode table)
{
    var rowNodes = table.SelectNodes(".//tr")?.ToList() ?? new List<HtmlNode>();
    var rows = new List<List<string>>();

    foreach (var rowNode in rowNodes)
    {
        var cells = rowNode.SelectNodes("./th|./td")?.ToList() ?? new List<HtmlNode>();
        if (cells.Count == 0)
        {
            continue;
        }

        rows.Add(cells.Select(cell => CleanText(cell.InnerText) ?? string.Empty).ToList());
    }

    var maxColumns = rows.Count == 0 ? 0 : rows.Max(row => row.Count);
    foreach (var row in rows)
    {
        while (row.Count < maxColumns)
        {
            row.Add(string.Empty);
        }
    }

    return rows;
}

static List<TextItem> ExtractTextItems(HtmlDocument document, string root, string htmlFile, string title)
{
    var candidates = document.DocumentNode.SelectNodes("//p|//li|//pre|//div[contains(@class, 'note')]|//div[contains(@class, 'info-box')]|//div[contains(@class, 'danger-box')]")?.ToList()
        ?? new List<HtmlNode>();

    var items = new List<TextItem>();
    var seen = new HashSet<string>(StringComparer.Ordinal);

    foreach (var candidate in candidates)
    {
        if (candidate.Ancestors("table").Any())
        {
            continue;
        }

        var text = CleanText(candidate.InnerText);
        if (string.IsNullOrWhiteSpace(text))
        {
            continue;
        }

        var context = GetContext(candidate);
        var kind = candidate.Name switch
        {
            "pre" => "コード/擬似コード",
            "li" => "箇条書き",
            _ => "本文"
        };

        var key = string.Join("|", NormalizePath(root, htmlFile), context.Section, context.Subsection, kind, text);
        if (!seen.Add(key))
        {
            continue;
        }

        items.Add(new TextItem(
            NormalizePath(root, htmlFile),
            title,
            context.Section,
            context.Subsection,
            kind,
            text));
    }

    return items;
}

static List<DiagramItem> ExtractDiagramItems(HtmlDocument document, string root, string htmlFile, string title)
{
    var images = document.DocumentNode.SelectNodes("//img")?.ToList() ?? new List<HtmlNode>();
    var items = new List<DiagramItem>();

    foreach (var image in images)
    {
        var context = GetContext(image);
        items.Add(new DiagramItem(
            NormalizePath(root, htmlFile),
            title,
            context.Section,
            context.Subsection,
            CleanText(image.GetAttributeValue("src", string.Empty)) ?? string.Empty,
            CleanText(image.GetAttributeValue("alt", string.Empty)) ?? string.Empty));
    }

    return items;
}

static SectionContext GetContext(HtmlNode node)
{
    var sectionNode = node.Ancestors().FirstOrDefault(current => HasClass(current, "section"));
    var subsectionNode = node.Ancestors().FirstOrDefault(current => HasClass(current, "subsection"));

    var section = CleanText(sectionNode?.SelectSingleNode(".//*[contains(@class, 'section-header')]")?.InnerText) ?? string.Empty;
    var subsection = CleanText(subsectionNode?.SelectSingleNode(".//*[contains(@class, 'subsection-title')]")?.InnerText) ?? string.Empty;

    return new SectionContext(section, subsection);
}

static bool HasClass(HtmlNode node, string className)
{
    var classes = node.GetAttributeValue("class", string.Empty)
        .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    return classes.Contains(className, StringComparer.OrdinalIgnoreCase);
}

static string NormalizePath(string root, string fullPath)
{
    return Path.GetRelativePath(root, fullPath).Replace('\\', '/');
}

static string FirstNonEmpty(params string[] values)
{
    foreach (var value in values)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }
    }

    return string.Empty;
}

static string ToUniqueSheetName(string rawName, ISet<string> usedNames)
{
    var invalidChars = new[] { '[', ']', ':', '*', '?', '/', '\\' };
    var cleaned = new string(rawName.Where(character => !invalidChars.Contains(character)).ToArray());
    cleaned = cleaned.Replace("'", string.Empty);
    cleaned = cleaned.Replace("  ", " ");
    cleaned = string.IsNullOrWhiteSpace(cleaned) ? "Sheet" : cleaned.Trim();

    var baseName = cleaned.Length > 31 ? cleaned[..31] : cleaned;
    var candidate = baseName;
    var suffix = 1;
    while (usedNames.Contains(candidate))
    {
        var suffixText = $"_{suffix}";
        var prefixLength = Math.Min(31 - suffixText.Length, baseName.Length);
        candidate = baseName[..prefixLength] + suffixText;
        suffix++;
    }

    return candidate;
}

static string? CleanText(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return null;
    }

    var normalized = HtmlEntity.DeEntitize(value)
        .Replace("\r", "\n")
        .Replace("\u00A0", " ");
    var lines = normalized
        .Split('\n', StringSplitOptions.TrimEntries)
        .Where(line => !string.IsNullOrWhiteSpace(line))
        .Select(line => string.Join(' ', line.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)));

    return string.Join("\n", lines);
}

sealed record WorkbookJob(string SourceDirectory, string OutputPath, string DisplayName);
sealed record SectionContext(string Section, string Subsection);
sealed record TextItem(string File, string Title, string Section, string Subsection, string Kind, string Text);
sealed record DiagramItem(string File, string Title, string Section, string Subsection, string Image, string Alt);
'@

$code | dotnet run - -- $workspaceFullPath