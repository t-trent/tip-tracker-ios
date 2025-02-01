import SwiftUI

struct SettingsView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double

    // Now the initializer accepts a RecordsStore.
    init(recordsStore: RecordsStore, hourlyWage: Binding<Double>) {
        self._recordsStore = ObservedObject(wrappedValue: recordsStore)
        _hourlyWage = hourlyWage
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: General Section
                Section(header: Text("General")) {
                    NavigationLink(destination: HourlyWageDetailView(hourlyWage: $hourlyWage)) {
                        HStack {
                            Text("Hourly Wage")
                            Spacer()
                            Text(String(format: "$%.2f", hourlyWage))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: ComingSoonView(title: "Currency & Locale")) {
                        Text("Currency & Locale")
                    }
                    
                    NavigationLink(destination: ComingSoonView(title: "Theme")) {
                        Text("Theme")
                    }
                }
                
                // MARK: Records Section
                Section(header: Text("Records")) {
                    NavigationLink(destination: ComingSoonView(title: "Default Tip Percentage")) {
                        Text("Default Tip Percentage")
                    }
                    
                    NavigationLink(destination: ComingSoonView(title: "Sorting Options")) {
                        Text("Sorting Options")
                    }
                }
                
                // MARK: Notifications Section
                Section(header: Text("Notifications")) {
                    NavigationLink(destination: ComingSoonView(title: "Reminders")) {
                        Text("Reminders")
                    }
                }
                
                // MARK: Data & Privacy Section
                Section(header: Text("Data & Privacy")) {
                    NavigationLink(destination: ComingSoonView(title: "Export/Backup Data")) {
                        Text("Export/Backup Data")
                    }
                    
                    NavigationLink(destination: ComingSoonView(title: "Reset Data")) {
                        Text("Reset Data")
                    }
                    
                    NavigationLink(destination: ComingSoonView(title: "Privacy & Terms")) {
                        Text("Privacy & Terms")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct HourlyWageDetailView: View {
    @Binding var hourlyWage: Double
    @State private var wageText: String = ""
    @FocusState private var isWageFieldFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Information")) {
                Text("Your hourly wage is used to calculate your total earnings. Your hours worked will be multiplied by your hourly wage, and any tips will be added.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Enter Your Hourly Wage")) {
                TextField("Hourly Wage", text: $wageText)
                    .keyboardType(.decimalPad)
                    .focused($isWageFieldFocused)
            }
        }
        .navigationTitle("Hourly Wage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Toolbar for the keyboard
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    if let parsedValue = Double(wageText) {
                        hourlyWage = parsedValue
                    }
                    isWageFieldFocused = false
                }
            }
            // Save button in the navigation bar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if let parsedValue = Double(wageText) {
                        hourlyWage = parsedValue
                    }
                }
            }
        }
        .onAppear {
            wageText = String(format: "%.2f", hourlyWage)
        }
    }
}

/// A simple placeholder view for settings options not yet implemented.
struct ComingSoonView: View {
    let title: String
    
    var body: some View {
        VStack {
            Text("\(title) Coming Soon")
                .font(.title2)
                .padding()
            Spacer()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

import Foundation

#Preview("SettingsView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData500)
    SettingsView(recordsStore: store, hourlyWage: .constant(17.40))
        .preferredColorScheme(.light)
}
