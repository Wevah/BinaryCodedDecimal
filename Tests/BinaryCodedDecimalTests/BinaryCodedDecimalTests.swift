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
		XCTAssertEqual(try UInt64(binaryCodedDecimal: [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]), 100_000_000_000_000_000)
	}

	func testToBCD() {
		XCTAssertEqual(try 1234.binaryCodedDecimal(), [0x12, 0x34])
		XCTAssertEqual(try 1234.binaryCodedDecimal(byteCount: 3), [0x00, 0x12, 0x34])
	}

	func testSignedFromBCD() {
		XCTAssertEqual(try Int(binaryCodedDecimal: [0x01, 0x23, 0x4c]), 1234)
		XCTAssertEqual(try Int(binaryCodedDecimal: [0x12, 0x34, 0x5c]), 12345)

		XCTAssertEqual(try Int(binaryCodedDecimal: [0x01, 0x23, 0x4d]), -1234)
		XCTAssertEqual(try Int(binaryCodedDecimal: [0x12, 0x34, 0x5d]), -12345)

		XCTAssertEqual(try Int(binaryCodedDecimal: [0x01, 0x23, 0x4f]), 1234)
		XCTAssertEqual(try Int(binaryCodedDecimal: [0x12, 0x34, 0x5f]), 12345)

		XCTAssertThrowsError(try UInt(binaryCodedDecimal: [0x00, 0x12, 0x34, 0x5d]))
	}

	func testSignedToBCD() {
		XCTAssertEqual(try 1234.binaryCodedDecimal(includeSign: true), [0x01, 0x23, 0x4c])
		XCTAssertEqual(try 12345.binaryCodedDecimal(includeSign: true), [0x12, 0x34, 0x5c])

		XCTAssertEqual(try (-1234).binaryCodedDecimal(includeSign: true), [0x01, 0x23, 0x4d])
		XCTAssertEqual(try (-12345).binaryCodedDecimal(includeSign: true), [0x12, 0x34, 0x5d])

		XCTAssertEqual(try UInt(1234).binaryCodedDecimal(includeSign: true), [0x01, 0x23, 0x4f])
		XCTAssertEqual(try UInt(12345).binaryCodedDecimal(includeSign: true), [0x12, 0x34, 0x5f])

		XCTAssertEqual(try UInt(12345).binaryCodedDecimal(byteCount: 4, includeSign: true), [0x00, 0x12, 0x34, 0x5f])
	}

	func testEmptyBCD() {
		XCTAssertThrowsError(try Int(binaryCodedDecimal: []))
	}

	func testInvalidBDCDigit() {
		do {
			_ = try UInt16(binaryCodedDecimal: [0x99, 0x1a])
		} catch BCDError.bcdDigitTooBig {
			// success
		} catch {
			XCTFail()
		}
	}

	func testByteCountTooSmall() {
		do {
			_ = try 1234.binaryCodedDecimal(byteCount: 1)
		} catch BCDError.notRepresentableInByteCount {
			// success
		} catch {
			XCTFail()
		}
	}

	func testNegative() {
		do {
			_ = try (-1).binaryCodedDecimal()
		} catch BCDError.negative {
			// success
		} catch {
			XCTFail()
		}
	}

	func testTooBig() {
		do {
			_ = try UInt8(binaryCodedDecimal: [0x03, 0x00])
		} catch BCDError.bcdTooBigForType {
			// success
		} catch {
			XCTFail()
		}
	}

}
