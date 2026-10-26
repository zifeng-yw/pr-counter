import SwiftUI

@main
struct PRCounterApp: App {
    @State private var store = PRStore()

    var body: some Scene {
        MenuBarExtra {
            PRPanel(store: store)
        } label: {
            Label(store.menuBarTitle, systemImage: "arrow.triangle.pull")
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PRPanel: View {
    let store: PRStore
    @State private var granularity: ChartGranularity = .day

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let stats = store.stats {
                statGrid(stats)
                Picker("Range", selection: $granularity) {
                    ForEach(ChartGranularity.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                PRBarChart(buckets: stats.buckets(for: granularity), granularity: granularity)
                    .id(granularity)
            }
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.stats.map { "@\($0.login)" } ?? "GitHub")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(store.stats.map { "\($0.total)" } ?? "…")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            Text("pull requests")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statGrid(_ stats: PRStats) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                StatCell(title: "Open", value: "\(stats.open)")
                StatCell(title: "Merged", value: "\(stats.merged)")
                StatCell(title: "Closed", value: "\(stats.closed)")
            }
            GridRow {
                StatCell(title: "Merge rate", value: stats.mergeRate.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "–")
                StatCell(title: "Today", value: "\(stats.countInCurrent(.day))")
                StatCell(title: "This month", value: "\(stats.countInCurrent(.month))")
            }
        }
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let login = store.stats?.login,
                   let url = URL(string: "https://github.com/pulls?q=is%3Apr+author%3A\(login)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .help("Open on GitHub")
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .help("Refresh")
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .keyboardShortcut("q")
            .help("Quit")
        }
        .buttonStyle(.borderless)
    }
}

struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
