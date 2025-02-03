import SwiftUI
import Charts

// MARK: - Currency Formatter Helper
private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
}

// MARK: - TrendsViewModel

final class TrendsViewModel: ObservableObject {
    /// Stores computed pages for each grouping.
    @Published var paginatedGroupedData: [Grouping: [[GroupedData]]] = [:]
    
    private var records: [WorkRecord]
    private var hourlyWage: Double
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()
    
    init(records: [WorkRecord], hourlyWage: Double) {
        self.records = records
        self.hourlyWage = hourlyWage
        computeAllGroupings()
    }
    
    func update(records: [WorkRecord], hourlyWage: Double) {
        self.records = records
        self.hourlyWage = hourlyWage
        computeAllGroupings()
    }
    
    private func computeAllGroupings() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let weekly = self.computeWeeklyData()
            let monthly = self.computeMonthlyData()
            let yearly = self.computeYearlyData()
            DispatchQueue.main.async {
                self.paginatedGroupedData[.week] = weekly
                self.paginatedGroupedData[.month] = monthly
                self.paginatedGroupedData[.year] = yearly
            }
        }
    }
    
    // MARK: - WEEKLY DATA (Mon–Sun)
    private func computeWeeklyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliestDate = sorted.first?.date,
              let latestDate = sorted.last?.date else { return [] }
        
        let now = Date()
        let upperBound = max(latestDate, now)
        guard let earliestWeek = calendar.dateInterval(of: .weekOfYear, for: earliestDate),
              let latestWeek = calendar.dateInterval(of: .weekOfYear, for: upperBound) else {
            return []
        }
        
        let startOfFirstWeek = earliestWeek.start
        let startOfLastWeek = latestWeek.start
        
        var weekStart = startOfFirstWeek
        var pages: [[GroupedData]] = []
        
        while weekStart <= startOfLastWeek {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { break }
            
            var weekData: [GroupedData] = []
            let daysThisWeek = allDates(from: weekStart, to: weekEnd)
            for day in daysThisWeek {
                // Instead of filtering for each day, you might consider grouping your records by day once.
                let dailyRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
                let val = computeMetricValue(for: dailyRecords)
                weekData.append(GroupedData(startDate: day, value: val))
            }
            pages.append(weekData)
            guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeekStart
        }
        
        if let lastPage = pages.last, lastPage.allSatisfy({ $0.value == 0 }) {
            pages.removeLast()
        }
        
        return pages
    }
    
    // MARK: - MONTHLY DATA
    private func computeMonthlyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date,
              let latest = sorted.last?.date else { return [] }
        
        let now = Date()
        let upperDate = max(latest, now)
        
        guard let earliestMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest)),
              let latestMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: upperDate))
        else { return [] }
        
        var currentMonth = earliestMonthStart
        var pages: [[GroupedData]] = []
        
        while currentMonth <= latestMonthStart {
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<1
            var oneMonthData: [GroupedData] = []
            for dayNumber in daysInMonth {
                var comps = calendar.dateComponents([.year, .month], from: currentMonth)
                comps.day = dayNumber
                if let dayDate = calendar.date(from: comps) {
                    let dailyRecs = records.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
                    let val = computeMetricValue(for: dailyRecs)
                    oneMonthData.append(GroupedData(startDate: dayDate, value: val))
                }
            }
            pages.append(oneMonthData)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
            currentMonth = nextMonth
        }
        
        if let lastPage = pages.last, lastPage.allSatisfy({ $0.value == 0 }) {
            pages.removeLast()
        }
        
        return pages
    }
    
    // MARK: - YEARLY DATA
    private func computeYearlyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        let sorted = records.sorted { $0.date < $1.date }
        guard let earliest = sorted.first?.date,
              let latest = sorted.last?.date else { return [] }
        
        let now = Date()
        let upperBound = max(latest, now)
        
        let firstYear = calendar.component(.year, from: earliest)
        let lastYear = calendar.component(.year, from: upperBound)
        
        var pages: [[GroupedData]] = []
        
        for year in firstYear...lastYear {
            var oneYearData: [GroupedData] = []
            for month in 1...12 {
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = 1
                if let monthDate = calendar.date(from: comps) {
                    let monthlyRecs = records.filter { rec in
                        let recYear = calendar.component(.year, from: rec.date)
                        let recMonth = calendar.component(.month, from: rec.date)
                        return recYear == year && recMonth == month
                    }
                    let val = computeMetricValue(for: monthlyRecs)
                    oneYearData.append(GroupedData(startDate: monthDate, value: val))
                }
            }
            pages.append(oneYearData)
        }
        
        if let lastPage = pages.last, lastPage.allSatisfy({ $0.value == 0 }) {
            pages.removeLast()
        }
        
        return pages
    }
    
    // MARK: - HELPER: Compute Metric Value
    private func computeMetricValue(for records: [WorkRecord]) -> Double {
        let totalHours = records.reduce(0.0) { $0 + $1.hours }
        let totalTips = records.reduce(0.0) { $0 + $1.tips }
        let totalEarnings = (totalHours * hourlyWage) + totalTips
        
        // In this refactored code the metric is chosen at the view level.
        // We return totalEarnings as a default (you can adjust as needed).
        return totalEarnings
    }
}

