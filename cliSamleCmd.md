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

## バージョン

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
