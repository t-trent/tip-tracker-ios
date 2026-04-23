# Tip Tracker — Specification & Refactoring Guide

## 1. Application Overview

**Tip Tracker** is an iOS application that helps service-industry workers log daily work records (hours worked and tips earned), view earnings trends over time, and browse records on a calendar. All data is stored locally on-device using `UserDefaults` with JSON encoding.

### Core Value Proposition
- Simple, fast entry of daily work records (hours + tips)
- Automatic calculation of total earnings (hours × hourly wage + tips)
- Visual trends via bar charts (weekly, monthly, yearly)
- Calendar view with dot indicators for days with records
- 100% local/private — no server communication

---

## 2. Current Architecture Analysis

### 2.1 File Structure (as-is)

| File | Lines | Responsibility |
|------|-------|---------------|
| `Tip_TrackerApp.swift` | 63 | App entry point, `RecordsStore`, `MainAppView` (tab bar), theme application |
| `ContentView.swift` | 565 | Home tab, record list grouped by week, `WorkRecord` model, `AddRecordView`, `EditRecordView`, `UserDefaults` extension, `formatCurrency()`, `HeaderSummaryView`, `ItemSummaryView` |
| `TrendsView.swift` | 1197 | Trends tab, `TrendsViewModel`, `ChartView`, `SummaryView`, `GroupedMetrics`, `Grouping`/`Metric` enums, `allDates()` helper, `WorkRecord.dummyData500`, `Double.truncated(to:)` |
| `CalendarView.swift` | 312 | Calendar tab, `CalendarUIKitView` (UIViewRepresentable), `DayMetricsView` |
| `SettingsView.swift` | 582 | Settings tab + all sub-views: `HourlyWageDetailView`, `CurrencyLocaleView`, `ThemeSelectionView`, `WeekStartSelectionView`, `ReminderSettingsView`, `ExportDataView`, `ResetDataView`, `PrivacyTermsView`, `GenerateDataView` |
| `IntroSplashView.swift` | 196 | First-launch onboarding: feature overview + wage input |
| `Item.swift` | 19 | Unused SwiftData `Item` model (artifact from template) |

### 2.2 Key Problems in Current Architecture

1. **Massive view files** — `ContentView.swift` (565 lines) and `TrendsView.swift` (1197 lines) contain models, view models, views, helpers, extensions, and preview data all mixed together.
2. **No separation of concerns** — Business logic (earnings calculation, record grouping, date math) lives inside view structs.
3. **Duplicated code** — `formatCurrency()` is defined as a file-private function in both `ContentView.swift` and `TrendsView.swift`, and again inside `DayMetricsView`. Summary metric layouts (Hours/Tips/Earnings/Hourly Rate 2×2 grid) are copy-pasted across `HeaderSummaryView`, `ItemSummaryView`, `DayMetricsView`, `SummaryView`, and multiple sub-views.
4. **Persistence scattered across views** — `UserDefaults.standard.saveRecords(...)` is called directly from UI event handlers in `ContentView`, `CalendarView`, `SettingsView`, etc.
5. **`RecordsStore` is under-utilized** — It's a simple `ObservableObject` wrapper around `[WorkRecord]` with no save/load logic; persistence is handled ad-hoc by callers.
6. **Unused file** — `Item.swift` is a SwiftData template artifact that serves no purpose.
7. **`NavigationView` usage** — Should be migrated to `NavigationStack` (NavigationView is deprecated).
8. **`@Environment(\.presentationMode)`** — Should be migrated to `@Environment(\.dismiss)`.
9. **Static mutable state** — `TrendsView.lastCurrentIndex` is a static var used to persist chart page across tab switches, which is fragile.
10. **`AnyView` type erasure** — Used in `recordRow(for:)` in ContentView, which hurts SwiftUI performance.
11. **Currency symbol setting exists but isn't used** — `CurrencyLocaleView` stores a `currencySymbol` in AppStorage but `formatCurrency()` uses `NumberFormatter.currency` which uses the system locale.
12. **Week start day setting exists but isn't used** — `WeekStartSelectionView` stores `firstWeekday` in AppStorage but the grouping logic hardcodes `calendar.firstWeekday = 2`.
13. **Reminder settings UI exists but no notification scheduling logic** — The form saves preferences but never schedules `UNUserNotification` requests.
14. **Export to CSV button exists but has no implementation** — Contains a `// TODO` comment.

---

