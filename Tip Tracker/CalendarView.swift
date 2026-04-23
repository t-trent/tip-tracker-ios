import SwiftUI
import UIKit

// MARK: - CalendarView

struct CalendarView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double

    @State private var selectedDate: Date? = nil
    @State private var isShowingEditSheet = false

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.vertical, showsIndicators: true) {
                    // Removed .id(recordsStore.records) — decoration updates are handled
                    // incrementally inside CalendarUIKitView.updateUIView instead.
                    CalendarUIKitView(selectedDate: $selectedDate, records: recordsStore.records)
                        .padding()
                }

                Divider()

                if let date = selectedDate {
                    let dayRecords = recordsStore.records.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: date)
                    }
                    if !dayRecords.isEmpty {
                        ScrollView(.vertical, showsIndicators: true) {
                            DayMetricsView(dayRecords: dayRecords,
                                           hourlyWage: hourlyWage,
                                           date: date,
                                           onEdit: { isShowingEditSheet = true })
                                .padding(.bottom)
                        }
                        .frame(maxHeight: 160)
                    } else {
                        Text("No records for \(Formatters.fullDate.string(from: date))")
                            .padding()
                            .padding(.vertical)
                    }
                }

                Spacer()
            }
            .navigationTitle("Calendar")
            .sheet(isPresented: $isShowingEditSheet) {
                editSheet
            }
        }
        .dynamicTypeSize(.xSmall ... .large)
    }

    @ViewBuilder
    private var editSheet: some View {
        if let date = selectedDate,
           let record = recordsStore.records.first(where: {
               Calendar.current.isDate($0.date, inSameDayAs: date)
           }),
           let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
            NavigationView {
                EditRecordView(
                    record: $recordsStore.records[index],
                    onDelete: {
                        recordsStore.delete(record)
                        isShowingEditSheet = false
                    },
                    onSave: {
                        recordsStore.save()
                        isShowingEditSheet = false
                    }
                )
                .navigationTitle("Edit Record")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingEditSheet = false }
                    }
                }
            }
        } else {
            Text("No record selected")
        }
    }
}

// MARK: - CalendarUIKitView

struct CalendarUIKitView: UIViewRepresentable {
    @Binding var selectedDate: Date?
    let records: [WorkRecord]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale   = Locale.current

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        calendarView.delegate = context.coordinator

        // Seed the coordinator's date set so the first updateUIView diff is correct
        let cal = Calendar.current
        context.coordinator.decoratedDates = Set(records.map {
            cal.dateComponents([.year, .month, .day], from: $0.date)
        })

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // Keep coordinator's parent reference current for delegate callbacks
        context.coordinator.parent = self

        // Incrementally reload only dates whose decoration status changed
        let cal = Calendar.current
        let newDates = Set(records.map { cal.dateComponents([.year, .month, .day], from: $0.date) })
        let oldDates = context.coordinator.decoratedDates
        let changed  = Array(newDates.symmetricDifference(oldDates))
        context.coordinator.decoratedDates = newDates

        if !changed.isEmpty {
            uiView.reloadDecorations(forDateComponents: changed, animated: false)
        }

        // Sync the selected date highlight
        guard let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate else { return }
        if let date = selectedDate {
            let newComps = cal.dateComponents([.year, .month, .day], from: date)
            if let currentComps = selection.selectedDate,
               let currentDate = cal.date(from: currentComps),
               cal.isDate(currentDate, inSameDayAs: date) {
                return // already correct — no-op
            }
            selection.setSelected(newComps, animated: true)
        } else {
            selection.setSelected(nil, animated: true)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarUIKitView
        var decoratedDates: Set<DateComponents> = []

        init(_ parent: CalendarUIKitView) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           didSelectDate dateComponents: DateComponents?) {
            guard let comps = dateComponents,
                  let date = Calendar.current.date(from: comps) else {
                parent.selectedDate = nil
                return
            }
            parent.selectedDate = date
        }

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents) else { return nil }
            let hasRecord = parent.records.contains {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            return hasRecord ? .default(color: .systemBlue, size: .small) : nil
        }
    }
}

// MARK: - DayMetricsView

struct DayMetricsView: View {
    let dayRecords: [WorkRecord]
    let hourlyWage: Double
    let date: Date
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Formatters.fullDate.string(from: date))
                    .font(.headline)
                Spacer()
                if let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                    }
                }
            }

            MetricGrid(
                topLeading:    ("Total Hours",    String(format: "%.2f", dayRecords.totalHours)),
                topTrailing:   ("Total Earnings", formatCurrency(dayRecords.totalEarnings(wage: hourlyWage))),
                bottomLeading: ("Total Tips",     formatCurrency(dayRecords.totalTips)),
                bottomTrailing:("Hourly Rate",    formatCurrency(dayRecords.hourlyRate(wage: hourlyWage)) + "/hr"),
                valueFont: .title3
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("CalendarView with Dummy Data") {
    let store = RecordsStore(records: WorkRecord.dummyData)
    CalendarView(recordsStore: store, hourlyWage: .constant(17.40))
}
