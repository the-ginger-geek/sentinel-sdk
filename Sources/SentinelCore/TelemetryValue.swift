import Foundation

public enum TelemetryValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([TelemetryValue])
    case object([String: TelemetryValue])
    case null
}

extension TelemetryValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension TelemetryValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
}

extension TelemetryValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
}

extension TelemetryValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension TelemetryValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: TelemetryValue...) {
        self = .array(elements)
    }
}

extension TelemetryValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, TelemetryValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

public extension Dictionary where Key == String, Value == TelemetryValue {
    static let empty: [String: TelemetryValue] = [:]
}
