import SwiftUI
import UniformTypeIdentifiers

// MARK: - Snapshot Types

enum SnapshotOperation: String, Codable {
    case beforeImport = "Before Import"
    case beforeReset = "Before Reset"
    case beforeRestore = "Before Restore"
    case manual = "Manual Backup"
}

struct SnapshotMetadata: Codable, Identifiable {
    var timestamp: Date
    var operation: SnapshotOperation
    var recordCount: Int
    var filename: String
    var id: String { filename }
}

private struct StoredSnapshot: Codable {
    var metadata: SnapshotMetadata
    var records: [WorkRecord]
}

// MARK: - Snapshot Manager

class DataSnapshotManager {
    static let shared = DataSnapshotManager()
    private init() {}

    private var snapshotsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("TipTrackerSnapshots", isDirectory: true)
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
    }

    @discardableResult
    func saveSnapshot(records: [WorkRecord], operation: SnapshotOperation) throws -> SnapshotMetadata {
        ensureDirectoryExists()
        let timestamp = Date()
        let nameFormatter = DateFormatter()
        nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "snapshot_\(nameFormatter.string(from: timestamp)).json"
        let metadata = SnapshotMetadata(
            timestamp: timestamp,
            operation: operation,
            recordCount: records.count,
            filename: filename
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(StoredSnapshot(metadata: metadata, records: records))
        try data.write(to: snapshotsDirectory.appendingPathComponent(filename))
        return metadata
    }

    func loadSnapshots() -> [SnapshotMetadata] {
        ensureDirectoryExists()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SnapshotMetadata? in
                guard let data = try? Data(contentsOf: url),
                      let snap = try? decoder.decode(StoredSnapshot.self, from: data)
                else { return nil }
                return snap.metadata
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func restoreSnapshot(metadata: SnapshotMetadata) throws -> [WorkRecord] {
        let url = snapshotsDirectory.appendingPathComponent(metadata.filename)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoredSnapshot.self, from: data).records
    }

    func deleteSnapshot(metadata: SnapshotMetadata) {
        try? FileManager.default.removeItem(at: snapshotsDirectory.appendingPathComponent(metadata.filename))
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export & Import View

struct ExportImportView: View {
    @ObservedObject var recordsStore: RecordsStore

    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var importMode: ImportMode = .merge
    @State private var pendingImportRecords: [WorkRecord]? = nil
    @State private var showingImportConfirm = false
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var errorMessage: String? = nil
    @State private var showingError = false
    @State private var showingFilePicker = false

    enum ImportMode: String, CaseIterable {
        case merge = "Merge"
        case replace = "Replace"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                exportSection
                Divider()
                importSection
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .navigationTitle("Export & Import")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Permission denied for selected file."
                    showingError = true
                    return
                }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                url.stopAccessingSecurityScopedResource()
                handleImportedFile(url: tempURL)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .alert("Confirm Import", isPresented: $showingImportConfirm) {
            Button("Cancel", role: .cancel) { pendingImportRecords = nil }
            Button(
                importMode == .replace ? "Replace" : "Merge",
                role: importMode == .replace ? .destructive : .none
            ) {
                commitImport()
            }
        } message: {
            if let records = pendingImportRecords {
                let n = records.count
                if importMode == .replace {
                    Text("Replace all existing records with \(n) imported record\(n == 1 ? "" : "s")?")
                } else {
                    Text("Merge \(n) imported record\(n == 1 ? "" : "s") with your existing data?")
                }
            }
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Export Data", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("Save your \(recordsStore.records.count) record\(recordsStore.records.count == 1 ? "" : "s") as a file you can back up or share.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button { exportCSV() } label: {
                    Label("Export CSV", systemImage: "tablecells")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { exportJSON() } label: {
                    Label("Export JSON", systemImage: "curlybraces")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func exportCSV() {
        var lines = ["id,date,hours,tips"]
        for r in recordsStore.records {
            lines.append("\(r.id),\(Formatters.isoDate.string(from: r.date)),\(r.hours),\(String(format: "%.2f", r.tips))")
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tip_tracker_export.csv")
        try? FileManager.default.removeItem(at: tempURL)
        try? lines.joined(separator: "\n").write(to: tempURL, atomically: true, encoding: .utf8)
        shareItems = [tempURL]
        showingShareSheet = true
    }

    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(recordsStore.records) else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tip_tracker_export.json")
        try? FileManager.default.removeItem(at: tempURL)
        try? data.write(to: tempURL)
        shareItems = [tempURL]
        showingShareSheet = true
    }

    // MARK: Import

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Import Data", systemImage: "square.and.arrow.down")
                .font(.headline)

            Text("Load records from a .csv or .json file. A snapshot is saved automatically before any import.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Import Mode")
                    .font(.subheadline)
                    .bold()

                Picker("Import Mode", selection: $importMode) {
                    ForEach(ImportMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(importMode == .merge
                     ? "New records (matched by ID) will be added alongside existing ones."
                     : "All existing records will be permanently replaced.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                showingFilePicker = true
            } label: {
                Label("Choose File…", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func handleImportedFile(url: URL) {
        do {
            let records = try parseFile(at: url)
            pendingImportRecords = records
            showingImportConfirm = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func parseFile(at url: URL) throws -> [WorkRecord] {
        let data = try Data(contentsOf: url)
        switch url.pathExtension.lowercased() {
        case "json":
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let records = try decoder.decode([WorkRecord].self, from: data)
                guard !records.isEmpty else { throw ImportError.noRecords }
                return records
            } catch is DecodingError {
                throw ImportError.invalidJSON
            }
        case "csv":
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.invalidEncoding
            }
            return try parseCSV(text)
        default:
            throw ImportError.unsupportedFormat
        }
    }

    private func parseCSV(_ text: String) throws -> [WorkRecord] {
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { throw ImportError.noRecords }
        lines.removeFirst()
        var records: [WorkRecord] = []
        for line in lines {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= 4,
                  let date = Formatters.isoDate.date(from: fields[1].trimmingCharacters(in: .whitespaces)),
                  let hours = Double(fields[2].trimmingCharacters(in: .whitespaces)),
                  let tips = Double(fields[3].trimmingCharacters(in: .whitespaces))
            else { continue }
            let id = UUID(uuidString: fields[0].trimmingCharacters(in: .whitespaces)) ?? UUID()
            records.append(WorkRecord(id: id, hours: hours, tips: tips, date: date))
        }
        guard !records.isEmpty else { throw ImportError.noRecords }
        return records
    }

    private func commitImport() {
        guard let records = pendingImportRecords else { return }
        pendingImportRecords = nil
        try? DataSnapshotManager.shared.saveSnapshot(records: recordsStore.records, operation: .beforeImport)
        if importMode == .replace {
            recordsStore.records = records
            importResultMessage = "Replaced data with \(records.count) imported record\(records.count == 1 ? "" : "s")."
        } else {
            let existingIDs = Set(recordsStore.records.map { $0.id })
            let added = records.filter { !existingIDs.contains($0.id) }
            recordsStore.records += added
            importResultMessage = "Added \(added.count) new record\(added.count == 1 ? "" : "s")."
        }
        recordsStore.save()
        showingImportResult = true
    }

    enum ImportError: LocalizedError {
        case invalidEncoding, unsupportedFormat, noRecords, invalidJSON

        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "The file's encoding is not UTF-8."
            case .unsupportedFormat: return "Unsupported format. Please choose a .csv or .json file."
            case .noRecords: return "No valid records found in the file."
            case .invalidJSON: return "The JSON file could not be parsed. Make sure it was exported from Tip Tracker."
            }
        }
    }
}

// MARK: - Data History View

struct DataHistoryView: View {
    @ObservedObject var recordsStore: RecordsStore

    @State private var snapshots: [SnapshotMetadata] = []
    @State private var snapshotToRestore: SnapshotMetadata?
    @State private var showingRestoreConfirm = false
    @State private var showingRestoreResult = false
    @State private var restoreResultMessage = ""
    @State private var errorMessage: String?
    @State private var showingError = false

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if snapshots.isEmpty {
                emptyState
            } else {
                snapshotList
            }
        }
        .navigationTitle("Data History")
        .navigationBarTitleDisplayMode(.inline)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    createManualSnapshot()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Save snapshot")
            }
        }
        .onAppear { snapshots = DataSnapshotManager.shared.loadSnapshots() }
        .alert("Restore Snapshot?", isPresented: $showingRestoreConfirm) {
            Button("Cancel", role: .cancel) { snapshotToRestore = nil }
            Button("Restore", role: .destructive) { commitRestore() }
        } message: {
            if let s = snapshotToRestore {
                Text("Your current \(recordsStore.records.count) record\(recordsStore.records.count == 1 ? "" : "s") will be replaced with \(s.recordCount) from this snapshot. Your current data will be saved as a new snapshot first.")
            }
        }
        .alert("Restore Complete", isPresented: $showingRestoreResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreResultMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Snapshots")
                .font(.title2).bold()
            Text("Snapshots are saved automatically before imports and resets. Tap + to save one now.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var snapshotList: some View {
        List {
            ForEach(snapshots) { snapshot in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.operation.rawValue)
                            .font(.headline)
                        Text(timestampFormatter.string(from: snapshot.timestamp))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(snapshot.recordCount) record\(snapshot.recordCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Restore") {
                        snapshotToRestore = snapshot
                        showingRestoreConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                for i in indexSet {
                    DataSnapshotManager.shared.deleteSnapshot(metadata: snapshots[i])
                }
                snapshots.remove(atOffsets: indexSet)
            }
        }
    }

    private func createManualSnapshot() {
        try? DataSnapshotManager.shared.saveSnapshot(records: recordsStore.records, operation: .manual)
        snapshots = DataSnapshotManager.shared.loadSnapshots()
    }

    private func commitRestore() {
        guard let snapshot = snapshotToRestore else { return }
        snapshotToRestore = nil
        do {
            try DataSnapshotManager.shared.saveSnapshot(records: recordsStore.records, operation: .beforeRestore)
            let restored = try DataSnapshotManager.shared.restoreSnapshot(metadata: snapshot)
            recordsStore.records = restored
            recordsStore.save()
            restoreResultMessage = "Restored \(restored.count) record\(restored.count == 1 ? "" : "s")."
            snapshots = DataSnapshotManager.shared.loadSnapshots()
            showingRestoreResult = true
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}
