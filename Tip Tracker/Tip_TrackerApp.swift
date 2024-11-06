import SwiftUI
import SwiftData

// 1) Create a new container view for the tabs
struct MainAppView: View {
    @State private var records: [WorkRecord] = UserDefaults.standard.loadRecords()
        @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.bar.xaxis")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// 2) In your App entry point, show MainAppView
@main
struct MyTipTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}
