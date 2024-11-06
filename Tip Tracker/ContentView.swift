import SwiftUI

struct ContentView: View {
    @State private var records: [WorkRecord] = UserDefaults.standard.loadRecords()
    @State private var isPresentingSheet = false
    
    // Read the hourly wage from UserDefaults via @AppStorage
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    
    var body: some View {
        NavigationView {
            List {
                let sortedWeekStarts = groupedRecords.keys.sorted(by: >)
                
                ForEach(sortedWeekStarts, id: \.self) { weekStart in
                    let recordsForWeek = (groupedRecords[weekStart] ?? [])
                        .sorted { $0.date > $1.date } // Ascending date order
                    
                    // Calculate weekly totals
                    let totalHours = recordsForWeek.reduce(0.0) { $0 + $1.hours }
                    let totalTips  = recordsForWeek.reduce(0.0) { $0 + $1.tips }
                    let totalEarningsForWeek = totalHours * hourlyWage + totalTips
                    let weeklyAverageRate = (totalHours > 0) ? (totalEarningsForWeek / totalHours) : 0
                    
                    Section(
                        header: VStack(alignment: .leading, spacing: 4) {
                            Text("Week of \(formattedWeekDate(weekStart))")
                                .font(.headline)
                                .bold()
                            
                            // Subheading with weekly total hours and tips
                            Text("""
                                Hours: \(totalHours, specifier: "%.2f")  \
                                |  Tips: $\(totalTips, specifier: "%.2f")  \
                                |  Hourly: $\(weeklyAverageRate, specifier: "%.2f")/hr  \
                                |  Total: $\(totalEarningsForWeek, specifier: "%.2f")
                                """)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    ) {
                        ForEach(recordsForWeek) { record in
                            if let index = records.firstIndex(where: { $0.id == record.id }) {
                                NavigationLink(
                                    destination: EditRecordView(
                                        record: $records[index],
                                        onDelete: { deleteRecord(record) },
                                        onSave: { UserDefaults.standard.saveRecords(records) }
                                    )
                                ) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formattedDate(record.date))
                                            .font(.headline)
                                            .bold()
                                        HStack {
                                            Text("Hours:")
                                                .bold()
                                            Text(hoursText(for: record.hours))
                                        }
                                        HStack {
                                            Text("Tips:")
                                                .bold()
                                            Text("$\(record.tips, specifier: "%.2f")")
                                        }
                                        // Now show total earnings
                                        HStack {
                                            Text("Total Earnings:")
                                                .bold()
                                            Text(totalEarningsString(for: record))
                                        }
                                        
                                        // Hourly Rate
                                        HStack {
                                            Text("Hourly Rate:")
                                                .bold()
                                            Text(hourlyRateString(for: record))
                                        }

                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tip Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresentingSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingSheet) {
                AddRecordView { newRecord in
                    records.append(newRecord)
                    UserDefaults.standard.saveRecords(records)
                    isPresentingSheet = false
                }
            }
        }
    }
    
    /// Calculate and format total earnings = (hours * hourlyWage) + tips
    private func totalEarningsString(for record: WorkRecord) -> String {
        let total = record.hours * hourlyWage + record.tips
        return String(format: "$%.2f", total)
    }
    
    private func hoursText(for hours: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        
        // Attempt to format; fallback to raw string if needed
        if let formatted = formatter.string(from: hours as NSNumber) {
            return formatted
        } else {
            return String(hours)
        }
    }
    
    private func hourlyRateString(for record: WorkRecord) -> String {
        // total = hours * hourlyWage + tips
        let total = record.hours * hourlyWage + record.tips
        
        // Avoid dividing by zero if hours = 0
        guard record.hours > 0 else { return "$0.00/hr" }
        
        let rate = total / record.hours
        return String(format: "$%.2f/hr", rate)
    }
    
    private var groupedRecords: [Date: [WorkRecord]] {
        // Create a mutable copy of Calendar.current
        var calendar = Calendar.current
        // Force Monday (2) as the first weekday
        calendar.firstWeekday = 2
        
        let grouped = Dictionary(grouping: records) { record in
            let interval = calendar.dateInterval(of: .weekOfYear, for: record.date)
            return interval?.start ?? record.date
        }
        return grouped
    }
    
    // Delete record and save updated list
    private func deleteRecord(_ record: WorkRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records.remove(at: index)
            UserDefaults.standard.saveRecords(records)
        }
    }
    
    // Format individual record date (e.g., "Wednesday, Jan 1, 2025")
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formattedWeekDate(_ date: Date, format: String = "MMM d, yyyy") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

}

// Model for Work Record
struct WorkRecord: Identifiable, Codable {
    var id = UUID()
    var hours: Double
    var tips: Double
    var date: Date
}

// View for adding a new record
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

struct EditRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var record: WorkRecord
    var onDelete: () -> Void
    var onSave: () -> Void

    @State private var hoursText: String = ""
    @State private var tipsText: String = ""
    @State private var selectedDate: Date
    
    // For the delete confirmation
    @State private var isShowingDeleteConfirmation = false

    init(record: Binding<WorkRecord>,
         onDelete: @escaping () -> Void,
         onSave: @escaping () -> Void
    ) {
        _record = record
        self.onDelete = onDelete
        self.onSave = onSave
        _selectedDate = State(initialValue: record.wrappedValue.date)
    }

    var body: some View {
        Form {
            Section(header: Text("Edit Work Details")) {
                // Hours
                HStack {
                    Text("Hours")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $hoursText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                }

                // Tips
                HStack {
                    Text("Tips Earned")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $tipsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                }

                // Date
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
                    // Parse hours
                    if let parsedHours = Double(hoursText) {
                        record.hours = parsedHours
                    }
                    // Parse tips
                    if let parsedTips = Double(tipsText) {
                        record.tips = parsedTips
                    }
                    record.date = selectedDate

                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        // Show the delete confirmation
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
        // On appear, format the text with exactly two decimals
        .onAppear {
            hoursText = String(record.hours)
            tipsText  = String(format: "%.2f", record.tips)
        }
    }
}
