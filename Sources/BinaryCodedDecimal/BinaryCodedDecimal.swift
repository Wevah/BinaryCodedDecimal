import Foundation

extension Array where Element: BinaryInteger {

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

/// The sign specified in a binary-coded decimal representation.
///
/// See: [https://en.wikipedia.org/wiki/Binary-coded_decimal#Packed_BCD](https://en.wikipedia.org/wiki/Binary-coded_decimal#Packed_BCD)
enum BCDSign: UInt8 {

	case unsigned = 0xf
	case positive = 0xc
	case negative = 0xd
	case none

	init(_ value: UInt8?) {
		guard let value = value else {
			self = .none;
			return
		}

		switch value & 0xf {
			case 0xa, 0xc, 0xe:
				self = .positive
			case 0xb, 0xd:
				self = .negative
			case 0xf:
				self = .unsigned
			default:
				self = .none
		}
	}

}

extension DataProtocol {

	var bcdSign: BCDSign {
		return BCDSign(self.last)
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
	case integerNegative(AnyInteger)
	case bcdNegative(Any.Type)
	case bcdOutOfRangeForType(Any.Type)
	case bcdEmpty

	public var debugDescription: String {
		switch self {
			case let .bcdDigitTooBig(bcd):
				return "A hex digit in \(bcd.hexadecimalDescription(uppercase: true)) is larger than 9."
			case let .notRepresentableInByteCount(int, count: count, actualCount: actualCount):
				return "\(int) cannot be represented as BCD in \(count) byte(s) (requires at least \(actualCount) bytes)."
			case let .integerNegative(int):
				return "\(int) is negative."
			case let .bcdNegative(type):
				return "BCD represents a negative number, but \(type) is an unsigned type."
			case let .bcdOutOfRangeForType(type):
				return "BCD representation is too large to fit into \(type)."
			case .bcdEmpty:
				return "BCD representation has zero length."
		}
	}

}

public extension FixedWidthInteger {

	/// Create an integer from a (packed, big-endian) binary-coded-decimal representation
	///
	/// Example:
	/// ```
	/// let int = Int(binaryCodedDecimal: [0x16, 0x04])
	/// // int is 1604
	/// ```
	///
	/// If the low 4 bits of the last byte are in the range `0xa`-`0xf`, they are interpreted as
	/// indicating the sign of the number:
	///
	/// - `0xa`, `0xc`, `0xe`: Positive
	/// - `0xb`, `0xd`: Negative
	/// - `0xf`: Unsigned (positive)
	/// - Parameter bcd: The binary-coded-decimal representation.
	/// - Throws:
	///   - `BCDError.bcdDigitTooBig` if any nibble of `bcd` is greater than 9.
	///   - `BCDError.bcdTooBigForType` if the unencoded form of `bcd` can't fit into `Self`.
	init<T>(binaryCodedDecimal bcd: T) throws where T: DataProtocol {
		guard !bcd.isEmpty else { throw BCDError.bcdEmpty }
		
		// 9 * 2 is the maximum digits of an Int64.
		// UInt64 could be used here for unsigned types, but that would complexify the code.
		guard bcd.count <= 10 else { throw BCDError.bcdOutOfRangeForType(Self.self) }

		let sign = bcd.bcdSign

		var result: Int64 = 0
		var multiplier: Int64 = 1

		guard sign != .negative || Self.isSigned else {
			throw BCDError.bcdNegative(Self.self)
		}

		let remaining: T.SubSequence

		if sign != .none {
			let byte = bcd.last!

			result += Int64(byte >> 4)

			multiplier *= 10

			remaining = bcd.dropLast()
		} else {
			remaining = bcd[...]
		}

		for byte in remaining.reversed() {
			result += Int64(byte & 0xf) * multiplier

			guard result < multiplier * 10 else { throw BCDError.bcdDigitTooBig([UInt8](bcd)) }

			result += Int64(byte >> 4) * multiplier * 10

			let multOverflow = multiplier.multipliedReportingOverflow(by: 100)

			guard !multOverflow.overflow else { break }

			multiplier = multOverflow.partialValue

			guard result < multiplier else { throw BCDError.bcdDigitTooBig([UInt8](bcd)) }
		}

		guard result <= Self.max && result >= Self.min else { throw BCDError.bcdOutOfRangeForType(Self.self) }

		self = Self(sign == .negative ? -result : result)
	}

	/// Create a (packed, big-endian) binary-coded-decimal representation of an integer.
	///
	/// Example:
	/// ```
	/// let bcd = 1604.binaryCodedDecimal()
	/// // bcd is [0x16, 0x04]
	/// ```
	/// - Parameters:
	///   - byteCount: The byte count of the final representation.
	///   	If `0`, there is no limit or padding.
	///   - includeSign: If true, store the sign in the low 4 bits of the result:
	///
	///     `0xc` if `self` is negative, `0xd` if `self` is positive and signed, or `0xf` if `self` is unsigned.
	/// - Throws:
	///   - `BCDError.negative` if `self` is negative.
	///   - `BCDError.notRepresentableInByteCount` if `self` would require more than `byteCount` bytes.
	/// - Returns: A (big-endian) binary-coded-decimal representation of `self`, padded to `byteCount` bytes.
	func binaryCodedDecimal(byteCount: Int = 0, includeSign: Bool = false) throws -> [UInt8] {
		guard self >= 0 || includeSign else { throw BCDError.integerNegative(AnyInteger(self)) }

		var copy = self.magnitude

		var bcd = [UInt8]()

		if includeSign {
			var byte: UInt8 = Self.isSigned ? (self < 0 ? BCDSign.negative.rawValue : BCDSign.positive.rawValue) : BCDSign.unsigned.rawValue

			while copy != 0 {
				byte |= UInt8(copy % 10) << 4
				copy /= 10
				bcd.insert(byte, at: 0)

				byte = UInt8(copy % 10)
				copy /= 10
			}

			if byte != 0 {
				bcd.insert(byte, at: 0)
			}
		} else {
			while copy != 0 {
				var byte: UInt8 = UInt8(copy % 10)
				copy /= 10
				byte |= UInt8(copy % 10) << 4
				copy /= 10
				bcd.insert(byte, at: 0)
			}
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
