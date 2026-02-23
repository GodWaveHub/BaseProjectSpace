---
name: 99-html
description: Instructions for converting markdown to HTML.
---

# markdownのhtml化の指示
- html成果物は、99_html フォルダに配置してください。
- 99_htmlの下に、変換元ファイルのフォルダパスに従ってフォルダを作成して格納してください。

# 99_html スタイル利用ガイド
markdownをHTML化した成果物で使う最小限のスタイルは以下とする。

- assets/css/style.css … 画面表示用のベーススタイル（余計な余白・多色・アイコンを避け、穏やかな配色）
- print.css … 印刷時の最小限スタイル（任意で読み込み）

## 使い方（HTML内で参照）

HTMLの<head>内で以下のようにlinkしてください。

<link rel="stylesheet" href="./assets/css/style.css">
<link rel="stylesheet" href="./print.css" media="print">

必要に応じて、本文を<main>や<div class="markdown-body">などのラッパーで包むと整った幅になります。

```html
<main>
  <!-- ここにMarkdownから生成されたHTML本文 -->
</main>
```

## md → html 変換時のヒント

- 生成ツールでテンプレート（ヘッダー）を差し込める場合、上記linkタグをテンプレートに入れてください。
- スタイルは余計なpadding/marginを避けています。必要な場合のみコンテナに最小限のpaddingを付けています。
- 色は落ち着いたトーン（濃灰、薄い境界、穏やかな青緑）を使用しています。

## 注意

- アイコンフォントや外部CDNは使用していません。
- 必要に応じて変数（:root内のCSSカスタムプロパティ）を調整してください。
