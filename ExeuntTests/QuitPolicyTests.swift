import XCTest
@testable import Exeunt

final class QuitPolicyTests: XCTestCase {
    private let textEdit = "com.apple.TextEdit"

    func testQuitsWhenLastWindowCloses() {
        XCTAssertTrue(QuitPolicy().shouldQuit(bundleID: textEdit, windowsBefore: 1, windowsAfter: 0))
        XCTAssertTrue(QuitPolicy().shouldQuit(bundleID: textEdit, windowsBefore: 3, windowsAfter: 0))
    }

    func testKeepsAppWithWindowsLeftOrNoneToStartWith() {
        XCTAssertFalse(QuitPolicy().shouldQuit(bundleID: textEdit, windowsBefore: 2, windowsAfter: 1))
        XCTAssertFalse(QuitPolicy().shouldQuit(bundleID: textEdit, windowsBefore: 0, windowsAfter: 0))
        XCTAssertFalse(QuitPolicy().shouldQuit(bundleID: textEdit, windowsBefore: 1, windowsAfter: nil))
    }

    func testNeverQuitsFinderOrItself() {
        let policy = QuitPolicy(mode: .onlyListed, list: QuitPolicy.neverQuit)
        for id in QuitPolicy.neverQuit {
            XCTAssertFalse(QuitPolicy().shouldQuit(bundleID: id, windowsBefore: 1, windowsAfter: 0))
            XCTAssertFalse(policy.shouldQuit(bundleID: id, windowsBefore: 1, windowsAfter: 0))
        }
        XCTAssertFalse(QuitPolicy().shouldQuit(bundleID: nil, windowsBefore: 1, windowsAfter: 0))
    }

    func testExclusionList() {
        let policy = QuitPolicy(mode: .allExcept, list: [textEdit])
        XCTAssertFalse(policy.shouldQuit(bundleID: textEdit, windowsBefore: 1, windowsAfter: 0))
        XCTAssertTrue(policy.shouldQuit(bundleID: "com.apple.iCal", windowsBefore: 1, windowsAfter: 0))
    }

    func testOnlyListedMode() {
        let policy = QuitPolicy(mode: .onlyListed, list: [textEdit])
        XCTAssertTrue(policy.shouldQuit(bundleID: textEdit, windowsBefore: 1, windowsAfter: 0))
        XCTAssertFalse(policy.shouldQuit(bundleID: "com.apple.iCal", windowsBefore: 1, windowsAfter: 0))
    }

    func testDisabledNeverQuits() {
        let policy = QuitPolicy(enabled: false)
        XCTAssertFalse(policy.shouldQuit(bundleID: textEdit, windowsBefore: 1, windowsAfter: 0))
    }
}
