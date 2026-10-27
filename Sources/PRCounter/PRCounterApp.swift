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

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct PRPanel: View {
    let store: PRStore
    @State private var granularity: ChartGranularity = .day
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let stats = store.stats {
                let buckets = stats.buckets(for: granularity)
                Picker("Range", selection: $granularity) {
                    ForEach(ChartGranularity.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                statGrid(stats.scoped(to: buckets), bucketCount: buckets.count)
                PRBarChart(buckets: buckets, granularity: granularity)
                    .id(granularity)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AsyncImage(url: store.stats?.profile.avatarURL) { avatarImage in
                avatarImage.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(store.stats.map { $0.profile.name ?? $0.profile.login } ?? "GitHub")
                    .font(.headline)
                if let profile = store.stats?.profile {
                    ProfileLink(login: profile.login)
                } else {
                    Text("Loading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(store.stats.map { "\($0.total)" } ?? "…")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("PRs")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statGrid(_ scopedStats: PRStats, bucketCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeTitle(bucketCount: bucketCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    StatCell(title: "PRs", value: "\(scopedStats.total)")
                    StatCell(title: "Merged", value: "\(scopedStats.merged)")
                    StatCell(title: "Merge rate", value: scopedStats.mergeRate.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "–")
                }
                GridRow {
                    StatCell(title: "Open", value: "\(scopedStats.open)")
                    StatCell(title: "Closed", value: "\(scopedStats.closed)")
                    StatCell(title: averageTitle, value: averageValue(total: scopedStats.total, bucketCount: bucketCount))
                }
            }
        }
    }

    private func rangeTitle(bucketCount: Int) -> String {
        switch granularity {
        case .day: "Last \(bucketCount) days"
        case .week: "Last \(bucketCount) weeks"
        case .month: "Last \(bucketCount) months"
        case .all: "All time · \(bucketCount) months"
        }
    }

    private var averageTitle: String {
        switch granularity {
        case .day: "Avg / day"
        case .week: "Avg / week"
        case .month, .all: "Avg / month"
        }
    }

    private func averageValue(total: Int, bucketCount: Int) -> String {
        guard bucketCount > 0 else { return "–" }
        return (Double(total) / Double(bucketCount)).formatted(.number.precision(.fractionLength(1)))
    }

    private var footer: some View {
        HStack {
            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(errorMessage)
            } else if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let login = store.stats?.profile.login,
                   let url = URL(string: "https://github.com/pulls?q=is%3Apr+author%3A\(login)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .help("Open on GitHub")
            Button {
                openWindow(id: "settings")
                NSApplication.shared.activate()
            } label: {
                Image(systemName: "gearshape")
            }
            .keyboardShortcut(",")
            .help("Settings")
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

struct ProfileLink: View {
    let login: String
    @State private var isHovered = false

    var body: some View {
        Link(destination: URL(string: "https://github.com/\(login)")!) {
            Text("@\(login)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovered = $0 }
        .help("Open GitHub profile")
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
