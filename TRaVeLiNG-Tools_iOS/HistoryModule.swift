import SwiftUI
import FirebaseCore
import FirebaseFirestore

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
    let partnerName: String?
    let campaignId: Int?
    
    init(id: String = UUID().uuidString, createdDate: Date = Date(), departureCode: String, arrivalCode: String, outboundDate: String, returnDate: String?, shortenedURL: String, affiliateURL: String, isRoundTrip: Bool, partnerName: String? = nil, campaignId: Int? = nil) {
        self.id = id
        self.createdDate = createdDate
        self.departureCode = departureCode
        self.arrivalCode = arrivalCode
        self.outboundDate = outboundDate
        self.returnDate = returnDate
        self.shortenedURL = shortenedURL
        self.affiliateURL = affiliateURL
        self.isRoundTrip = isRoundTrip
        self.partnerName = partnerName
        self.campaignId = campaignId
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
    
    // Firestore用の辞書変換
    var dictionary: [String: Any] {
        return [
            "id": id,
            "createdDate": Timestamp(date: createdDate),
            "departureCode": departureCode,
            "arrivalCode": arrivalCode,
            "outboundDate": outboundDate,
            "returnDate": returnDate as Any,
            "shortenedURL": shortenedURL,
            "affiliateURL": affiliateURL,
            "isRoundTrip": isRoundTrip,
            "partnerName": partnerName as Any,
            "campaignId": campaignId as Any
        ]
    }
    
    // Firestoreからの初期化
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let timestamp = dictionary["createdDate"] as? Timestamp,
              let departureCode = dictionary["departureCode"] as? String,
              let arrivalCode = dictionary["arrivalCode"] as? String,
              let outboundDate = dictionary["outboundDate"] as? String,
              let shortenedURL = dictionary["shortenedURL"] as? String,
              let affiliateURL = dictionary["affiliateURL"] as? String,
              let isRoundTrip = dictionary["isRoundTrip"] as? Bool else {
            return nil
        }
        
        self.id = id
        self.createdDate = timestamp.dateValue()
        self.departureCode = departureCode
        self.arrivalCode = arrivalCode
        self.outboundDate = outboundDate
        self.returnDate = dictionary["returnDate"] as? String
        self.shortenedURL = shortenedURL
        self.affiliateURL = affiliateURL
        self.isRoundTrip = isRoundTrip
        self.partnerName = dictionary["partnerName"] as? String
        self.campaignId = dictionary["campaignId"] as? Int
    }
}

class AffiliateURLHistoryManager: ObservableObject {
    @Published var records: [AffiliateURLRecord] = []
    private static let storageKey = "affiliate_url_history"
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    static let shared = AffiliateURLHistoryManager()
    
    init() {
        loadLocalRecords()
        startFirestoreListener()
    }
    
    deinit {
        listener?.remove()
    }
    
    func startFirestoreListener() {
        // Firebaseが初期化されていない場合はスキップ（初回起動時など）
        guard FirebaseApp.app() != nil else { return }
        
        listener = db.collection("history")
            .order(by: "createdDate", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let newRecords = documents.compactMap { AffiliateURLRecord(dictionary: $0.data()) }
                DispatchQueue.main.async {
                    self?.records = newRecords
                    self?.saveLocalRecords()
                }
            }
    }
    
    func addRecord(departureCode: String, arrivalCode: String, outboundDate: String, returnDate: String?, shortenedURL: String, affiliateURL: String, isRoundTrip: Bool, partnerName: String? = nil, campaignId: Int? = nil) {
        let record = AffiliateURLRecord(departureCode: departureCode, arrivalCode: arrivalCode, outboundDate: outboundDate, returnDate: returnDate, shortenedURL: shortenedURL, affiliateURL: affiliateURL, isRoundTrip: isRoundTrip, partnerName: partnerName, campaignId: campaignId)
        
        // Firestoreに保存（オフライン時は自動でキューイングされる）
        db.collection("history").document(record.id).setData(record.dictionary) { error in
            if let error = error {
                print("Error saving to Firestore: \(error.localizedDescription)")
            }
        }
        
        // ローカルにも即時反映（UI応答性のため）
        if !records.contains(where: { $0.id == record.id }) {
            records.insert(record, at: 0)
            saveLocalRecords()
        }
    }
    
    func search(_ query: String) -> [AffiliateURLRecord] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? records : records.filter { $0.matchesSearchQuery(query) }
    }
    
    func deleteRecord(_ record: AffiliateURLRecord) {
        db.collection("history").document(record.id).delete() { error in
            if let error = error {
                print("Error deleting from Firestore: \(error.localizedDescription)")
            }
        }
        
        records.removeAll { $0.id == record.id }
        saveLocalRecords()
    }
    
    func deleteAll() {
        // Firestoreのドキュメントを一括削除（本来はバッチ処理が望ましい）
        for record in records {
            db.collection("history").document(record.id).delete()
        }
        
        records.removeAll()
        saveLocalRecords()
    }
    
    private func saveLocalRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("❌ Save error: \(error)")
        }
    }
    
    private func loadLocalRecords() {
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
                                    if let partnerName = record.partnerName, let campaignId = record.campaignId {
                                        Button(action: { 
                                            UIPasteboard.general.string = record.shortenedURL
                                            showCopyFeedback = "コピーしました"
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                showCopyFeedback = nil
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "doc.on.doc")
                                                Text("他(\(campaignId))")
                                            }.font(.caption2.weight(.semibold)).padding(.horizontal, 8).frame(height: 28).background(Color.orange.opacity(0.1)).foregroundStyle(.orange).cornerRadius(4)
                                        }
                                    } else {
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
