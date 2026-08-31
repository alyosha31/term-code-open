import AppKit
import Foundation
import TermCodeOpenCore

private func report(_ error: Error) {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("term-code-open: \(message)\n".utf8))
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
        if arguments.count == 2, arguments[0] == "--preview" {
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
