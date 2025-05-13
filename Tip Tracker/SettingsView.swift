import SwiftUI

// MARK: - Settings Root View
struct SettingsView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double

    var body: some View {
        NavigationView {
            List {
                // General Section
                Section(header: Text("General")) {
                    NavigationLink(destination: HourlyWageDetailView(hourlyWage: $hourlyWage)) {
                        Label("Hourly Wage", systemImage: "dollarsign.circle")
                    }
                    NavigationLink(destination: CurrencyLocaleView()) {
                        Label("Currency Symbol", systemImage: "dollarsign.bank.building")
                    }
                    NavigationLink(destination: ThemeSelectionView()) {
                        Label("Theme", systemImage: "circle.lefthalf.fill")
                    }
                }

                // Records Section
                Section(header: Text("Records")) {
                    NavigationLink(destination: WeekStartSelectionView()) {
                        Label("Week Start Day", systemImage: "arrow.counterclockwise")
                    }
                }

                // Notifications Section
                Section(header: Text("Notifications")) {
                    NavigationLink(destination: ReminderSettingsView()) {
                        Label("Reminders", systemImage: "bell")
                    }
                }

                // Data & Privacy Section
                Section(header: Text("Data & Privacy")) {
                    NavigationLink(destination: ExportDataView()) {
                        Label("Export/Backup Data", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink(destination: GenerateDataView(recordsStore: recordsStore)) {
                        Label("Manage Data", systemImage: "folder")
                    }
                    NavigationLink(destination: ResetDataView(recordsStore: recordsStore)) {
                        Label("Reset Data", systemImage: "trash")
                    }
                    NavigationLink(destination: PrivacyTermsView()) {
                        Label("Privacy & Terms", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .dynamicTypeSize(.xSmall ... .large)
    }
}


/// A custom, full‑screen‑style wage input to match your onboarding look.
private struct HourlyWageDetailView: View {
    @Binding var hourlyWage: Double
    @State private var wageText: String = ""
    @FocusState private var isWageFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon + Title
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Enter your hourly wage")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Explanation
                Text("Your hourly wage is used to calculate your total earnings. Your hours worked will be multiplied by your wage, and any tips you earn will be added on top.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                // Input field
                HStack {
                    Text("$")
                        .font(.title2)
                    TextField("0.00", text: $wageText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .multilineTextAlignment(.leading)
                        .focused($isWageFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveWage()
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Save button
                Button(action: saveWage) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(Double(wageText) == nil)
                .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isWageFieldFocused = false
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .navigationTitle("Hourly Wage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wageText = String(format: "%.2f", hourlyWage)
        }
    }
    
    private func saveWage() {
        if let wage = Double(wageText) {
            hourlyWage = wage
            dismiss()
        }
    }
}

/// A simple placeholder for unimplemented settings.
struct ComingSoonView: View {
    let title: String
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("\(title) Coming Soon")
                .font(.title2)
                .padding(.top, 8)
            Spacer()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Currency & Locale
struct CurrencyLocaleView: View {
    let symbols = ["$", "€", "£"]
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    var body: some View {
        Form {
            Section(header: Text("Select Currency Symbol")) {
                Picker(selection: $currencySymbol) {
                    ForEach(symbols, id: \.self) { symbol in
                        Text(symbol).tag(symbol)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Currency & Locale")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Theme Selection
struct ThemeSelectionView: View {
    enum Theme: String, CaseIterable, Identifiable {
        case system = "Match System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }

    @AppStorage("appTheme") private var appTheme: Theme = .system

    var body: some View {
        Form {
            Section(header: Text("Select Theme")) {
                Picker(selection: $appTheme) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(.xSmall ... .large)
    }
}

// MARK: - Week Start Selection
struct WeekStartSelectionView: View {
    @AppStorage("firstWeekday") private var firstWeekday: Int = 2 // Monday = 2
    @Environment(\.dismiss) private var dismiss
    let weekdays = Calendar.current.weekdaySymbols // Sunday-first array

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Image(systemName: "calendar")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Choose Week Start")
                    .font(.title2)
                    .bold()

                Text("Select the first day of the week. This affects how entries are grouped and how your weekly summaries are calculated.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                Picker("Week starts on", selection: $firstWeekday) {
                    ForEach(1...7, id: \.self) { index in
                        Text(weekdays[index - 1]).tag(index)
                    }
                }
                .pickerStyle(.menu)

                Spacer(minLength: 12)
            }
            .padding(.top, 40)
        }
        .navigationTitle("Week Start Day")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

// MARK: - Reminder Settings
struct ReminderSettingsView: View {
    // Store the time in seconds since reference date
    @AppStorage("reminderTimeInterval") private var reminderTimeInterval: Double = Self.defaultReminderTime().timeIntervalSinceReferenceDate
    
    // Store selected weekdays as comma‑separated integers ("1,3,5")
    @AppStorage("reminderDays") private var reminderDaysString: String = ""
    
    private let weekdays = Calendar.current.weekdaySymbols  // Sunday‐first
    
    // Computed Date backed by that TimeInterval
    private var reminderTime: Date {
        get { Date(timeIntervalSinceReferenceDate: reminderTimeInterval) }
        set { reminderTimeInterval = newValue.timeIntervalSinceReferenceDate }
    }
    
    // Computed Set<Int> for the days (get only)
    private var reminderDays: Set<Int> {
        Set(reminderDaysString
                .split(separator: ",")
                .compactMap { Int($0) }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Time of Day")) {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: { reminderTime },
                        set: { reminderTimeInterval = $0.timeIntervalSinceReferenceDate }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            
            Section(header: Text("Days of Week")) {
                ForEach(1...7, id: \.self) { day in
                    Toggle(isOn: Binding(
                        get: { reminderDays.contains(day) },
                        set: { isOn in
                            var days = reminderDays
                            if isOn { days.insert(day) }
                            else   { days.remove(day) }
                            reminderDaysString = days.sorted().map(String.init).joined(separator: ",")
                        }
                    )) {
                        Text(weekdays[day - 1])
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private static func defaultReminderTime() -> Date {
        var comps = DateComponents()
        comps.hour = 20
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

// MARK: - Export Data
struct ExportDataView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Export Your Data")
                .font(.title2).bold()

            Text("Generate a spreadsheet (.csv) of all your work records to share or backup.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Button("Export to CSV") {
                // TODO: export logic
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top, 40)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

// MARK: - Reset Data
struct ResetDataView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Reset All Data")
                .font(.title2).bold()

            Text("This will permanently delete all of your records. This action cannot be undone.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            Button("Delete Everything") {
                showConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("Reset Data")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top, 40)
        .dynamicTypeSize(.large)
        .alert("Are you sure?", isPresented: $showConfirm) {
            Button("Delete", role: .destructive) {
                // Clear the store and persist
                recordsStore.records.removeAll()
                UserDefaults.standard.saveRecords(recordsStore.records)
                // Go back to Settings
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All records will be lost permanently.")
        }
    }
}

// MARK: - Privacy & Terms
struct PrivacyTermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy & Terms")
                    .font(.title2).bold()

                Text("Tip Tracker is a 100% local app. All your data is stored on your device and never shared or transmitted to any server or third party.")
                Text("You may export your data yourself via the Export feature, but otherwise nothing leaves your device.")
                Text("By using this app, you agree that the developer holds no liability for loss or damage of your data. Please backup regularly.")
                
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Privacy & Terms")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

// MARK: - Generate Data
struct GenerateDataView: View {
    @ObservedObject var recordsStore: RecordsStore
    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate: Date = Date()
    @State private var probability: Double = 0.5
    @State private var hoursMin: Double = 2.0
    @State private var hoursMax: Double = 8.0
    @State private var tipsMin: Double = 0.0
    @State private var tipsMax: Double = 20.0
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let step: Double = 0.25

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Date Range Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Range")
                        .font(.headline)
                    DatePicker("From", selection: $fromDate, displayedComponents: .date)
                    DatePicker("To", selection: $toDate, displayedComponents: .date)
                }
                
                // Probability Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Probability of Entry")
                        .font(.headline)
                    Slider(value: $probability, in: 0...1)
                    Text(String(format: "Chance per day: %.0f%%", probability * 100))
                }
                
                // Hours Range Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hours Range")
                        .font(.headline)
                    HStack {
                        Text("Min:")
                        Slider(value: $hoursMin, in: 2...16, step: step)
                        Text(String(format: "%.2f", hoursMin))
                    }
                    HStack {
                        Text("Max:")
                        Slider(value: $hoursMax, in: hoursMin...16, step: step)
                        Text(String(format: "%.2f", hoursMax))
                    }
                }
                
                // Tip Rate Range Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tip Rate Range ($/hr)")
                        .font(.headline)
                    HStack {
                        Text("Min:")
                        Slider(value: $tipsMin, in: 0...100, step: 0.01)
                        Text(String(format: "$%.2f", tipsMin))
                    }
                    HStack {
                        Text("Max:")
                        Slider(value: $tipsMax, in: tipsMin...100, step: 0.01)
                        Text(String(format: "$%.2f", tipsMax))
                    }
                }
                
                // Generate Button
                Button("Generate") {
                    startGeneration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!recordsStore.records.isEmpty || isGenerating)
                
                if !recordsStore.records.isEmpty {
                    Text("Please clear all existing records before generating data.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Generate Data")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(!recordsStore.records.isEmpty)
        .overlay {
            if isGenerating {
                ProgressView("Generating…")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
            }
        }
        .alert("Generate Data", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func startGeneration() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            var newRecords: [WorkRecord] = []
            let calendar = Calendar.current
            var date = calendar.startOfDay(for: fromDate)
            let end = calendar.startOfDay(for: toDate)
            while date <= end {
                if Double.random(in: 0...1) <= probability {
                    let hours = Double.random(in: hoursMin...hoursMax)
                    let roundedHours = (hours / step).rounded() * step
                    let tipRate = Double.random(in: tipsMin...tipsMax)
                    let tips = roundedHours * tipRate
                    newRecords.append(WorkRecord(hours: roundedHours, tips: tips, date: date))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }
            DispatchQueue.main.async {
                if newRecords.isEmpty {
                    alertMessage = "No records generated. Adjust your probability or date range."
                } else {
                    recordsStore.records = newRecords
                    UserDefaults.standard.saveRecords(newRecords)
                    alertMessage = "Successfully generated \(newRecords.count) records."
                }
                isGenerating = false
                showAlert = true
            }
        }
    }
}

// MARK: - Preview

import Foundation

#Preview("SettingsView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData500)
    SettingsView(recordsStore: store, hourlyWage: .constant(17.40))
        .preferredColorScheme(.light)
}
