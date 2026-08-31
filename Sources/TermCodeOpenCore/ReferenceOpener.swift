import Foundation

public struct ReferenceOpener {
    private let parser = ReferenceParser()
    private let gitRootResolver = GitRootResolver()
    private let launcher = GhosttyLauncher()

    public init() {}

    public func open(url: String) throws {
        let reference = try parser.parse(url: url)
        try open(reference)
    }

    public func open(reference rawReference: String, cwd: String) throws {
        let reference = try parser.parse(reference: rawReference, cwd: cwd)
        try open(reference)
    }

    public func preview(url: String) throws -> String {
        let reference = try parser.parse(url: url)
        return try preview(reference)
    }

    public func preview(reference rawReference: String, cwd: String) throws -> String {
        let reference = try parser.parse(reference: rawReference, cwd: cwd)
        return try preview(reference)
    }

    private func open(_ reference: CodeReference) throws {
        let root = gitRootResolver.workingDirectory(for: reference.fileURL)
        try launcher.launch(reference: reference, workingDirectory: root)
    }

    private func preview(_ reference: CodeReference) throws -> String {
        let root = gitRootResolver.workingDirectory(for: reference.fileURL)
        return "working-directory: \(root.path)\ncommand: \(try launcher.commandPreview(reference: reference))"
    }
}
