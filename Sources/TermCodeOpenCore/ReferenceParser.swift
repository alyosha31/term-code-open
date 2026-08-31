import Foundation

public struct ReferenceParser {
    public init() {}

    public func parse(url rawURL: String, requireExistingFile: Bool = true) throws -> CodeReference {
        guard let components = URLComponents(string: rawURL) else {
            throw CodeReferenceError.invalidURL
        }
        guard components.scheme?.lowercased() == "nvim" else {
            throw CodeReferenceError.unsupportedScheme(components.scheme)
        }
        guard components.host?.lowercased() == "open" else {
            throw CodeReferenceError.unsupportedAction(components.host)
        }

        let query = Dictionary(grouping: components.queryItems ?? [], by: \.name)
            .compactMapValues { $0.last?.value }
        guard let rawPath = query["path"] ?? query["file"], !rawPath.isEmpty else {
            throw CodeReferenceError.missingPath
        }

        let line = try positiveInteger(query["line"], default: 1)
        let column = try positiveInteger(query["column"] ?? query["col"], default: 1)
        let endLine = try optionalPositiveInteger(query["end"] ?? query["endLine"])
        let fileURL = try resolve(path: rawPath, cwd: query["cwd"])
        try validate(fileURL, requireExistingFile: requireExistingFile)
        return CodeReference(fileURL: fileURL, line: line, column: column, endLine: endLine)
    }

    public func parse(reference: String, cwd: String, requireExistingFile: Bool = true) throws -> CodeReference {
        let pattern = #"^(.*?):([0-9]+)(?:-([0-9]+))?(?::([0-9]+))?$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: reference,
                range: NSRange(reference.startIndex..., in: reference)
              ),
              let pathRange = Range(match.range(at: 1), in: reference),
              let lineRange = Range(match.range(at: 2), in: reference)
        else {
            let fileURL = try resolve(path: reference, cwd: cwd)
            try validate(fileURL, requireExistingFile: requireExistingFile)
            return CodeReference(fileURL: fileURL)
        }

        let path = String(reference[pathRange])
        let line = Int(reference[lineRange]) ?? 1
        let endLine = value(at: 3, from: match, in: reference).flatMap(Int.init)
        let column = value(at: 4, from: match, in: reference).flatMap(Int.init) ?? 1
        let fileURL = try resolve(path: path, cwd: cwd)
        try validate(fileURL, requireExistingFile: requireExistingFile)
        return CodeReference(fileURL: fileURL, line: line, column: column, endLine: endLine)
    }

    public func parse(
        file: String,
        cwd: String,
        line: Int = 1,
        column: Int = 1,
        endLine: Int? = nil,
        requireExistingFile: Bool = true
    ) throws -> CodeReference {
        guard line > 0 else { throw CodeReferenceError.invalidPosition(String(line)) }
        guard column > 0 else { throw CodeReferenceError.invalidPosition(String(column)) }
        if let endLine, endLine <= 0 {
            throw CodeReferenceError.invalidPosition(String(endLine))
        }
        let fileURL = try resolve(path: file, cwd: cwd)
        try validate(fileURL, requireExistingFile: requireExistingFile)
        return CodeReference(fileURL: fileURL, line: line, column: column, endLine: endLine)
    }

    private func resolve(path rawPath: String, cwd: String?) throws -> URL {
        let expandedPath = NSString(string: rawPath).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath).standardizedFileURL
        }
        guard let cwd, !cwd.isEmpty else {
            throw CodeReferenceError.relativePathWithoutWorkingDirectory
        }
        let expandedCWD = NSString(string: cwd).expandingTildeInPath
        return URL(fileURLWithPath: expandedCWD, isDirectory: true)
            .appendingPathComponent(expandedPath)
            .standardizedFileURL
    }

    private func validate(_ fileURL: URL, requireExistingFile: Bool) throws {
        guard requireExistingFile else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            throw CodeReferenceError.fileDoesNotExist(fileURL.path)
        }
        guard !isDirectory.boolValue else {
            throw CodeReferenceError.pathIsNotAFile(fileURL.path)
        }
    }

    private func positiveInteger(_ value: String?, default defaultValue: Int) throws -> Int {
        guard let value else { return defaultValue }
        guard let number = Int(value), number > 0 else {
            throw CodeReferenceError.invalidPosition(value)
        }
        return number
    }

    private func optionalPositiveInteger(_ value: String?) throws -> Int? {
        guard let value else { return nil }
        guard let number = Int(value), number > 0 else {
            throw CodeReferenceError.invalidPosition(value)
        }
        return number
    }

    private func value(at index: Int, from match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
