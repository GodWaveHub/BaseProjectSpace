<#
.SYNOPSIS
    Convert Mermaid (.mmd) to SVG using Kroki API.

.DESCRIPTION
    Sends Mermaid text to Kroki (default: https://kroki.io/mermaid/svg) and saves SVG.
    Intended for design documents. No Docker is used.

.PARAMETER InputPath
    Path to a .mmd file.

.PARAMETER OutputPath
    Path to output .svg. If omitted, replaces .mmd with .svg.

.PARAMETER KrokiUrl
    Kroki endpoint.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateScript({
        if (-not (Test-Path $_)) { throw "Input file not found: $_" }
        if ($_ -notmatch '\.mmd$') { throw "Input file must have .mmd extension: $_" }
        return $true
    })]
    [string]$InputPath,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$KrokiUrl = "https://kroki.io/mermaid/svg"
)

begin {
    Write-Host "=== Mermaid to SVG Converter ===" -ForegroundColor Cyan
    Write-Host ("Kroki API: {0}" -f $KrokiUrl) -ForegroundColor Gray
    Write-Host ""
}

process {
    try {
        $inputFile = Get-Item -Path $InputPath -ErrorAction Stop
        Write-Host ("Input:  {0}" -f $inputFile.FullName) -ForegroundColor Green

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = $inputFile.FullName -replace '\.mmd$', '.svg'
        }

        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        Write-Host ("Output: {0}" -f $OutputPath) -ForegroundColor Green

        $mermaidContent = Get-Content -Path $inputFile.FullName -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($mermaidContent)) {
            throw "Input file is empty."
        }

        if ($mermaidContent -notmatch '(graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram|gantt|pie|flowchart)') {
            Write-Warning "Mermaid syntax keyword not detected. The diagram may be invalid."
        }

        $headers = @{ "Content-Type" = "text/plain; charset=utf-8" }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($mermaidContent)

        Invoke-WebRequest -Uri $KrokiUrl -Method Post -Body $bytes -Headers $headers -OutFile $OutputPath -ErrorAction Stop

        [PSCustomObject]@{
            InputFile  = $inputFile.FullName
            OutputFile = $OutputPath
            Success    = $true
            FileSize   = (Get-Item $OutputPath).Length
        }

        Write-Host "OK" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host ("FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "" 

        [PSCustomObject]@{
            InputFile  = $InputPath
            OutputFile = $OutputPath
            Success    = $false
            Error      = $_.Exception.Message
        }
    }
}

end {
    Write-Host "=== Done ===" -ForegroundColor Cyan
}
