import SwiftUI

// MARK: - Models & Manager
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
    var dateDisplayText: String {
        if isRoundTrip, let returnDate = returnDate {
            return "往路:\(formatDate(outboundDate))、復路:\(formatDate(returnDate))"
        } else {
            return "出発:\(formatDate(outboundDate))"
        }
    }
    var directionArrow: String { isRoundTrip ? "⇄" : "→" }
    var tripTypeLabel: String { isRoundTrip ? "往復" : "片道" }
    var tripTypeColor: Color { isRoundTrip ? .red : .blue }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
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

// MARK: - History List View
struct AffiliateHistoryListView: View {
    @StateObject private var historyManager = AffiliateURLHistoryManager.shared
    @State private var searchText = ""
    @State private var recordToDelete: AffiliateURLRecord?
    @State private var showDeleteConfirm = false
    @State private var showCopyFeedback: String?
    
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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.createdDate, style: .date).font(.caption).foregroundStyle(.secondary)
                                    Text(record.createdDate, style: .time).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(record.tripTypeLabel)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .frame(height: 22)
                                        .background(record.tripTypeColor.opacity(0.15))
                                        .foregroundStyle(record.tripTypeColor)
                                        .cornerRadius(11)
                                    HStack(spacing: 4) {
                                        Text(record.departureCode).font(.subheadline.weight(.semibold))
                                        Text(record.directionArrow).font(.title3)
                                        Text(record.arrivalCode).font(.subheadline.weight(.semibold))
                                    }.foregroundStyle(record.tripTypeColor)
                                }
                                Text(record.dateDisplayText).font(.caption).foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    Text(record.shortenedURL).font(.caption).lineLimit(1).truncationMode(.middle).foregroundStyle(.blue)
                                    Spacer()
                                    Button(action: { 
                                        UIPasteboard.general.string = record.statsURL
                                        showCopyFeedback = "コピーしました"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showCopyFeedback = nil
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.doc")
                                            Text("統計用")
                                        }.font(.caption2.weight(.semibold)).padding(.horizontal, 8).frame(height: 28).background(Color.purple.opacity(0.1)).foregroundStyle(.purple).cornerRadius(4)
                                    }
                                    Button(action: { recordToDelete = record; showDeleteConfirm = true }) {
                                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
                                    }
                                }
                            }.padding(12).background(Color(.systemGray6)).cornerRadius(8).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
                        }
                    }.listStyle(.inset)
                }
                
                if !filteredRecords.isEmpty {
                    Button(action: { recordToDelete = nil; showDeleteConfirm = true }) {
                        HStack { Image(systemName: "trash"); Text("すべて削除") }
                            .frame(maxWidth: .infinity).frame(height: 44).background(Color.red.opacity(0.1)).foregroundStyle(.red).cornerRadius(8)
                    }.padding(12)
                }
            }.navigationTitle("生成履歴").navigationBarTitleDisplayMode(.inline)
        }.toast(message: $showCopyFeedback)
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
    func toast(message: Binding<String?>) -> some View {
        ZStack {
            self
            if let msg = message.wrappedValue {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                        Text(msg).foregroundStyle(.white)
                        Spacer()
                    }.padding(12).background(Color.green).cornerRadius(8).padding(12)
                    Spacer()
                }
            }
        }
    }
}