## 3. Data Model Specification

### 3.1 WorkRecord

The core data entity. Each record represents one work shift.

```
WorkRecord
├── id: UUID              (auto-generated, stable identity)
├── hours: Double         (hours worked, e.g. 6.5)
├── tips: Double          (tip amount in dollars, e.g. 45.00)
└── date: Date            (the date of the shift)
```

**Protocols**: `Identifiable`, `Codable`, `Hashable`, `Equatable`

**Equality**: Two records are equal if they have the same `date`, `hours`, and `tips` (ignoring `id`). This is a custom implementation — note that this means two different shifts on the same day with the same hours/tips would compare equal even with different UUIDs.

**Derived values** (given an `hourlyWage`):
- `totalEarnings = hours × hourlyWage + tips`
- `hourlyRate = totalEarnings / hours` (guarded for hours > 0)

### 3.2 GroupedMetrics

Used by TrendsView to represent aggregated data for a time period (one day, one month, etc.).

```
GroupedMetrics
├── id: UUID
├── startDate: Date       (start of the period)
├── hours: Double         (total hours in period)
├── tips: Double          (total tips in period)
├── earnings: Double      (total earnings in period)
└── hourlyRate: Double    (computed: earnings / hours)
```

### 3.3 Enums

**Grouping**: `.week`, `.month`, `.year` — Controls the time period for trends charts.

**Metric**: `.hours`, `.tips`, `.hourlyRate`, `.totalEarnings` — Controls which value is plotted on charts.

**Theme**: `.system`, `.light`, `.dark` — Controls app-wide color scheme override.

### 3.4 Persistence

**Current**: `UserDefaults` with key `"workRecords"`. Records are JSON-encoded/decoded via `Codable`.

**UserDefaults keys in use**:
| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `workRecords` | Data (JSON) | `[]` | All work records |
| `hourlyWage` | Double | 0.0 | User's hourly wage |
| `hasSeenIntro` | Bool | false | Whether onboarding has been completed |
| `appTheme` | String | "Match System" | Theme preference |
| `currencySymbol` | String | "$" | Currency symbol (NOT YET WIRED UP) |
| `firstWeekday` | Int | 2 (Monday) | Week start day (NOT YET WIRED UP) |
| `reminderTimeInterval` | Double | 8:00 PM | Reminder time (NOT YET WIRED UP) |
| `reminderDays` | String | "" | Comma-separated weekday ints (NOT YET WIRED UP) |

---

## 4. Feature Specification

### 4.1 Onboarding (IntroSplashView)

**Trigger**: Shown as a sheet on first launch (`hasSeenIntro == false`).

**Flow**:
1. Welcome screen with app name and 4 feature descriptions (Record Tracking, Trends Analysis, Calendar View, Settings)
2. "Get Started" button navigates to wage input
3. Wage input: dollar field with decimal pad, "Save & Continue" button (disabled until valid number entered)
4. On save: stores wage to `@AppStorage("hourlyWage")`, sets `hasSeenIntro = true`, dismisses sheet

**UI Details**:
- Uses `NavigationStack` with programmatic navigation via enum route
- Dynamic type capped at `.large`
- Keyboard toolbar with "Done" button

### 4.2 Home Tab (ContentView)

**Purpose**: Primary record management — view, add, edit, and delete work records.

**Empty state**: Icon (tray) + "No records yet" + instruction to tap "+"

**List structure**:
- Records grouped by week (Monday start)
- Sections sorted most-recent-first
- Section header: "Week of MMM d, yyyy" with expandable `DisclosureGroup` showing:
  - Hours, Earnings, Tips, Hourly Rate (2×2 grid)
- Each row shows a single record: date label + same 2×2 metric grid
- Tapping a row navigates to `EditRecordView`

**Add Record** (sheet):
- Fields: Hours Worked (decimal pad), Tips Earned (decimal pad), Date (DatePicker)
- Each text field has an inline clear button (×)
- Cancel / Save toolbar buttons
- Save creates a `WorkRecord`, appends to store, persists to UserDefaults

**Edit Record** (push navigation):
- Fields: Hours (pre-filled), Tips Earned (pre-filled), Date (pre-filled)
- Each text field has an inline clear button with focus management
- Save button in toolbar — updates record in-place, persists, pops back
- Delete Record button with confirmation alert ("Are you sure? This action cannot be undone.")
- Auto-focuses hours field on appear

