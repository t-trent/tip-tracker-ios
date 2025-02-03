import SwiftUI

struct ContentView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double
    @State private var isPresentingSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedWeekStarts, id: \.self) { weekStart in
                    sectionView(for: weekStart)
                }
            }
            .navigationTitle("Tip Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingSheet) {
                AddRecordView { newRecord in
                    // Append new record to the shared store.
                    recordsStore.records.append(newRecord)
                    UserDefaults.standard.saveRecords(recordsStore.records)
                    isPresentingSheet = false
                }
            }
        }
    }
    
    // MARK: - Helper Computed Properties
    
    /// Groups records by week, using Monday as the first day of the week.
    private var groupedRecords: [Date: [WorkRecord]] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        return Dictionary(grouping: recordsStore.records) { record in
            let interval = calendar.dateInterval(of: .weekOfYear, for: record.date)
            return interval?.start ?? record.date
        }
    }
    
    /// Sorted week start dates (most recent first)
    private var sortedWeekStarts: [Date] {
        groupedRecords.keys.sorted(by: >)
    }
    
    // MARK: - Section and Row Builders
    
    /// Returns a section view for a given week start date.
    private func sectionView(for weekStart: Date) -> some View {
        let recordsForWeek = recordsForWeek(for: weekStart)
        return Section(
            header: HeaderSummaryView(
                records: recordsForWeek,
                hourlyWage: hourlyWage,
                headerText: "Week of \(formattedWeekDate(weekStart))"
            )
        ) {
            ForEach(recordsForWeek) { record in
                recordRow(for: record)
            }
        }
    }
    
    /// Returns all records for a given week start date, sorted descending by date.
    private func recordsForWeek(for weekStart: Date) -> [WorkRecord] {
        (groupedRecords[weekStart] ?? []).sorted { $0.date > $1.date }
    }
    
    /// Creates a row view for a single record.
    private func recordRow(for record: WorkRecord) -> some View {
        if let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
            return AnyView(
                NavigationLink(
                    destination: EditRecordView(
                        record: $recordsStore.records[index],
                        onDelete: { deleteRecord(record) },
                        onSave: { UserDefaults.standard.saveRecords(recordsStore.records) }
                    )
                ) {
                    // Replace the manual record summary with ItemSummaryView.
                    ItemSummaryView(
                        records: [record],
                        hourlyWage: hourlyWage,
                        itemText: formattedDate(record.date)
                    )
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // MARK: - Formatting and Calculations
    
    /// Returns a formatted string for total earnings (hours * hourlyWage + tips).
    private func totalEarningsString(for record: WorkRecord) -> String {
        let total = record.hours * hourlyWage + record.tips
        return formatCurrency(total)
    }
    
    /// Formats the hours value using a NumberFormatter.
    private func hoursText(for hours: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter.string(from: hours as NSNumber) ?? String(hours)
    }
    
    /// Returns a formatted hourly rate string.
    private func hourlyRateString(for record: WorkRecord) -> String {
        let total = record.hours * hourlyWage + record.tips
        guard record.hours > 0 else { return "$0.00/hr" }
        let rate = total / record.hours
        return formatCurrency(rate) + "/hr"
    }
    
    /// Formats an individual record's date.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    /// Formats the week header date.
    private func formattedWeekDate(_ date: Date, format: String = "MMM d, yyyy") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    /// Deletes a record and saves the updated list.
    private func deleteRecord(_ record: WorkRecord) {
        if let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
            recordsStore.records.remove(at: index)
            UserDefaults.standard.saveRecords(recordsStore.records)
        }
    }
    
    // MARK: - HeaderSummaryView
    
    /// A header view that shows the headerText and a tappable arrow to expand/collapse the weekly summary.
    struct HeaderSummaryView: View {
        let records: [WorkRecord]
        let hourlyWage: Double
        let headerText: String
        
        @State private var isExpanded: Bool = false
        
        private var totalHours: Double {
            records.reduce(0) { $0 + $1.hours }
        }
        
        private var totalTips: Double {
            records.reduce(0) { $0 + $1.tips }
        }
        
        private var totalEarnings: Double {
            (totalHours * hourlyWage) + totalTips
        }
        
        private var hourlyRate: Double {
            totalHours == 0 ? 0 : totalEarnings / totalHours
        }
        
        var body: some View {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    // Expanded content: now row 1 shows Hours and Earnings, row 2 shows Tips and Hourly Rate.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Hours")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", totalHours))
                                    .font(.headline)
                                    .bold()
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Earnings")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalEarnings))
                                    .font(.headline)
                                    .bold()
                            }
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Tips")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(totalTips))
                                    .font(.headline)
                                    .bold()
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Hourly Rate")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(hourlyRate) + "/hr")
                                    .font(.headline)
                                    .bold()
                            }
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    // The collapsed header remains unchanged.
                    HStack {
                        Text(headerText)
                            .font(.title3)
                            .bold()
                    }
                    .padding(.vertical, 4)
                }
            )
        }
    }
    
    struct ItemSummaryView: View {
        let records: [WorkRecord]
        let hourlyWage: Double
        let itemText: String
        
        private var totalHours: Double {
            records.reduce(0) { $0 + $1.hours }
        }
        
        private var totalTips: Double {
            records.reduce(0) { $0 + $1.tips }
        }
        
        private var totalEarnings: Double {
            (totalHours * hourlyWage) + totalTips
        }
        
        private var hourlyRate: Double {
            totalHours == 0 ? 0 : totalEarnings / totalHours
        }
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(itemText)
                    .font(.body)
                    .padding(.bottom, 4)
                    .bold()
                
                // First row: Hours and Earnings.
                HStack {
                    VStack(alignment: .leading) {
                        Text("Hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", totalHours))
                            .font(.body)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Earnings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(totalEarnings))
                            .font(.body)
                            .bold()
                    }
                }
                // Second row: Tips and Hourly Rate.
                HStack {
                    VStack(alignment: .leading) {
                        Text("Tips")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(totalTips))
                            .font(.body)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Hourly Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(hourlyRate) + "/hr")
                            .font(.body)
                            .bold()
                    }
                }
            }
        }
    }
}

