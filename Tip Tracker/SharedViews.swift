import SwiftUI

// MARK: - MetricStatView

/// A label + value pair displayed vertically; used throughout all metric summaries.
struct MetricStatView: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading
    var valueFont: Font = .body

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(valueFont)
                .bold()
        }
    }
}

// MARK: - MetricRow

/// A single row with a leading and trailing MetricStatView.
struct MetricRow: View {
    let leading: (label: String, value: String)
    let trailing: (label: String, value: String)
    var valueFont: Font = .body

    var body: some View {
        HStack {
            MetricStatView(label: leading.label, value: leading.value,
                           alignment: .leading, valueFont: valueFont)
            Spacer()
            MetricStatView(label: trailing.label, value: trailing.value,
                           alignment: .trailing, valueFont: valueFont)
        }
    }
}

// MARK: - MetricGrid

/// A 2×2 grid of metric stats (two MetricRows stacked).
struct MetricGrid: View {
    let topLeading: (label: String, value: String)
    let topTrailing: (label: String, value: String)
    let bottomLeading: (label: String, value: String)
    let bottomTrailing: (label: String, value: String)
    var valueFont: Font = .body

    var body: some View {
        VStack(spacing: 8) {
            MetricRow(leading: topLeading, trailing: topTrailing, valueFont: valueFont)
            MetricRow(leading: bottomLeading, trailing: bottomTrailing, valueFont: valueFont)
        }
    }
}
