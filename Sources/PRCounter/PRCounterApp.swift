import SwiftUI

@main
struct PRCounterApp: App {
    @State private var store = PRStore()

    var body: some Scene {
        MenuBarExtra {
            PRMenu(store: store)
        } label: {
            Label(store.menuBarTitle, systemImage: "arrow.triangle.pull")
                .labelStyle(.titleAndIcon)
        }
    }
}

struct PRMenu: View {
    let store: PRStore

    var body: some View {
        if let stats = store.stats {
            Text("@\(stats.login)")
            Divider()
            Text("Total: \(stats.total)")
            Text("Open: \(stats.open)")
            Text("Merged: \(stats.merged)")
            Text("Closed: \(stats.closed)")
            Divider()
            Text("Today: \(stats.today)")
            Text("This month: \(stats.thisMonth)")
        }
        if let errorMessage = store.errorMessage {
            Text("Error: \(errorMessage)")
        }
        if let lastUpdated = store.lastUpdated {
            Text("Updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
        }
        Divider()
        Button("Open on GitHub") {
            if let login = store.stats?.login,
               let url = URL(string: "https://github.com/pulls?q=is%3Apr+author%3A\(login)") {
                NSWorkspace.shared.open(url)
            }
        }
        Button("Refresh") {
            Task { await store.refresh() }
        }
        .keyboardShortcut("r")
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
