import Charts
import SwiftUI
import UIKit

struct FireSimulatorView: View {
    @AppStorage("fire.birthYear") private var birthYear = "1997"
    @AppStorage("fire.birthMonth") private var birthMonth = "7"
    @AppStorage("fire.initialCapital") private var initialCapital = "500"
    @AppStorage("fire.monthlyInvestment") private var monthlyInvestment = "10"
    @AppStorage("fire.realReturn") private var realReturn = "5"
    @AppStorage("fire.retirementAge") private var retirementAge = "35"
    @AppStorage("fire.annualExpensesAfterRetirement") private var annualExpensesAfterRetirement = "300"

    @AppStorage("fire.usePension") private var usePension = false
    @AppStorage("fire.pensionStartAge") private var pensionStartAge = "65"
    @AppStorage("fire.annualExpensesAfterPension") private var annualExpensesAfterPension = "200"
    @State private var simulationData: [SimResult] = []

    private let ageOptions = Array(20...100)

    private func buildSimulationData() -> [SimResult] {
        let today = Date()
        let month = String(format: "%02d", Int(birthMonth) ?? 1)
        let birthDateString = "\(birthYear)-\(month)-01"

        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        guard let birthDate = parser.date(from: birthDateString) else { return [] }

        let currentAge = Int((today.timeIntervalSince(birthDate) / (60 * 60 * 24 * 365.25)).rounded(.down))
        if currentAge <= 0 { return [] }

        let initial = parseNum(initialCapital)
        let monthly = parseNum(monthlyInvestment)
        let annualReturn = parseNum(realReturn)
        let retirement = Int(parseNum(retirementAge).rounded(.down))
        let annualRetired = parseNum(annualExpensesAfterRetirement)
        let pensionAge = parseNum(pensionStartAge)
        let annualAfterPension = parseNum(annualExpensesAfterPension)

        var assets = initial
        var rows: [SimResult] = []

        for age in currentAge...110 {
            let startAssets = max(0, assets)
            var investment = 0.0
            var expenses = 0.0

            if age < retirement {
                investment = monthly * 12
            } else {
                expenses = annualRetired
                if usePension, Double(age) >= pensionAge {
                    expenses = annualAfterPension
                }
            }

            let flow = investment - expenses
            let base = startAssets + flow
            let returnAmount = base > 0 ? (base * annualReturn / 100) : 0
            let endAssets = max(0, (base + returnAmount).rounded())

            rows.append(
                SimResult(
                    age: age,
                    startAssets: startAssets.rounded(),
                    investment: flow.rounded(),
                    returnAmount: returnAmount.rounded(),
                    endAssets: endAssets
                )
            )

            assets = endAssets
            if assets <= 0, age > retirement {
                break
            }
        }

        return rows
    }

    private var retirementAgeValue: Int {
        Int(parseNum(retirementAge).rounded(.down))
    }

    private var retirementAssets: Double {
        simulationData.first(where: { $0.age >= retirementAgeValue })?.startAssets ?? 0
    }

    private var assetsRunOutAge: Int? {
        simulationData.first(where: { $0.endAssets <= 0 && $0.age > retirementAgeValue })?.age
    }

    private var assetChartSection: some View {
        Section("資産推移グラフ") {
            Chart(simulationData) { row in
                AreaMark(
                    x: .value("年齢", row.age),
                    y: .value("総資産", row.endAssets)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.25), .blue.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("年齢", row.age),
                    y: .value("総資産", row.endAssets)
                )
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .foregroundStyle(.blue)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatYAxisValue(amount))
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        Form {
                Section("シミュレーション条件") {
                    Picker("生年", selection: $birthYear) {
                        ForEach(1950...2070, id: \.self) { year in
                            Text("\(String(year))年").tag(String(year))
                        }
                    }

                    Picker("生月", selection: $birthMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(String(month))
                        }
                    }

                    Picker("リタイア年齢（歳）", selection: $retirementAge) {
                        ForEach(ageOptions, id: \.self) { age in
                            Text("\(age)歳").tag(String(age))
                        }
                    }

                    LabeledNumericField(title: "元金（万円）", text: $initialCapital, example: "500")
                    LabeledNumericField(title: "毎月積み立て額（万円）", text: $monthlyInvestment, example: "10")
                    LabeledNumericField(title: "実質リターン（％）", text: $realReturn, example: "5")

                    LabeledNumericField(title: "リタイア後の年間支出（万円）", text: $annualExpensesAfterRetirement, example: "300")

                    Toggle("年金情報を考慮する", isOn: $usePension)

                    if usePension {
                        Picker("年金受給開始年齢（歳）", selection: $pensionStartAge) {
                            ForEach(ageOptions, id: \.self) { age in
                                Text("\(age)歳").tag(String(age))
                            }
                        }
                        LabeledNumericField(title: "受給開始後の年間支出（万円）", text: $annualExpensesAfterPension, example: "200")
                    }
                }

                assetChartSection

                Section("年間推移詳細") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            compactHeaderCell("年齢\n(歳)")
                            compactHeaderCell("年初資産\n(万円)")
                            compactHeaderCell("年間収支\n(万円)")
                            compactHeaderCell("運用益\n(万円)")
                            compactHeaderCell("年末合計\n(万円)")
                        }

