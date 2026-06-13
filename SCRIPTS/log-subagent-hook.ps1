# =============================================================================
# log-subagent-hook.ps1
# GitHub Copilot CLI フックイベント ログスクリプト（Windows / PowerShell 用）
#
# 概要:
#   .github/hooks/sample.json から呼び出されるフックハンドラ。
#   各フックイベント発火時に標準入力から JSON ペイロードを受け取り、
#   ログファイルに追記する。
#
# 対応フックイベント:
#   sessionStart, sessionEnd, userPromptSubmitted,
#   preToolUse, postToolUse, postToolUseFailure,
#   agentStop, subagentStart, subagentStop,
#   errorOccurred, preCompact, notification, permissionRequest
#
# ログ出力先: logs/hook-events.log（リポジトリルート相対）
# =============================================================================

# ログファイルのパス（スクリプトの1階層上 = リポジトリルートの logs/ フォルダ）
$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir   = Join-Path $repoRoot "logs"
$logFile  = Join-Path $logDir "hook-events.log"

# ログディレクトリが存在しない場合は作成する
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# 標準入力から JSON ペイロードを受け取る（フックエンジンが stdin に渡す）
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$inputJson = $input | Out-String

# タイムスタンプと入力内容をログに追記する
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logEntry  = "[${timestamp}] HOOK FIRED`n${inputJson}`n"

Add-Content -Path $logFile -Value $logEntry -Encoding UTF8

# デバッグ用: stderr に発火通知を出力（通常運用では削除可）
Write-Error "[hook] Event logged to: $logFile" 2>&1 | Out-Null
