<#
.SYNOPSIS
    エージェント議論オーケストレーター
.DESCRIPTION
    複数のカスタムエージェントが議題について議論を行うPowerShellスクリプト。
    仕様書: Discuss/discussion-spec.md

    ■ 必須パラメータ
      -TopicFile   : 議題ファイルのパス
      -AgentsFile  : 参加エージェントリストファイルのパス
      -Rounds      : 議論ラウンド数（全エージェントが1回ずつ発言 = 1ラウンド）

    ■ 省略可能パラメータ
      -DiscussionFile : 議論ファイルの出力パス。
                        省略時は TopicFile の ID から自動生成
                        （Discuss/discussions/discussion-{id}.md）
      -Model          : copilot CLI で使用するAIモデル名。
                                                省略時は "gpt-5.4" が使用される。
      -Summarize      : 指定すると最終ラウンド後に要約を議論ファイル末尾に追記する。
                        省略時は要約を生成しない。
      -Force          : 既存の議論ファイルを警告なく上書きする。
                        省略時は既存ファイルがある場合エラーとなる。

.EXAMPLE
    # 最小構成（必須パラメータのみ）
    .\Discuss\discuss.ps1 `
      -TopicFile "Discuss/discussions/topic-001.md" `
      -AgentsFile "Discuss/discussions/agents-001.md" `
      -Rounds 3

        Model は省略され "gpt-5.4" が使用される。
    議論ファイルは Discuss/discussions/discussion-001.md に自動生成される。

.EXAMPLE
    # モデルを指定して要約付きで実行
    .\Discuss\discuss.ps1 `
      -TopicFile "Discuss/discussions/topic-001.md" `
      -AgentsFile "Discuss/discussions/agents-001.md" `
      -Rounds 3 `
      -Model "claude-opus-4.6" `
      -Summarize

    Claude Opus 4.6 で議論を実施し、完了後に議論ファイル末尾に要約を追記する。

.EXAMPLE
    # 全パラメータを明示的に指定
    .\Discuss\discuss.ps1 `
      -TopicFile "Discuss/discussions/topic-002.md" `
      -AgentsFile "Discuss/discussions/agents-001.md" `
      -Rounds 3 `
      -DiscussionFile "Discuss/discussions/discussioned-002.md" `
            -Model "gpt-5.4" `
      -Summarize `
      -Force
        gpt-5.4 で3ラウンド議論し、指定パスに議論ファイルを出力、要約も生成する。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$TopicFile,

    [Parameter(Mandatory = $true)]
    [string]$AgentsFile,

    [Parameter(Mandatory = $true)]
    [int]$Rounds,

    [string]$DiscussionFile,

    [string]$Model = 'gpt-5.4',

    [switch]$Summarize,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────
# エンコーディング設定（copilot CLI の UTF-8 出力を正しく受け取る）
# ─────────────────────────────────────────────
$prevConsoleOutputEncoding = [Console]::OutputEncoding
$prevOutputEncoding = $OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PromptTemplate = Join-Path $PSScriptRoot 'discuss.prompt.md'

# ─────────────────────────────────────────────
# ユーティリティ関数
# ─────────────────────────────────────────────
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$ts] $Message"
}

function Resolve-ProjectPath {
    param([string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return $RelativePath
    }
    return Join-Path $ProjectRoot $RelativePath
}

function Parse-AgentList {
    param([string]$FilePath)
    $lines = Get-Content -Path $FilePath -Encoding UTF8
    $agents = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\-\s+(.+)$') {
            $agents += $Matches[1].Trim()
        }
    }
    return $agents
}

function Read-AgentDefinition {
    param([string]$AgentName)

    # .github/agents/{name}.md または {name}.agent.md を探索
    $candidates = @(
        (Join-Path $ProjectRoot ".github/agents/$AgentName.md"),
        (Join-Path $ProjectRoot ".github/agents/$AgentName.agent.md")
    )

    $agentFile = $null
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $agentFile = $c
            break
        }
    }

    if (-not $agentFile) {
        Write-Error "エージェント定義ファイルが見つかりません: $AgentName (検索先: $($candidates -join ', '))"
        exit 1
    }

    $content = Get-Content -Path $agentFile -Raw -Encoding UTF8
    $description = ''
    $body = $content

    # YAMLフロントマターのパース
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---\r?\n(.*)$') {
        $frontmatter = $Matches[1]
        $body = $Matches[2].Trim()

        if ($frontmatter -match "description:\s*['""]?([^'""]+)['""]?") {
            $description = $Matches[1].Trim()
        }
    }

    return @{
        Name        = $AgentName
        Description = $description
        Body        = $body
    }
}

function Test-CopilotModel {
    param(
        [string]$CandidateModel,
        [string]$ProbeAgentName
    )

    $probePrompt = '次の文字だけ返してください: OK'
    $probeOutput = copilot -p $probePrompt `
        --agent $ProbeAgentName `
        --allow-all `
        --model $CandidateModel 2>&1

    return @{
        Success = ($LASTEXITCODE -eq 0)
        Output  = ($probeOutput | Out-String).Trim()
    }
}

