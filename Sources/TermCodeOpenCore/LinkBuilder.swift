import Foundation

public enum LinkBuilderError: LocalizedError {
    case couldNotBuildURL

    public var errorDescription: String? {
        "Could not build an nvim:// URL for the code reference."
    }
}

public struct LinkBuilder: Sendable {
    public init() {}

    public func url(for reference: CodeReference) throws -> URL {
        var components = URLComponents()
        components.scheme = "nvim"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "path", value: reference.fileURL.path),
            URLQueryItem(name: "line", value: String(reference.line)),
            URLQueryItem(name: "column", value: String(reference.column)),
        ]
        if let endLine = reference.endLine {
            components.queryItems?.append(URLQueryItem(name: "end", value: String(endLine)))
        }
        guard let url = components.url else { throw LinkBuilderError.couldNotBuildURL }
        return url
    }

    public func osc8(for reference: CodeReference, label: String? = nil) throws -> String {
        let target = try url(for: reference).absoluteString
        let visibleLabel = label ?? displayLabel(for: reference)
        return "\u{001B}]8;;\(target)\u{001B}\\\(visibleLabel)\u{001B}]8;;\u{001B}\\"
    }

    private func displayLabel(for reference: CodeReference) -> String {
        var result = "\(reference.fileURL.path):\(reference.line)"
        if let endLine = reference.endLine {
            result += "-\(endLine)"
        } else if reference.column > 1 {
            result += ":\(reference.column)"
        }
        return result
    }
}
