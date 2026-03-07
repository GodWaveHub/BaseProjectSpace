---
name: uml
description: Instructions for creating UML diagrams and other charts.
---

# 作成ルール
- Mermaid図はHTMLに直接書かないでください。CDN経由でレンダリングしないでください。
- mmdからsvgへの変換スクリプトは `scripts/render-mermaid.ps1` を参照してください。

## 作成手順
- UMLおよび図をMermaid記法の `.mmd` ファイルで作成する。
- mmdファイルをSVG形式に変換する。

## 配置場所
- mmdファイルとSVGファイルは各ドキュメントフォルダの直下にmdフォルダを作成して格納する。

## 作成時の注意点
- mmdからsvgへの変換でエラーが出力する場合はエラーが出ないように修正してください。
