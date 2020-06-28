import XCTest
@testable import BinaryCodedDecimal

final class BinaryCodedDecimalTests: XCTestCase {
	func testFromBCD() {
		XCTAssertEqual(try Int(binaryCodedDecimal: [0x22]), 22)
	}

	func testTwoByteUInt8() {
		XCTAssertEqual(try UInt8(binaryCodedDecimal: [0x02, 0x00]), 200)
	}

	func test10ByteUInt64() {
		XCTAssertEqual(try UInt64(binaryCodedDecimal: [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), 10_000_000_000_000_000_000)
	}

	func testToBCD() {
		XCTAssertEqual(try 1234.binaryCodedDecimal(), [0x12, 0x34])
		XCTAssertEqual(try 1234.binaryCodedDecimal(byteCount: 3), [0x00, 0x12, 0x34])
	}

	func testInvalidBDCDigit() {
		do {
			_ = try UInt16(binaryCodedDecimal: [0x99, 0x1a])
		} catch BCDError.bcdDigitTooBig {

		} catch {
			XCTFail()
		}
	}

	func testByteCountTooSmall() {
		do {
			_ = try 1234.binaryCodedDecimal(byteCount: 1)
		} catch BCDError.notRepresentableInByteCount {

		} catch {
			XCTFail()
		}
	}

	func testNegative() {
		do {
			_ = try (-1).binaryCodedDecimal()
		} catch BCDError.negative {

		} catch {
			XCTFail()
		}
	}

	func testTooBig() {
		do {
			_ = try UInt8(binaryCodedDecimal: [0x03, 0x00])
		} catch BCDError.bcdTooBigForType {

		} catch {
			XCTFail()
		}
	}

}
