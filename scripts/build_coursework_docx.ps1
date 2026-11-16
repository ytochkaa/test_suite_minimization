param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDocx,
    [Parameter(Mandatory = $true)]
    [string]$ChapterMarkdown,
    [Parameter(Mandatory = $true)]
    [string]$OutputDocx
)

$ErrorActionPreference = 'Stop'
$wordNamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$xmlNamespace = 'http://www.w3.org/XML/1998/namespace'

function Add-WordAttribute {
    param(
        [System.Xml.XmlDocument]$Document,
        [System.Xml.XmlElement]$Element,
        [string]$Name,
        [string]$Value
    )
    $attribute = $Document.CreateAttribute('w', $Name, $wordNamespace)
    $attribute.Value = $Value
    [void]$Element.Attributes.Append($attribute)
}

function New-WordParagraph {
    param(
        [System.Xml.XmlDocument]$Document,
        [string]$Text,
        [string]$Style = 'a',
        [bool]$Bold = $false,
        [bool]$Code = $false,
        [bool]$PageBreakBefore = $false
    )

    $paragraph = $Document.CreateElement('w', 'p', $wordNamespace)
    $paragraphProperties = $Document.CreateElement('w', 'pPr', $wordNamespace)
    $paragraphStyle = $Document.CreateElement('w', 'pStyle', $wordNamespace)
    Add-WordAttribute $Document $paragraphStyle 'val' $Style
    [void]$paragraphProperties.AppendChild($paragraphStyle)

    if ($PageBreakBefore) {
        $pageBreak = $Document.CreateElement('w', 'pageBreakBefore', $wordNamespace)
        [void]$paragraphProperties.AppendChild($pageBreak)
    }

    if ($Code) {
        $spacing = $Document.CreateElement('w', 'spacing', $wordNamespace)
        Add-WordAttribute $Document $spacing 'before' '0'
        Add-WordAttribute $Document $spacing 'after' '0'
        Add-WordAttribute $Document $spacing 'line' '240'
        Add-WordAttribute $Document $spacing 'lineRule' 'auto'
        [void]$paragraphProperties.AppendChild($spacing)
    }

    [void]$paragraph.AppendChild($paragraphProperties)
    $run = $Document.CreateElement('w', 'r', $wordNamespace)

    if ($Bold -or $Code) {
        $runProperties = $Document.CreateElement('w', 'rPr', $wordNamespace)
        if ($Bold) {
            [void]$runProperties.AppendChild($Document.CreateElement('w', 'b', $wordNamespace))
        }
        if ($Code) {
            $fonts = $Document.CreateElement('w', 'rFonts', $wordNamespace)
            Add-WordAttribute $Document $fonts 'ascii' 'Consolas'
            Add-WordAttribute $Document $fonts 'hAnsi' 'Consolas'
            [void]$runProperties.AppendChild($fonts)
            $size = $Document.CreateElement('w', 'sz', $wordNamespace)
            Add-WordAttribute $Document $size 'val' '18'
            [void]$runProperties.AppendChild($size)
        }
        [void]$run.AppendChild($runProperties)
    }

    $textNode = $Document.CreateElement('w', 't', $wordNamespace)
    $spaceAttribute = $Document.CreateAttribute('xml', 'space', $xmlNamespace)
    $spaceAttribute.Value = 'preserve'
    [void]$textNode.Attributes.Append($spaceAttribute)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$paragraph.AppendChild($run)
    return $paragraph
}

function New-WordTable {
    param(
        [System.Xml.XmlDocument]$Document,
        [object[]]$Rows
    )

    $table = $Document.CreateElement('w', 'tbl', $wordNamespace)
    $tableProperties = $Document.CreateElement('w', 'tblPr', $wordNamespace)
    $borders = $Document.CreateElement('w', 'tblBorders', $wordNamespace)
    foreach ($side in @('top', 'left', 'bottom', 'right', 'insideH', 'insideV')) {
        $border = $Document.CreateElement('w', $side, $wordNamespace)
        Add-WordAttribute $Document $border 'val' 'single'
        Add-WordAttribute $Document $border 'sz' '4'
        Add-WordAttribute $Document $border 'space' '0'
        Add-WordAttribute $Document $border 'color' '808080'
        [void]$borders.AppendChild($border)
    }
    [void]$tableProperties.AppendChild($borders)
    [void]$table.AppendChild($tableProperties)

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Document.CreateElement('w', 'tr', $wordNamespace)
        foreach ($cellValue in $Rows[$rowIndex]) {
            $cell = $Document.CreateElement('w', 'tc', $wordNamespace)
            $cellProperties = $Document.CreateElement('w', 'tcPr', $wordNamespace)
            $verticalAlignment = $Document.CreateElement('w', 'vAlign', $wordNamespace)
            Add-WordAttribute $Document $verticalAlignment 'val' 'center'
            [void]$cellProperties.AppendChild($verticalAlignment)
            [void]$cell.AppendChild($cellProperties)
            $cleanValue = ($cellValue -replace '`', '' -replace '\*\*', '').Trim()
            [void]$cell.AppendChild((New-WordParagraph $Document $cleanValue 'a' ($rowIndex -eq 0)))
            [void]$row.AppendChild($cell)
        }
        [void]$table.AppendChild($row)
    }
    return $table
}

