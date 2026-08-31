import XCTest
@testable import TermCodeOpenCore

final class ReferenceParserTests: XCTestCase {
    private let parser = ReferenceParser()

    func testParsesAbsoluteNvimURL() throws {
        let reference = try parser.parse(
            url: "nvim://open?path=%2Ftmp%2Fexample.py&line=42&column=7&end=50",
            requireExistingFile: false
        )
        XCTAssertEqual(reference.fileURL.path, "/tmp/example.py")
        XCTAssertEqual(reference.line, 42)
        XCTAssertEqual(reference.column, 7)
        XCTAssertEqual(reference.endLine, 50)
    }

    func testResolvesRelativePathAgainstCWD() throws {
        let reference = try parser.parse(
            url: "nvim://open?path=Sources%2Fmain.swift&cwd=%2Ftmp%2Fproject&line=9",
            requireExistingFile: false
        )
        XCTAssertEqual(reference.fileURL.path, "/tmp/project/Sources/main.swift")
        XCTAssertEqual(reference.line, 9)
    }

    func testParsesPathLineRange() throws {
        let reference = try parser.parse(
            reference: "fulfilio/accounting/invoice.py:5077-5091",
            cwd: "/tmp/work",
            requireExistingFile: false
        )
        XCTAssertEqual(reference.fileURL.path, "/tmp/work/fulfilio/accounting/invoice.py")
        XCTAssertEqual(reference.line, 5077)
        XCTAssertEqual(reference.endLine, 5091)
        XCTAssertEqual(reference.column, 1)
    }

    func testParsesPathLineAndColumn() throws {
        let reference = try parser.parse(
            reference: "Sources/App.swift:12:4",
            cwd: "/tmp/work",
            requireExistingFile: false
        )
        XCTAssertEqual(reference.line, 12)
        XCTAssertEqual(reference.column, 4)
    }

    func testRejectsRelativeURLWithoutCWD() {
        XCTAssertThrowsError(
            try parser.parse(
                url: "nvim://open?path=Sources%2Fmain.swift&line=9",
                requireExistingFile: false
            )
        ) { error in
            XCTAssertEqual(error as? CodeReferenceError, .relativePathWithoutWorkingDirectory)
        }
    }

    func testRejectsUnsupportedRoute() {
        XCTAssertThrowsError(
            try parser.parse(
                url: "nvim://run?path=%2Ftmp%2Fexample.py",
                requireExistingFile: false
            )
        ) { error in
            XCTAssertEqual(error as? CodeReferenceError, .unsupportedAction("run"))
        }
    }
}
