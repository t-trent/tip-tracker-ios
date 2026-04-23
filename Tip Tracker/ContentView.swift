import SwiftUI

struct ContentView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double
    @AppStorage("firstWeekday") private var firstWeekday: Int = 2
    @State private var isPresentingSheet = false

    var body: some View {
        NavigationView {
            Group {
                if recordsStore.records.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .navigationTitle("Tip Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isPresentingSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingSheet) {
                AddRecordView { newRecord in
                    recordsStore.add(newRecord)
                    isPresentingSheet = false
                }
            }
        }
        .dynamicTypeSize(.xSmall ... .large)
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No records yet")
                .font(.title2).bold()
            Text("Tap the \"+\" button above to add your first work record.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var recordsList: some View {
        List {
            ForEach(sortedWeekStarts, id: \.self) { weekStart in
                sectionView(for: weekStart)
            }
        }
    }

    // MARK: - Grouping

    private var groupedRecords: [Date: [WorkRecord]] {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return Dictionary(grouping: recordsStore.records) { record in
            calendar.dateInterval(of: .weekOfYear, for: record.date)?.start ?? record.date
        }
    }

    private var sortedWeekStarts: [Date] {
        groupedRecords.keys.sorted(by: >)
    }

    // MARK: - Section & Row Builders

    private func sectionView(for weekStart: Date) -> some View {
        let weekRecords = recordsForWeek(weekStart)
        return Section(
            header: HeaderSummaryView(
                records: weekRecords,
                hourlyWage: hourlyWage,
                headerText: "Week of \(Formatters.shortDate.string(from: weekStart))"
            )
        ) {
            ForEach(weekRecords) { record in
                recordRow(for: record)
            }
        }
    }

    private func recordsForWeek(_ weekStart: Date) -> [WorkRecord] {
        (groupedRecords[weekStart] ?? []).sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func recordRow(for record: WorkRecord) -> some View {
        if let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
            NavigationLink(destination: EditRecordView(
                record: $recordsStore.records[index],
                onDelete: { recordsStore.delete(record) },
                onSave: { recordsStore.save() }
            )) {
                ItemSummaryView(
                    records: [record],
                    hourlyWage: hourlyWage,
                    itemText: Formatters.recordDate.string(from: record.date)
                )
            }
        }
    }

    // MARK: - Week Header View

    struct HeaderSummaryView: View {
        let records: [WorkRecord]
        let hourlyWage: Double
        let headerText: String
        @State private var isExpanded = false

        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                MetricGrid(
                    topLeading:    ("Hours",       String(format: "%.2f", records.totalHours)),
                    topTrailing:   ("Earnings",    formatCurrency(records.totalEarnings(wage: hourlyWage))),
                    bottomLeading: ("Tips",        formatCurrency(records.totalTips)),
                    bottomTrailing:("Hourly Rate", formatCurrency(records.hourlyRate(wage: hourlyWage)) + "/hr"),
                    valueFont: .headline
                )
                .padding(.top, 8)
            } label: {
                Text(headerText)
                    .font(.title3).bold()
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Record Row View

    struct ItemSummaryView: View {
        let records: [WorkRecord]
        let hourlyWage: Double
        let itemText: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(itemText)
                    .font(.body).bold()
                    .padding(.bottom, 4)
                MetricGrid(
                    topLeading:    ("Hours",       String(format: "%.2f", records.totalHours)),
                    topTrailing:   ("Earnings",    formatCurrency(records.totalEarnings(wage: hourlyWage))),
                    bottomLeading: ("Tips",        formatCurrency(records.totalTips)),
                    bottomTrailing:("Hourly Rate", formatCurrency(records.hourlyRate(wage: hourlyWage)) + "/hr")
                )
            }
        }
    }
}

// MARK: - Add Record View

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
                    clearableField("Hours Worked", text: $hoursWorked)
                    clearableField("Tips Earned", text: $tipsEarned)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Record")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let hours = Double(hoursWorked), let tips = Double(tipsEarned) {
                            onSave(WorkRecord(hours: hours, tips: tips, date: selectedDate))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clearableField(_ placeholder: String, text: Binding<String>) -> some View {
        ZStack(alignment: .trailing) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .padding(.trailing, 30)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
    }
}

// MARK: - Edit Record View

struct EditRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var record: WorkRecord
    var onDelete: () -> Void
    var onSave: () -> Void

    enum Field: Hashable { case hours, tips }
    @FocusState private var focusedField: Field?

    @State private var hoursText = ""
    @State private var tipsText = ""
    @State private var selectedDate: Date
    @State private var isShowingDeleteConfirmation = false

    init(record: Binding<WorkRecord>, onDelete: @escaping () -> Void, onSave: @escaping () -> Void) {
        _record = record
        self.onDelete = onDelete
        self.onSave = onSave
        _selectedDate = State(initialValue: record.wrappedValue.date)
    }

    var body: some View {
        Form {
            Section(header: Text("Edit Work Details")) {
                labeledField("Hours", text: $hoursText, field: .hours)
                labeledField("Tips Earned", text: $tipsText, field: .tips)
                HStack {
                    Text("Date").frame(width: 100, alignment: .leading)
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
                    if let h = Double(hoursText) { record.hours = h }
                    if let t = Double(tipsText)  { record.tips  = t }
                    record.date = selectedDate
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("Are you sure you want to delete?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            hoursText = String(record.hours)
            tipsText  = String(format: "%.2f", record.tips)
            focusedField = .hours
        }
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(label).frame(width: 100, alignment: .leading)
            ZStack(alignment: .trailing) {
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .focused($focusedField, equals: field)
                    .padding(.trailing, 30)
                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                        focusedField = field
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("ContentView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData)
    ContentView(recordsStore: store, hourlyWage: .constant(17.40))
}
