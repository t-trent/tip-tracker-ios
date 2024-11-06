import SwiftUI

struct SettingsView: View {
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    
    @State private var wageText: String = ""
    
    // A focus binding for the TextField
    @FocusState private var isWageFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Hourly Wage")) {
                    TextField(
                        "Enter hourly wage",
                        text: $wageText
                    )
                    .keyboardType(.decimalPad)
                    .focused($isWageFieldFocused)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // This places a "Done" button at the top of the keyboard
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        if let parsedValue = Double(wageText) {
                            hourlyWage = parsedValue
                        }
                        isWageFieldFocused = false
                    }
                }
            }
            .onAppear {
                wageText = String(format: "%.2f", hourlyWage)
            }
        }
    }
}
