import SwiftUI
import SwiftData

import SwiftUI

class RecordsStore: ObservableObject {
    @Published var records: [WorkRecord]
    
    init(records: [WorkRecord] = []) {
        self.records = records
    }
}

struct MainAppView: View {
    
    @State private var store = RecordsStore(records: UserDefaults.standard.loadRecords())
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    
    var body: some View {
        TabView {
            ContentView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TrendsView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem {
                    Label("Trends", systemImage: "chart.bar.xaxis")
                }
            CalendarView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            SettingsView(recordsStore: store, hourlyWage: $hourlyWage)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

@main
struct MyTipTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
}
