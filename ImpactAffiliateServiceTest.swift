import Foundation

// MARK: - Manual Testing Script for ImpactAffiliateService

/// このスクリプトは ImpactAffiliateService の基本的な機能をテストします
func testImpactAffiliateService() async {
    print("🧪 ImpactAffiliateService テスト開始\n")
    
    // テストケース1: 有効なSkyscanner URL
    await test_ValidSkyscannerURL()
    
    // テストケース2: 無効なURL
    await test_InvalidURL()
    
    // テストケース3: ネットワークエラー
    await test_NetworkError()
    
    print("\n✅ テスト完了")
}

// MARK: - Test Cases

/// テスト1: 有効なSkyscanner URLでアフィリエイトリンク生成
private func test_ValidSkyscannerURL() async {
    print("テスト1️⃣: 有効なSkyscanner URL")
    let testURL = "https://www.skyscanner.jp/transport/flights/NRT/LAX/2024-12-20/2024-12-30/"
    
    do {
        let trackingURL = try await ImpactAffiliateService.generateTrackingLink(skyscannerLink: testURL)
        print("✅ 成功: \(trackingURL)")
        assert(trackingURL.contains("skyscanner.pxf.io"), "レスポンスが vanity URL 形式ではありません")
    } catch let error as ImpactAffiliateService.ImpactError {
        print("❌ エラー: \(error.localizedDescription)")
    } catch {
        print("❌ 予期しないエラー: \(error)")
    }
    print()
}

/// テスト2: 無効なURL（空文字列）
private func test_InvalidURL() async {
    print("テスト2️⃣: 無効なURL（空文字列）")
    
    do {
        _ = try await ImpactAffiliateService.generateTrackingLink(skyscannerLink: "")
        print("❌ エラーが発生すべきでした")
    } catch let error as ImpactAffiliateService.ImpactError {
        print("✅ 期待通りのエラー: \(error.localizedDescription)")
    } catch {
        print("❌ 予期しないエラー: \(error)")
    }
    print()
}

/// テスト3: ネットワークエラーのシミュレーション
private func test_NetworkError() async {
    print("テスト3️⃣: 不正なURLでのネットワークエラー")
    let invalidURL = "https://invalid.example.com/test"
    
    do {
        _ = try await ImpactAffiliateService.generateTrackingLink(skyscannerLink: invalidURL)
        print("ℹ️  APIがレスポンスを返しました（ネットワークエラーではない）")
    } catch let error as ImpactAffiliateService.ImpactError {
        print("✅ エラーハンドリング機能確認: \(error.localizedDescription)")
    } catch {
        print("✅ ネットワークエラーキャッチ: \(error)")
    }
    print()
}

// MARK: - Entry Point

// 実行方法: swift ImpactAffiliateServiceTest.swift
// または Xcode の playground で実行
