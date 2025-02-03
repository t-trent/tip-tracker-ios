import SwiftUI
import Charts
import UIKit

// MARK: - CalendarView

struct CalendarView: View {
    @ObservedObject var recordsStore: RecordsStore
    @Binding var hourlyWage: Double

    @State private var selectedDate: Date? = nil
    @State private var isShowingEditSheet: Bool = false
    @State private var recordToEdit: WorkRecord? = nil

    var body: some View {
        NavigationView {
            VStack {
                // Wrap the calendar in a scroll view.
                // Here we use horizontal scrolling, but you can also try .vertical
                ScrollView(.vertical, showsIndicators: true) {
                    CalendarUIKitView(selectedDate: $selectedDate,
                                      records: recordsStore.records)
                        .frame(width: UIScreen.main.bounds.width, height: 460)
                        .padding()
                }
                
                Divider()

                // If a date is selected, show the metrics using DayMetricsView in its own scroll view.
                if let date = selectedDate {
                    let dayRecords = recordsStore.records.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: date)
                    }

                    if !dayRecords.isEmpty {
                        // Here we wrap the metrics in a vertical scroll view.
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 16) {
                                DayMetricsView(dayRecords: dayRecords,
                                               hourlyWage: hourlyWage,
                                               date: date,
                                               onEdit: {
                                                   // For this example, we use the first record for editing.
                                                   recordToEdit = dayRecords.first
                                                   isShowingEditSheet = true
                                               })
                            }
                            .padding(.bottom)
                        }
                        // You can constrain the height if needed.
                        .frame(maxHeight: 200)
                    } else {
                        Text("No records for \(formattedDate(date))")
                            .padding()
                            .padding(.vertical)
                    }
                }

                Spacer()
            }
            .navigationTitle("Calendar")
            .sheet(isPresented: $isShowingEditSheet) {
                if let record = recordToEdit,
                   let index = recordsStore.records.firstIndex(where: { $0.id == record.id }) {
                    NavigationView {
                        EditRecordView(record: $recordsStore.records[index],
                                       onDelete: {
                                           recordsStore.records.remove(at: index)
                                           isShowingEditSheet = false
                                       },
                                       onSave: {
                                           UserDefaults.standard.saveRecords(recordsStore.records)
                                           isShowingEditSheet = false
                                       })
                            .navigationTitle("Edit Record")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        isShowingEditSheet = false
                                    }
                                }
                            }
                    }
                } else {
                    Text("No record selected")
                }
            }
        }
    }

    // A helper to format the selected date.
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - CalendarUIKitView (SwiftUI wrapper for UICalendarView)

struct CalendarUIKitView: UIViewRepresentable {
    @Binding var selectedDate: Date?
    let records: [WorkRecord]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale.current

        // Use a single-date selection behavior.
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection

        // Set the delegate to provide decorations.
        calendarView.delegate = context.coordinator

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        guard let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate else {
            return
        }

        if let date = selectedDate {
            // Convert the date to DateComponents (year, month, and day).
            let newComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)

            // Check the currently selected date in the calendar view.
            if let currentComponents = selection.selectedDate,
               let currentDate = Calendar.current.date(from: currentComponents) {
                // Compare the current date and the new date.
                if !Calendar.current.isDate(currentDate, inSameDayAs: date) {
                    selection.setSelected(newComponents, animated: true)
                }
            } else {
                // No selection exists yet.
                selection.setSelected(newComponents, animated: true)
            }
        } else {
            // Clear the selection if selectedDate is nil.
            selection.setSelected(nil, animated: true)
        }
    }

    // Coordinator to handle selection and decoration.
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarUIKitView

        init(_ parent: CalendarUIKitView) {
            self.parent = parent
        }

        // MARK: - UICalendarSelectionSingleDateDelegate

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let tappedDate = Calendar.current.date(from: dateComponents) else {
                parent.selectedDate = nil
                return
            }

            // If the tapped date is already selected, de-select it.
            if let currentSelectedDate = parent.selectedDate,
               Calendar.current.isDate(tappedDate, inSameDayAs: currentSelectedDate) {
                // Clear the selection in the calendar view.
                selection.setSelected(nil, animated: true)
                parent.selectedDate = nil
            } else {
                // Otherwise, update the selectedDate with the tapped date.
                parent.selectedDate = tappedDate
            }
        }

        // MARK: - UICalendarViewDelegate

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            // Convert the date components to a Date.
            guard let date = Calendar.current.date(from: dateComponents) else { return nil }

            // If there is at least one record for this day, return a dot decoration.
            if parent.records.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                return .default(color: .systemBlue, size: .small)
            }
            return nil
        }
    }
}

// MARK: - DayMetricsView

struct DayMetricsView: View {
    let dayRecords: [WorkRecord]
    let hourlyWage: Double
    let date: Date

    // Optional closure to be called when tapping the edit button.
    var onEdit: (() -> Void)? = nil

    // Computed properties for the day’s metrics.
    private var totalHours: Double {
        dayRecords.reduce(0) { $0 + $1.hours }
    }

    private var totalTips: Double {
        dayRecords.reduce(0) { $0 + $1.tips }
    }

    private var totalEarnings: Double {
        (totalHours * hourlyWage) + totalTips
    }

    private var hourlyRate: Double {
        totalHours > 0 ? totalEarnings / totalHours : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with formatted date and an edit button (if an action is provided).
            HStack {
                Text(formattedDate(date))
                    .font(.headline)

                Spacer()

                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                    }
                }
            }

            // First row: Total Hours and Total Earnings.
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

            // Second row: Total Tips and Hourly Rate.
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
                    Text("\(formatCurrency(hourlyRate))/hr")
                        .font(.title3)
                        .bold()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Preview

#Preview("CalendarView with Dummy Data") {
    // Create a RecordsStore with dummy data.
    let store = RecordsStore(records: WorkRecord.dummyData500)
    CalendarView(recordsStore: store, hourlyWage: .constant(17.40))
        .preferredColorScheme(.light)
}
