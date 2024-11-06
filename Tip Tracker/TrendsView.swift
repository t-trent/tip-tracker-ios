import SwiftUI
import Charts

struct TrendsView: View {
    let records: [WorkRecord] = UserDefaults.standard.loadRecords()
    
    @AppStorage("hourlyWage") private var hourlyWage: Double = 0.0
    @State private var selectedGrouping: Grouping = .week
    @State private var selectedMetric: Metric = .tips
    @State private var currentIndex: Int = 0  // Track the current page index
    
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
                }
                
                // Swipeable Chart
                TabView(selection: $currentIndex) {
                    ForEach(paginatedGroupedData.indices, id: \.self) { index in
                        ChartView(data: paginatedGroupedData[index],
                                  metric: selectedMetric,
                                  grouping: selectedGrouping)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .padding()
                .onAppear {
                    // Jump to the most recent chunk on first appear
                    currentIndex = max(0, paginatedGroupedData.count - 1)
                }
                .onChange(of: selectedGrouping) {
                    // Jump to the most recent chunk whenever grouping changes
                    currentIndex = max(0, paginatedGroupedData.count - 1)
                }
                
                Spacer()
            }
            .navigationTitle("Trends")
        }
    }
    
    // MARK: - DATA SOURCE SWITCH
    
    private var paginatedGroupedData: [[GroupedData]] {
        switch selectedGrouping {
        case .week:
            return computeWeeklyData()
        case .month:
            return computeMonthlyData()
        case .year:
            return computeYearlyData()
        }
    }
    
    // MARK: - CHART TITLE
    
    private var chartTitle: String? {
        guard currentIndex < paginatedGroupedData.count else { return nil }
        let currentData = paginatedGroupedData[currentIndex]
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

    // MARK: - WEEKLY DATA (Mon–Sun)
    
    private func computeWeeklyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        
        /// Calendar with Monday as first weekday
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // 2 = Monday in most locales

        // Sort records
        let sorted = records.sorted { $0.date < $1.date }
        
        // Earliest record date and last record date
        guard let earliestDate = sorted.first?.date else { return [] }
        guard let latestDate   = sorted.last?.date else { return [] }
        
        // We'll fill up to the "current" date if that's later
        let now = Date()
        let upperBound = max(latestDate, now)
        
        // 1) Find the Monday of the earliest record's week
        guard let earliestWeek = calendar.dateInterval(of: .weekOfYear, for: earliestDate),
              let latestWeek   = calendar.dateInterval(of: .weekOfYear, for: upperBound)
        else {
            return []
        }
        
        let startOfFirstWeek = earliestWeek.start  // Should be a Monday if firstWeekday=2
        let startOfLastWeek  = latestWeek.start
        
        // 2) Step from `startOfFirstWeek` in 7-day increments through `startOfLastWeek`
        var weekStart = startOfFirstWeek
        var pages: [[GroupedData]] = []
        
        while weekStart <= startOfLastWeek {
            // The end of that week is 6 days later (Mon..Sun)
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
                break
            }
            
            // Gather daily data from weekStart..weekEnd
            var weekData: [GroupedData] = []
            
            let daysThisWeek = allDates(from: weekStart, to: weekEnd)
            for day in daysThisWeek {
                let dailyRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
                let val = computeMetricValue(for: dailyRecords, metric: selectedMetric)
                weekData.append(GroupedData(startDate: day, value: val))
            }
            
            pages.append(weekData)
            
            // Move to the next Monday
            guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                break
            }
            weekStart = nextWeekStart
        }
        
        // 2) **Remove the last page if it’s completely empty** (no data):
        if let lastPage = pages.last,
           lastPage.allSatisfy({ $0.value == 0 }) {
            pages.removeLast()
        }
        
        return pages
    }
    
    // MARK: - MONTHLY DATA (Fill to future days in current month)
    
    private func computeMonthlyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .gregorian)
        
        let sorted = records.sorted(by: { $0.date < $1.date })
        guard let earliest = sorted.first?.date,
              let latest   = sorted.last?.date
        else { return [] }
        
        // We fill at least until "now," so empty future days in the current month appear
        let now       = Date()
        let upperDate = max(latest, now)

        // The month that includes earliest
        guard let earliestMonthStart = calendar.date(from:
            calendar.dateComponents([.year, .month], from: earliest))
        else { return [] }
        
        // The month that includes upperDate
        guard let latestMonthStart = calendar.date(from:
            calendar.dateComponents([.year, .month], from: upperDate))
        else { return [] }
        
        var currentMonth = earliestMonthStart
        var pages: [[GroupedData]] = []
        
        while currentMonth <= latestMonthStart {
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<1
            var oneMonthData: [GroupedData] = []
            
            // For each day in this month
            for dayNumber in daysInMonth {
                var comps = calendar.dateComponents([.year, .month], from: currentMonth)
                comps.day = dayNumber
                if let dayDate = calendar.date(from: comps) {
                    // If dayDate is beyond the final upperDate’s month,
                    // optionally check if dayDate > upperDate to skip
                    let dailyRecs = records.filter {
                        calendar.isDate($0.date, inSameDayAs: dayDate)
                    }
                    let val = computeMetricValue(for: dailyRecs, metric: selectedMetric)
                    oneMonthData.append(GroupedData(startDate: dayDate, value: val))
                }
            }
            
            pages.append(oneMonthData)
            
            // Move to next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
                break
            }
            currentMonth = nextMonth
        }
        
        return pages
    }
    
    // MARK: - YEARLY DATA (Fill to future months in current year)
    
    private func computeYearlyData() -> [[GroupedData]] {
        guard !records.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .gregorian)
        
        let sorted = records.sorted(by: { $0.date < $1.date })
        guard let earliest = sorted.first?.date,
              let latest   = sorted.last?.date
        else { return [] }
        
        // Fill to at least the current year
        let now = Date()
        let upperBound = max(latest, now)
        
        let firstYear = calendar.component(.year, from: earliest)
        let lastYear  = calendar.component(.year, from: upperBound)
        
        var pages: [[GroupedData]] = []
        
        for year in firstYear...lastYear {
            var oneYearData: [GroupedData] = []
            
            // 1..12 for each month of that year
            for month in 1...12 {
                // Construct the "start date" of that month
                var comps = DateComponents()
                comps.year  = year
                comps.month = month
                comps.day   = 1
                
                // If this month is in the future beyond upperBound, skip
                if let monthDate = calendar.date(from: comps),
                   monthDate <= upperBound {
                    
                    // Filter records for that month
                    let monthlyRecs = records.filter { rec in
                        let recYear  = calendar.component(.year,  from: rec.date)
                        let recMonth = calendar.component(.month, from: rec.date)
                        return (recYear == year && recMonth == month)
                    }
                    
                    let val = computeMetricValue(for: monthlyRecs, metric: selectedMetric)
                    oneYearData.append(GroupedData(startDate: monthDate, value: val))
                }
            }
            
            if !oneYearData.isEmpty {
                pages.append(oneYearData)
            }
        }
        
        return pages
    }
    
    // MARK: - HELPER
    
    private func computeMetricValue(for records: [WorkRecord], metric: Metric) -> Double {
        let totalHours = records.reduce(0.0) { $0 + $1.hours }
        let totalTips = records.reduce(0.0) { $0 + $1.tips }
        let totalEarnings = (totalHours * hourlyWage) + totalTips
        
        switch metric {
        case .hours:
            return totalHours
        case .tips:
            return totalTips
        case .totalEarnings:
            return totalEarnings
        case .hourlyRate:
            return totalHours == 0 ? 0 : totalEarnings / totalHours
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

// MARK: - Chart View

struct ChartView: View {
    let data: [GroupedData]
    let metric: Metric
    let grouping: Grouping

    /// Holds which data point is currently selected (for the RuleMark + callout).
    @State private var selectedData: GroupedData? = nil

    /// If true, we’ve recognized the “press and hold” gesture; now we can drag.
    @State private var longPressActive = false

    var body: some View {
        Chart {
            // 1) Draw the bars
            ForEach(data) { item in
                BarMark(
                    x: .value("Date", item.startDate, unit: xAxisUnit),
                    y: .value(metric.displayName, item.value)
                )
                .foregroundStyle(.blue)
            }

            // 2) Dotted RuleMark if we have a selected data point
            if let selected = selectedData {
                RuleMark(x: .value("Selected Date", selected.startDate, unit: xAxisUnit))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .foregroundStyle(.secondary)
            }
        }
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
        .frame(height: 250)
        // Overlay for gestures and callout
        .chartOverlay { proxy in
            GeometryReader { geo in
                // a) “Catch taps” to dismiss the rule mark if it’s showing
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // If the rule mark is up, dismiss it.
                        if selectedData != nil {
                            dismissRuleMark()
                        }
                    }
                    // b) Combine a long-press with a drag:
                    //    - A short press-and-hold *activates* the rule mark
                    //    - Then the drag updates the selection
                    .gesture(longPressThenDrag(proxy: proxy, geo: geo))

                // c) If we have a selection, draw the callout label at the top
                if let selected = selectedData {
                    let plotFrame = geo[proxy.plotFrame!]

                    // The raw X position in the plot for that date
                    let lineX = proxy.position(forX: selected.startDate) ?? 0
                    let rawCalloutX = plotFrame.origin.x + lineX
                    let calloutY = plotFrame.origin.y - 30

                    // Clamp to keep the label from going off the edges
                    let calloutWidth: CGFloat = 100 // Adjusted for potentially longer text
                    let leftLimit  = plotFrame.minX + calloutWidth / 2
                    let rightLimit = plotFrame.maxX - calloutWidth / 2
                    let clampedX = min(max(rawCalloutX, leftLimit), rightLimit)

                    // Format your date/value strings
                    let dateStr  = dateString(for: selected.startDate, grouping: grouping)
                    let valueStr = formattedValue(for: metric, value: selected.value)

                    Group {
                        Text("\(dateStr)\n\(valueStr)")
                            .font(.caption)
                            .multilineTextAlignment(.center) // Center-align text
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 2)
                            )
                    }
                    // Position it, centered horizontally on clampedX,
                    // and about 30 points above the chart’s top edge
                    .position(x: clampedX, y: calloutY)
                }
            }
        }
        // Whenever metric or grouping changes, dismiss the rule mark
        .onChange(of: metric) { newMetric, oldMetric in
            dismissRuleMark()
        }
        // Alternatively, use the zero-parameter closure if preferred:
        /*
        .onChange(of: metric) {
            dismissRuleMark()
        }
        */
        .onChange(of: grouping) { newGrouping, oldGrouping in
            dismissRuleMark()
        }
        // Alternatively, use the zero-parameter closure if preferred:
        /*
        .onChange(of: grouping) {
            dismissRuleMark()
        }
        */
    }

    // MARK: - Chart Gesture

    /// A gesture that first requires a short press-and-hold, then allows dragging.
    private func longPressThenDrag(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        // Adjust `minimumDuration` as needed for “short press”
        let longPress = LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                // Once the press is recognized, we “activate” dragging
                longPressActive = true
            }

        // A simple drag that updates `selectedData` *only if* the press was activated
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
                // Optionally, deactivate long press after dragging
                longPressActive = false
                // If you want the dotted line to disappear after drag ends, uncomment:
                // selectedData = nil
            }

        // Sequence them: must do a successful longPress *before* the drag
        return longPress.sequenced(before: drag)
    }

    /// Clears any selection/rule mark
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
            formatter.dateFormat = "E d" // e.g., "Mon 23"
        case .month:
            formatter.dateFormat = "d"   // e.g., "23"
        case .year:
            formatter.dateFormat = "MMM" // e.g., "Jan"
        }
        return formatter.string(from: date)
    }

    // MARK: - Callout Helpers

    private func dateString(for date: Date, grouping: Grouping) -> String {
        let formatter = DateFormatter()
        switch grouping {
        case .week:
            formatter.dateFormat = "E MMM d"
        case .month:
            formatter.dateFormat = "MMM d"
        case .year:
            formatter.dateFormat = "MMM yyyy"
        }
        return formatter.string(from: date)
    }

    /// Formats the value string based on the selected metric.
    private func formattedValue(for metric: Metric, value: Double) -> String {
        switch metric {
        case .hours:
            // Assuming hours can have fractional parts, format to one decimal place
            return String(format: "%.1f hours", value)
        case .tips, .totalEarnings:
            // Format as currency with two decimal places
            return String(format: "$%.2f", value)
        case .hourlyRate:
            // Format as currency per hour with two decimal places
            return String(format: "$%.2f/hr", value)
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
    case hours, tips, totalEarnings, hourlyRate
    
    var displayName: String {
        switch self {
        case .hours:         return "Hours"
        case .tips:          return "Tips"
        case .totalEarnings: return "Total"
        case .hourlyRate:    return "Hourly"
        }
    }
}

struct GroupedData: Identifiable {
    let id = UUID()
    let startDate: Date
    let value: Double
}


