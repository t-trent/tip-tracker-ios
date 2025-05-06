import SwiftUI
import SwiftData

class RecordsStore: ObservableObject {
    @Published var records: [WorkRecord]
    
    init(records: [WorkRecord] = []) {
        self.records = records
    }
}

struct MainAppView: View {
    @State private var store = RecordsStore(records: UserDefaults.standard.loadRecords())
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0

    // 1) Track whether we've ever shown the intro
    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false
    // 2) Control the sheet presentation
    @State private var showingIntro: Bool = false

    var body: some View {
        TabView {
            ContentView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem { Label("Home", systemImage: "house.fill") }

            TrendsView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem { Label("Trends", systemImage: "chart.bar.xaxis") }

            CalendarView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            if !hasSeenIntro {
                showingIntro = true
            }
        }
        .sheet(isPresented: $showingIntro) {
            IntroSplashView()
        }
    }
}

@main
struct MyTipTrackerApp: App {
    // Read the user's theme preference
    @AppStorage("appTheme") private var appThemeRaw: String = ThemeSelectionView.Theme.system.rawValue
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .preferredColorScheme({ () -> ColorScheme? in
                    switch ThemeSelectionView.Theme(rawValue: appThemeRaw) ?? .system {
                    case .system: return nil
                    case .light: return .light
                    case .dark: return .dark
                    }
                }())
        }
    }
}