// MARK: - TrendsView

struct TrendsView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double
    @State private var selectedGrouping: Grouping = .week
    @State private var selectedMetric: Metric = .tips
    // Persist current tab index for swipeable chart.
    static var lastCurrentIndex: Int = 0
    @State private var currentIndex: Int = TrendsView.lastCurrentIndex
    
    @StateObject private var viewModel: TrendsViewModel
    
    init(recordsStore: RecordsStore, hourlyWage: Binding<Double>) {
        self.recordsStore = recordsStore
        self._hourlyWage = hourlyWage
        // Initialize the view model with the current records and wage.
        _viewModel = StateObject(wrappedValue: TrendsViewModel(records: recordsStore.records,
                                                                hourlyWage: hourlyWage.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Metric Picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Grouping Picker
                Picker("Grouping", selection: $selectedGrouping) {
                    ForEach(Grouping.allCases, id: \.self) { grouping in
                        Text(grouping.displayName).tag(grouping)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if let title = chartTitle {
                    Text(title)
                        .font(.headline)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
                
                // Swipeable Chart
                if let pages = viewModel.paginatedGroupedData[selectedGrouping], !pages.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(pages.indices, id: \.self) { index in
                            ChartView(data: pages[index],
                                      metric: selectedMetric,
                                      grouping: selectedGrouping,
                                      hourlyWage: hourlyWage)
                                .frame(maxWidth: .infinity, maxHeight: 500)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .id(selectedGrouping)
                    .padding()
                    .onAppear {
                        // Jump to the most recent chunk on first appear
                        currentIndex = max(0, pages.count - 1)
                    }
                    .onChange(of: selectedGrouping) {
                        // Jump to the most recent chunk whenever grouping changes
                        currentIndex = max(0, pages.count - 1)
                    }
                    .onChange(of: currentIndex) {
                        TrendsView.lastCurrentIndex = currentIndex
                    }
                } else {
                    // Show a loading indicator if pages are not yet computed.
                    ProgressView("Loading data…")
                        .frame(maxWidth: .infinity, maxHeight: 500)
                }
                
                // Summary View
                if let dateRange = currentPageInterval {
                    // Filter the records to include only those in the current page’s date range.
                    let filteredRecords = recordsStore.records.filter { dateRange.contains($0.date) }
                    SummaryView(records: filteredRecords,
                                hourlyWage: hourlyWage,
                                grouping: selectedGrouping)
                }
                Spacer()
            }
            .navigationTitle("Trends")
            // Update view model when records or wage change.
            .onChange(of: recordsStore.records) {
                viewModel.update(records: recordsStore.records, hourlyWage: hourlyWage)
            }
            .onChange(of: hourlyWage) {
                viewModel.update(records: recordsStore.records, hourlyWage: hourlyWage)
            }
        }
    }
    
    private var currentPageInterval: DateInterval? {
        guard let pages = viewModel.paginatedGroupedData[selectedGrouping],
              currentIndex < pages.count,
              let firstDate = pages[currentIndex].first?.startDate else {
            return nil
        }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        
        switch selectedGrouping {
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: firstDate)
        case .month:
            return cal.dateInterval(of: .month, for: firstDate)
        case .year:
            return cal.dateInterval(of: .year, for: firstDate)
        }
    }
    
    private var chartTitle: String? {
        guard let pages = viewModel.paginatedGroupedData[selectedGrouping],
              currentIndex < pages.count else { return nil }
        let currentData = pages[currentIndex]
        guard let firstDate = currentData.first?.startDate else { return nil }
        
        let formatter = DateFormatter()
        switch selectedGrouping {
        case .week:
            formatter.dateFormat = "MMM d, yyyy"
            return "Week of \(formatter.string(from: firstDate))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: firstDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: firstDate)
        }
    }
}

// MARK: - Chart View

struct ChartView: View {
    let data: [GroupedData]
    let metric: Metric
    let grouping: Grouping
    let hourlyWage: Double
    
    @State private var selectedData: GroupedData? = nil
    @State private var longPressActive = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Date", item.startDate, unit: xAxisUnit),
                            y: .value(metric.displayName, item.valueFor(metric: metric, hourlyWage: hourlyWage))
                        )
                        .foregroundStyle(.blue)
                    }
                    
                    if let selected = selectedData {
                        RuleMark(x: .value("Selected Date", selected.startDate, unit: xAxisUnit))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .chartXAxis {
                    if grouping == .month {
                        AxisMarks(
                            values: data.map(\.startDate).filter { date in
                                let dayNum = Calendar.current.component(.day, from: date)
                                return (dayNum - 1) % 7 == 0
                            }
                        ) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            AxisValueLabel {
                                if let dateVal = value.as(Date.self) {
                                    let dayNum = Calendar.current.component(.day, from: dateVal)
                                    Text("\(dayNum)")
                                }
                            }
                        }
                    } else {
                        AxisMarks(values: data.map(\.startDate)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(xAxisLabel(for: date))
                                }
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedData != nil {
                                    dismissRuleMark()
                                }
                            }
                            .gesture(longPressThenDrag(proxy: proxy, geo: geo))
                        
                        if let selected = selectedData {
                            let plotFrame = geo[proxy.plotFrame!]
                            let lineX = proxy.position(forX: selected.startDate) ?? 0
                            let rawCalloutX = plotFrame.origin.x + lineX
                            let calloutY = plotFrame.origin.y
                            
                            let calloutWidth: CGFloat = 100
                            let leftLimit = plotFrame.minX + calloutWidth / 2
                            let rightLimit = plotFrame.maxX - calloutWidth / 2
                            let clampedX = min(max(rawCalloutX, leftLimit), rightLimit)
                            
                            let dateStr = tickerDateString(for: selected.startDate, grouping: grouping)
                            let valueStr = formattedValue(for: metric, value: selected.valueFor(metric: metric, hourlyWage: hourlyWage))
                            
                            Group {
                                Text("\(dateStr)\n\(valueStr)")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(.systemBackground))
                                            .shadow(radius: 2)
                                    )
                            }
                            .position(x: clampedX, y: calloutY)
                        }
                    }
                }
                .onChange(of: metric) { _, _ in dismissRuleMark() }
                .onChange(of: grouping) { _, _ in dismissRuleMark() }
            }
        }
        .padding(.top, 30)
    }
       
    private func longPressThenDrag(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        let longPress = LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                longPressActive = true
            }
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard longPressActive else { return }
                let plotFrame = geo[proxy.plotFrame!]
                let locationX = value.location.x - plotFrame.origin.x
                if let draggedDate: Date = proxy.value(atX: locationX) {
                    selectedData = findNearest(to: draggedDate, in: data)
                }
            }
            .onEnded { _ in
                longPressActive = false
            }
        return longPress.sequenced(before: drag)
    }
    
    private func dismissRuleMark() {
        selectedData = nil
        longPressActive = false
    }
    
    // MARK: - Axis Helpers
    
    private var xAxisUnit: Calendar.Component {
        switch grouping {
        case .week, .month:
            return .day
        case .year:
            return .month
        }
    }
    
    private func xAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch grouping {
        case .week:
            formatter.dateFormat = "E d"
        case .month:
            formatter.dateFormat = "d"
        case .year:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
    
    // MARK: - Callout Helpers
    
    private func tickerDateString(for date: Date, grouping: Grouping) -> String {
        let formatter = DateFormatter()
        switch grouping {
        case .week, .month:
            formatter.dateFormat = "E MMM d"
        case .year:
            formatter.dateFormat = "MMM yyyy"
        }
        return formatter.string(from: date)
    }
    
    /// Formats the value string based on the selected metric.
    private func formattedValue(for metric: Metric, value: Double) -> String {
        switch metric {
        case .hours:
            return String(format: "%.2f hours", value)
        case .tips, .totalEarnings:
            return formatCurrency(value)
        case .hourlyRate:
            return formatCurrency(value) + "/hr"
        }
    }
    
    private func findNearest(to target: Date, in data: [GroupedData]) -> GroupedData? {
        guard !data.isEmpty else { return nil }
        return data.min {
            abs($0.startDate.timeIntervalSinceReferenceDate - target.timeIntervalSinceReferenceDate)
                < abs($1.startDate.timeIntervalSinceReferenceDate - target.timeIntervalSinceReferenceDate)
        }
    }
}

