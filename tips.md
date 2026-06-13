# Github Copilot

## プロンプト入力

### `#`（チャット変数）：コンテキストを指定する

回答の「材料」となる情報を指定します。これを活用することで、Copilot が「どのコードについて話しているか」を正確に把握できます。

| 変数名 | 説明 |
|:---|:---|
| `#file` | 特定のファイルを指定します（例：`#file:main.py`）。 |
| `#selection` | エディタで現在選択しているコード範囲を参照します。 |
| `#editor` | 現在開いているエディタの可視範囲を参照します。 |
| `#codebase` | ワークスペース全体をコンテキストとして含めます。 |
| `#git` | カレントブランチやコミット履歴など、Git の情報を参照します。 |
| `#terminalSelection` | ターミナルで選択しているテキストを参照します。 |
| `#terminalLastCommand` | ターミナルで最後に実行したコマンドを参照します。 |

### `/`（スラッシュコマンド）：指示をショートカットする

よく使う指示を短縮して伝えることができます。

| コマンド | 説明 |
|:---|:---|
| `/explain` | 選択したコードの意味や動作を解説させます。 |
| `/fix` | コード内のバグを修正したり、エラーの解決策を提案させます。 |
| `/tests` | 選択したコードに対するユニットテストを生成します。 |
| `/doc` | コードにドキュメント（コメント、JSDocなど）を追加します。 |
| `/new` | 新しいプロジェクトやファイルの雛形（スキャフォールド）を作成します。 |
| `/clear` | チャット履歴をリセットして、新しいセッションを開始します。 |

### `@`（チャット参加者）：誰に頼むか決める

特定の役割（エージェント）に絞って質問できます。

* `@workspace`: プロジェクト全体について質問する場合（「このプロジェクトの認証フローは？」など）。
* `@terminal`: ターミナルの操作やコマンドの使い方について聞く場合。
* `@vscode`: VS Code 本体の設定や機能について聞く場合。


---

### 💡 使い方のコツ

これらを組み合わせると非常に強力です。

* **例1：** `@workspace /explain #file:auth.py`
  * （ワークスペース全体を考慮しつつ、`auth.py` の内容を解説して）
* **例2：** `/fix #terminalLastCommand`
  * （さっきターミナルで出たエラーを直して）
* **例3：** `/explain #terminalLastCommand`
  * （さっきターミナルで出て結果を説明して）


チャット入力欄で `#` や `/` を入力するだけで、その場で利用可能な候補がプルダウン表示されるので、まずは入力してみるのが一番の近道です。

# Copilot CLI

## インストール

```powershell
npm install -g @github/copilot
```

## バージョンアップ

```powershell
copilot version
copilot update
copilot version
```

## 起動例（PowerShell）

### 直前セッションを再開して起動

```powershell
copilot --resume `
  --allow-all-tools `
  --model "gpt-5.4"
```

### ログ出力＋追加ディレクトリを許可して起動

```powershell
copilot --log-dir ./logs `
  --add-dir C:\work\shared `
  --allow-all-tools `
  --model "gpt-5.4"
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

### エージェントを指定するとき（.agent.md　はいらないのがポイント）

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
  --model "gpt-5.4"
```

```powershell
```

```powershell
```

## ヘルプ

```powershell
copilot help
copilot help config
copilot help environment
copilot help logging
copilot help permissions
```

## 利用できるモデル一覧

`copilot help config`で確認できる
```
  `model`: AI model to use for Copilot CLI; can be changed with /model command or --model flag option.
    - "claude-sonnet-4.6"
    - "claude-sonnet-4.5"
    - "claude-haiku-4.5"
    - "claude-opus-4.7"
    - "claude-opus-4.6"
    - "claude-opus-4.6-fast"
    - "claude-opus-4.5"
    - "gpt-5.5"
    - "gpt-5.4"
    - "gpt-5.3-codex"
    - "gpt-5.2-codex"
    - "gpt-5.2"
    - "gpt-5.4-mini"
    - "gpt-5-mini"
    - "gpt-4.1"
```

## インタラクティブモードでのスラッシュコマンド

Copilot CLIの対話モードでは、スラッシュコマンドを利用して設定やツールの状態を動的に変更できます。

| コマンド | 説明 |
|:---|:---|
| `/fleet` | 利用可能なサブエージェント（フリート）の一覧表示や呼び出し、管理を行います。複数の専門エージェントにタスクを分担させる際に有用です。 |
| `/model` | セッション中に利用するAIモデルを動的に変更します（例: `/model claude-opus-4.6`）。 |
| `/agent` | アクティブなエージェントを別のものに切り替えます。 |
| `/allow-all` | ファイル操作やコマンド実行など、すべてのツールの使用を許可します。都度承認する手間を省くことができます。 |
| `/allow` | 特定のツールやディレクトリへのアクセスのみを限定して許可します。 |
| `/clear` | 現在のコンテキスト（チャット履歴）をクリアし、新しい状態から再開します。 |
| `/help` | 対話モード内で利用可能なコマンドの一覧などを表示します。 |
| `/exit` | 対話モードを終了します。 |


# GitHub CLI

## インストール

```powershell
winget install --id GitHub.cli
```

## バージョンアップ

```powershell
gh --version
winget upgrade --id GitHub.cli
gh --version
```
## 認証設定
以下で認証設定を行う。

```powershell
gh auth login
? Where do you use GitHub? GitHub.com                                                           
? What is your preferred protocol for Git operations on this host? HTTPS                        
? Authenticate Git with your GitHub credentials? Yes                                            
? How would you like to authenticate GitHub CLI? Paste an authentication token                  
Tip: you can generate a Personal Access Token here https://github.com/settings/tokens           
The minimum required scopes are 'repo', 'read:org', 'workflow'.                                 
? Paste your authentication token: ****************************************                     
- gh config set -h github.com git_protocol https
✓ Configured git protocol
✓ Logged in as GodWaveHub
```
```powershell
gh auth status
github.com
  ✓ Logged in to github.com account GodWaveHub (keyring)
  - Active account: true
  - Git operations protocol: https
  - Token: ghp_************************************
  - Token scopes: 'gist', 'read:org', 'repo'
```
## projectのid取得時のコマンド
- ただし、トークンの権限にproject:readの追加が必要
```powershell
gh api graphql -f query='query { user(login: "GodWaveHub") { projectsV2(first: 10) { nodes { id title } } } }'
{
  "data": {
    "user": {
      "projectsV2": {
        "nodes": [
          {
            "id": "PVT_kwHOA-wQNs4BYky6",
            "title": "test"
          }
        ]
      }
    }
  }
}
```
# GitHub Copilot の他知識集

## 対話型実施時の知識

### 権限付与

```
/allow-all
```

### 「カスタムプロンプト」機能

* .github\\prompts\\sample.prompt.md の実行方法

```
@workspace /run sample.prompt.md
```

```
/run sample
```

```
/{プロンプト名}
```

※ スラッシュ(/)を入れると、候補にプロンプト名が出てくるので選べばよい

## Agent Debugパネル

コマンドパレットから

```
Developer: Open Agent Debug Panel
```


