# TravelPayouts API キーの設定方法

## 概要
TravelPayouts APIを使用するには、APIキーを設定する必要があります。セキュリティのため、APIキーはGitHubにコミットされません。

## セットアップ手順

### 1. LocalConfig.plist の作成
プロジェクトルートに `LocalConfig.plist` ファイルを作成します：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>TRAVELPAYOUTS_API_KEY</key>
    <string>b5eab9b181d11b677083dee207b74206</string>
</dict>
</plist>
```

### 2. ファイル位置
```
TRaVeLiNG-Tools-iOS/
├── LocalConfig.plist  ← ここに配置
├── TRaVeLiNG-Tools_iOS.xcodeproj/
└── ...
```

### 3. Gitから除外
`.gitignore` に既に以下が記載されているため、LocalConfig.plist は自動的にコミットされません：
```
# API Keys and Local Config (do not commit)
Config.plist
LocalConfig.plist
.env
```

## API キーについて
- **trs**: 532203 (固定)
- **marker**: 731698 (固定)
- **API Key**: b5eab9b181d11b677083dee207b74206
- **Endpoint**: https://api.travelpayouts.com/links/v1/create

## パートナー対応
現在対応しているパートナー：
- **Traveloka** (Campaign ID: 632)
- **Trip.com** (Campaign ID: 121)

## トラブルシューティング

### APIキーが見つからない場合
エラーメッセージ「TravelPayouts API Keyが設定されていません」が表示される場合：
1. LocalConfig.plist が正しく作成されているか確認
2. XMLが正しいか確認
3. Xcode を再起動

### パートナーリンク生成に失敗する場合
1. APIキーが有効か確認
2. インターネット接続を確認
3. URLが正しい形式か確認（traveloka.com など）

## セキュリティに関する注意
⚠️ **重要**: LocalConfig.plist には個人のAPIキーが含まれています。
- 絶対にGitHubにコミットしないでください
- 他の人に共有しないでください
- .gitignore に含まれていることを確認してください
