import Foundation

public extension Array where Element: BinaryInteger {

	/// A hexadecimal representation of an array of integers.
	///
	/// Example:
	///
	/// ```
	/// let hexed = [100, 255].hexadecimalDescription()
	/// // hexed is "[0x64, 0xff]"
	/// ```
	/// - Parameter uppercase: Whether hexadecimal digits A-F should be uppercased.
	/// - Returns: A string describing the array with the elements displayed as hexadecimal.
	func hexadecimalDescription(uppercase: Bool = false) -> String {
		let mapped = self.map {
			return "0x\(String($0, radix: 16, uppercase: uppercase))"
		}

		return "[\(mapped.joined(separator: ", "))]"
	}

}

/// A type-erased binary integer.
public struct AnyInteger: CustomStringConvertible {

	var base: Any

	init<T>(_ integer: T) where T: BinaryInteger {
		base = integer
	}

	public var description: String { "\(base)" }

}

public enum BCDError: Error, CustomDebugStringConvertible {

	case bcdDigitTooBig([UInt8])
	case notRepresentableInByteCount(AnyInteger, count: Int, actualCount: Int)
	case negative(AnyInteger)
	case bcdTooBigForType(Any.Type)

	public var debugDescription: String {
		switch self {
			case let .bcdDigitTooBig(bcd):
				return "A hex digit in \(bcd.hexadecimalDescription(uppercase: true)) is larger than 9."
			case let .notRepresentableInByteCount(int, count: count, actualCount: actualCount):
				return "\(int) cannot be represented as BCD in \(count) byte(s) (requires at least \(actualCount) bytes)."
			case let .negative(int):
				return "\(int) is negative."
			case let .bcdTooBigForType(type):
				return "BCD representation is too large to fit into \(type)."
		}
	}

}


public extension FixedWidthInteger {

	/// Create an integer from a (big-endian) binary-coded-decimal representation
	///
	/// Example:
	/// ```
	/// let int = Int(binaryCodedDecimal: [0x16, 0x04])
	/// // int is 1604
	/// ```
	/// - Parameter bcd: The binary-coded-decimal representation.
	/// - Throws:
	///   - `BCDError.bcdDigitTooBig` if any nibble of `bcd` is greater than 9.
	///   - `BCDError.bcdTooBigForType` if the unencoded form of `bcd` can't fit into `Self`.
	init<T>(binaryCodedDecimal bcd: T) throws where T: DataProtocol {
		// 10 * 2 is the maximum digits of a UInt64; anything larger will never fit into an integer type.
		guard bcd.count <= 10 else { throw BCDError.bcdTooBigForType(Self.self) }

		var result: UInt64 = 0
		var multiplier: UInt64 = 1

		for byte in bcd.reversed() {
			result += UInt64(byte & 0xf) * multiplier

			guard result < multiplier * 10 else { throw BCDError.bcdDigitTooBig([UInt8](bcd)) }

			result += UInt64(byte >> 4) * multiplier * 10

			let multOverflow = multiplier.multipliedReportingOverflow(by: 100)

			guard !multOverflow.overflow else { break }

			multiplier = multOverflow.partialValue

			guard result < multiplier else { throw BCDError.bcdDigitTooBig([UInt8](bcd)) }
		}

		guard result <= Self.max else { throw BCDError.bcdTooBigForType(Self.self) }

		self = Self(result)
	}

	/// Create a binary-coded-decimal representation of an integer.
	///
	/// Example:
	/// ```
	/// let bcd = 1604.binaryCodedDecimal()
	/// // bcd is [0x16, 0x04]
	/// ```
	/// - Parameter byteCount: The byte count of the final representation.
	///   If `0`, there is no limit or padding.
	/// - Throws:
	///   - `BCDError.negative` if `self` is negative.
	///   - `BCDError.notRepresentableInByteCount` if `self` would require more than `byteCount` bytes.
	/// - Returns: A (big-endian) binary-coded-decimal representation of `self`, padded to `byteCount` bytes.
	func binaryCodedDecimal(byteCount: Int = 0) throws -> [UInt8] {
		guard self >= 0 else { throw BCDError.negative(AnyInteger(self)) }

		var copy = self

		var bcd = [UInt8]()

		while copy != 0 {
			var byte: UInt8 = UInt8(copy % 10)
			copy /= 10
			byte |= UInt8(copy % 10) << 4
			copy /= 10
			bcd.insert(byte, at: 0)
		}

		if byteCount > 0 {
			guard bcd.count <= byteCount else {
				throw BCDError.notRepresentableInByteCount(AnyInteger(self), count: byteCount, actualCount: bcd.count)
			}

			if byteCount > bcd.count {
				for _ in bcd.count..<byteCount {
					bcd.insert(0x0, at: 0)
				}
			}
		}

		return bcd
	}
}