// MARK: - Models and Other Views

struct WorkRecord: Identifiable, Codable {
    var id = UUID()
    var hours: Double
    var tips: Double
    var date: Date
}

extension WorkRecord: Equatable {
    public static func == (lhs: WorkRecord, rhs: WorkRecord) -> Bool {
        return lhs.date == rhs.date &&
               lhs.hours == rhs.hours &&
               lhs.tips == rhs.tips
    }
}

struct AddRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var hoursWorked = ""
    @State private var tipsEarned = ""
    @State private var selectedDate = Date()
    
    var onSave: (WorkRecord) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Work Details")) {
                    TextField("Hours Worked", text: $hoursWorked)
                        .keyboardType(.decimalPad)
                    TextField("Tips Earned", text: $tipsEarned)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Record")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let hours = Double(hoursWorked),
                           let tips = Double(tipsEarned) {
                            let newRecord = WorkRecord(hours: hours, tips: tips, date: selectedDate)
                            onSave(newRecord)
                        }
                    }
                }
            }
        }
    }
}

struct EditRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var record: WorkRecord
    var onDelete: () -> Void
    var onSave: () -> Void
    
    @State private var hoursText: String = ""
    @State private var tipsText: String = ""
    @State private var selectedDate: Date
    @State private var isShowingDeleteConfirmation = false
    
    init(record: Binding<WorkRecord>,
         onDelete: @escaping () -> Void,
         onSave: @escaping () -> Void) {
        _record = record
        self.onDelete = onDelete
        self.onSave = onSave
        _selectedDate = State(initialValue: record.wrappedValue.date)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Edit Work Details")) {
                HStack {
                    Text("Hours")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $hoursText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Text("Tips Earned")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $tipsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Text("Date")
                        .frame(width: 100, alignment: .leading)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            Section {
                Button("Delete Record", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if let parsedHours = Double(hoursText) {
                        record.hours = parsedHours
                    }
                    if let parsedTips = Double(tipsText) {
                        record.tips = parsedTips
                    }
                    record.date = selectedDate
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("Are you sure you want to delete?",
               isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            hoursText = String(record.hours)
            tipsText  = String(format: "%.2f", record.tips)
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let recordsKey = "workRecords"
    
    func saveRecords(_ records: [WorkRecord]) {
        if let encoded = try? JSONEncoder().encode(records) {
            set(encoded, forKey: UserDefaults.recordsKey)
        }
    }
    
    func loadRecords() -> [WorkRecord] {
        if let data = data(forKey: UserDefaults.recordsKey),
           let decoded = try? JSONDecoder().decode([WorkRecord].self, from: data) {
            return decoded
        }
        return []
    }
}

// MARK: - Currency Formatter Helper

private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
}

// MARK: - Preview

import Foundation

#Preview("ContentView with Dummy Data") {
    // Create a RecordsStore with the dummy data.
    let store = RecordsStore(records: WorkRecord.dummyData500)
    ContentView(recordsStore: store, hourlyWage: .constant(17.40))
        .preferredColorScheme(.light)
}
