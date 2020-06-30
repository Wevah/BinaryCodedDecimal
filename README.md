# BinaryCodedDecimal

Convert from integers to and from binary-coded decimal in Swift. 

```swift
public extension FixedWidthInteger {

	init<T>(binaryCodedDecimal bcd: T) throws where T: DataProtocol
	
	func binaryCodedDecimal(byteCount: Int = 0, includeSign: Bool = false) throws -> [UInt8]

}
```