**Dynamic type**: Capped at `.xSmall ... .large`

### 4.3 Trends Tab (TrendsView)

**Purpose**: Visualize earnings data with interactive bar charts and summary statistics.

**Empty state**: Icon (chart.bar) + "No trends yet" + instruction to add records

**Controls**:
- "Viewing [Metric] by [Grouping]" — two dropdown menus
  - Metrics: Hours, Tips, Hourly, Earnings
  - Groupings: Week, Month, Year
- Page selector dropdown showing the current period title (e.g., "Week of Apr 1, 2026")

**Chart (ChartView)**:
- Swift Charts `BarMark` visualization
- X-axis: dates (day for week/month view, month for year view)
- Y-axis: selected metric value, scaled to 1.5× the page max
- Interactive: long-press + drag shows a `RuleMark` with a callout tooltip showing date + value
- Tap anywhere dismisses the rule mark
- Swipeable pages via `TabView` with `PageTabViewStyle`

**Summary section below chart**:
- Located at bottom of chart page
- "Summary" header with dropdown for summary type
- Available summary types depend on grouping:
  - Week: Overall Totals, Daily Average
  - Month: Overall Totals, Daily Average, Weekly Average
  - Year: Overall Totals, Daily Average, Weekly Average, Monthly Average
- Each summary shows the same 2×2 grid: Hours, Earnings, Tips, Hourly Rate
- Weekly/monthly averages exclude the current (incomplete) week/month

**Above the chart**:
- Label showing "TOTAL [METRIC]" or "AVERAGE HOURLY" with the aggregated value for the current page

**TrendsViewModel**:
- Computes paginated data for all three groupings on a background thread
- Weekly: each page = 7 days (Mon–Sun), daily granularity
- Monthly: each page = days in that month, daily granularity
- Yearly: each page = 12 months, monthly granularity
- Removes trailing empty pages
- Re-computes when records or hourlyWage change

### 4.4 Calendar Tab (CalendarView)

**Purpose**: Visual date-based browsing of records.

**Calendar**:
- Uses `UICalendarView` via `UIViewRepresentable` (`CalendarUIKitView`)
- Single-date selection behavior
- Days with records show a small blue dot decoration
- Calendar updates when records change (uses `.id(recordsStore.records)`)

**Day detail panel** (below calendar):
- When a date with records is selected: shows `DayMetricsView`
  - Formatted full date header with "Edit" button
  - 2×2 metric grid: Total Hours, Total Earnings, Total Tips, Hourly Rate
  - Max height 160pt, scrollable
- When a date without records is selected: "No records for [date]"
- Edit button opens `EditRecordView` in a sheet (with Cancel toolbar button)

**Dynamic type**: Capped at `.xSmall ... .large`

### 4.5 Settings Tab (SettingsView)

**Structure**: List with 4 sections:

#### General
1. **Hourly Wage** → `HourlyWageDetailView`
   - Full-screen-style form: icon, title, explanation, dollar input field, Save button
   - Pre-fills current wage, keyboard toolbar with Done
   - Saves to `@AppStorage("hourlyWage")`

2. **Currency Symbol** → `CurrencyLocaleView`
   - Inline picker with options: $, €, £
   - Saves to `@AppStorage("currencySymbol")`
   - **NOTE: Not wired to formatCurrency() — needs implementation**

3. **Theme** → `ThemeSelectionView`
   - Inline picker: Match System, Light, Dark
   - Saves to `@AppStorage("appTheme")`
   - Applied at app root via `.preferredColorScheme()`

#### Records
4. **Week Start Day** → `WeekStartSelectionView`
   - Menu picker for all 7 weekdays
   - Saves to `@AppStorage("firstWeekday")`
   - **NOTE: Not wired to grouping logic — needs implementation**

#### Notifications
5. **Reminders** → `ReminderSettingsView`
   - Time picker for reminder time
   - Toggle for each day of the week
   - Saves to `@AppStorage("reminderTimeInterval")` and `@AppStorage("reminderDays")`
   - **NOTE: No notification scheduling logic — needs implementation**

#### Data & Privacy
6. **Export/Backup Data** → `ExportDataView`
   - Description + "Export to CSV" button
   - **NOTE: Not implemented — contains `// TODO`**

7. **Manage Data** → `GenerateDataView`
   - Developer/testing tool to generate random records
   - Parameters: date range, probability per day, hours range, tip rate range
   - Only works when record store is empty
   - Generates on background thread with progress overlay

