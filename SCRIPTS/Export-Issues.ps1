[CmdletBinding()]
param(
    [string]$Repo,

    [string]$OutputDir = (Join-Path -Path (Get-Location) -ChildPath "issues-export"),

    [ValidateSet("open", "closed", "all")]
    [string]$State = "all",

    [ValidateRange(1, 1000)]
    [int]$Limit = 1000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# UTF8エンコーディングを強制し、日本語の文字化けを防ぐ
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) was not found. Install it first, then run 'gh auth login'."
}

& gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI authentication is required. Run 'gh auth login' first."
}

$resolvedOutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$timestamp = Get-Date -Format "yyyyMMddHH"
$csvPath = Join-Path -Path $resolvedOutputDir -ChildPath "$($timestamp)_issue_list.csv"

# Issueの本文(Body)から親子関係や期間などのメタデータを抽出するための正規表現
# 運用ルールとして以下の形式のHTMLコメントが含まれていることを想定します。
# <!-- parent: #123 -->, <!-- level: 設計 -->, <!-- detail: 詳細 -->
# <!-- start: 2026-05-01 -->, <!-- end: 2026-05-15 -->, <!-- progress: 50% -->

$ghArgs = @(
    "issue",
    "list",
    "--state",
    $State,
    "--limit",
    $Limit.ToString(),
    "--json",
    "number,title,body,state,createdAt,updatedAt"
)

if ($Repo) {
    $ghArgs += @("--repo", $Repo)
}

# 出力を文字列として取得し、空文字でないことを確認
$jsonText = & gh @ghArgs | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "Failed to export issues with 'gh issue list'."
}

$issues = if ([string]::IsNullOrWhiteSpace($jsonText)) {
    @()
} else {
    @($jsonText | ConvertFrom-Json)
}

# GitHub GraphQL API を用いてネイティブの Sub-issue (parent) 情報を取得する
$nativeParents = @{}
$gqlQuery = 'query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { issues(first: 100) { nodes { number parent { number } } } } }'
$oldGhRepo = $env:GH_REPO
if ($Repo) { $env:GH_REPO = $Repo }

try {
    $gqlOutput = & gh api graphql -F owner='{owner}' -F name='{repo}' -f query=$gqlQuery | Out-String
    if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($gqlOutput))) {
        $gqlJson = $gqlOutput | ConvertFrom-Json
        foreach ($node in $gqlJson.data.repository.issues.nodes) {
            if ($null -ne $node.parent) {
                $nativeParents[$node.number.ToString()] = $node.parent.number.ToString()
            }
        }
    }
} catch {
    # 失敗時は無視してタグ解析にフォールバック
} finally {
    if ($Repo) { $env:GH_REPO = $oldGhRepo }
}

# パースと情報の構築
$issueMap = @{}
foreach ($i in $issues) {
    $parentMatch = [regex]::Match($i.body, "(?i)<!--\s*parent:\s*#?(\d+)\s*-->")
    # ネイティブの Sub-issue を優先し、設定されていなければ本文のタグを参照する
    $parent = if ($nativeParents.ContainsKey($i.number.ToString())) {
        $nativeParents[$i.number.ToString()]
    } elseif ($parentMatch.Success) {
        $parentMatch.Groups[1].Value
    } else {
        $null
    }
    
    $startMatch = [regex]::Match($i.body, "(?i)<!--\s*start:\s*(.*?)\s*-->")
    $start = if ($startMatch.Success) { $startMatch.Groups[1].Value } else { "" }

    $endMatch = [regex]::Match($i.body, "(?i)<!--\s*end:\s*(.*?)\s*-->")
    $end = if ($endMatch.Success) { $endMatch.Groups[1].Value } else { "" }

    $progressMatch = [regex]::Match($i.body, "(?i)<!--\s*progress:\s*(.*?)\s*-->")
    $progress = if ($progressMatch.Success) { $progressMatch.Groups[1].Value.Trim() } else { "0%" }

    $i | Add-Member -MemberType NoteProperty -Name "ParentId" -Value $parent
    $i | Add-Member -MemberType NoteProperty -Name "StartDate" -Value ($start.Trim())
    $i | Add-Member -MemberType NoteProperty -Name "EndDate" -Value ($end.Trim())
    $i | Add-Member -MemberType NoteProperty -Name "Progress" -Value $progress
    $issueMap[$i.number.ToString()] = $i
}

# 階層パスを取得する関数（無限ループ対応付き）
function Get-HierarchyPath($item, $visited = @()) {
    if ($null -eq $item.ParentId -or -not $issueMap.ContainsKey($item.ParentId) -or ($visited -contains $item.ParentId)) {
        return @($item)
    }
    $parent = $issueMap[$item.ParentId]
    return @(Get-HierarchyPath $parent ($visited + $item.number.ToString())) + @($item)
}

# 最大階層の計算とパスのキャッシュ
$maxDepth = 1
$processedIssues = foreach ($i in $issues) {
    $path = @(Get-HierarchyPath $i)
    if ($path.Count -gt $maxDepth) { $maxDepth = $path.Count }
    @{ Issue = $i; Path = $path }
}

$results = foreach ($p in $processedIssues) {
    $i = $p.Issue
    $path = $p.Path
    $depth = $path.Count
    
    $obj = [ordered]@{}
    for ($lvl = 1; $lvl -le $maxDepth; $lvl++) {
        $obj["Level${lvl}_Title"] = if ($lvl -eq $depth) { $i.title } else { "" }
    }
    
    $obj["Status"]          = $i.state
    $obj["StartDate"]       = $i.StartDate
    $obj["EndDate"]         = $i.EndDate
    
    # PlannedProgress (予定進捗) の計算
    $plannedProgress = "0%"
    if (-not [string]::IsNullOrWhiteSpace($i.StartDate) -and -not [string]::IsNullOrWhiteSpace($i.EndDate)) {
        try {
            $startDt = [datetime]$i.StartDate
            $endDt = [datetime]$i.EndDate
            $nowDt = (Get-Date).Date
            
            if ($nowDt -lt $startDt) {
                $plannedProgress = "0%"
            } elseif ($nowDt -gt $endDt) {
                $plannedProgress = "100%"
            } else {
                $totalDays = ($endDt - $startDt).Days + 1
                $passedDays = ($nowDt - $startDt).Days + 1
                $pct = [math]::Round(($passedDays / $totalDays) * 100)
                $plannedProgress = "$pct%"
            }
        } catch {
            $plannedProgress = ""
        }
    }
    $obj["PlannedProgress"] = $plannedProgress

    # 実績進捗(Sub-issues progress) / 末端は"-"
    $hasChild = $false
    foreach ($v in $processedIssues) {
        if ($v.Issue.ParentId -eq $i.number.ToString()) {
            $hasChild = $true
            break
        }
    }
    
    if ($hasChild) {
        $obj["Sub-issues progress"] = $i.Progress
    } else {
        $obj["Sub-issues progress"] = "-"
    }

    $obj["_SortKey"]        = ($path | ForEach-Object { $_.number.ToString().PadLeft(10, '0') }) -join "-"
    
    [PSCustomObject]$obj
}

$results | Sort-Object "_SortKey" | Select-Object -Property * -ExcludeProperty "_SortKey" |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

Write-Host "Exported $(@($results).Count) issue(s)."
Write-Host "CSV : $csvPath"
