import Foundation

// MARK: - Model

struct WorkRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var hours: Double
    var tips: Double
    var date: Date

    init(id: UUID = UUID(), hours: Double, tips: Double, date: Date) {
        self.id = id
        self.hours = hours
        self.tips = tips
        self.date = date
    }
}

extension WorkRecord: Equatable {
    static func == (lhs: WorkRecord, rhs: WorkRecord) -> Bool {
        lhs.id == rhs.id
    }
}

extension WorkRecord {
    func earnings(wage: Double) -> Double { hours * wage + tips }
    func hourlyRate(wage: Double) -> Double { hours > 0 ? earnings(wage: wage) / hours : 0 }
}

// MARK: - Array Aggregation

extension Array where Element == WorkRecord {
    var totalHours: Double { reduce(0) { $0 + $1.hours } }
    var totalTips: Double { reduce(0) { $0 + $1.tips } }

    func totalEarnings(wage: Double) -> Double { totalHours * wage + totalTips }
    func hourlyRate(wage: Double) -> Double {
        totalHours > 0 ? totalEarnings(wage: wage) / totalHours : 0
    }

    var uniqueDayCount: Int {
        Set(map { Calendar.current.startOfDay(for: $0.date) }).count
    }
}

// MARK: - Persistence

extension UserDefaults {
    private static let recordsKey = "workRecords"

    func saveRecords(_ records: [WorkRecord]) {
        if let encoded = try? JSONEncoder().encode(records) {
            set(encoded, forKey: UserDefaults.recordsKey)
        }
    }

    func loadRecords() -> [WorkRecord] {
        guard let data = data(forKey: UserDefaults.recordsKey),
              let decoded = try? JSONDecoder().decode([WorkRecord].self, from: data)
        else { return [] }
        return decoded
    }
}

// MARK: - Preview Data

extension Double {
    func truncated(to places: Int) -> Double {
        let multiplier = pow(10, Double(places))
        return Double(Int(self * multiplier)) / multiplier
    }
}

extension WorkRecord {
    static let dummyData: [WorkRecord] = {
        var records: [WorkRecord] = []
        let calendar = Calendar.current
        for dayOffset in 0..<50 {
            if Double.random(in: 0..<1) < 0.3 { continue }
            let hours = Double(Int.random(in: 4...8))
            let tips = Double.random(in: 30...80).truncated(to: 2)
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                records.append(WorkRecord(hours: hours, tips: tips, date: date))
            }
        }
        return records
    }()

    static var dummyData500: [WorkRecord] { dummyData }
}
