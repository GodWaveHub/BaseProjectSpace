# JTS API メモ

JTS Topology Suite を使うときに、まず確認する主要 API と設計上の注意点を整理したメモです。

## 主要パッケージ

- org.locationtech.jts.geom
- org.locationtech.jts.io
- org.locationtech.jts.operation.union
- org.locationtech.jts.operation.valid
- org.locationtech.jts.precision
- org.locationtech.jts.geom.prep

## 依存関係

### Maven

org.locationtech.jts:jts-core

### Gradle

implementation 'org.locationtech.jts:jts-core:<version>'

実際のバージョンはプロジェクト標準に合わせて決めます。

## 主要クラスと責務

### ジオメトリ生成

- GeometryFactory: Geometry 生成の起点
- PrecisionModel: 座標精度の定義
- Coordinate: 座標値
- Point、LineString、LinearRing、Polygon、MultiPoint、MultiLineString、MultiPolygon、GeometryCollection
- Envelope: 境界矩形

### 入出力

- WKTReader: WKT から Geometry を生成
- WKTWriter: Geometry を WKT 化
- WKBReader: WKB から Geometry を生成
- WKBWriter: Geometry を WKB 化

### 妥当性と精度

- Geometry.isValid: 基本妥当性確認
- Geometry.isSimple: 単純形状判定
- IsValidOp: 妥当性の詳細確認
- TopologyValidationError: 妥当性エラー内容の取得
- GeometryPrecisionReducer: 精度調整

### 集合演算と性能

- Geometry.union
- Geometry.intersection
- Geometry.difference
- Geometry.symDifference
- Geometry.buffer
- UnaryUnionOp: 複数 Geometry の統合
- PreparedGeometryFactory: 繰り返し述語判定の高速化

## 目的別の選び方

### 交差判定したい

- 単発: Geometry.intersects
- 同じ面や領域に対して大量判定: PreparedGeometryFactory で PreparedGeometry を作り intersects

### 包含判定したい

- Geometry.contains
- 逆方向の意味が必要なら Geometry.within

contains と within は向きが逆なので、主語を固定してから書きます。

### 複数 Polygon をまとめたい

- 少数で単発: union
- 件数が多い: UnaryUnionOp

### 近傍領域を作りたい

- Geometry.buffer

ただし、距離単位は座標系の単位に依存します。緯度経度の度単位で buffer すると、メートル感覚の距離にはなりません。

### WKT/WKB を使いたい

- テスト・ログ・手作業確認: WKT
- 保存・通信・サイズ重視: WKB

## 座標変換について

JTS は Geometry の SRID を保持できますが、SRID を設定しただけで座標値は変換されません。

### JTS だけで扱える範囲

- 座標値を持つ Geometry の生成
- Geometry 演算
- 任意ロジックによる座標値の加工

### JTS だけでは扱わない方がよい範囲

- EPSG コードを使った厳密な CRS 変換
- 測地系差を考慮した投影変換

この要求がある場合は、専用ライブラリ導入可否を設計判断に含めます。

## Javadoc で先に確認する観点

- メソッドの返却型は何か
- 元 Geometry を破壊しないか
- 例外が何か
- 精度や位相に関する注意書きがあるか
- null を許容するか
- 繰り返し処理で使うときのコストは高くないか

## 実装レビュー観点

- Geometry 型が要件に合っているか
- 外部入力の WKT/WKB をそのまま信用していないか
- 無効 Geometry の対策があるか
- buffer の距離単位が明示されているか
- SRID 混在データを無自覚に演算していないか
- 大量処理で逐次 union していないか

## 参考 URL

- JTS GitHub: https://github.com/locationtech/jts
- JTS Javadoc: https://locationtech.github.io/jts/javadoc/
