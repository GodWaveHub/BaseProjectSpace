# Sub-issues progress依存の除去

- **実行日時**: 2026-05-24 15:43 UTC
- **AIモデル**: Claude Sonnet 4
- **実行時間**: 約5分

## 指示内容

進捗率[%] の取得と親の反映に、Sub-issues progress を利用する必要はありません。
各issueの 進捗率[%] の値のみ取り扱えばよいです。
Sub-issues progressを参照しているのであれば、やめてください。

## 修正内容

ワークフローからGraphQL `parent`/`subIssues` APIへの依存を完全に除去し、REST APIのタイムラインイベントベースの実装に変更:

1. **親issue特定**: GraphQL `parent` フィールド → REST API タイムラインの `added_to_parent` イベント
2. **子issue一覧取得**: GraphQL `subIssues` フィールド → REST API タイムラインの `added_to_sub_issue` イベント
3. **各issueの進捗率取得**: GraphQL response の body → REST API で個別にissue取得してbodyから読み取り

これにより、GitHub Sub-issues progress機能に一切依存せず、各issueのbody内「進捗率[%]: XX」テキストのみを使用するようになりました。

## 利用ツール

- GitHub MCP Server (issues)