function Resolve-ExecutionModel {
    param(
        [string]$RequestedModel,
        [string]$ProbeAgentName
    )

    $fallbackModel = 'gpt-5.4'
    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add($RequestedModel)
    if ($RequestedModel -ne $fallbackModel) {
        $candidates.Add($fallbackModel)
    }

    foreach ($candidate in $candidates) {
        Write-Log "モデル事前検証中... ($candidate)"
        $probe = Test-CopilotModel -CandidateModel $candidate -ProbeAgentName $ProbeAgentName
        if ($probe.Success) {
            if ($candidate -ne $RequestedModel) {
                Write-Log "⚠ モデル '$RequestedModel' は現在利用できないため '$candidate' にフォールバックします"
            }
            return $candidate
        }

        if (-not [string]::IsNullOrWhiteSpace($probe.Output)) {
            $firstLine = ($probe.Output -split "\r?\n")[0].Trim()
            Write-Log "⚠ モデル '$candidate' の事前検証に失敗: $firstLine"
        }
    }

    Write-Error "指定モデル '$RequestedModel' は現在利用できません。'copilot help config' で利用可能なモデルを確認してください。"
    exit 1
}

function Build-AgentPrompt {
    param(
        [hashtable]$Agent,
        [string]$TopicContent,
        [string]$DiscussionContent,
        [int]$CurrentRound,
        [int]$TotalRounds,
        [string]$DynamicInstruction = '',
        [string]$PersonalityReminder = ''
    )

    if (-not (Test-Path $PromptTemplate)) {
        Write-Error "プロンプトテンプレートが見つかりません: $PromptTemplate"
        exit 1
    }

    $template = Get-Content -Path $PromptTemplate -Raw -Encoding UTF8

    $discussionSection = if ([string]::IsNullOrWhiteSpace($DiscussionContent)) {
        'まだ誰も発言していません。最初の発言者としてあなたの見解を述べてください。'
    } else {
        $DiscussionContent
    }

    # フェーズ指示を決定
    $phaseInstruction = Get-PhaseInstruction -CurrentRound $CurrentRound -TotalRounds $TotalRounds

    $prompt = $template `
        -replace '\{エージェント名\}', $Agent.Name `
        -replace '\{エージェント定義本文\}', $Agent.Body `
        -replace '\{議題ファイルの内容\}', $TopicContent `
        -replace '\{議論ファイルの現在の内容\}', $discussionSection `
        -replace '\{現在のラウンド\}', $CurrentRound `
        -replace '\{全ラウンド数\}', $TotalRounds `
        -replace '\{フェーズ指示\}', $phaseInstruction `
        -replace '\{ラウンド特別指示\}', $DynamicInstruction `
        -replace '\{性格強調\}', $PersonalityReminder

    return $prompt
}

function Get-PhaseInstruction {
    param(
        [int]$CurrentRound,
        [int]$TotalRounds
    )

    if ($TotalRounds -le 1) {
        return @"
【単発ラウンド】自分の立場を明確にし、具体的な根拠と新しい視点を示してください。
"@
    }

    # フェーズ判定：序盤(探索) → 中盤前半(激論) → 中盤後半(深堀り) → 終盤(収束)
    # 中盤を長く取ることで議論の多様性を確保する
    $progress = $CurrentRound / $TotalRounds

    if ($progress -le 0.20) {
        return @"
【探索フェーズ（序盤）】議論はまだ始まったばかりです。
- まずはあなた独自の切り口で自由に意見を述べてください
- 他の参加者とは異なる角度から論点を提示してください
- この段階では合意を急がず、論点の幅を広げることが目的です
"@
    } elseif ($progress -le 0.50) {
        return @"
【激論フェーズ（中盤前半）】各自の立場が見えてきました。ここからが本番です。
- **遠慮なく反論してください。友人同士だからこそ本音でぶつかれます**
- 他の参加者の意見の弱点・矛盾・見落としを具体的に指摘してください
- 「それは違う」「甘い」「見落としている」とはっきり言ってOKです
- 反例やデータで攻めてください。抽象的な賛同は禁止です
- 自分の前ラウンドの意見を修正してもOKです
"@
    } elseif ($progress -le 0.80) {
        return @"
【深堀りフェーズ（中盤後半）】議論が白熱しています。さらに掘り下げてください。
- これまでの議論で見落とされている **盲点** はないか探してください
- 「もし○○だったら？」という仮定を投げかけ、議論の前提を揺さぶってください
- 他の参加者が避けている **不都合な真実** を指摘してください
- まだ出ていない新しい論点・データ・事例があれば積極的に持ち込んでください
- 同じ結論の繰り返しは絶対に避けてください
"@
    } else {
        return @"
【収束フェーズ（終盤）】議論の最終盤です。
- これまでの議論を振り返り、**あなたの最終結論** を述べてください
- 合意できた点と、最後まで意見が分かれた点を整理してください
- 議論を通じて自分の意見がどう変化したか述べてください
- 相談者への最終アドバイスを具体的に述べてください
"@
    }
}

function Get-RoundDynamic {
    param(
        [hashtable]$CurrentAgent,
        [hashtable[]]$AllAgents,
        [int]$CurrentRound,
        [int]$TotalRounds,
        [int]$AgentIndex
    )

    # ラウンド1と最終ラウンドは特別指示なし
    if ($CurrentRound -eq 1 -or $CurrentRound -eq $TotalRounds) {
        return ''
    }

    $otherAgents = @($AllAgents | Where-Object { $_.Name -ne $CurrentAgent.Name })
    if ($otherAgents.Count -eq 0) { return '' }

    # エージェントごとに異なるターゲットを決定論的に選択
    $targetAgent = $otherAgents[($CurrentRound + $AgentIndex) % $otherAgents.Count]

    $dynamics = @(
        @{
            Name = 'challenge'
            Instruction = @"
### このラウンドの特別ミッション
**$($targetAgent.Name) の主張に正面から反論してください。** その論点のどこが甘いか、どんな条件で破綻するかを具体的に示してください。友人だからこそ遠慮なくぶつかってください。
"@
        },
        @{
            Name = 'new_perspective'
            Instruction = @"
### このラウンドの特別ミッション
**これまでの議論で誰も触れていない、まったく新しい切り口を導入してください。** 例えば：別のリスク、見落とされている選択肢、意外なデータ、異なる価値観からの視点など。「それは考えていなかった」と言わせる発言を目指してください。
"@
        },
        @{
            Name = 'bold_claim'
            Instruction = @"
### このラウンドの特別ミッション
**大胆で挑発的な意見を1つ述べてください。** 全員が「え？」と思うような切り口を狙ってください。ただの暴論ではなく、一理ある大胆さが理想です。議論を揺さぶる発言をしてください。
"@
        },
        @{
            Name = 'devils_advocate'
            Instruction = @"
### このラウンドの特別ミッション
**あえて、これまでの自分の立場と反対の主張をしてください。** 「自分でもこう思うこともある」という形で、逆の視点を真剣に検討してください。最終的に元の立場に戻ってもOKですが、反対側の論理も丁寧に展開してください。
"@
        },
        @{
            Name = 'direct_question'
            Instruction = @"
### このラウンドの特別ミッション
**発言の最後に $($targetAgent.Name) への鋭い質問を投げかけてください。** 「はい/いいえ」で答えられない、思考を迫る問いにしてください。この質問が次のラウンドの議論を動かす起点になることを意識してください。
"@
        }
    )

    # ラウンド番号とエージェントインデックスに基づいて異なるダイナミクスを割り当て
    $dynamicIndex = ($CurrentRound * 3 + $AgentIndex) % $dynamics.Count
    return $dynamics[$dynamicIndex].Instruction
}

function Get-PersonalityReminder {
    param([hashtable]$Agent)

    return @"
### あなたの個性を最大限に発揮してください
あなたは「$($Agent.Name)」（$($Agent.Description)）です。
- 他の参加者と同じトーンや結論にならないよう、あなた独自の切り口を貫いてください
- 議論が一方向に流れている場合、あなたの役割からの異論や別視点を強く主張してください
- あなたの性格・立場に基づく「らしい」発言を心がけてください
"@
}

function Clean-Response {
    param([string]$RawResponse)

    if ([string]::IsNullOrWhiteSpace($RawResponse)) {
        return $RawResponse
    }

    $lines = $RawResponse -split "`n"
    $cleanedLines = @()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # copilot CLI のメタデータ行を除去
        if ($trimmed -match '^\s*Changes\s+\+[\d.]+\s+-[\d.]+') { continue }
        if ($trimmed -match '^\s*Requests\s+[\d.]+\s+Premium') { continue }
        if ($trimmed -match '^\s*Tokens\s+[↑↓]') { continue }

        $cleanedLines += $line
    }

    $result = ($cleanedLines -join "`n").Trim()

    # copilot-instructions フッターアーティファクトを除去
    # 「この回答は...のルールに従っています。」「この回答はAGENT:...を利用しました。」等
    $result = $result -replace '\s*この回答はcopilot-instructionsのルールに従っています。[^\n]*', ''
    $result = $result -replace '\s*この回答はAGENT:[^\n]+を利用しました。[^\n]*', ''
    $result = $result -replace '\s*この回答はMCP:[^\n]+を利用しました。[^\n]*', ''
    $result = $result -replace '\s*この回答はSKILL:[^\n]+を利用しました。[^\n]*', ''
    $result = $result -replace '\s*この回答はSUBAGENT:[^\n]+を利用しました。[^\n]*', ''
    $result = $result -replace '\s*この回答はCUSTOM_PROMPT:[^\n]+を利用しました。[^\n]*', ''
    $result = $result -replace '\s*適用ルール：[^\n]*', ''

    return $result.Trim()
}

