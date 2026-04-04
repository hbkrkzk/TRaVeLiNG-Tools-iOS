import SwiftUI

struct SkyscannerAffiliateView: View {
    @State private var skyscannerLink: String = ""
    @State private var generatedURL: String?
    @State private var shortenedURL: String?
    @State private var shareText: String?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var isViewLoaded: Bool = false
    @State private var showMenuSheet: Bool = false
    @State private var activeMenuTab: Int = 0
    @State private var flightInfo: SkyscannerFlightInfo?
    @State private var showCopyFeedback: String?
    @State private var feedbackColor: Color = .green
    @StateObject private var historyManager = AffiliateURLHistoryManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("URLを入力")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            TextField("Skyscannerリンク", text: $skyscannerLink)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(height: 44)
                            
                            Button(action: pasteFromClipboard) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.clipboard.fill")
                                    Text("ペーストする")
                                }
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(Color.blue)
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Button(action: generateURL) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isLoading ? "生成中..." : "URLを生成")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || skyscannerLink.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(isLoading || skyscannerLink.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                    
                    if isViewLoaded {
                        if let text = shareText {
                            resultBox(title: "シェアテキスト", icon: "quote.bubble.fill", content: text, color: .orange)
                        }
                        
                        if let shortUrl = shortenedURL {
                            resultBox(title: "短縮URL", icon: "link.circle.fill", content: shortUrl, color: .purple)
                        }
                        
                        if let url = generatedURL {
                            resultBox(title: "アフィリエイトURL", icon: "checkmark.circle.fill", content: url, color: .green)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(12)
            }
            .navigationTitle("Skyscanner Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showMenuSheet = true; activeMenuTab = 0 }) {
                            Label("履歴", systemImage: "clock")
                        }
                        Button(action: { showMenuSheet = true; activeMenuTab = 1 }) {
                            Label("設定", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "エラーが発生しました")
            }
            .toast(message: $showCopyFeedback, color: feedbackColor)
            .sheet(isPresented: $showMenuSheet) {
                if activeMenuTab == 0 {
                    AffiliateHistoryListView()
                } else {
                    ShareTextSettingsView(isPresented: $showMenuSheet)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isViewLoaded = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultBox(title: String, icon: String, content: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .cornerRadius(8)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            Text(content)
                .font(.caption)
                .lineLimit(3)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Button(action: { 
                copyToClipboard(content)
                showCopyFeedback = "コピーしました"
                feedbackColor = color
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopyFeedback = nil
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text("コピー")
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(color.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func generateURL() {
        let trimmedLink = skyscannerLink.trimmingCharacters(in: .whitespaces)
        guard !trimmedLink.isEmpty else {
            errorMessage = "URLを入力してください"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // async/await で処理を実行
        Task {
            do {
                // URL解析
                guard let info = await parseSkyscannerLinkAsync(trimmedLink) else {
                    await MainActor.run {
                        self.errorMessage = "URLを解析できませんでした"
                        self.showError = true
                        self.isLoading = false
                    }
                    return
                }
                
                // Impact.com API でアフィリエイトURL生成
                let affiliateUrl = try await SkyscannerURLService.generateAffiliateURLDirectAsync(trimmedLink)
                
                let template = info.isRoundTrip
                    ? ShareTextService.shared.getRoundTripTemplate()
                    : ShareTextService.shared.getOnewayTemplate()
                
                // 短縮URL取得
                let shortUrl = await shortenURLAsync(affiliateUrl)
                
                await MainActor.run {
                    self.flightInfo = info
                    self.generatedURL = affiliateUrl
                    
                    let finalUrl = shortUrl ?? affiliateUrl
                    self.shortenedURL = finalUrl
                    self.shareText = template.replacingOccurrences(of: "{URL}", with: finalUrl)
                    
                    // 履歴に保存
                    self.historyManager.addRecord(
                        departureCode: info.departure,
                        arrivalCode: info.arrival,
                        outboundDate: info.departureDate,
                        returnDate: info.returnDate,
                        shortenedURL: finalUrl,
                        affiliateURL: affiliateUrl,
                        isRoundTrip: info.isRoundTrip
                    )
                    
                    self.isLoading = false
                }
            } catch let error as ImpactAffiliateService.ImpactError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// URL解析を非同期で実行
    private func parseSkyscannerLinkAsync(_ link: String) async -> SkyscannerFlightInfo? {
        return await withCheckedContinuation { continuation in
            SkyscannerURLService.parseSkyscannerLink(link) { info in
                continuation.resume(returning: info)
            }
        }
    }
    
    /// URL短縮を非同期で実行
    private func shortenURLAsync(_ url: String) async -> String? {
        return await withCheckedContinuation { continuation in
            SkyscannerURLService().shortenURL(url) { shortUrl in
                continuation.resume(returning: shortUrl)
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboard = UIPasteboard.general.string {
            skyscannerLink = clipboard
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Share Text Settings View

struct ShareTextSettingsView: View {
    @Binding var isPresented: Bool
    @State private var roundTripTemplate: String = ""
    @State private var onewayTemplate: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("往復フライト")) {
                    TextEditor(text: $roundTripTemplate)
                        .frame(height: 200)
                }
                
                Section(header: Text("片道フライト")) {
                    TextEditor(text: $onewayTemplate)
                        .frame(height: 200)
                }
                
                Section {
                    Button(action: saveTemplates) {
                        Text("保存する")
                    }
                    Button(action: resetToDefaults) {
                        Text("デフォルトに戻す")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("テンプレート設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                roundTripTemplate = ShareTextService.shared.getRoundTripTemplate()
                onewayTemplate = ShareTextService.shared.getOnewayTemplate()
            }
        }
    }
    
    private func saveTemplates() {
        if ShareTextService.shared.validateTemplate(roundTripTemplate) {
            ShareTextService.shared.setRoundTripTemplate(roundTripTemplate)
        }
        if ShareTextService.shared.validateTemplate(onewayTemplate) {
            ShareTextService.shared.setOnewayTemplate(onewayTemplate)
        }
    }
    
    private func resetToDefaults() {
        ShareTextService.shared.resetToDefaults()
        roundTripTemplate = ShareTextService.shared.getRoundTripTemplate()
        onewayTemplate = ShareTextService.shared.getOnewayTemplate()
    }
}

// MARK: - History Module

struct AffiliateURLRecord: Identifiable, Codable {
    let id: String
    let createdDate: Date
    let departureCode: String
    let arrivalCode: String
    let outboundDate: String
    let returnDate: String?
    let shortenedURL: String
    let affiliateURL: String
    let isRoundTrip: Bool
    
    init(departureCode: String, arrivalCode: String, outboundDate: String, returnDate: String?, shortenedURL: String, affiliateURL: String, isRoundTrip: Bool) {
        self.id = UUID().uuidString
        self.createdDate = Date()
        self.departureCode = departureCode
        self.arrivalCode = arrivalCode
        self.outboundDate = outboundDate
        self.returnDate = returnDate
        self.shortenedURL = shortenedURL
        self.affiliateURL = affiliateURL
        self.isRoundTrip = isRoundTrip
    }
    
    var statsURL: String { shortenedURL + "+" }
    var shareText: String { ShareTextService.shared.generateShareText(isRoundTrip: isRoundTrip, shortenedURL: shortenedURL) }
    var dateDisplayText: String {
        if isRoundTrip, let returnDate = returnDate {
            return "往路:\(formatDate(outboundDate))、復路:\(formatDate(returnDate))"
        } else {
            return "出発:\(formatDate(outboundDate))"
        }
    }
    var directionArrow: String { isRoundTrip ? "⇄" : "→" }
    var directionLabel: String { isRoundTrip ? "往復" : "片道" }
    
    private func formatDate(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        let cal = Calendar.current
        let y = cal.component(.year, from: date) - 2000
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return "\(y)年\(m)月\(d)日"
    }
    
    func matchesSearchQuery(_ query: String) -> Bool {
        let q = query.lowercased()
        return departureCode.lowercased().contains(q) || arrivalCode.lowercased().contains(q) || shortenedURL.lowercased().contains(q)
    }
}

class AffiliateURLHistoryManager: ObservableObject {
    @Published var records: [AffiliateURLRecord] = []
    private static let storageKey = "affiliate_url_history"
    static let shared = AffiliateURLHistoryManager()
    
    init() { loadRecords() }
    
    func addRecord(departureCode: String, arrivalCode: String, outboundDate: String, returnDate: String?, shortenedURL: String, affiliateURL: String, isRoundTrip: Bool) {
        let record = AffiliateURLRecord(departureCode: departureCode, arrivalCode: arrivalCode, outboundDate: outboundDate, returnDate: returnDate, shortenedURL: shortenedURL, affiliateURL: affiliateURL, isRoundTrip: isRoundTrip)
        records.insert(record, at: 0)
        saveRecords()
    }
    
    func search(_ query: String) -> [AffiliateURLRecord] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? records : records.filter { $0.matchesSearchQuery(query) }
    }
    
    func deleteRecord(_ record: AffiliateURLRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }
    
    func deleteAll() {
        records.removeAll()
        saveRecords()
    }
    
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("❌ Save error: \(error)")
        }
    }
    
    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { records = []; return }
        do {
            records = try JSONDecoder().decode([AffiliateURLRecord].self, from: data)
        } catch {
            print("❌ Load error: \(error)")
            records = []
        }
    }
}

struct AffiliateHistoryListView: View {
    @StateObject private var historyManager = AffiliateURLHistoryManager.shared
    @State private var searchText = ""
    @State private var recordToDelete: AffiliateURLRecord?
    @State private var showDeleteConfirm = false
    @State private var showCopyFeedback: String?
    @State private var feedbackColor: Color = .green
    
    var filteredRecords: [AffiliateURLRecord] {
        searchText.isEmpty ? historyManager.records : historyManager.search(searchText)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                    TextField("検索", text: $searchText).textFieldStyle(.roundedBorder)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                        }
                    }
                }.padding(12).background(Color(.systemGray6))
                
                if filteredRecords.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.xmark").font(.system(size: 48)).foregroundStyle(.gray)
                        Text(searchText.isEmpty ? "履歴なし" : "検索結果なし").font(.headline)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Text(record.createdDate, style: .date).font(.caption2).foregroundStyle(.secondary)
                                            Text(record.createdDate, style: .time).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        HStack(spacing: 6) {
                                            Text(record.directionLabel)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 4)
                                                .background(record.isRoundTrip ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                                                .foregroundStyle(record.isRoundTrip ? .red : .blue)
                                                .cornerRadius(4)
                                            Text("\(record.departureCode.uppercased())")
                                                .font(.body.weight(.semibold))
                                            Text(record.directionArrow)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                            Text("\(record.arrivalCode.uppercased())")
                                                .font(.body.weight(.semibold))
                                        }
                                        Text(record.dateDisplayText)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Button(action: { 
                                            UIPasteboard.general.string = record.shortenedURL
                                            showCopyFeedback = "URLコピー"
                                            feedbackColor = .blue
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                showCopyFeedback = nil
                                            }
                                        }) {
                                            Text(record.shortenedURL).font(.caption2).lineLimit(1).truncationMode(.middle).foregroundStyle(.blue).padding(.horizontal, 6).padding(.vertical, 2)
                                        }.buttonStyle(.plain).background(Color.blue.opacity(0.1)).cornerRadius(4).frame(height: 28)
                                        HStack(spacing: 4) {
                                            Button(action: { 
                                                UIPasteboard.general.string = record.statsURL
                                                showCopyFeedback = "統計用コピー"
                                                feedbackColor = .purple
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    showCopyFeedback = nil
                                                }
                                            }) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "chart.bar.xaxis").font(.caption2.weight(.semibold))
                                                    Text("統計")
                                                }.font(.caption2.weight(.semibold)).frame(width: 54, height: 28).background(Color.purple.opacity(0.15)).foregroundStyle(.purple).cornerRadius(6)
                                            }.buttonStyle(.plain)
                                            Button(action: { 
                                                UIPasteboard.general.string = record.shareText
                                                showCopyFeedback = "シェア文言コピー"
                                                feedbackColor = .orange
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    showCopyFeedback = nil
                                                }
                                            }) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "square.and.arrow.up").font(.caption2.weight(.semibold))
                                                    Text("シェア")
                                                }.font(.caption2.weight(.semibold)).frame(width: 54, height: 28).background(Color.orange.opacity(0.15)).foregroundStyle(.orange).cornerRadius(6)
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }.padding(10).background(Color.white).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1)).listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)).listRowSeparator(.hidden).listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    historyManager.deleteRecord(record)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }.listStyle(.inset)
                }
            }.navigationTitle("生成履歴").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !filteredRecords.isEmpty {
                    Menu {
                        Button(role: .destructive, action: { recordToDelete = nil; showDeleteConfirm = true }) {
                            Label("すべて削除", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }.toast(message: $showCopyFeedback, color: feedbackColor)
         .alert("削除確認", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                if let record = recordToDelete {
                    historyManager.deleteRecord(record)
                } else {
                    historyManager.deleteAll()
                }
                recordToDelete = nil
            }
        } message: {
            Text(recordToDelete != nil ? "この記録を削除しますか?" : "すべての履歴を削除しますか?")
        }
    }
}

extension View {
    func toast(message: Binding<String?>, color: Color = .green) -> some View {
        ZStack {
            self
            if let msg = message.wrappedValue {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                        Text(msg).foregroundStyle(.white)
                        Spacer()
                    }.padding(12).background(color).cornerRadius(8).padding(12)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    SkyscannerAffiliateView()
}