$sourcePath = (Resolve-Path -LiteralPath $SourceDocx).Path
$chapterPath = (Resolve-Path -LiteralPath $ChapterMarkdown).Path
$outputPath = [System.IO.Path]::GetFullPath($OutputDocx)
$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$workDirectory = Join-Path $env:TEMP ('coursework-docx-' + [Guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $workDirectory 'source.zip'
$unpackedPath = Join-Path $workDirectory 'unpacked'
New-Item -ItemType Directory -Force -Path $workDirectory, $unpackedPath | Out-Null

try {
    Copy-Item -LiteralPath $sourcePath -Destination $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $unpackedPath -Force
    $documentPath = Join-Path $unpackedPath 'word/document.xml'
    [xml]$document = Get-Content -LiteralPath $documentPath -Raw -Encoding UTF8
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $namespaceManager.AddNamespace('w', $wordNamespace)
    $body = $document.SelectSingleNode('//w:body', $namespaceManager)
    $sectionProperties = $body.SelectSingleNode('./w:sectPr', $namespaceManager)

    $existingText = ($document.SelectNodes('//w:t', $namespaceManager) | ForEach-Object { $_.InnerText }) -join ' '
    if ($existingText -match 'ГЛАВА 2\. ПРАКТИЧЕСКАЯ ЧАСТЬ') {
        throw 'В исходном документе уже есть практическая глава.'
    }

    $lines = Get-Content -LiteralPath $chapterPath -Encoding UTF8
    $inCodeBlock = $false
    $tableRows = New-Object System.Collections.Generic.List[object]

    function Flush-Table {
        if ($tableRows.Count -gt 0) {
            $table = New-WordTable $document $tableRows.ToArray()
            [void]$body.InsertBefore($table, $sectionProperties)
            $tableRows.Clear()
        }
    }

    foreach ($rawLine in $lines) {
        $line = $rawLine.TrimEnd()

        if ($line -eq '```json') {
            Flush-Table
            $inCodeBlock = $true
            continue
        }
        if ($line -eq '```') {
            $inCodeBlock = $false
            continue
        }
        if ($inCodeBlock) {
            [void]$body.InsertBefore((New-WordParagraph $document $rawLine 'a' $false $true), $sectionProperties)
            continue
        }

        if ($line -match '^\|.*\|$') {
            if ($line -match '^\|[\s:|-]+\|$') {
                continue
            }
            $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            [void]$tableRows.Add($cells)
            continue
        }

        Flush-Table
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $cleanLine = $line -replace '`', '' -replace '\*\*', ''
        if ($cleanLine -match '^# (.+)$') {
            [void]$body.InsertBefore((New-WordParagraph $document $matches[1] '1' $false $false $true), $sectionProperties)
        } elseif ($cleanLine -match '^## (.+)$') {
            [void]$body.InsertBefore((New-WordParagraph $document $matches[1] '2'), $sectionProperties)
        } elseif ($cleanLine -match '^### (.+)$') {
            [void]$body.InsertBefore((New-WordParagraph $document $matches[1] '3'), $sectionProperties)
        } elseif ($cleanLine -match '^- (.+)$') {
            [void]$body.InsertBefore((New-WordParagraph $document ('— ' + $matches[1]) 'a9'), $sectionProperties)
        } elseif ($cleanLine -match '^\d+\. (.+)$') {
            [void]$body.InsertBefore((New-WordParagraph $document $cleanLine 'a9'), $sectionProperties)
        } else {
            [void]$body.InsertBefore((New-WordParagraph $document $cleanLine 'a'), $sectionProperties)
        }
    }
    Flush-Table

    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($documentPath, $document.OuterXml, $utf8WithoutBom)

    $temporaryOutput = Join-Path $workDirectory 'output.zip'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipStream = [System.IO.File]::Open($temporaryOutput, [System.IO.FileMode]::Create)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive(
            $zipStream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($file in Get-ChildItem -LiteralPath $unpackedPath -Recurse -File) {
                $relativePath = $file.FullName.Substring($unpackedPath.Length).TrimStart('\', '/') -replace '\\', '/'
                $entry = $archive.CreateEntry($relativePath, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                $fileStream = [System.IO.File]::OpenRead($file.FullName)
                try {
                    $fileStream.CopyTo($entryStream)
                } finally {
                    $fileStream.Dispose()
                    $entryStream.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }
    Copy-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
} finally {
    if (Test-Path -LiteralPath $workDirectory) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force
    }
}

Write-Output $outputPath



