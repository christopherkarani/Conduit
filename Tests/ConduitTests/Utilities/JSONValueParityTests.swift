import XCTest
@testable import Conduit

final class JSONValueParityTests: XCTestCase {

    func testLiteralsAndAccessors() throws {
        let nullValue: JSONValue = nil
        XCTAssertEqual(nullValue, .null)

        let boolValue: JSONValue = true
        XCTAssertEqual(boolValue.boolValue, true)
        XCTAssertNil(boolValue.stringValue)

        let intValue: JSONValue = 42
        XCTAssertEqual(intValue.intValue, 42)
        XCTAssertEqual(intValue.doubleValue, 42.0)

        let doubleValue: JSONValue = 3.5
        XCTAssertEqual(doubleValue.doubleValue, 3.5)
        XCTAssertNil(doubleValue.intValue)

        let integralDouble: JSONValue = 10.0
        XCTAssertEqual(integralDouble.intValue, 10)

        let stringValue: JSONValue = "hello"
        XCTAssertEqual(stringValue.stringValue, "hello")

        let arrayValue: JSONValue = [1, 2, 3]
        XCTAssertEqual(arrayValue.arrayValue, [.int(1), .int(2), .int(3)])

        let objectValue: JSONValue = ["key": "value"]
        XCTAssertEqual(objectValue.objectValue?["key"]?.stringValue, "value")
    }
}