8. **Reset Data** → `ResetDataView`
   - Warning UI + "Delete Everything" button
   - Confirmation alert → clears all records, persists, navigates back

9. **Privacy & Terms** → `PrivacyTermsView`
   - Static text explaining local-only data storage and liability disclaimer

---

## 5. Proposed Refactored Architecture (MVVM)

### 5.1 Directory Structure

```
Tip Tracker/
├── App/
│   └── Tip_TrackerApp.swift          — @main entry point, theme application
│
├── Models/
│   ├── WorkRecord.swift              — WorkRecord struct
│   ├── GroupedMetrics.swift           — GroupedMetrics struct
│   └── Enums.swift                   — Grouping, Metric, Theme enums
│
├── Services/
│   ├── RecordStore.swift             — Observable record store with persistence
│   ├── PersistenceService.swift      — UserDefaults or SwiftData persistence layer
│   ├── NotificationService.swift     — UNUserNotification scheduling
│   └── ExportService.swift           — CSV export logic
│
├── ViewModels/
│   ├── HomeViewModel.swift           — Record grouping, CRUD operations
│   ├── TrendsViewModel.swift         — Chart data computation, pagination
│   ├── CalendarViewModel.swift       — Date selection, record filtering
│   └── SettingsViewModel.swift       — Settings management, data generation
│
├── Views/
│   ├── MainTabView.swift             — TabView container
│   │
│   ├── Onboarding/
│   │   ├── IntroSplashView.swift     — Welcome + feature list
│   │   └── WageInputView.swift       — Initial wage entry
│   │
│   ├── Home/
│   │   ├── HomeView.swift            — Record list with week sections
│   │   ├── AddRecordView.swift       — Sheet for new records
│   │   └── EditRecordView.swift      — Push view for editing/deleting
│   │
│   ├── Trends/
│   │   ├── TrendsView.swift          — Controls + chart + summary layout
│   │   ├── ChartView.swift           — Swift Charts bar chart with interaction
│   │   └── SummaryView.swift         — Aggregated metrics display
│   │
│   ├── Calendar/
│   │   ├── CalendarTabView.swift     — Calendar + day detail layout
│   │   ├── CalendarUIKitView.swift   — UIViewRepresentable wrapper
│   │   └── DayMetricsView.swift      — Single-day metrics card
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift        — Settings list
│   │   ├── HourlyWageView.swift      — Wage input detail
│   │   ├── CurrencyLocaleView.swift  — Currency picker
│   │   ├── ThemeSelectionView.swift   — Theme picker
│   │   ├── WeekStartView.swift       — Week start picker
│   │   ├── ReminderSettingsView.swift — Notification preferences
│   │   ├── ExportDataView.swift      — CSV export
│   │   ├── GenerateDataView.swift    — Test data generation
│   │   ├── ResetDataView.swift       — Data deletion
│   │   └── PrivacyTermsView.swift    — Legal text
│   │
│   └── Components/
│       ├── MetricsGridView.swift     — Reusable 2×2 Hours/Earnings/Tips/Rate grid
│       ├── ClearableTextField.swift  — TextField with inline clear button
│       └── EmptyStateView.swift      — Reusable icon + title + subtitle placeholder
│
├── Utilities/
│   ├── Formatters.swift              — formatCurrency(), date formatters
│   ├── DateHelpers.swift             — allDates(), week interval helpers
│   └── PreviewData.swift             — WorkRecord.dummyData for previews
│
└── Tests/
    ├── WorkRecordTests.swift
    ├── HomeViewModelTests.swift
    ├── TrendsViewModelTests.swift
    └── RecordStoreTests.swift
```

### 5.2 Key Refactoring Moves

#### A. Extract `RecordStore` as the Single Source of Truth

```swift
// Services/RecordStore.swift
@Observable
final class RecordStore {
    private(set) var records: [WorkRecord] = []
    private let persistence: PersistenceService

    init(persistence: PersistenceService = .userDefaults) {
        self.persistence = persistence
        self.records = persistence.loadRecords()
    }

    func add(_ record: WorkRecord) { ... }
    func update(_ record: WorkRecord) { ... }
    func delete(_ record: WorkRecord) { ... }
    func deleteAll() { ... }
    func replaceAll(with records: [WorkRecord]) { ... }
    // All mutations auto-persist
}
```