// MARK: - SummaryView

struct SummaryView: View {
    let records: [WorkRecord]
    let hourlyWage: Double
    let grouping: Grouping  // Determines which summary options to show

    // MARK: - Summary Type Enum
    enum SummaryType: String, Identifiable, CaseIterable {
        case overall = "Overall Totals"
        case daily = "Daily Average"
        case weekly = "Weekly Average"
        case monthly = "Monthly Average"
        
        var id: String { self.rawValue }
    }
    
    // Available summary options vary by grouping.
    private var availableSummaryTypes: [SummaryType] {
        switch grouping {
        case .week:
            return [.overall, .daily]
        case .month:
            return [.overall, .daily, .weekly]
        case .year:
            return [.overall, .daily, .weekly, .monthly]
        }
    }
    
    @State private var selectedSummary: SummaryType = .overall

    // MARK: - Overall Totals Computations
    private var totalHours: Double {
        records.reduce(0) { $0 + $1.hours }
    }
    
    private var totalTips: Double {
        records.reduce(0) { $0 + $1.tips }
    }
    
    private var totalEarnings: Double {
        (totalHours * hourlyWage) + totalTips
    }
    
    private var hourlyRate: Double {
        totalHours == 0 ? 0 : totalEarnings / totalHours
    }
    
    // MARK: - Daily Averages Computations
    private var uniqueDaysCount: Int {
        let calendar = Calendar.current
        return Set(records.map { calendar.startOfDay(for: $0.date) }).count
    }
    