function Build-CondensedHistory {
    param(
        [string]$FullDiscussion,
        [int]$CurrentRound
    )

    # ラウンド1〜2はそのまま全文を返す
    if ($CurrentRound -le 2) {
        return $FullDiscussion
    }

    # "## ラウンド N" 境界で分割
    $parts = $FullDiscussion -split '(?=\n## ラウンド \d+)'

    # parts[0] = ヘッダ部分, parts[1..] = 各ラウンド
    $result = $parts[0].TrimEnd()

    $result += "`n`n> **注**: ラウンド3以降はプロンプト肥大化を防ぐため、過去ラウンドは要点のみ表示しています。"

    for ($i = 1; $i -lt $parts.Count; $i++) {
        $roundText = $parts[$i].Trim()

        # ラウンド番号を抽出
        if ($roundText -match '^## ラウンド (\d+)') {
            $roundNum = [int]$Matches[1]
        } else {
            continue
        }

        if ($roundNum -eq ($CurrentRound - 1)) {
            # 直前ラウンド: 全文を保持
            $result += "`n`n$roundText"
        } elseif ($roundNum -lt ($CurrentRound - 1)) {
            # それ以前のラウンド: 各発言者の冒頭のみ抽出
            $result += "`n`n## ラウンド $roundNum（要点のみ）"

            $speakerBlocks = [regex]::Matches($roundText, '### 【(.+?)】[^\n]*\n([\s\S]*?)(?=\n### |\z)')
            foreach ($block in $speakerBlocks) {
                $speaker = $block.Groups[1].Value
                $body = $block.Groups[2].Value.Trim()
                # 最初の一文（。まで、最大150文字）を抽出
                $firstSentence = if ($body -match '^(.{1,150}?[。\.])') {
                    $Matches[1]
                } elseif ($body.Length -gt 150) {
                    $body.Substring(0, 150) + '…'
                } else {
                    $body
                }
                $result += "`n- **$speaker**: $firstSentence"
            }
        }
        # CurrentRound 以降のラウンドがあれば無視
    }

    return $result
}

