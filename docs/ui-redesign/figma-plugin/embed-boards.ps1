$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$importRoot = Join-Path (Split-Path -Parent $pluginRoot) "figma-import"
$templatePath = Join-Path $pluginRoot "ui.template.html"
$outputPath = Join-Path $pluginRoot "ui.html"

$boards = @(
    Get-ChildItem -LiteralPath $importRoot -Filter "*.svg" -File |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                name = $_.Name
                svg = [string](Get-Content -LiteralPath $_.FullName -Raw)
            }
        }
)

if ($boards.Count -ne 12) {
    throw "Expected 12 SVG boards, found $($boards.Count)."
}

$template = Get-Content -LiteralPath $templatePath -Raw
$payload = $boards | ConvertTo-Json -Depth 4 -Compress
$output = $template.Replace("__PARRYHOOK_BOARDS__", $payload)

if ($output -eq $template) {
    throw "Template placeholder was not found."
}

[System.IO.File]::WriteAllText(
    $outputPath,
    $output,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Embedded $($boards.Count) SVG boards into $outputPath"
