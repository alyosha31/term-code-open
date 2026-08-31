import Foundation

public enum GhosttyLauncherError: LocalizedError {
    case neovimNotFound
    case appleScriptFailed(String)

    public var errorDescription: String? {
        switch self {
        case .neovimNotFound:
            return "Could not find nvim in a standard installation location."
        case let .appleScriptFailed(message):
            return "Ghostty could not create the editor tab: \(message)"
        }
    }
}

public struct GhosttyLauncher: Sendable {
    private static let appleScript = #"""
    on run argv
        set projectRoot to item 1 of argv
        set launchCommand to item 2 of argv

        tell application "Ghostty"
            activate
            set cfg to new surface configuration
            set initial working directory of cfg to projectRoot
            set command of cfg to launchCommand

            if (count of windows) is 0 then
                new window with configuration cfg
            else
                set createdTab to new tab in front window with configuration cfg
                select tab createdTab
            end if
        end tell
    end run
    """#

    public init() {}

    public func launch(reference: CodeReference, workingDirectory: URL) throws {
        let nvim = try neovimExecutable()
        let cursorCommand = "+call cursor(\(reference.line), \(reference.column))"
        let command = [nvim, cursorCommand, "--", reference.fileURL.path]
            .map(shellQuote)
            .joined(separator: " ")

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.appleScript, workingDirectory.path, command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown AppleScript error"
            throw GhosttyLauncherError.appleScriptFailed(message)
        }
    }

    public func commandPreview(reference: CodeReference) throws -> String {
        let nvim = try neovimExecutable()
        return [
            nvim,
            "+call cursor(\(reference.line), \(reference.column))",
            "--",
            reference.fileURL.path,
        ].map(shellQuote).joined(separator: " ")
    }

    private func neovimExecutable() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/nvim",
            "/usr/local/bin/nvim",
            "/usr/bin/nvim",
        ]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw GhosttyLauncherError.neovimNotFound
        }
        return path
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
