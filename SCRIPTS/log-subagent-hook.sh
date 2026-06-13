#!/bin/bash
# =============================================================================
# log-subagent-hook.sh
# GitHub Copilot CLI フックイベント ログスクリプト（Linux / macOS 用）
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

# スクリプトの2階層上をリポジトリルートとする
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/hook-events.log"

# ログディレクトリが存在しない場合は作成する
mkdir -p "${LOG_DIR}"

# 標準入力から JSON ペイロードを受け取る（フックエンジンが stdin に渡す）
INPUT_JSON=$(cat)

# タイムスタンプと入力内容をログに追記する
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
{
  echo "[${TIMESTAMP}] HOOK FIRED"
  echo "${INPUT_JSON}"
  echo ""
} >> "${LOG_FILE}"

# デバッグ用: stderr に発火通知を出力（通常運用では削除可）
echo "[hook] Event logged to: ${LOG_FILE}" >&2
