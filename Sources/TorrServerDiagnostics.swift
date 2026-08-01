import AppKit
import Foundation

enum DiagnosticResultKind: Equatable {
    case idle
    case checking
    case success
    case warning
    case failure
}

struct DiagnosticResult: Equatable {
    let kind: DiagnosticResultKind
    let message: String

    static let idle = DiagnosticResult(kind: .idle, message: "")
}

struct TorrServerStorageSnapshot: Equatable {
    var cacheUsed: Int64 = 0
    var cacheCapacity: Int64 = 0
    var diskCacheSize: Int64 = 0
    var freeDiskSpace: Int64 = 0
    var diskCacheEnabled = false
    var diskCachePath = ""

    var isLowOnDiskSpace: Bool {
        freeDiskSpace > 0 && freeDiskSpace < 10 * 1024 * 1024 * 1024
    }
}

final class TorrServerDiagnosticsService {
    private let api = NativeTorrServerAPI()

    func checkPort(language: AppLanguage) async -> DiagnosticResult {
        do {
            try await api.checkHealth()
            return DiagnosticResult(
                kind: .success,
                message: language == .russian
                    ? "Порт 8090 отвечает: API TorrServer доступен."
                    : "Port 8090 responds: TorrServer API is available."
            )
        } catch {
            return DiagnosticResult(
                kind: .failure,
                message: language == .russian
                    ? "Порт 8090 не отвечает: \(error.localizedDescription)"
                    : "Port 8090 is not responding: \(error.localizedDescription)"
            )
        }
    }

    func findTorrServerProcesses(language: AppLanguage) async -> DiagnosticResult {
        await Task.detached(priority: .userInitiated) {
            do {
                let output = try Self.run("/bin/ps", arguments: ["-axo", "pid=,command="])
                let matches = output.split(separator: "\n").filter {
                    $0.localizedCaseInsensitiveContains("TorrServer")
                        && !$0.localizedCaseInsensitiveContains("TorrServer.app")
                }
                guard !matches.isEmpty else {
                    return DiagnosticResult(
                        kind: .warning,
                        message: language == .russian
                            ? "Других процессов TorrServer не найдено."
                            : "No other TorrServer process was found."
                    )
                }
                return DiagnosticResult(
                    kind: .success,
                    message: (language == .russian ? "Найдено: " : "Found: ") + matches.map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }.joined(separator: " · ")
                )
            } catch {
                return DiagnosticResult(kind: .failure, message: error.localizedDescription)
            }
        }.value
    }

    func inspectExecutable(path: String, language: AppLanguage) async -> DiagnosticResult {
        await Task.detached(priority: .userInitiated) {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return DiagnosticResult(
                    kind: .failure,
                    message: language == .russian
                        ? "Исполняемый файл не выбран."
                        : "No executable selected."
                )
            }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return DiagnosticResult(
                    kind: .failure,
                    message: language == .russian
                        ? "Выбранный файл не существует."
                        : "The selected file does not exist."
                )
            }
            guard FileManager.default.isExecutableFile(atPath: trimmed) else {
                return DiagnosticResult(
                    kind: .failure,
                    message: language == .russian
                        ? "Файл не является исполняемым. Разрешите запуск или выберите другую сборку."
                        : "The file is not executable. Allow execution or select another build."
                )
            }
            do {
                let type = try Self.run("/usr/bin/file", arguments: [trimmed])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let isNative = type.localizedCaseInsensitiveContains("arm64")
                return DiagnosticResult(
                    kind: isNative ? .success : .warning,
                    message: isNative
                        ? (language == .russian
                            ? "Файл исправен и содержит код Apple Silicon arm64."
                            : "Executable is valid and contains Apple Silicon arm64 code.")
                        : (language == .russian
                            ? "Файл запускаемый, но arm64 не обнаружен: \(type)"
                            : "Executable can run, but arm64 was not detected: \(type)")
                )
            } catch {
                return DiagnosticResult(kind: .warning, message: error.localizedDescription)
            }
        }.value
    }

    func storageSnapshot(torrents: [NativeTorrent]) async -> TorrServerStorageSnapshot {
        var snapshot = TorrServerStorageSnapshot()
        let home = NSHomeDirectory()
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: home),
           let free = attributes[.systemFreeSize] as? NSNumber {
            snapshot.freeDiskSpace = free.int64Value
        }

        if let settings = try? await api.settings() {
            snapshot.cacheCapacity = settings.cacheSize
            snapshot.diskCacheEnabled = settings.useDisk
            snapshot.diskCachePath = settings.torrentsSavePath
            if settings.useDisk, Self.isSafeCacheRoot(settings.torrentsSavePath) {
                snapshot.diskCacheSize = await Task.detached {
                    Self.directorySize(atPath: settings.torrentsSavePath)
                }.value
            }
        }

        for torrent in torrents where torrent.isActive {
            if let state = try? await api.cacheState(hash: torrent.hash) {
                snapshot.cacheUsed += state.filled
                snapshot.cacheCapacity = max(snapshot.cacheCapacity, state.capacity)
            }
        }
        return snapshot
    }

    func clearCache(torrents: [NativeTorrent]) async throws {
        let settings = try? await api.settings()
        for torrent in torrents where !torrent.hash.isEmpty {
            try? await api.dropTorrentCache(hash: torrent.hash)
        }

        guard let settings,
              settings.useDisk,
              Self.isSafeCacheRoot(settings.torrentsSavePath) else { return }

        let root = URL(fileURLWithPath: settings.torrentsSavePath, isDirectory: true)
            .standardizedFileURL
        let knownHashes = Set(torrents.map { $0.hash.lowercased() }.filter { $0.count == 40 })
        for hash in knownHashes {
            let target = root.appendingPathComponent(hash, isDirectory: true).standardizedFileURL
            guard target.deletingLastPathComponent() == root else { continue }
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
        }
    }

    func report(
        status: String,
        tooltip: String,
        executablePath: String,
        storage: TorrServerStorageSnapshot,
        port: DiagnosticResult,
        process: DiagnosticResult,
        executable: DiagnosticResult
    ) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "unknown"
        return [
            "TorrServer GUI diagnostics",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "App: \(appVersion)",
            "Status: \(status)",
            "Details: \(tooltip)",
            "Executable: \(executablePath)",
            "Port: \(port.message)",
            "Process: \(process.message)",
            "Executable check: \(executable.message)",
            "Memory buffer: \(storage.cacheUsed) / \(storage.cacheCapacity) bytes",
            "Disk cache: \(storage.diskCacheSize) bytes at \(storage.diskCachePath)",
            "Free disk: \(storage.freeDiskSpace) bytes"
        ].joined(separator: "\n")
    }

    private static func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw AppError(output.isEmpty ? "Diagnostic command failed." : output)
        }
        return output
    }

    private static func isSafeCacheRoot(_ path: String) -> Bool {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        return !normalized.isEmpty
            && normalized != "/"
            && normalized != NSHomeDirectory()
            && normalized.count > 4
    }

    private static func directorySize(atPath path: String) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
