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
`model`: AI model to use for Copilot CLI; can be changed with /model command or --model flag option.
\- "claude-sonnet-4.6"
\- "claude-sonnet-4.5"
\- "claude-haiku-4.5"
\- "claude-opus-4.6"
\- "claude-opus-4.6-fast"
\- "claude-opus-4.5"
\- "claude-sonnet-4"
\- "gpt-5.4"
\- "gpt-5.3-codex"
\- "gpt-5.2-codex"
\- "gpt-5.2"
\- "gpt-5.1"
\- "gpt-5.4-mini"
\- "gpt-5-mini"
\- "gpt-4.1"

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


