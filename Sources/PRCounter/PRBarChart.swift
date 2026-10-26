import Charts
import SwiftUI

enum HeatmapPalette {
    static let light: [Color] = [
        Color(red: 0xEB / 255, green: 0xED / 255, blue: 0xF0 / 255),
        Color(red: 0x9B / 255, green: 0xE9 / 255, blue: 0xA8 / 255),
        Color(red: 0x40 / 255, green: 0xC4 / 255, blue: 0x63 / 255),
        Color(red: 0x30 / 255, green: 0xA1 / 255, blue: 0x4E / 255),
        Color(red: 0x21 / 255, green: 0x6E / 255, blue: 0x39 / 255),
    ]
    static let dark: [Color] = [
        Color(red: 0x16 / 255, green: 0x1B / 255, blue: 0x22 / 255),
        Color(red: 0x0E / 255, green: 0x44 / 255, blue: 0x29 / 255),
        Color(red: 0x00 / 255, green: 0x6D / 255, blue: 0x32 / 255),
        Color(red: 0x26 / 255, green: 0xA6 / 255, blue: 0x41 / 255),
        Color(red: 0x39 / 255, green: 0xD3 / 255, blue: 0x53 / 255),
    ]

    static func level(count: Int, maxCount: Int) -> Int {
        guard count > 0, maxCount > 0 else { return 0 }
        return min(4, max(1, Int((Double(count) / Double(maxCount) * 4).rounded(.up))))
    }
}

struct PRBarChart: View {
    let buckets: [ChartBucket]
    let granularity: ChartGranularity
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate: Date?

    private var palette: [Color] { colorScheme == .dark ? HeatmapPalette.dark : HeatmapPalette.light }
    private var maxCount: Int { buckets.map(\.count).max() ?? 0 }

    private var highlightedBucket: ChartBucket? {
        guard let selectedDate else { return buckets.last }
        let calendar = Calendar.current
        let selectedStart = calendar.dateInterval(of: granularity.calendarComponent, for: selectedDate)?.start
        return buckets.first { $0.start == selectedStart } ?? buckets.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let highlightedBucket {
                    Text(label(for: highlightedBucket.start))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(highlightedBucket.count) PRs")
                        .monospacedDigit()
                }
            }
            .font(.caption)
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.start, unit: granularity.calendarComponent),
                    y: .value("PRs", bucket.count)
                )
                .foregroundStyle(palette[HeatmapPalette.level(count: bucket.count, maxCount: maxCount)])
                .cornerRadius(2)
                .opacity(highlightedBucket?.start == bucket.start || selectedDate == nil ? 1 : 0.55)
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: axisDates) { _ in
                    AxisValueLabel(format: axisFormat)
                }
            }
            .frame(height: 140)
            legend
        }
    }

    private var axisDates: [Date] {
        let labelStep = max(1, buckets.count / 4)
        return stride(from: 0, to: buckets.count - labelStep / 2, by: labelStep).map { buckets[$0].start }
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Spacer()
            Text("Less")
            ForEach(palette.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette[index])
                    .strokeBorder(.primary.opacity(0.08))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var axisFormat: Date.FormatStyle {
        switch granularity {
        case .day, .week: .dateTime.month(.abbreviated).day()
        case .month: .dateTime.month(.abbreviated)
        }
    }

    private func label(for start: Date) -> String {
        switch granularity {
        case .day:
            return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            return "Week of \(start.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        }
    }
}
