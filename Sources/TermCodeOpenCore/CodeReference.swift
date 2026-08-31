import Foundation

public struct CodeReference: Equatable, Sendable {
    public let fileURL: URL
    public let line: Int
    public let column: Int
    public let endLine: Int?

    public init(fileURL: URL, line: Int = 1, column: Int = 1, endLine: Int? = nil) {
        self.fileURL = fileURL.standardizedFileURL
        self.line = max(line, 1)
        self.column = max(column, 1)
        self.endLine = endLine.map { max($0, line) }
    }
}

public enum CodeReferenceError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedScheme(String?)
    case unsupportedAction(String?)
    case missingPath
    case relativePathWithoutWorkingDirectory
    case invalidPosition(String)
    case fileDoesNotExist(String)
    case pathIsNotAFile(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The code-reference URL is invalid."
        case let .unsupportedScheme(scheme):
            return "Unsupported URL scheme: \(scheme ?? "<missing>")."
        case let .unsupportedAction(action):
            return "Unsupported URL action: \(action ?? "<missing>")."
        case .missingPath:
            return "The code-reference URL has no path or file query parameter."
        case .relativePathWithoutWorkingDirectory:
            return "A relative path requires a cwd query parameter."
        case let .invalidPosition(value):
            return "Invalid line or column value: \(value)."
        case let .fileDoesNotExist(path):
            return "The referenced file does not exist: \(path)."
        case let .pathIsNotAFile(path):
            return "The referenced path is not a regular file: \(path)."
        }
    }
}
