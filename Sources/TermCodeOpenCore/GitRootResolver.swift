import Foundation

public struct GitRootResolver: Sendable {
    public init() {}

    public func workingDirectory(for fileURL: URL) -> URL {
        let directory = fileURL.deletingLastPathComponent().standardizedFileURL
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "rev-parse", "--show-toplevel"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return directory }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard let root = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !root.isEmpty
            else { return directory }
            return URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL
        } catch {
            return directory
        }
    }
}
