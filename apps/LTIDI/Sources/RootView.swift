import SwiftUI
import LTIDICore

enum Route: Hashable {
    case activity(String)
    case settings
}

enum FormTarget: Identifiable, Hashable {
    case new
    case edit(String)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let id): return id
        }
    }
}

struct LogTarget: Identifiable {
    let id = UUID()
    let activityID: String
    /// `nil` = new registration.
    let entry: LogEntry?
    let date: DayDate
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudBackupService.self) private var cloud
    @State private var path: [Route] = []
    @State private var formTarget: FormTarget?
    @State private var showFirstLaunchRestore = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onNewActivity: { formTarget = .new })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .activity(let id):
                        ActivityDetailView(activityID: id, onEdit: { formTarget = .edit(id) })
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .sheet(item: $formTarget) { target in
            switch target {
            case .new:
                ActivityFormView(activity: store.data.newActivityTemplate(), isNew: true, onDeleted: {})
            case .edit(let id):
                if let activity = store.data.activity(id: id) {
                    ActivityFormView(activity: activity, isNew: false, onDeleted: { path.removeAll() })
                }
            }
        }
        .sheet(isPresented: $showFirstLaunchRestore) {
            CloudRestoreView(firstLaunch: true)
        }
        .task {
            if await cloud.shouldOfferRestore() { showFirstLaunchRestore = true }
        }
        .overlay(alignment: .bottom) { ToastView() }
        .animation(.spring(duration: 0.3), value: store.toast?.id)
        .sensoryFeedback(.success, trigger: store.quickLogCount)
        .confirmationDialog(
            quickLogTitle,
            isPresented: Binding(get: { store.pendingQuickLog != nil }, set: { if !$0 { store.pendingQuickLog = nil } }),
            titleVisibility: .visible,
            presenting: store.pendingQuickLog
        ) { activity in
            Button("Registra oggi") { store.quickLog(activity) }
            Button("Annulla", role: .cancel) {}
        }
        .alert(
            "Attenzione",
            isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var quickLogTitle: String {
        store.pendingQuickLog.map { "Registrare “\($0.name)” per oggi?" } ?? ""
    }
}

struct ToastView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if let toast = store.toast {
            HStack(spacing: 12) {
                Text(toast.text)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if toast.undo != nil {
                    Button("Annulla") { store.performUndo() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }
}

struct ChipButton: View {
    @Environment(AppStore.self) private var store
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let accent = Color(hex: store.data.settings.accent)
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? accent.opacity(0.2) : Color.chipFill, in: Capsule())
                .foregroundStyle(isSelected ? accent : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct Panel<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.headline)
            }
            content
        }
        .cardStyle()
    }
}