function Invoke-Agent {
    param(
        [string]$AgentName,
        [string]$Prompt
    )

    # GitHub Copilot CLI を利用してエージェントを呼び出す
    Write-Log "copilot CLI 呼び出し中... (agent=$AgentName, model=$Model)"

    $response = copilot -p $Prompt `
        --agent $AgentName `
        --allow-all `
        --model $Model 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "⚠ copilot CLI がエラーを返しました (exit $LASTEXITCODE)"
        return $null
    }

    $raw = ($response | Out-String).Trim()
    $cleaned = Clean-Response $raw

    return $cleaned
}

function Build-SummaryPrompt {
    param([string]$DiscussionContent)

    $prompt = @"
以下の議論ログを読み、要約してください。

## 出力形式
1. 議論の結論（合意点）
2. 未解決の論点
3. 各参加者の主要な主張（箇条書き）
4. 推奨アクション

## 議論ログ
$DiscussionContent
"@
    return $prompt
}

# ─────────────────────────────────────────────
# バリデーション
# ─────────────────────────────────────────────
$TopicFilePath = Resolve-ProjectPath $TopicFile
$AgentsFilePath = Resolve-ProjectPath $AgentsFile

if (-not (Test-Path $TopicFilePath)) {
    Write-Error "議題ファイルが存在しません: $TopicFilePath"
    exit 1
}
if (-not (Test-Path $AgentsFilePath)) {
    Write-Error "参加エージェントリストファイルが存在しません: $AgentsFilePath"
    exit 1
}
if ($Rounds -le 0) {
    Write-Error "ラウンド数は1以上を指定してください: $Rounds"
    exit 1
}

# ─────────────────────────────────────────────
# ファイル読み込み
# ─────────────────────────────────────────────
$topicContent = Get-Content -Path $TopicFilePath -Raw -Encoding UTF8
$agentNames = Parse-AgentList $AgentsFilePath

if ($agentNames.Count -eq 0) {
    Write-Error "エージェントリストにエージェントが記載されていません: $AgentsFilePath"
    exit 1
}

# エージェント定義の読み込み
$agents = @()
foreach ($name in $agentNames) {
    $agents += Read-AgentDefinition $name
}

$Model = Resolve-ExecutionModel -RequestedModel $Model -ProbeAgentName $agents[0].Name

# 議題タイトルの抽出（最初の # 見出し or ## テーマ の内容）
$topicTitle = '（不明）'
if ($topicContent -match '##\s*テーマ\s*\r?\n(.+)') {
    $topicTitle = $Matches[1].Trim()
} elseif ($topicContent -match '#\s+(.+)') {
    $topicTitle = $Matches[1].Trim()
}

# ─────────────────────────────────────────────
# 議論ファイルの初期化
# ─────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($DiscussionFile)) {
    # TopicFileからIDを抽出して自動命名
    $topicBaseName = [System.IO.Path]::GetFileNameWithoutExtension($TopicFilePath)
    $id = '001'
    if ($topicBaseName -match 'topic-(.+)$') {
        $id = $Matches[1]
    }
    $discussionsDir = Join-Path $PSScriptRoot 'discussions'
    if (-not (Test-Path $discussionsDir)) {
        New-Item -ItemType Directory -Path $discussionsDir -Force | Out-Null
    }
    $DiscussionFilePath = Join-Path $discussionsDir "discussion-$id.md"
} else {
    $DiscussionFilePath = Resolve-ProjectPath $DiscussionFile
}

$agentNameList = ($agents | ForEach-Object { $_.Name }) -join ', '
$startTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$header = @"
# 議論ログ

議題: $topicTitle
開始日時: $startTime
参加エージェント: $agentNameList

---

"@

# 既存ファイルの上書き保護
if ((Test-Path $DiscussionFilePath) -and -not $Force) {
    Write-Error "議論ファイルが既に存在します: $DiscussionFilePath`n上書きするには -Force を指定してください。"
    exit 1
}

