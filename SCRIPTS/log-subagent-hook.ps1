param(
    [string]$LogPath
)

$rawInput = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($rawInput)) {
    exit 0
}

try {
    $payload = $rawInput | ConvertFrom-Json -Depth 20
}
catch {
    Write-Error 'Failed to parse hook payload as JSON.'
    exit 1
}

function Get-Text {
    param(
        $Value,
        [string]$Fallback
    )

    if ($null -eq $Value) {
        return $Fallback
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Fallback
    }

    return $text
}

function Limit-Text {
    param(
        [string]$Value,
        [int]$MaxLength = 160
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $normalized = $Value -replace '\s+', ' '
    if ($normalized.Length -le $MaxLength) {
        return $normalized
    }

    return $normalized.Substring(0, $MaxLength - 3) + '...'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $projectRoot '.github/hooks/agent.log'
}

$logDirectory = Split-Path -Parent $LogPath
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$eventName = Get-Text $payload.hook_event_name 'UnknownEvent'
$sessionId = Get-Text $payload.session_id '-'

switch ($eventName) {
    'PreToolUse' {
        $caller = Get-Text $payload.agent_type 'main'
        $callee = Get-Text $payload.tool_input.subagent_type 'unknown'
        $description = Limit-Text (Get-Text $payload.tool_input.description '')
        $message = "[{0}] event={1} phase=before caller={2} callee={3} session={4}" -f $timestamp, $eventName, $caller, $callee, $sessionId
        if ($description) {
            $message += " description={0}" -f $description
        }
    }
    'PostToolUse' {
        $caller = Get-Text $payload.agent_type 'main'
        $callee = Get-Text $payload.tool_input.subagent_type 'unknown'
        $message = "[{0}] event={1} phase=after caller={2} callee={3} session={4}" -f $timestamp, $eventName, $caller, $callee, $sessionId
    }
    'SubagentStart' {
        $callee = Get-Text $payload.agent_type 'unknown'
        $agentId = Get-Text $payload.agent_id '-'
        $message = "[{0}] event={1} phase=spawned callee={2} agentId={3} session={4}" -f $timestamp, $eventName, $callee, $agentId, $sessionId
    }
    'SubagentStop' {
        $callee = Get-Text $payload.agent_type 'unknown'
        $agentId = Get-Text $payload.agent_id '-'
        $summary = Limit-Text (Get-Text $payload.last_assistant_message '')
        $message = "[{0}] event={1} phase=finished callee={2} agentId={3} session={4}" -f $timestamp, $eventName, $callee, $agentId, $sessionId
        if ($summary) {
            $message += " summary={0}" -f $summary
        }
    }
    default {
        $message = "[{0}] event={1} session={2}" -f $timestamp, $eventName, $sessionId
    }
}

Add-Content -Path $LogPath -Value $message