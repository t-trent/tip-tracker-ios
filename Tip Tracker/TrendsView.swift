import SwiftUI
import Charts

// MARK: - GroupedMetrics Model

struct GroupedMetrics: Identifiable {
    let id = UUID()
    let startDate: Date
    let hours: Double
    let tips: Double
    let earnings: Double

    var hourlyRate: Double { hours > 0 ? earnings / hours : 0 }

    func valueFor(metric: Metric) -> Double {
        switch metric {
        case .hours:         return hours
        case .tips:          return tips
        case .totalEarnings: return earnings
        case .hourlyRate:    return hourlyRate
        }
    }
}

// MARK: - Enums

enum Grouping: String, CaseIterable {
    case week, month, year

    var displayName: String {
        switch self {
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }
}

enum Metric: String, CaseIterable {
    case hours, tips, hourlyRate, totalEarnings

    var displayName: String {
        switch self {
        case .hours:         return "Hours"
        case .tips:          return "Tips"
        case .hourlyRate:    return "Hourly"
        case .totalEarnings: return "Earnings"
        }
    }
}

protocol TrendsMenuOption {
    var displayName: String { get }
}

extension Grouping: TrendsMenuOption {}
extension Metric: TrendsMenuOption {}

// MARK: - TrendsViewModel

final class TrendsViewModel: ObservableObject {
    @Published var paginatedGroupedData: [Grouping: [[GroupedMetrics]]] = [:]

    private var records: [WorkRecord]
    private var hourlyWage: Double
    private var firstWeekday: Int

    init(records: [WorkRecord], hourlyWage: Double, firstWeekday: Int = 2) {
        self.records = records
        self.hourlyWage = hourlyWage
        self.firstWeekday = firstWeekday
        computeAllGroupings()
    }

    func update(records: [WorkRecord], hourlyWage: Double, firstWeekday: Int) {
        self.records = records
        self.hourlyWage = hourlyWage
        self.firstWeekday = firstWeekday
        computeAllGroupings()
    }

    private func computeAllGroupings() {
        // Capture values before the background hop to avoid races
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        let records = self.records
        let wage = self.hourlyWage

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let weekly  = Self.computeWeeklyData(records: records, hourlyWage: wage, calendar: cal)
            let monthly = Self.computeMonthlyData(records: records, hourlyWage: wage, calendar: cal)
            let yearly  = Self.computeYearlyData(records: records, hourlyWage: wage, calendar: cal)
            DispatchQueue.main.async {
                self.paginatedGroupedData[.week]  = weekly
                self.paginatedGroupedData[.month] = monthly
                self.paginatedGroupedData[.year]  = yearly
            }
        }
    }

    // MARK: Weekly (Mon–Sun pages)

    private static func computeWeeklyData(records: [WorkRecord], hourlyWage: Double, calendar: Calendar) -> [[GroupedMetrics]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date, let latest = sorted.last?.date else { return [] }

        let upper = max(latest, Date())
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: earliest),
              let lastWeek  = calendar.dateInterval(of: .weekOfYear, for: upper) else { return [] }

        var weekStart = firstWeek.start
        var pages: [[GroupedMetrics]] = []

        while weekStart <= lastWeek.start {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            let days = allDates(from: weekStart, to: weekEnd, calendar: calendar)
            let page = days.map { day -> GroupedMetrics in
                let daily = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
                return GroupedMetrics(
                    startDate: day,
                    hours: daily.totalHours,
                    tips: daily.totalTips,
                    earnings: daily.totalEarnings(wage: hourlyWage)
                )
            }
            pages.append(page)
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }

