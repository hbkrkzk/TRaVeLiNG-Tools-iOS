# TRaVeLiNG Tools iOS

TRaVeLiNG-Tools-Web を参考に作成した SwiftUI 版の iOS アプリです。

## 機能

- Skyscanner Link
  - Skyscanner 検索リンクからアフィリエイトURLを生成
  - 短縮URL・統計用URL・シェア文言のコピー
  - 履歴の検索・削除・再コピー
- Boarding Barcode
  - 搭乗情報から IATA 文字列を生成
  - Aztec / PDF417 バーコードを生成表示
  - IATA 生データのコピー
- FIRE Simulator
  - 条件入力による年次シミュレーション
  - リタイア時資産・資産寿命の算出
  - 資産推移グラフと年次詳細表示

## 最近の更新

- Skyscanner Link の履歴カードを2カラム構成に調整し、操作ボタンをコンパクト化
- 履歴カード左右に余白を追加し、カード境界を視認しやすく改善
- コピー操作のフィードバック色を機能ごとに統一（URL/統計/シェア）

## 開き方

1. Xcode で TRaVeLiNG-Tools_iOS.xcodeproj を開く
2. Scheme で TRaVeLiNG-Tools_iOS を選択
3. iOS Simulator を選択して Run

## 補足

- App Icon は未設定です（Assets に空の AppIcon セットを作成済み）。
- Bundle Identifier は com.traveling.toolsios を仮設定しています。