This eliminates the scattered `UserDefaults.standard.saveRecords(...)` calls throughout the views. Every mutation goes through the store.

#### B. Extract Reusable `MetricsGridView`

The 2×2 grid showing Hours / Earnings / Tips / Hourly Rate is duplicated in 5+ places. Extract once:

```swift
// Views/Components/MetricsGridView.swift
struct MetricsGridView: View {
    let hours: Double
    let tips: Double
    let earnings: Double
    let hourlyRate: Double
    var labelStyle: Font = .subheadline
    var valueStyle: Font = .title3
    // Renders the standard 2×2 layout
}
```

#### C. Centralize Formatters

```swift
// Utilities/Formatters.swift
enum Formatters {
    static func currency(_ amount: Double) -> String { ... }
    static func hours(_ hours: Double) -> String { ... }
    static let weekHeader: DateFormatter = { ... }()
    static let recordDate: DateFormatter = { ... }()
    static let fullDate: DateFormatter = { ... }()
}
```

#### D. Use `@Observable` (Observation framework) instead of `ObservableObject`

Migrate from `@ObservedObject` / `@Published` to the modern `@Observable` macro for better performance and simpler code.

#### E. Migrate `NavigationView` → `NavigationStack`

All four tabs currently use the deprecated `NavigationView`. Replace with `NavigationStack` for better navigation control and value-based navigation.

#### F. Wire Up Unfinished Settings

- **Currency symbol**: Use `@AppStorage("currencySymbol")` in `Formatters.currency()` to respect the user's choice.
- **Week start day**: Read `@AppStorage("firstWeekday")` in `HomeViewModel` and `TrendsViewModel` instead of hardcoding 2.
- **Reminders**: Implement `NotificationService` that schedules/cancels `UNUserNotificationRequest` based on saved preferences.
- **CSV Export**: Implement `ExportService` that generates a CSV string and presents a `ShareLink` or `UIActivityViewController`.

### 5.3 ViewModel Responsibilities

#### HomeViewModel
- Groups records by week (respecting `firstWeekday` setting)
- Provides sorted week sections
- Handles add/edit/delete by delegating to `RecordStore`
- Computes per-week and per-record summary values

#### TrendsViewModel (already partially exists)
- Computes paginated `GroupedMetrics` for week/month/year on background thread
- Provides chart data, page titles, y-axis scaling
- Computes page totals and averages
- Should accept `RecordStore` directly rather than raw arrays

#### CalendarViewModel
- Tracks selected date
- Filters records for the selected day
- Provides the set of dates that have records (for decorations)

#### SettingsViewModel
- Manages data generation parameters and execution
- Handles reset confirmation flow
- Coordinates with `NotificationService` for reminder scheduling
- Coordinates with `ExportService` for CSV generation

---

## 6. Calculation Reference

These are the exact formulas used throughout the app. Any reimplementation must match these.

### Per-Record
```
totalEarnings = hours × hourlyWage + tips
hourlyRate    = totalEarnings / hours    (0 if hours == 0)
```

### Per-Period (week/month/year/day)
```
totalHours    = sum of all record.hours in period
totalTips     = sum of all record.tips in period
totalEarnings = (totalHours × hourlyWage) + totalTips
hourlyRate    = totalEarnings / totalHours    (0 if totalHours == 0)
```

### Daily Average
```
uniqueDays         = count of distinct calendar days with records
dailyAvgHours      = totalHours / uniqueDays
dailyAvgTips       = totalTips / uniqueDays
dailyAvgEarnings   = totalEarnings / uniqueDays
dailyAvgHourly     = dailyAvgEarnings / dailyAvgHours    (0 if avgHours == 0)
```

### Weekly Average (excludes current incomplete week)
```
completedRecords   = records where weekStart < currentWeekStart
uniqueWeeks        = count of distinct week starts
weeklyAvg*         = corresponding total / uniqueWeeks
```

### Monthly Average (excludes current incomplete month)
```
completedRecords   = records where monthStart < currentMonthStart
uniqueMonths       = count of distinct month starts
monthlyAvg*        = corresponding total / uniqueMonths
```

---

## 7. UI Patterns & Constants

### Dynamic Type
All views cap dynamic type at `.large` (using `.dynamicTypeSize(.xSmall ... .large)` or `.dynamicTypeSize(...DynamicTypeSize.large)`).

