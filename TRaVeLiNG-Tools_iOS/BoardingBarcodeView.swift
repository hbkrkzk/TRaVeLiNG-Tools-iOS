import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct BoardingBarcodeView: View {
    enum InputField: Int, CaseIterable {
        case firstName
        case lastName
        case from
        case to
        case operatorCode
        case flightNum
        case seat
        case bookingRef
        case boardingIndex
    }

    @AppStorage("boarding.firstName") private var firstName = ""
    @AppStorage("boarding.lastName") private var lastName = ""
    @AppStorage("boarding.from") private var from = ""
    @AppStorage("boarding.to") private var to = ""
    @AppStorage("boarding.operatorCode") private var operatorCode = ""
    @AppStorage("boarding.flightNum") private var flightNum = ""
    @AppStorage("boarding.departureDate") private var departureDateTimeInterval = Date().timeIntervalSince1970
    @State private var bookingRef = ""
    @AppStorage("boarding.seat") private var seat = ""
    @State private var boardingIndex = ""
    @AppStorage("boarding.cabinClass") private var cabinClass = "Y"
    @AppStorage("boarding.codeType") private var codeTypeRaw = BarcodeType.aztec.rawValue
    @State private var copyStatus = "コピー"
    @State private var renderedBarcodeImage: UIImage?
    @State private var isViewLoaded = false
    @FocusState private var focusedField: InputField?

    private let ciContext = CIContext()

    private var nameError: String? {
        firstName.count + lastName.count > 19 ? "氏名が長すぎます（姓+名の合計は最大19文字）" : nil
    }

    private var departureDate: Date {
        Date(timeIntervalSince1970: departureDateTimeInterval)
    }

    private var departureDateBinding: Binding<Date> {
        Binding(
            get: { departureDate },
            set: { departureDateTimeInterval = $0.timeIntervalSince1970 }
        )
    }

    private var codeTypeBinding: Binding<BarcodeType> {
        Binding(
            get: { BarcodeType(rawValue: codeTypeRaw) ?? .aztec },
            set: { codeTypeRaw = $0.rawValue }
        )
    }

    private var rawData: String {
        let nameField = upPadRight("\(lastName)/\(firstName)", count: 20)
        let refField = upPadRight(bookingRef, count: 7)
        let fromField = upPadRight(from, count: 3)
        let toField = upPadRight(to, count: 3)
        let opField = upPadRight(operatorCode, count: 3)
        let fnField = upPadRight(flightNum, count: 5)
        let dayField = padLeft(String(dayOfYear(for: departureDate)), count: 3)
        let seatField = padLeft(seat, count: 4)
        let seqField = upPadRight(padLeft(boardingIndex, count: 4), count: 5)

        let part1 = "M1\(nameField)E\(refField)"
        let part2 = "\(fromField)\(toField)\(opField)\(fnField)"
        let part3 = "\(dayField)\(cabinClass)\(seatField)\(seqField)100"
        
        return part1 + part2 + part3
    }

    private var flightInfoSection: some View {
        Section("区間・便情報") {
            LabeledInputField(title: "出発地", text: $from, example: "HND", field: .from, focusedField: $focusedField)
                .onChange(of: from) {
                    from = String(from.uppercased().prefix(3))
                }

            LabeledInputField(title: "到着地", text: $to, example: "NYC", field: .to, focusedField: $focusedField)
                .onChange(of: to) {
                    to = String(to.uppercased().prefix(3))
                }

            LabeledInputField(title: "運航会社コード", text: $operatorCode, example: "NH", field: .operatorCode, focusedField: $focusedField)
                .onChange(of: operatorCode) {
                    operatorCode = String(operatorCode.uppercased().prefix(3))
                }

            let flightView = LabeledInputField(title: "便名", text: $flightNum, example: "001", field: .flightNum, focusedField: $focusedField)
            let flightWithKeyboard = flightView.keyboardType(.numbersAndPunctuation)
            
            flightWithKeyboard
                .onChange(of: flightNum) {
                    flightNum = String(flightNum.prefix(5))
                }

            DatePicker("出発日", selection: departureDateBinding, displayedComponents: .date)
        }
    }

    private var classSeatSection: some View {
        Section("クラス・座席") {
            Picker("搭乗クラス", selection: $cabinClass) {
                Text("エコノミー (Y)").tag("Y")
                Text("ビジネス (C)").tag("C")
                Text("ファースト (F)").tag("F")
            }

            LabeledInputField(title: "座席番号", text: $seat, example: "23A", field: .seat, focusedField: $focusedField)
                .onChange(of: seat) {
                    seat = String(seat.uppercased().prefix(4))
                }
        }
    }

    private var referenceInfoSection: some View {
        Section("参照情報") {
            LabeledInputField(title: "PNR", text: $bookingRef, example: "ABC123", field: .bookingRef, focusedField: $focusedField)
                .onChange(of: bookingRef) {
                    bookingRef = String(bookingRef.uppercased().prefix(7))
                }

            let boardingView = LabeledInputField(title: "搭乗インデックス", text: $boardingIndex, example: "12", field: .boardingIndex, focusedField: $focusedField)
            let boardingWithKeyboard = boardingView.keyboardType(.numberPad)
            
            boardingWithKeyboard
                .onChange(of: boardingIndex) {
                    boardingIndex = String(boardingIndex.prefix(4))
                }
        }
    }

    private var outputSection: some View {
        Section("出力") {
            Picker("バーコード形式", selection: codeTypeBinding) {
                Text("Aztec（標準）").tag(BarcodeType.aztec)
                Text("PDF417").tag(BarcodeType.pdf417)
            }

            if let renderedBarcodeImage {
                Image(uiImage: renderedBarcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
            } else {
                Text("バーコードを生成できませんでした")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        Form {
            if let nameError {
                Section {
                    Text(nameError)
                        .foregroundStyle(.red)
                }
            }

            Section("乗客情報") {
                LabeledInputField(title: "名", text: $firstName, example: "John", field: .firstName, focusedField: $focusedField)
                    .onChange(of: firstName) {
                        firstName = firstName.uppercased()
                    }

                LabeledInputField(title: "姓", text: $lastName, example: "Smith", field: .lastName, focusedField: $focusedField)
                    .onChange(of: lastName) {
                        lastName = lastName.uppercased()
                    }
            }

            // 他のセクションは遅延レンダリング
            if isViewLoaded {
                flightInfoSection
                classSeatSection
                referenceInfoSection
                outputSection
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    moveFocus(by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveFocus(by: -1))

                Button {
                    moveFocus(by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveFocus(by: 1))

                Spacer()

                Button("閉じる") {
                    focusedField = nil
                }
            }
        }
        .navigationTitle("Boarding Pass Code")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if focusedField == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IATA生データ文字列")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rawData)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button(copyStatus) {
                        UIPasteboard.general.string = rawData
                        copyStatus = "コピーしました"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copyStatus = "コピー"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.bar)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            bookingRef = Self.randomBookingRef()
            boardingIndex = String(Int.random(in: 1...200))
            // 0.05秒後にセクション表示 + バーコード生成開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isViewLoaded = true
                updateBarcodeImage()
            }
        }
        .onChange(of: rawData) {
            updateBarcodeImage()
        }
        .onChange(of: codeTypeRaw) {
            updateBarcodeImage()
        }
    }

    private func generateBarcode(for text: String, type: BarcodeType) -> UIImage? {
        guard let data = text.data(using: .ascii, allowLossyConversion: true) else {
            return nil
        }

        let outputImage: CIImage?
        switch type {
        case .aztec:
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = data
            filter.compactStyle = 0
            filter.layers = 11
            outputImage = filter.outputImage
        case .pdf417:
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = data
            filter.compactionMode = 2
            outputImage = filter.outputImage
        }

        guard
            let ciImage = outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)),
            let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func randomBookingRef() -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<6).map { _ in charset.randomElement()! })
    }

    private func upPadRight(_ value: String, count: Int) -> String {
        let upper = value.uppercased()
        if upper.count >= count {
            return String(upper.prefix(count))
        }
        return upper + String(repeating: " ", count: count - upper.count)
    }

    private func padLeft(_ value: String, count: Int) -> String {
        let upper = value.uppercased()
        if upper.count >= count {
            return String(upper.prefix(count))
        }
        return String(repeating: "0", count: count - upper.count) + upper
    }

    private func dayOfYear(for date: Date) -> Int {
        Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: date) ?? 1
    }

    private func canMoveFocus(by delta: Int) -> Bool {
        guard let focusedField else { return false }
        let next = focusedField.rawValue + delta
        return InputField(rawValue: next) != nil
    }

    private func moveFocus(by delta: Int) {
        guard let focusedField else { return }
        let next = focusedField.rawValue + delta
        self.focusedField = InputField(rawValue: next)
    }

    private func updateBarcodeImage() {
        let type = BarcodeType(rawValue: codeTypeRaw) ?? .aztec
        renderedBarcodeImage = generateBarcode(for: rawData, type: type)
    }
}

enum BarcodeType: String, CaseIterable, Hashable {
    case aztec
    case pdf417
}

private struct LabeledInputField: View {
    let title: String
    @Binding var text: String
    let example: String
    let field: BoardingBarcodeView.InputField
    var focusedField: FocusState<BoardingBarcodeView.InputField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $text, prompt: Text(example))
                .textInputAutocapitalization(.characters)
                .focused(focusedField, equals: field)
        }
    }
}

#Preview {
    NavigationStack {
        BoardingBarcodeView()
    }
}
