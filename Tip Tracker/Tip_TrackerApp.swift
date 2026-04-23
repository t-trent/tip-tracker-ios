import SwiftUI

// MARK: - RecordsStore

final class RecordsStore: ObservableObject {
    @Published var records: [WorkRecord]

    init(records: [WorkRecord] = []) {
        self.records = records
    }

    func add(_ record: WorkRecord) {
        records.append(record)
        save()
    }

    func delete(_ record: WorkRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func save() {
        UserDefaults.standard.saveRecords(records)
    }
}

// MARK: - Root View

struct MainAppView: View {
    @State private var store = RecordsStore(records: UserDefaults.standard.loadRecords())
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false
    @State private var showingIntro = false

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
            if !hasSeenIntro { showingIntro = true }
        }
        .sheet(isPresented: $showingIntro) {
            IntroSplashView()
        }
    }
}

// MARK: - App Entry Point

@main
struct MyTipTrackerApp: App {
    @AppStorage("appTheme") private var appThemeRaw: String = ThemeSelectionView.Theme.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch ThemeSelectionView.Theme(rawValue: appThemeRaw) ?? .system {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