### Navigation
- Home: `NavigationView` → List → NavigationLink push to EditRecordView
- Trends: `NavigationView` → VStack (no push navigation)
- Calendar: `NavigationView` → VStack; edit via sheet
- Settings: `NavigationView` → List → NavigationLink push to detail views
- Onboarding: `NavigationStack` with value-based navigation

### Sheets
- Add Record: presented from Home tab "+" button
- Edit Record (Calendar): presented from day detail "Edit" button
- Intro Splash: presented from MainAppView on first launch

### Color Scheme
- App root applies `.preferredColorScheme()` based on `appTheme` AppStorage
- Uses system colors: `.secondary`, `.accentColor`, `Color(.systemGray4)`, `Color(.systemGray5)`, `Color(.systemGray6)`

### Tab Bar
- Home: `house.fill`
- Trends: `chart.bar.xaxis`
- Calendar: `calendar`
- Settings: `gearshape`

---

## 8. Known Issues & Technical Debt

1. **`Item.swift` is unused** — Delete it.
2. **`AnyView` in `recordRow(for:)`** — Replace with `@ViewBuilder` or optional binding restructure.
3. **`formatCurrency` duplicated 3 times** — Consolidate into one shared utility.
4. **`NavigationView` deprecated** — Migrate to `NavigationStack`.
5. **`presentationMode` deprecated** — Migrate to `@Environment(\.dismiss)`.
6. **Static `TrendsView.lastCurrentIndex`** — Replace with proper state management.
7. **UserDefaults for complex data** — Consider migrating to SwiftData for better performance, querying, and scalability.
8. **No input validation** — AddRecordView silently does nothing if fields aren't valid numbers. Should show error feedback.
9. **No data backup/restore** — Export is unimplemented.
10. **Calendar decoration doesn't update on month change** — May need explicit reload via `reloadDecorations(forDateComponents:animated:)`.
11. **`WorkRecord.Equatable` ignores `id`** — Could cause subtle bugs with list diffing.
12. **DateFormatter created on every render** — Should be cached as static properties.

---

## 9. Testing Strategy for Reimplementation

### Unit Tests (Testing framework)
- `WorkRecord`: encoding/decoding, equality
- `RecordStore`: add, update, delete, persistence round-trip
- `HomeViewModel`: week grouping, sorting, calculations
- `TrendsViewModel`: weekly/monthly/yearly page computation, metric values, edge cases (empty records, single record, records spanning year boundaries)
- `Formatters`: currency formatting, date formatting
- Calculation accuracy: verify all formulas from Section 6

### UI Tests (XCUIAutomation)
- Onboarding flow: launch → intro → enter wage → dismiss → verify main UI
- Add record: tap +, fill fields, save, verify in list
- Edit record: tap row, change values, save, verify updated
- Delete record: tap row, delete with confirmation, verify removed
- Calendar: tap date with record, verify metrics shown
- Trends: switch metrics, switch groupings, verify chart updates
- Settings: change wage, verify recalculation in Home/Trends
- Reset: delete all data, verify empty states

---

## 10. Migration Priorities

**Phase 1 — Extract & Organize (no behavior changes)**
1. Create directory structure
2. Move `WorkRecord` to `Models/WorkRecord.swift`
3. Move `GroupedMetrics`, `Grouping`, `Metric` to `Models/`
4. Extract `formatCurrency` and date formatters to `Utilities/Formatters.swift`
5. Extract `MetricsGridView`, `ClearableTextField`, `EmptyStateView` to `Components/`
6. Delete `Item.swift`

**Phase 2 — RecordStore Centralization**
1. Build `RecordStore` with encapsulated persistence
2. Update all views to use `RecordStore` methods instead of direct UserDefaults calls
3. Remove `UserDefaults` extension from `ContentView.swift`

**Phase 3 — ViewModels**
1. Extract `HomeViewModel` from `ContentView`
2. Clean up existing `TrendsViewModel`
3. Create `CalendarViewModel`
4. Create `SettingsViewModel`

**Phase 4 — Modernization**
1. Migrate `ObservableObject` → `@Observable`
2. Migrate `NavigationView` → `NavigationStack`
3. Migrate `presentationMode` → `dismiss`
4. Remove `AnyView` usage

**Phase 5 — Complete Unfinished Features**
1. Wire currency symbol setting to formatter
2. Wire week start day setting to grouping logic
3. Implement notification scheduling
4. Implement CSV export

**Phase 6 — Testing**
1. Add unit tests for models and view models
2. Add UI tests for critical flows