$header | Set-Content -Path $DiscussionFilePath -Encoding UTF8 -NoNewline

# ─────────────────────────────────────────────
# メインループ
# ─────────────────────────────────────────────
Write-Log '=== 議論開始 ==='
Write-Log "議題: $topicTitle"
Write-Log "参加エージェント: $agentNameList"
Write-Log "ラウンド数: $Rounds"

$totalStatements = 0
$maxRetries = 2

for ($round = 1; $round -le $Rounds; $round++) {
    Write-Log "--- ラウンド $round/$Rounds ---"

    # ── ラウンド内隔離: ラウンド開始前にスナップショットを取得 ──
    # 同一ラウンド内の他エージェントの発言は見えない（独立思考を促進）
    $rawDiscussion = Get-Content -Path $DiscussionFilePath -Raw -Encoding UTF8
    $baseDiscussion = Clean-Response $rawDiscussion
    $discussionContext = Build-CondensedHistory -FullDiscussion $baseDiscussion -CurrentRound $round

    # ラウンドごとにエージェント順をシャッフル（同じ人が常に最初に発言しないように）
    $roundAgents = if ($round -eq 1) {
        @($agents)  # 初回は定義順
    } else {
        @($agents | Get-Random -Count $agents.Count)
    }

    $roundStatements = @()

    for ($agentIdx = 0; $agentIdx -lt $roundAgents.Count; $agentIdx++) {
        $agent = $roundAgents[$agentIdx]
        Write-Log "発言者: $($agent.Name)（$($agent.Description)）"

        # ラウンドダイナミクスと性格強調を生成
        $dynamicInstruction = Get-RoundDynamic `
            -CurrentAgent $agent `
            -AllAgents $agents `
            -CurrentRound $round `
            -TotalRounds $Rounds `
            -AgentIndex $agentIdx

        $personalityReminder = Get-PersonalityReminder -Agent $agent

        # プロンプト構築（全エージェントが同じスナップショットを参照）
        $prompt = Build-AgentPrompt `
            -Agent $agent `
            -TopicContent $topicContent `
            -DiscussionContent $discussionContext `
            -CurrentRound $round `
            -TotalRounds $Rounds `
            -DynamicInstruction $dynamicInstruction `
            -PersonalityReminder $personalityReminder

        # エージェント呼び出し（リトライ付き）
        $response = $null
        for ($retry = 0; $retry -le $maxRetries; $retry++) {
            $response = Invoke-Agent -AgentName $agent.Name -Prompt $prompt
            if ($null -ne $response -and $response.Length -gt 0) {
                break
            }
            if ($retry -lt $maxRetries) {
                Write-Log "⚠ $($agent.Name) の呼び出しに失敗。リトライ $($retry + 1)/$maxRetries ..."
            }
        }

        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        if ($null -eq $response -or $response.Length -eq 0) {
            Write-Log "✘ $($agent.Name) の呼び出しに失敗しました（スキップ）"
            $roundStatements += @{
                Agent     = $agent
                Response  = '*（エージェント呼び出し失敗のためスキップ）*'
                Timestamp = $ts
                Success   = $false
            }
            continue
        }

        $roundStatements += @{
            Agent     = $agent
            Response  = $response.Trim()
            Timestamp = $ts
            Success   = $true
        }

        $totalStatements++
        Write-Log "✔ $($agent.Name) の発言を記録しました"
    }

    # ── ラウンド全体をまとめて議論ファイルに追記 ──
    "`n## ラウンド $round`n" | Add-Content -Path $DiscussionFilePath -Encoding UTF8 -NoNewline
    foreach ($stmt in $roundStatements) {
        $entry = "`n### 【$($stmt.Agent.Name)】（$($stmt.Timestamp)）`n`n$($stmt.Response)`n"
        $entry | Add-Content -Path $DiscussionFilePath -Encoding UTF8 -NoNewline
    }
}