                        ForEach(simulationData) { row in
                            HStack(spacing: 4) {
                                compactValueCell("\(row.age)")
                                compactValueCell(formatNumber(row.startAssets))
                                compactValueCell(formatSigned(row.investment), color: row.investment >= 0 ? .green : .red)
                                compactValueCell(formatNumber(row.returnAmount))
                                compactValueCell(formatNumber(row.endAssets), weight: .semibold)
                            }
                            .font(.caption2)
                        }
                    }
                    .padding(.vertical, 8)
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") {
                    dismissKeyboard()
                }
            }
        }
        .navigationTitle("FIRE Simulator")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("リタイア時の資産")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(formatNumber(retirementAssets)) 万円")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                Divider()
                    .frame(height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("資産寿命")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let assetsRunOutAge {
                        Text("\(assetsRunOutAge) 歳")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text("110 歳+")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .onAppear {
            birthYear = birthYear.replacingOccurrences(of: ",", with: "")
            simulationData = buildSimulationData()
        }
        .onChange(of: birthYear) {
            simulationData = buildSimulationData()
        }
        .onChange(of: birthMonth) {
            simulationData = buildSimulationData()
        }
        .onChange(of: initialCapital) {
            simulationData = buildSimulationData()
        }
        .onChange(of: monthlyInvestment) {
            simulationData = buildSimulationData()
        }
        .onChange(of: realReturn) {
            simulationData = buildSimulationData()
        }
        .onChange(of: retirementAge) {
            simulationData = buildSimulationData()
        }
        .onChange(of: annualExpensesAfterRetirement) {
            simulationData = buildSimulationData()
        }
        .onChange(of: usePension) {
            simulationData = buildSimulationData()
        }
        .onChange(of: pensionStartAge) {
            simulationData = buildSimulationData()
        }
        .onChange(of: annualExpensesAfterPension) {
            simulationData = buildSimulationData()
        }
    }

    private func parseNum(_ value: String) -> Double {
        let converted = value
            .unicodeScalars
            .map { scalar -> Character in
                if (0xFF10...0xFF19).contains(scalar.value) {
                    return Character(UnicodeScalar(scalar.value - 0xFEE0) ?? scalar)
                }
                return Character(scalar)
            }
        let normalized = String(converted)
            .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(normalized) ?? 0
    }

    private func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }

        let rounded = value.rounded()
        return Self.decimalFormatter.string(from: NSNumber(value: rounded)) ?? String(format: "%.0f", rounded)
    }

    private func formatSigned(_ value: Double) -> String {
        guard value.isFinite else { return value.sign == .minus ? "-∞" : "+∞" }

        let number = formatNumber(abs(value))
        return value >= 0 ? "+\(number)" : "-\(number)"
    }

    private func formatYAxisValue(_ amountInManYen: Double) -> String {
        guard amountInManYen.isFinite else { return "∞" }

        if amountInManYen < 10000 {
            return "\(formatNumber(amountInManYen))万"
        }

        let oku = amountInManYen / 10000
        return String(format: "%.1f億", oku)
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private func compactHeaderCell(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactValueCell(_ text: String, color: Color = .primary, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.caption2.weight(weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct LabeledNumericField: View {
    let title: String
    @Binding var text: String
    let example: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $text, prompt: Text(example))
                .keyboardType(.decimalPad)
        }
    }
}

struct SimResult: Identifiable {
    let age: Int
    let startAssets: Double
    let investment: Double
    let returnAmount: Double
    let endAssets: Double

    var id: Int { age }
}

#Preview {
    NavigationStack {
        FireSimulatorView()
    }
}
