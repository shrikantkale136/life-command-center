import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("lastBackupExport") private var lastExport = 0.0
    @State private var exportPassword = ""
    @State private var confirmation = ""
    @State private var restorePassword = ""
    @State private var encryptedImport: Data?
    @State private var importedSnapshot: BackupSnapshot?
    @State private var document: BackupDocument?
    @State private var exports = false
    @State private var imports = false
    @State private var confirmsRestore = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Form {
            Section {
                SecureField("Backup password", text: $exportPassword).textContentType(.newPassword)
                SecureField("Confirm password", text: $confirmation).textContentType(.newPassword)
                Button("Export backup", systemImage: "square.and.arrow.up") { exportBackup() }
                    .disabled(busy || exportPassword.count < 12 || exportPassword != confirmation)
                if lastExport > 0 { LabeledContent("Last export", value: Date(timeIntervalSince1970: lastExport).formatted(date: .abbreviated, time: .shortened)) }
            } header: { Text("Export") } footer: {
                Text("Use at least 12 characters. The backup contains all records, card images, and portable preferences. The password is never saved and cannot be recovered.")
            }
            Section {
                Button("Choose backup from Files", systemImage: "folder") { clearImport(); imports = true }.disabled(busy)
                if encryptedImport != nil && importedSnapshot == nil {
                    SecureField("Backup password", text: $restorePassword)
                    Button("Unlock backup") { unlockBackup() }.disabled(busy || restorePassword.isEmpty)
                    Button("Cancel import", role: .cancel) { clearImport() }.disabled(busy)
                }
                if let snapshot = importedSnapshot {
                    LabeledContent("Backup date", value: snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Records", value: String(snapshot.recordCount))
                    LabeledContent("Visiting cards", value: String(snapshot.cards.count))
                    LabeledContent("Image files", value: String(snapshot.images.count))
                    Button("Replace current data…", role: .destructive) { confirmsRestore = true }.disabled(busy)
                    Button("Cancel import", role: .cancel) { clearImport() }.disabled(busy)
                }
            } header: { Text("Restore") } footer: { Text("Restoring replaces current records and portable preferences. App lock and device permissions are kept. The complete backup is checked before replacement.") }
            if busy { Section { ProgressView("Working…") } }
            if let successMessage { Section { Text(successMessage).foregroundStyle(.secondary) } }
        }
        .navigationTitle("Backup & restore").navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(busy)
        .fileExporter(isPresented: $exports, document: document, contentType: .homeManagerBackup,
                      defaultFilename: "HomeManager-\(Date.now.formatted(.iso8601.year().month().day())).homemanagerbackup") { result in
            if case .success = result { lastExport = Date.now.timeIntervalSince1970; successMessage = "Backup exported successfully." }
            if case .failure(let error) = result, (error as NSError).code != NSUserCancelledError { errorMessage = error.localizedDescription }
            document = nil; exportPassword = ""; confirmation = ""
        }
        .fileImporter(isPresented: $imports, allowedContentTypes: [.homeManagerBackup, .data]) { result in
            switch result {
            case .success(let url):
                busy = true
                Task {
                    do {
                        let data = try await Task.detached(priority: .userInitiated) {
                            let scoped = url.startAccessingSecurityScopedResource()
                            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                            guard size <= 512 * 1024 * 1024 else { throw BackupError.invalid }
                            return try Data(contentsOf: url)
                        }.value
                        encryptedImport = data
                    } catch { errorMessage = error.localizedDescription }
                    busy = false
                }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { errorMessage = error.localizedDescription }
            }
        }
        .alert("Replace current data?", isPresented: $confirmsRestore) {
            Button("Replace data", role: .destructive) { restoreBackup() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Current records and images will be replaced with this backup. This is a replacement, not a merge.") }
        .alert("Backup & restore", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onDisappear { exportPassword = ""; confirmation = ""; restorePassword = "" }
    }
    private func clearImport() { encryptedImport = nil; importedSnapshot = nil; restorePassword = ""; successMessage = nil }
    private func exportBackup() {
        busy = true; successMessage = nil
        let password = exportPassword
        Task {
            do {
                let snapshot = try BackupService().capture(in: context)
                let data = try await Task.detached(priority: .userInitiated) {
                    try BackupCrypto.encrypt(JSONEncoder().encode(snapshot), password: password)
                }.value
                document = BackupDocument(data: data); exports = true
            } catch { errorMessage = error.localizedDescription }
            exportPassword = ""; confirmation = ""; busy = false
        }
    }
    private func unlockBackup() {
        guard let data = encryptedImport else { return }
        busy = true
        let password = restorePassword
        Task {
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    let snapshot = try JSONDecoder().decode(BackupSnapshot.self, from: BackupCrypto.decrypt(data, password: password))
                    try snapshot.validate()
                    return snapshot
                }.value
                importedSnapshot = snapshot; encryptedImport = nil
            } catch { errorMessage = error.localizedDescription }
            restorePassword = ""; busy = false
        }
    }
    private func restoreBackup() {
        guard let snapshot = importedSnapshot else { return }
        busy = true
        Task { @MainActor in
            do { try BackupService().restore(snapshot, in: context); clearImport(); successMessage = "Backup restored successfully." }
            catch { errorMessage = error.localizedDescription }
            busy = false
        }
    }
}