    private var dailyAverageHours: Double {
        uniqueDaysCount > 0 ? totalHours / Double(uniqueDaysCount) : 0
    }
    
    private var dailyAverageTips: Double {
        uniqueDaysCount > 0 ? totalTips / Double(uniqueDaysCount) : 0
    }
    
    private var dailyAverageEarnings: Double {
        uniqueDaysCount > 0 ? totalEarnings / Double(uniqueDaysCount) : 0
    }
    
    private var dailyAverageHourly: Double {
        let avgHours = dailyAverageHours
        return avgHours > 0 ? dailyAverageEarnings / avgHours : 0
    }
    
    // MARK: - Weekly Averages Computations (for Month & Year grouping)
    private var completedRecordsForWeek: [WorkRecord] {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return records
        }
        return records.filter { record in
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: record.date) {
                return weekInterval.start < currentWeekStart
            }
            return false
        }
    }
    
    private var uniqueCompletedWeeksCount: Int {
        let calendar = Calendar.current
        let weekStartDates = completedRecordsForWeek.compactMap { record -> Date? in
            return calendar.dateInterval(of: .weekOfYear, for: record.date)?.start
        }
        return Set(weekStartDates).count
    }
    
    private var weeklyTotalHours: Double {
        completedRecordsForWeek.reduce(0) { $0 + $1.hours }
    }
    
    private var weeklyTotalTips: Double {
        completedRecordsForWeek.reduce(0) { $0 + $1.tips }
    }
    
    private var weeklyTotalEarnings: Double {
        (weeklyTotalHours * hourlyWage) + weeklyTotalTips
    }
    
    private var weeklyAverageHours: Double {
        uniqueCompletedWeeksCount > 0 ? weeklyTotalHours / Double(uniqueCompletedWeeksCount) : 0
    }
    
    private var weeklyAverageTips: Double {
        uniqueCompletedWeeksCount > 0 ? weeklyTotalTips / Double(uniqueCompletedWeeksCount) : 0
    }
    
    private var weeklyAverageEarnings: Double {
        uniqueCompletedWeeksCount > 0 ? weeklyTotalEarnings / Double(uniqueCompletedWeeksCount) : 0
    }
    
    private var weeklyAverageHourly: Double {
        let avgHours = weeklyAverageHours
        return avgHours > 0 ? weeklyAverageEarnings / avgHours : 0
    }
    
    // MARK: - Monthly Averages Computations (for Year grouping)
    private var completedRecords: [WorkRecord] {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return records
        }
        return records.filter { record in
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            if let recordMonthStart = calendar.date(from: comps) {
                return recordMonthStart < currentMonthStart
            }
            return false
        }
    }
    
    private var uniqueCompletedMonthsCount: Int {
        let calendar = Calendar.current
        let monthStartDates = completedRecords.compactMap { record -> Date? in
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: comps)
        }
        return Set(monthStartDates).count
    }
    
    private var monthlyTotalHours: Double {
        completedRecords.reduce(0) { $0 + $1.hours }
    }
    
    private var monthlyTotalTips: Double {
        completedRecords.reduce(0) { $0 + $1.tips }
    }
    
    private var monthlyTotalEarnings: Double {
        (monthlyTotalHours * hourlyWage) + monthlyTotalTips
    }
    
    private var monthlyAverageHours: Double {
        uniqueCompletedMonthsCount > 0 ? monthlyTotalHours / Double(uniqueCompletedMonthsCount) : 0
    }
    
    private var monthlyAverageTips: Double {
        uniqueCompletedMonthsCount > 0 ? monthlyTotalTips / Double(uniqueCompletedMonthsCount) : 0
    }
    
    private var monthlyAverageEarnings: Double {
        uniqueCompletedMonthsCount > 0 ? monthlyTotalEarnings / Double(uniqueCompletedMonthsCount) : 0
    }
    
    private var monthlyAverageHourly: Double {
        let avgHours = monthlyAverageHours
        return avgHours > 0 ? monthlyAverageEarnings / avgHours : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with drop-down menu.
            HStack {
                Text("Summary")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(availableSummaryTypes) { type in
                        Button(action: { selectedSummary = type }) {
                            Text(type.rawValue)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(selectedSummary.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .padding(4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)
            .onChange(of: grouping) {
                if (grouping == .week) && selectedSummary == .weekly {
                    selectedSummary = .overall
                }
                if grouping != .year && selectedSummary == .monthly {
                    selectedSummary = .overall
                }
            }
            
            Group {
                if selectedSummary == .overall {
                    overallTotalsView
                } else if selectedSummary == .daily {
                    dailyAveragesView
                } else if selectedSummary == .weekly {
                    weeklyAveragesView
                } else if selectedSummary == .monthly {
                    monthlyAveragesView
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Subviews
    
    private var overallTotalsView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", totalHours))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total Earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(totalEarnings))
                        .font(.title3)
                        .bold()
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(totalTips))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Hourly Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(hourlyRate) + "/hr")
                        .font(.title3)
                        .bold()
                }
            }
        }
    }
    
    private var dailyAveragesView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", dailyAverageHours))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(dailyAverageEarnings))
                        .font(.title3)
                        .bold()
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(dailyAverageTips))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Hourly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(dailyAverageHourly) + "/hr")
                        .font(.title3)
                        .bold()
                }
            }
        }
    }
    
    private var weeklyAveragesView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", weeklyAverageHours))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(weeklyAverageEarnings))
                        .font(.title3)
                        .bold()
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(weeklyAverageTips))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Hourly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(weeklyAverageHourly) + "/hr")
                        .font(.title3)
                        .bold()
                }
            }
        }
    }
    
    private var monthlyAveragesView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Hours")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", monthlyAverageHours))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Earnings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(monthlyAverageEarnings))
                        .font(.title3)
                        .bold()
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Average Tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(monthlyAverageTips))
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Average Hourly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(monthlyAverageHourly) + "/hr")
                        .font(.title3)
                        .bold()
                }
            }
        }
    }
}