        if let last = pages.last, last.allSatisfy({ $0.earnings == 0 && $0.hours == 0 }) {
            pages.removeLast()
        }
        return pages
    }

    // MARK: Monthly (day-per-bar pages)

    private static func computeMonthlyData(records: [WorkRecord], hourlyWage: Double, calendar: Calendar) -> [[GroupedMetrics]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date, let latest = sorted.last?.date else { return [] }

        let upper = max(latest, Date())
        guard let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest)),
              let lastMonth  = calendar.date(from: calendar.dateComponents([.year, .month], from: upper))
        else { return [] }

        var current = firstMonth
        var pages: [[GroupedMetrics]] = []

        while current <= lastMonth {
            let range = calendar.range(of: .day, in: .month, for: current) ?? 1..<1
            let page: [GroupedMetrics] = range.compactMap { dayNum in
                var comps = calendar.dateComponents([.year, .month], from: current)
                comps.day = dayNum
                guard let dayDate = calendar.date(from: comps) else { return nil }
                let daily = records.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
                return GroupedMetrics(
                    startDate: dayDate,
                    hours: daily.totalHours,
                    tips: daily.totalTips,
                    earnings: daily.totalEarnings(wage: hourlyWage)
                )
            }
            pages.append(page)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        if let last = pages.last, last.allSatisfy({ $0.earnings == 0 && $0.hours == 0 }) {
            pages.removeLast()
        }
        return pages
    }

    // MARK: Yearly (month-per-bar pages)

    private static func computeYearlyData(records: [WorkRecord], hourlyWage: Double, calendar: Calendar) -> [[GroupedMetrics]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date, let latest = sorted.last?.date else { return [] }

        let upper = max(latest, Date())
        let firstYear = calendar.component(.year, from: earliest)
        let lastYear  = calendar.component(.year, from: upper)
        var pages: [[GroupedMetrics]] = []

        for year in firstYear...lastYear {
            let page: [GroupedMetrics] = (1...12).compactMap { month in
                var comps = DateComponents()
                comps.year = year; comps.month = month; comps.day = 1
                guard let monthDate = calendar.date(from: comps) else { return nil }
                let monthly = records.filter {
                    calendar.component(.year, from: $0.date)  == year &&
                    calendar.component(.month, from: $0.date) == month
                }
                return GroupedMetrics(
                    startDate: monthDate,
                    hours: monthly.totalHours,
                    tips: monthly.totalTips,
                    earnings: monthly.totalEarnings(wage: hourlyWage)
                )
            }
            pages.append(page)
        }

        if let last = pages.last, last.allSatisfy({ $0.earnings == 0 && $0.hours == 0 }) {
            pages.removeLast()
        }
        return pages
    }

    // MARK: Date helper

    private static func allDates(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var current = calendar.startOfDay(for: start)
        while current <= end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}

// MARK: - TrendsView

