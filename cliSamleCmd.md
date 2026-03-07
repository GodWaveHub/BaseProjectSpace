# Copilot CLI サンプルコマンド集

## インストール

```powershell
npm install -g @github/copilot
```

## 起動例（PowerShell）

### 直前セッションを再開して起動

```powershell
copilot --resume `
  --allow-all-tools `
  --model "gemini-3-pro-preview"
```

### ログ出力＋追加ディレクトリを許可して起動

```powershell
copilot --log-dir ./logs `
  --add-dir C:\work\shared `
  --allow-all-tools `
  --model "gemini-3-pro-preview"
```

## 複数行プロンプト例

```powershell
copilot -p @"
ブラウザ版スーパーマリオのような完全オリジナルのブラウザゲームを作成してください。1-1だけでよいです。
基本設計書も作成してください。
"@ `
  --allow-all-tools `
  --model "claude-opus-4.6"
```


### ファイルを指定するとき
```
-a ./test.txt
```
### エージェントを指定するとき（.agent　はいらないのがポイント）
```
  --agent stock-evaluate
```
### 定型

```powershell

copilot -p @"
#20260223_ベスト5銘柄推奨レポート_Model4_gemini31.md 
分析結果を評価してください。
"@ `
  --agent stock-evaluate `
  --allow-all `
  --model "gemini-3-pro-preview"

```
```powershell
```
```powershell
```


## バージョンアップ

```powershell
copilot update
copilot version
```

## ヘルプ

```powershell
copilot help
copilot help config
copilot help environment
copilot help logging
copilot help permissions
```

## model 2/28
Set the AI model to use (choices: "claude-sonnet-4.6", "claude-sonnet-4.5", "claude-haiku-4.5", 
"claude-opus-4.6", "claude-opus-4.6-fast", "claude-opus-4.5", "claude-sonnet-4", "gemini-3-pro-preview", 
"gpt-5.3-codex", "gpt-5.2-codex", "gpt-5.2", "gpt-5.1-codex-max", "gpt-5.1-codex", "gpt-5.1", "gpt-5.1-codex-mini", "gpt-5-mini", "gpt-4.1")


# GitHub Copilot の他知識集

## 「カスタムプロンプト」機能
.github\prompts\sample.prompt.md の実行方法
```
@workspace /run sample.prompt.md
```
```
/run sample
```

## Agent Debugパネル
コマンドパレットから
```
Developer: Open Agent Debug Panel
```


