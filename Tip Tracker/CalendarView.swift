import SwiftUI

// MARK: - CalendarSecondStat

enum CalendarSecondStat: String {
    case tips       = "Tips"
    case earnings   = "Earnings"
    case hourlyRate = "Hourly Rate"
}

// MARK: - CalendarView

struct CalendarView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double

    @AppStorage("firstWeekday") private var firstWeekday: Int = 2
    @AppStorage("calendarSecondStat") private var secondStat: CalendarSecondStat = .tips

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var isShowingEditSheet = false
    @State private var isShowingMonthPicker = false

    private var recordsByDay: [Date: WorkRecord] {
        let cal = Calendar.current
        var dict: [Date: WorkRecord] = [:]
        for record in recordsStore.records {
            dict[cal.startOfDay(for: record.date)] = record
        }
        return dict
    }

    private var yearRange: ClosedRange<Int> {
        let cal = Calendar.current
        let current = cal.component(.year, from: Date())
        let earliest = recordsStore.records.map { cal.component(.year, from: $0.date) }.min() ?? current
        return earliest...(current + 2)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                monthHeader
                statToggle
                dayOfWeekHeader
                calendarGrid
                Divider()
                selectedDayPanel
                Spacer()
            }
            .navigationTitle("Calendar")
            .sheet(isPresented: $isShowingEditSheet) {
                editSheet
            }
        }
        .dynamicTypeSize(.xSmall ... .large)
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { advanceMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal)
            }
            Spacer()
            Button { isShowingMonthPicker = true } label: {
                HStack(spacing: 4) {
                    Text(Formatters.monthYear.string(from: displayedMonth))
                        .font(.title2.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .sheet(isPresented: $isShowingMonthPicker) {
                MonthYearPickerSheet(displayedMonth: $displayedMonth, yearRange: yearRange)
                    .presentationDetents([.height(280)])
            }
            Spacer()
            Button { advanceMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func advanceMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = next
        }
    }

    // MARK: - Stat Toggle

    private var statToggle: some View {
        HStack {
            Text("Show:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Second stat", selection: $secondStat) {
                Text("Tips").tag(CalendarSecondStat.tips)
                Text("Earnings").tag(CalendarSecondStat.earnings)
                Text("Hourly").tag(CalendarSecondStat.hourlyRate)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        let symbols = orderedWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let offset = firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = buildMonthGrid()
        let byDay = recordsByDay
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let date = day {
                    let record = byDay[Calendar.current.startOfDay(for: date)]
                    DayCell(
                        date: date,
                        record: record,
                        hourlyWage: hourlyWage,
                        secondStat: secondStat,
                        isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: Calendar.current.isDateInToday(date)
                    ) {
                        let alreadySelected = selectedDate.map {
                            Calendar.current.isDate($0, inSameDayAs: date)
                        } ?? false
                        selectedDate = alreadySelected ? nil : date
                    }
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .aspectRatio(CGSize(width: 1, height: 1.1), contentMode: .fit)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func buildMonthGrid() -> [Date?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = cal.date(from: comps),
              let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)?.count
        else { return [] }

        let weekdayOfFirst = cal.component(.weekday, from: firstDay)
        let offset = (weekdayOfFirst - firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<daysInMonth {
            days.append(cal.date(byAdding: .day, value: i, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    // MARK: - Selected Day Panel

    @ViewBuilder
    private var selectedDayPanel: some View {
        if let date = selectedDate {
            let dayRecords = recordsStore.records.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            if !dayRecords.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    DayMetricsView(
                        dayRecords: dayRecords,
                        hourlyWage: hourlyWage,
                        date: date,
                        onEdit: { isShowingEditSheet = true }
                    )
                    .padding(.bottom)
                }
                .frame(maxHeight: 160)
            } else {
                Text("No records for \(Formatters.fullDate.string(from: date))")
                    .padding()
                    .padding(.vertical)
            }
        }
    }

    // MARK: - Edit Sheet

    @ViewBuilder
    private var editSheet: some View {
        if let date = selectedDate,
           let record = recordsStore.records.first(where: {
               Calendar.current.isDate($0.date, inSameDayAs: date)
           }),
           let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
            NavigationView {
                EditRecordView(
                    record: $recordsStore.records[index],
                    onDelete: {
                        recordsStore.delete(record)
                        isShowingEditSheet = false
                    },
                    onSave: {
                        recordsStore.save()
                        isShowingEditSheet = false
                    }
                )
                .navigationTitle("Edit Record")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingEditSheet = false }
                    }
                }
            }
        } else {
            Text("No record selected")
        }
    }
}

// MARK: - MonthYearPickerSheet

private struct MonthYearPickerSheet: View {
    @Binding var displayedMonth: Date
    let yearRange: ClosedRange<Int>
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    init(displayedMonth: Binding<Date>, yearRange: ClosedRange<Int>) {
        _displayedMonth = displayedMonth
        let comps = Calendar.current.dateComponents([.year, .month], from: displayedMonth.wrappedValue)
        _selectedMonth = State(initialValue: comps.month ?? 1)
        _selectedYear  = State(initialValue: comps.year ?? Calendar.current.component(.year, from: Date()))
        self.yearRange = yearRange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .padding()
                Spacer()
                Button("Done") {
                    var comps = DateComponents()
                    comps.year  = selectedYear
                    comps.month = selectedMonth
                    comps.day   = 1
                    if let date = Calendar.current.date(from: comps) {
                        displayedMonth = date
                    }
                    dismiss()
                }
                .bold()
                .padding()
            }
            Divider()
            HStack(spacing: 0) {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Year", selection: $selectedYear) {
                    ForEach(yearRange, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 110)
            }
        }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let date: Date
    let record: WorkRecord?
    let hourlyWage: Double
    let secondStat: CalendarSecondStat
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(dayNumberColor)

                if let record {
                    Text(hoursText(record.hours))
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(1)
                    Text(secondStatText(for: record))
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .aspectRatio(CGSize(width: 1, height: 1.1), contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(cellFill)
            )
        }
        .buttonStyle(.plain)
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    private func hoursText(_ hours: Double) -> String {
        return String(format: "%.2f h", hours)
    }

    private func secondStatText(for record: WorkRecord) -> String {
        switch secondStat {
        case .tips:       return formatCurrency(record.tips)
        case .earnings:   return formatCurrency(record.earnings(wage: hourlyWage))
        case .hourlyRate: return formatCurrency(record.hourlyRate(wage: hourlyWage)) + "/hr"
        }
    }

    private var dayNumberColor: Color {
        if isSelected { return .white }
        if isToday    { return .accentColor }
        return .primary
    }

    private var cellFill: Color {
        if isSelected    { return .accentColor }
        if record != nil { return Color.accentColor.opacity(0.1) }
        return .clear
    }
}

// MARK: - DayMetricsView

struct DayMetricsView: View {
    let dayRecords: [WorkRecord]
    let hourlyWage: Double
    let date: Date
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Formatters.fullDate.string(from: date))
                    .font(.headline)
                Spacer()
                if let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                    }
                }
            }

            MetricGrid(
                topLeading:    ("Total Hours",    String(format: "%.2f", dayRecords.totalHours)),
                topTrailing:   ("Total Earnings", formatCurrency(dayRecords.totalEarnings(wage: hourlyWage))),
                bottomLeading: ("Total Tips",     formatCurrency(dayRecords.totalTips)),
                bottomTrailing:("Hourly Rate",    formatCurrency(dayRecords.hourlyRate(wage: hourlyWage)) + "/hr"),
                valueFont: .title3
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("CalendarView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData)
    CalendarView(recordsStore: store, hourlyWage: .constant(17.40))
}