struct TrendsView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double
    @AppStorage("firstWeekday") private var firstWeekday: Int = 2
    @AppStorage("trendsSelectedGrouping") private var selectedGroupingRawValue: String = Grouping.week.rawValue
    @AppStorage("trendsSelectedMetric") private var selectedMetricRawValue: String = Metric.tips.rawValue
    @State private var currentIndex: Int = 0

    @StateObject private var viewModel: TrendsViewModel

    init(recordsStore: RecordsStore, hourlyWage: Binding<Double>) {
        self.recordsStore = recordsStore
        self._hourlyWage = hourlyWage
        let weekday = UserDefaults.standard.integer(forKey: "firstWeekday")
        _viewModel = StateObject(wrappedValue: TrendsViewModel(
            records: recordsStore.records,
            hourlyWage: hourlyWage.wrappedValue,
            firstWeekday: weekday == 0 ? 2 : weekday
        ))
    }

    private var selectedGrouping: Grouping {
        get { Grouping(rawValue: selectedGroupingRawValue) ?? .week }
        nonmutating set { selectedGroupingRawValue = newValue.rawValue }
    }

    private var selectedMetric: Metric {
        get { Metric(rawValue: selectedMetricRawValue) ?? .tips }
        nonmutating set { selectedMetricRawValue = newValue.rawValue }
    }

    private var pages: [[GroupedMetrics]] {
        viewModel.paginatedGroupedData[selectedGrouping] ?? []
    }

    private var currentPageData: [GroupedMetrics] {
        pages.indices.contains(currentIndex) ? pages[currentIndex] : []
    }

    private var currentPageTotal: Double {
        currentPageData.map { $0.valueFor(metric: selectedMetric) }.reduce(0, +)
    }

    private var currentPageAverageHourly: Double {
        let totalHours    = currentPageData.map(\.hours).reduce(0, +)
        let totalEarnings = currentPageData.map(\.earnings).reduce(0, +)
        return totalHours > 0 ? totalEarnings / totalHours : 0
    }

    private var yScaleMaxes: [Double] {
        pages.map { page in
            let rawMax = page.map { $0.valueFor(metric: selectedMetric) }.max() ?? 0
            return rawMax * 1.5
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if recordsStore.records.isEmpty {
                    emptyState
                } else {
                    trendsContent
                }
            }
            .navigationTitle("Trends")
            .onChange(of: recordsStore.records) {
                viewModel.update(records: recordsStore.records, hourlyWage: hourlyWage, firstWeekday: firstWeekday)
            }
            .onChange(of: hourlyWage) {
                viewModel.update(records: recordsStore.records, hourlyWage: hourlyWage, firstWeekday: firstWeekday)
            }
            .onChange(of: firstWeekday) {
                viewModel.update(records: recordsStore.records, hourlyWage: hourlyWage, firstWeekday: firstWeekday)
            }
            .dynamicTypeSize(.xSmall ... .large)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No trends yet")
                .font(.title2).bold()
            Text("Head over to the Home tab and tap \"+\" to add your first record, then come back here to see your charts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content

    private var trendsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            metricGroupingPicker
            if !pages.isEmpty {
                pagePicker
                pageTotal
                chartTabView
                if let interval = currentPageInterval {
                    let filtered = recordsStore.records.filter { interval.contains($0.date) }
                    SummaryView(records: filtered, hourlyWage: hourlyWage, grouping: selectedGrouping)
                        .padding(.horizontal)
                }
            } else {
                ProgressView("Loading data…")
                    .frame(maxWidth: .infinity, maxHeight: 500)
            }
            Spacer()
        }
    }

    // MARK: Metric + Grouping Picker

    private var metricGroupingPicker: some View {
        HStack(spacing: 4) {
            Text("Viewing").font(.title3).bold()
            dropdownMenu(title: selectedMetric.displayName, items: Metric.self) {
                selectedMetric = $0
            }
            Text("by").font(.title3).bold()
            dropdownMenu(title: selectedGrouping.displayName, items: Grouping.self) {
                selectedGrouping = $0
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func dropdownMenu<T: CaseIterable & Hashable & TrendsMenuOption>(
        title: String,
        items: T.Type,
        onSelect: @escaping (T) -> Void
    ) -> some View where T.AllCases: RandomAccessCollection {
        Menu {
            ForEach(Array(T.allCases), id: \.self) { item in
                Button(item.displayName) { onSelect(item) }
            }
        } label: {
            HStack(spacing: 2) {
                Text(title).font(.title3).bold()
                Image(systemName: "chevron.down")
            }
            .padding(4)
            .background(Color(.systemGray5))
            .cornerRadius(4)
        }
        .fixedSize()
    }

    // MARK: Page Picker

    private var pageTitles: [String] {
        pages.map { page in
            guard let first = page.first?.startDate else { return "" }
            switch selectedGrouping {
            case .week:  return "Week of \(Formatters.shortDate.string(from: first))"
            case .month: return Formatters.monthYear.string(from: first)
            case .year:  return Formatters.yearOnly.string(from: first)
            }
        }
    }

    private var pagePicker: some View {
        let safeIndex = pages.indices.contains(currentIndex) ? currentIndex : pages.count - 1
        let titles = pageTitles
        return Menu {
            ForEach(Array(pages.indices.reversed()), id: \.self) { i in
                Button(titles[i]) { currentIndex = i }
            }
        } label: {
            HStack(spacing: 2) {
                Text(titles[safeIndex]).font(.headline)
                Image(systemName: "chevron.down")
            }
            .padding(4)
            .background(Color(.systemGray5))
            .cornerRadius(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: Page Total

    private var pageTotal: some View {
        VStack(alignment: .leading, spacing: 4) {
            if selectedMetric == .hourlyRate {
                Text("AVERAGE HOURLY")
                    .font(.caption).foregroundStyle(.secondary)
                Text(formatCurrency(currentPageAverageHourly))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("TOTAL \(selectedMetric.displayName.uppercased())")
                    .font(.caption).foregroundStyle(.secondary)
                Group {
                    if selectedMetric == .tips || selectedMetric == .totalEarnings {
                        Text(formatCurrency(currentPageTotal))
                    } else {
                        Text(String(format: "%.2f", currentPageTotal))
                    }
                }
                .font(.title3).bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    // MARK: Chart TabView

    private var chartTabView: some View {
        TabView(selection: $currentIndex) {
            ForEach(pages.indices, id: \.self) { index in
                ChartView(
                    data: pages[index],
                    metric: selectedMetric,
                    grouping: selectedGrouping,
                    hourlyWage: hourlyWage,
                    yAxisMax: yScaleMaxes[index]
                )
                .frame(maxWidth: .infinity, maxHeight: 500)
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .id(selectedGrouping)
        .padding(.horizontal)
        .onAppear { currentIndex = pages.count - 1 }
        .onChange(of: selectedGrouping) { currentIndex = pages.count - 1 }
    }

    // MARK: Current Page Date Interval

    private var currentPageInterval: DateInterval? {
        guard pages.indices.contains(currentIndex),
              let firstDate = pages[currentIndex].first?.startDate else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        switch selectedGrouping {
        case .week:  return cal.dateInterval(of: .weekOfYear, for: firstDate)
        case .month: return cal.dateInterval(of: .month, for: firstDate)
        case .year:  return cal.dateInterval(of: .year, for: firstDate)
        }
    }
}

// MARK: - ChartView

struct ChartView: View {
    let data: [GroupedMetrics]
    let metric: Metric
    let grouping: Grouping
    let hourlyWage: Double
    let yAxisMax: Double

    @State private var selectedData: GroupedMetrics? = nil
    @State private var longPressActive = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Date", item.startDate, unit: xAxisUnit),
                            y: .value(metric.displayName, item.valueFor(metric: metric))
                        )
                        .foregroundStyle(.blue)
                    }
                    if let selected = selectedData {
                        RuleMark(x: .value("Selected", selected.startDate, unit: xAxisUnit))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .chartYScale(domain: 0...yAxisMax)
                .chartXAxis { xAxisContent }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        if let v = value.as(Double.self) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel { yLabel(for: v) }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { innerGeo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { if selectedData != nil { dismissCallout() } }
                            .gesture(longPressThenDrag(proxy: proxy, geo: innerGeo))

                        if let selected = selectedData {
                            calloutView(for: selected, proxy: proxy, geo: innerGeo)
                        }
                    }
                }
                .onChange(of: metric)   { _, _ in dismissCallout() }
                .onChange(of: grouping) { _, _ in dismissCallout() }
            }
        }
        .padding(.top, 30)
    }

    // MARK: Axis

    private var xAxisUnit: Calendar.Component {
        switch grouping {
        case .week, .month: return .day
        case .year:         return .month
        }
    }

    @AxisContentBuilder
    private var xAxisContent: some AxisContent {
        if grouping == .month {
            AxisMarks(
                values: data.map(\.startDate).filter { date in
                    (Calendar.current.component(.day, from: date) - 1) % 7 == 0
                }
            ) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text("\(Calendar.current.component(.day, from: d))")
                    }
                }
            }
        } else {
            AxisMarks(values: data.map(\.startDate)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(xLabel(for: d))
                    }
                }
            }
        }
    }

    private func xLabel(for date: Date) -> String {
        switch grouping {
        case .week:  return Formatters.weekdayDay.string(from: date)
        case .month: return Formatters.monthAbbrev.string(from: date)
        case .year:  return Formatters.monthAbbrev.string(from: date)
        }
    }

    private func yLabel(for value: Double) -> Text {
        switch metric {
        case .tips, .hourlyRate, .totalEarnings: return Text("$\(value, specifier: "%.0f")")
        case .hours:                             return Text("\(value, specifier: "%.0f")h")
        }
    }

    // MARK: Callout

    private func calloutView(for selected: GroupedMetrics, proxy: ChartProxy, geo: GeometryProxy) -> some View {
        let plotFrame = geo[proxy.plotFrame!]
        let lineX = proxy.position(forX: selected.startDate) ?? 0
        let rawX = plotFrame.origin.x + lineX
        let calloutWidth: CGFloat = 100
        let clampedX = min(max(rawX, plotFrame.minX + calloutWidth / 2), plotFrame.maxX - calloutWidth / 2)

        let dateStr = calloutDateString(for: selected.startDate)
        let valueStr = calloutValueString(for: metric, value: selected.valueFor(metric: metric))

        return Text("\(dateStr)\n\(valueStr)")
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 2)
            )
            .position(x: clampedX, y: plotFrame.origin.y)
    }

    private func calloutDateString(for date: Date) -> String {
        switch grouping {
        case .week, .month: return Formatters.calloutDate.string(from: date)
        case .year:         return Formatters.calloutMonthYear.string(from: date)
        }
    }

    private func calloutValueString(for metric: Metric, value: Double) -> String {
        switch metric {
        case .hours:                             return String(format: "%.2f hours", value)
        case .tips, .totalEarnings:              return formatCurrency(value)
        case .hourlyRate:                        return formatCurrency(value) + "/hr"
        }
    }

    // MARK: Gesture

    private func longPressThenDrag(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        let longPress = LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in longPressActive = true }
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard longPressActive else { return }
                let plotFrame = geo[proxy.plotFrame!]
                let locationX = value.location.x - plotFrame.origin.x
                if let draggedDate: Date = proxy.value(atX: locationX) {
                    selectedData = data.min {
                        abs($0.startDate.timeIntervalSinceReferenceDate - draggedDate.timeIntervalSinceReferenceDate)
                        < abs($1.startDate.timeIntervalSinceReferenceDate - draggedDate.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .onEnded { _ in longPressActive = false }
        return longPress.sequenced(before: drag)
    }

    private func dismissCallout() {
        selectedData = nil
        longPressActive = false
    }
}

// MARK: - SummaryView

struct SummaryView: View {
    let records: [WorkRecord]
    let hourlyWage: Double
    let grouping: Grouping

    enum SummaryType: String, Identifiable, CaseIterable {
        case overall = "Overall Totals"
        case daily   = "Daily Average"
        case weekly  = "Weekly Average"
        case monthly = "Monthly Average"
        var id: String { rawValue }
    }

    private var availableSummaryTypes: [SummaryType] {
        switch grouping {
        case .week:  return [.overall, .daily]
        case .month: return [.overall, .daily, .weekly]
        case .year:  return [.overall, .daily, .weekly, .monthly]
        }
    }

    @State private var selectedSummary: SummaryType = .overall

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Summary").font(.headline)
                Spacer()
                Menu {
                    ForEach(availableSummaryTypes) { type in
                        Button(type.rawValue) { selectedSummary = type }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(selectedSummary.rawValue).font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .padding(4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)
            .onChange(of: grouping) {
                if grouping == .week  && selectedSummary == .weekly  { selectedSummary = .overall }
                if grouping != .year  && selectedSummary == .monthly { selectedSummary = .overall }
            }

            switch selectedSummary {
            case .overall: overallPanel
            case .daily:   dailyPanel
            case .weekly:  weeklyPanel
            case .monthly: monthlyPanel
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Summary Panels

    private var overallPanel: some View {
        MetricGrid(
            topLeading:    ("Total Hours",    String(format: "%.2f", records.totalHours)),
            topTrailing:   ("Total Earnings", formatCurrency(records.totalEarnings(wage: hourlyWage))),
            bottomLeading: ("Total Tips",     formatCurrency(records.totalTips)),
            bottomTrailing:("Hourly Rate",    formatCurrency(records.hourlyRate(wage: hourlyWage)) + "/hr"),
            valueFont: .title3
        )
    }

    private var dailyPanel: some View {
        let days       = Double(max(1, records.uniqueDayCount))
        let avgHours   = records.totalHours / days
        let avgEarnings = records.totalEarnings(wage: hourlyWage) / days
        let avgTips    = records.totalTips / days
        let avgHourly  = avgHours > 0 ? avgEarnings / avgHours : 0
        return MetricGrid(
            topLeading:    ("Average Hours",    String(format: "%.2f", avgHours)),
            topTrailing:   ("Average Earnings", formatCurrency(avgEarnings)),
            bottomLeading: ("Average Tips",     formatCurrency(avgTips)),
            bottomTrailing:("Average Hourly",   formatCurrency(avgHourly) + "/hr"),
            valueFont: .title3
        )
    }

    private var weeklyPanel: some View {
        let recs  = completedWeekRecords
        let weeks = Double(max(1, uniqueCompletedWeeks))
        let avgHours    = recs.totalHours / weeks
        let avgEarnings = recs.totalEarnings(wage: hourlyWage) / weeks
        let avgTips     = recs.totalTips / weeks
        let avgHourly   = avgHours > 0 ? avgEarnings / avgHours : 0
        return MetricGrid(
            topLeading:    ("Average Hours",    String(format: "%.2f", avgHours)),
            topTrailing:   ("Average Earnings", formatCurrency(avgEarnings)),
            bottomLeading: ("Average Tips",     formatCurrency(avgTips)),
            bottomTrailing:("Average Hourly",   formatCurrency(avgHourly) + "/hr"),
            valueFont: .title3
        )
    }

    private var monthlyPanel: some View {
        let recs   = completedMonthRecords
        let months = Double(max(1, uniqueCompletedMonths))
        let avgHours    = recs.totalHours / months
        let avgEarnings = recs.totalEarnings(wage: hourlyWage) / months
        let avgTips     = recs.totalTips / months
        let avgHourly   = avgHours > 0 ? avgEarnings / avgHours : 0
        return MetricGrid(
            topLeading:    ("Average Hours",    String(format: "%.2f", avgHours)),
            topTrailing:   ("Average Earnings", formatCurrency(avgEarnings)),
            bottomLeading: ("Average Tips",     formatCurrency(avgTips)),
            bottomTrailing:("Average Hourly",   formatCurrency(avgHourly) + "/hr"),
            valueFont: .title3
        )
    }

    // MARK: - Filtered Record Sets

    private var completedWeekRecords: [WorkRecord] {
        let cal = Calendar.current
        guard let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return records
        }
        return records.filter {
            (cal.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? .distantFuture) < currentWeekStart
        }
    }

    private var uniqueCompletedWeeks: Int {
        let cal = Calendar.current
        return Set(completedWeekRecords.compactMap {
            cal.dateInterval(of: .weekOfYear, for: $0.date)?.start
        }).count
    }

    private var completedMonthRecords: [WorkRecord] {
        let cal = Calendar.current
        guard let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else {
            return records
        }
        return records.filter {
            let comps = cal.dateComponents([.year, .month], from: $0.date)
            return (cal.date(from: comps) ?? .distantFuture) < currentMonthStart
        }
    }

    private var uniqueCompletedMonths: Int {
        let cal = Calendar.current
        return Set(completedMonthRecords.compactMap {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date))
        }).count
    }
}

// MARK: - Preview

#Preview("TrendsView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData)
    TrendsView(recordsStore: store, hourlyWage: .constant(17.40))
}
