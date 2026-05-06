---
name: jts-topology-suite
description: 'JTS Topology Suite を使った Java 実装支援スキルです。Geometry、buffer、intersects、contains、union、difference、WKT、WKB、SRID、PrecisionModel、Javadoc を使って空間処理コードを設計・実装・レビューするときに使用します。JTS API 選定、ジオメトリ生成、妥当性確認、WKT/WKB 入出力、座標変換の判断を支援します。'
argument-hint: '作りたい空間処理の目的、入力形式、使いたい Geometry 型、性能要件を書いてください'
user-invocable: true
---

# JTS Topology Suite

JTS Topology Suite を使った Java プログラムを、Javadoc を根拠に設計・実装・レビューするためのスキルです。

## このスキルが扱う範囲

- JTS API の選定
- GeometryFactory、PrecisionModel、Coordinate、Envelope の使い分け
- Geometry に対する buffer、intersects、contains、within、touches、crosses、overlaps、union、difference、intersection の実装
- WKT/WKB の読み書き
- 妥当性確認、精度問題、性能上の注意点
- 座標変換の実装方針の判断

## 使うタイミング

- JTS を使った Java コードを書きたいとき
- WKT や WKB から Geometry を生成したいとき
- バッファ、交差判定、和集合などの空間演算を正しく実装したいとき
- Javadoc を確認しながら、目的に合う JTS API を選びたいとき
- 座標系や SRID を含む設計判断が必要なとき

## 基本方針

1. 先に業務目的を固定する
2. 次に Geometry 型、入力形式、期待する出力形式を固定する
3. その後で Javadoc を根拠に API を選ぶ
4. 実装前に精度、妥当性、性能上の前提を明示する
5. 実装後は WKT ベースのテストケースで結果を検証する

## 実装手順

### 1. 目的と前提を整理する

最初に以下を明確にします。

- 何を判定したいか: 交差判定、包含判定、近傍検索、重なり除去など
- 何を生成したいか: バッファ済み Polygon、統合済み MultiPolygon、切り抜き結果など
- 入力形式: Coordinate 配列、WKT、WKB、既存 Geometry
- 出力形式: Geometry、WKT、WKB、面積、長さ、真偽値
- Geometry 型: Point、LineString、Polygon、MultiPolygon など
- SRID の扱い: 既知か、不明か、統一済みか
- 性能要件: 単発処理か、大量件数の繰り返し判定か

この情報が不足している場合は、いきなりコードを書かずに前提を補完します。

### 2. Javadoc を根拠に API を選ぶ

JTS 実装は、まず Javadoc 上の責務を確認してから API を選びます。

- Geometry の述語判定: intersects、contains、within、touches、crosses、overlaps
- Geometry の集合演算: union、difference、intersection、symDifference
- Geometry の派生演算: buffer、convexHull、getEnvelope
- 妥当性確認: isValid、isSimple、[JTS API メモ](./references/jts-api-notes.md) の妥当性系クラス
- WKT/WKB 入出力: WKTReader、WKTWriter、WKBReader、WKBWriter
- 複数 Geometry の統合: UnaryUnionOp
- 繰り返し判定の最適化: PreparedGeometryFactory

選定理由は、目的と API の責務を 1 対 1 で説明できる状態にします。

### 3. Geometry を安全に生成する

Geometry 生成時は以下を統一します。

- GeometryFactory を 1 箇所で定義する
- PrecisionModel を明示する
- SRID を明示する
- Polygon の外周リングと内周リングの構造を確認する
- 不正な座標列をそのまま投入しない

特に Polygon では、閉じた LinearRing と座標順序を確認します。

### 4. ジオメトリ操作を実装する

用途別の基本方針です。

- 単純な真偽値判定: Geometry の述語メソッドを使う
- 形状そのものを生成する: union、intersection、difference、buffer を使う
- 大量件数の統合: 個別 union の連鎖より UnaryUnionOp を優先する
- 同じ対象への大量判定: PreparedGeometryFactory を使う
- 近接判定や距離条件: distance と buffer のどちらが要件に合うかを先に決める

### 5. WKT/WKB を扱う

WKT/WKB を扱う場合は、読込と出力の責務を分離します。

- 入力のパースは WKTReader または WKBReader
- 外部出力は WKTWriter または WKBWriter
- ログ・テストでは WKT を優先する
- バイナリ連携や保存では WKB を使う

実装時は、パース失敗時の例外処理と null 取り扱いを明示します。

### 6. 座標変換の要否を判定する

重要事項として、JTS 自体は本格的な座標参照系変換ライブラリではありません。

- JTS が得意なこと: 座標を持つ Geometry の生成、空間演算、位相判定
- JTS が直接担当しないこと: EPSG ベースの厳密な CRS 変換

そのため、座標変換要求は次のように分岐します。

1. 座標値の単純な変換や平行移動、スケーリングだけなら JTS 周辺の通常 Java 実装で対応する
2. EPSG:4326 から EPSG:3857 のような CRS 変換が必要なら、専用ライブラリの導入可否を確認する
3. 専用ライブラリを使えない前提なら、JTS 単独では厳密な CRS 変換をしない方針を明示する

設計レビューでは、SRID を保持しているだけで座標変換したことにはならない点を必ず確認します。

### 7. 妥当性と精度を確認する

空間演算の前後で以下を確認します。

- isValid の結果
- self-intersection の有無
- 面積や長さの異常値
- 極小誤差による判定ブレ
- SRID の混在

必要に応じて PrecisionModel や精度調整系 API を検討します。特に小数誤差が多い入力では、演算結果の正当性を WKT ベースで再確認します。

### 8. テストを書く

最低限、以下のテストを書きます。

- 正常系: 想定した WKT 入力から期待した結果が返る
- 境界系: 接するだけ、完全包含、部分重複、非交差
- 異常系: 不正 WKT、不正 Polygon、null 入力
- 精度系: 微小誤差で結果が変わりやすいケース

期待値比較は以下を使い分けます。

- 位相的な等価性を見たい: equalsTopo 相当の考え方で比較
- 座標の完全一致を見たい: equalsExact 系の比較
- 出力確認を簡単にしたい: WKTWriter で文字列化して確認

## 品質チェック

- GeometryFactory が乱立していないか
- PrecisionModel と SRID を説明できるか
- Polygon 生成時にリング構造が妥当か
- union をループで愚直連結していないか
- 繰り返し判定で PreparedGeometry を使う余地がないか
- WKT/WKB の例外処理があるか
- SRID の保持と座標変換を混同していないか
- テストケースに境界条件が入っているか

## よくある誤り

- SRID を設定しただけで座標変換済みと見なす
- 繰り返し union を逐次実行して性能を落とす
- 無効な Polygon をそのまま演算に使う
- equalsExact で位相的な一致確認をしてしまう
- バッファ距離の単位を座標系の単位と切り離して考えてしまう
- 交差判定の大量実行で PreparedGeometry を使わない

## 出力方針

このスキルを使って実装支援を行うときは、以下の順で出力します。

1. 要件整理
2. JTS API 選定理由
3. 実装コード
4. 妥当性と精度の注意点
5. テスト観点

## 参照

- [JTS API メモ](./references/jts-api-notes.md)