Write-Log "=== 議論完了（全${Rounds}ラウンド・${totalStatements}発言） ==="

# ─────────────────────────────────────────────
# 要約（オプション）— DiscussionFile 末尾に追記
# ─────────────────────────────────────────────
if ($Summarize) {
    Write-Log '要約を生成中...'

    $fullDiscussion = Get-Content -Path $DiscussionFilePath -Raw -Encoding UTF8
    $summaryPrompt = Build-SummaryPrompt $fullDiscussion

    Write-Log "copilot CLI 呼び出し中... (要約生成, model=$Model)"
    $summaryRaw = copilot -p $summaryPrompt `
        --model $Model 2>&1

    $summaryResponse = $null
    if ($LASTEXITCODE -eq 0) {
        $summaryResponse = Clean-Response (($summaryRaw | Out-String).Trim())
    }

    if ($null -ne $summaryResponse -and $summaryResponse.Length -gt 0) {
        $summaryEntry = @"

---

## 要約・結論

生成日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

$summaryResponse
"@
        $summaryEntry | Add-Content -Path $DiscussionFilePath -Encoding UTF8 -NoNewline
        Write-Log '✔ 要約を議論ファイル末尾に追記しました'
    } else {
        Write-Log '✘ 要約の生成に失敗しました'
    }
}

Write-Log "議論ファイル: $DiscussionFilePath"

$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed
Write-Log ("総実行時間: {0:hh\:mm\:ss}" -f $elapsed)

# ─────────────────────────────────────────────
# エンコーディング復元
# ─────────────────────────────────────────────
[Console]::OutputEncoding = $prevConsoleOutputEncoding
$OutputEncoding = $prevOutputEncoding
