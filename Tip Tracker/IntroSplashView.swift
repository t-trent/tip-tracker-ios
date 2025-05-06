import SwiftUI

struct IntroSplashView: View {
    // Dismiss the sheet once we're fully done.
    @Environment(\.dismiss) private var dismiss
    // Persist that we’ve completed the intro flow.
    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false
    // Save their wage directly to AppStorage.
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0
    
    @State private var isAnimating = false
    
    // A tiny enum to drive our navigation.
    private enum Route: Hashable {
        case wageInput
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // MARK: Logo + Title
                VStack(spacing: 16) {
                    Text("Welcome to Tip Tracker!")
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // MARK: Features
                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(
                        icon: "house.fill",
                        title: "Record Tracking",
                        description: "Log daily work records including hours worked and tips received."
                    )
                    FeatureRow(
                        icon: "chart.bar.xaxis",
                        title: "Trends Analysis",
                        description: "View charts and summary metrics that display overall, daily, weekly, and monthly earnings trends."
                    )
                    FeatureRow(
                        icon: "calendar",
                        title: "Calendar View",
                        description: "A calendar marks days with records with a dot. Tap a day to view aggregated metrics and quickly edit records."
                    )
                    FeatureRow(
                        icon: "gearshape",
                        title: "Settings",
                        description: "Customize settings such as your hourly wage, currency, locale, and other preferences."
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // MARK: Navigation to Wage Input
                NavigationLink(value: Route.wageInput) {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
            }
            .padding(.top, 50)
            .padding(.bottom, 40)
            // Clamp the entire view’s dynamic type
            .dynamicTypeSize(...DynamicTypeSize.large)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .wageInput:
                    WageInputView { enteredWage in
                        // Save wage, mark intro done, and dismiss the sheet
                        hourlyWage = enteredWage
                        hasSeenIntro = true
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A simple wage‐input form with a “Save” button.
private struct WageInputView: View {
    @State private var wageText: String = ""
    @FocusState private var isWageFieldFocused: Bool
    let onComplete: (Double) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon + Title
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("What's your hourly wage?")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Explanation
                Text("Your hourly wage is used to calculate your total earnings.")
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
                        .onSubmit { isWageFieldFocused = false }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                // Save button
                Button(action: {
                    if let wage = Double(wageText) {
                        onComplete(wage)
                    }
                }) {
                    Text("Save & Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .disabled(Double(wageText) == nil)

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
        .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview("Intro Flow") {
    IntroSplashView()
}
