import AppKit
import Foundation
import TermCodeOpenCore

private func report(_ error: Error) {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("term-code-open: \(message)\n".utf8))
}

private enum CLIError: LocalizedError {
    case missingValue(String)
    case invalidNumber(String, String)
    case unknownOption(String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(option):
            return "Missing value for \(option)."
        case let .invalidNumber(option, value):
            return "Invalid numeric value for \(option): \(value)."
        case let .unknownOption(option):
            return "Unknown option: \(option)."
        }
    }
}

private struct StructuredReferenceArguments {
    var file: String?
    var cwd = FileManager.default.currentDirectoryPath
    var line = 1
    var column = 1
    var endLine: Int?
    var preview = false

    init(_ arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let option = arguments[index]
            if option == "--preview-file" {
                preview = true
                index += 1
                continue
            }
            guard index + 1 < arguments.count else { throw CLIError.missingValue(option) }
            let value = arguments[index + 1]
            switch option {
            case "--file": file = value
            case "--cwd": cwd = value
            case "--line": line = try Self.number(value, for: option)
            case "--column", "--col": column = try Self.number(value, for: option)
            case "--end": endLine = try Self.number(value, for: option)
            default: throw CLIError.unknownOption(option)
            }
            index += 2
        }
        guard file != nil else { throw CLIError.missingValue("--file") }
    }

    private static func number(_ value: String, for option: String) throws -> Int {
        guard let number = Int(value), number > 0 else {
            throw CLIError.invalidNumber(option, value)
        }
        return number
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let opener = ReferenceOpener()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            NSApplication.shared.terminate(nil)
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        defer { NSApplication.shared.terminate(nil) }
        guard let rawURL = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            report(CodeReferenceError.invalidURL)
            return
        }
        do {
            try opener.open(url: rawURL)
        } catch {
            report(error)
        }
    }
}

func runCLI(arguments: [String]) -> Int32 {
    let opener = ReferenceOpener()
    let parser = ReferenceParser()
    let linkBuilder = LinkBuilder()
    do {
        if arguments.contains("--file") {
            let structured = try StructuredReferenceArguments(arguments)
            if structured.preview {
                print(try opener.preview(
                    file: structured.file!,
                    cwd: structured.cwd,
                    line: structured.line,
                    column: structured.column,
                    endLine: structured.endLine
                ))
            } else {
                try opener.open(
                    file: structured.file!,
                    cwd: structured.cwd,
                    line: structured.line,
                    column: structured.column,
                    endLine: structured.endLine
                )
            }
        } else if arguments.count == 2, arguments[0] == "--preview" {
            print(try opener.preview(url: arguments[1]))
        } else if arguments.count == 2, arguments[0] == "--reference" {
            try opener.open(reference: arguments[1], cwd: FileManager.default.currentDirectoryPath)
        } else if arguments.count == 2, arguments[0] == "--preview-reference" {
            print(try opener.preview(
                reference: arguments[1],
                cwd: FileManager.default.currentDirectoryPath
            ))
        } else if arguments.count == 2, arguments[0] == "--url-reference" {
            let reference = try parser.parse(
                reference: arguments[1],
                cwd: FileManager.default.currentDirectoryPath
            )
            print(try linkBuilder.url(for: reference).absoluteString)
        } else if (2...3).contains(arguments.count), arguments[0] == "--osc8-reference" {
            let reference = try parser.parse(
                reference: arguments[1],
                cwd: FileManager.default.currentDirectoryPath
            )
            print(try linkBuilder.osc8(
                for: reference,
                label: arguments.count == 3 ? arguments[2] : nil
            ))
        } else if arguments.count == 1, arguments[0].hasPrefix("nvim://") {
            try opener.open(url: arguments[0])
        } else {
            print("""
            Usage:
              term-code-open 'nvim://open?path=/absolute/file&line=42&column=1'
              term-code-open --reference 'relative/file.py:42-57'
              term-code-open --preview URL
              term-code-open --preview-reference REFERENCE
              term-code-open --url-reference REFERENCE
              term-code-open --osc8-reference REFERENCE [LABEL]
              term-code-open --file FILE [--cwd DIR] [--line N] [--column N] [--end N]
              term-code-open --preview-file --file FILE [--cwd DIR] [--line N] [--column N]
            """)
            return arguments.isEmpty ? 0 : 64
        }
        return 0
    } catch {
        report(error)
        return 1
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    exit(runCLI(arguments: arguments))
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