// MARK: - Data Models & Enums

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

/// The value stored in a chart column.
struct GroupedData: Identifiable {
    let id = UUID()
    let startDate: Date
    let value: Double
    
    /// This helper lets the chart compute the value for the given metric.
    /// You can adjust the logic as needed.
    func valueFor(metric: Metric, hourlyWage: Double) -> Double {
        switch metric {
        case .hours:
            // You would compute hours differently if needed.
            return value
        case .tips:
            return value
        case .totalEarnings:
            return value
        case .hourlyRate:
            // For hourly rate, you might need additional info.
            return value
        }
    }
}

/// Returns all daily dates between `start` and `end` inclusive.
private func allDates(from start: Date, to end: Date) -> [Date] {
    var result: [Date] = []
    let calendar = Calendar(identifier: .gregorian)
    var current = calendar.startOfDay(for: start)
    
    while current <= end {
        result.append(current)
        if let next = calendar.date(byAdding: .day, value: 1, to: current) {
            current = next
        } else {
            break
        }
    }
    return result
}

// MARK: - Preview

extension Double {
    func truncated(to places: Int) -> Double {
        let multiplier = pow(10, Double(places))
        return Double(Int(self * multiplier)) / multiplier
    }
}

extension WorkRecord {
    static let dummyData500: [WorkRecord] = {
        var records: [WorkRecord] = []
        let calendar = Calendar.current
        for dayOffset in 0..<50 {
            let randomHours = Double.random(in: 6...10).truncated(to: 2)
            let randomTips = Double.random(in: 80...250).truncated(to: 2)
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                records.append(WorkRecord(hours: randomHours, tips: randomTips, date: date))
            }
        }
        return records
    }()
}

#Preview("TrendsView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData500)
    TrendsView(recordsStore: store, hourlyWage: .constant(17.40))
        .preferredColorScheme(.light)
}
