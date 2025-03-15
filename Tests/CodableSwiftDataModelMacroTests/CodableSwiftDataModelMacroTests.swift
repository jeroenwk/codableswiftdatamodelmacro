import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(CodableSwiftDataModelMacroMacros)
import CodableSwiftDataModelMacroMacros

let testMacros: [String: Macro.Type] = [
    "CodableClass": CodableClassMacro.self,
]
#endif

final class CodableSwiftDataModelMacroTests: XCTestCase {
    func test_CodableClass() throws {
        #if canImport(CodableSwiftDataModelMacroMacros)
        assertMacroExpansion(
            """
            @CodableClass
            class MyCodableClass {
                let constant = 33
                public var name: String = ""
                var price: Float = 1.0
                var foo: Foo?
                var bars: [Bar]?
                var dynprop: Int {
                    12
                }
                var dynprop2: Int {
                    get { 42 }
                    set { print(newValue) }
                }
                static let myStatic: Int = 3
                var setprop: Float {
                    didSet {
                        hello()
                    }
                }
                @NonCodable var number: Int

                init(name: String, price: Float, foo: Foo, bars: [Bar]?, setprop: Float) {
                    self.name = name
                    self.price = price
                    self.foo = foo
                    self.bars = bars
                    self.setprop = setprop
                }
            }
            """,
            expandedSource: """
            class MyCodableClass {
                let constant = 33
                public var name: String = ""
                var price: Float = 1.0
                var foo: Foo?
                var bars: [Bar]?
                var dynprop: Int {
                    12
                }
                var dynprop2: Int {
                    get { 42 }
                    set { print(newValue) }
                }
                static let myStatic: Int = 3
                var setprop: Float {
                    didSet {
                        hello()
                    }
                }
                @NonCodable var number: Int

                init(name: String, price: Float, foo: Foo, bars: [Bar]?, setprop: Float) {
                    self.name = name
                    self.price = price
                    self.foo = foo
                    self.bars = bars
                    self.setprop = setprop
                }
            
                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case name
                    case price
                    case foo
                    case bars
                    case setprop
                }
            
                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let name = try container.decode(String.self, forKey: .name)
                    let price = try container.decode(Float.self, forKey: .price)
                    let foo = try container.decodeIfPresent(Foo.self, forKey: .foo)
                    let bars = try container.decodeIfPresent([Bar].self, forKey: .bars)
                    let setprop = try container.decode(Float.self, forKey: .setprop)
                    self.init(name: name, price: price, foo: foo, bars: bars, setprop: setprop)
                }

                func decode(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decode(String.self, forKey: .name)
                    self.price = try container.decode(Float.self, forKey: .price)
                    self.foo = try container.decodeIfPresent(Foo.self, forKey: .foo)
                    self.bars = try container.decodeIfPresent([Bar].self, forKey: .bars)
                    self.setprop = try container.decode(Float.self, forKey: .setprop)
                }

                public func encode(to encoder: Encoder) throws {
                    let state = EncodingState.track(self, encoder: encoder)
                    defer {
                        EncodingState.untrack(self, state: state)
                    }
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    if !state.contains(self.name)  {
                        try container.encode(self.name, forKey: .name)
                    }
                    if !state.contains(self.price)  {
                        try container.encode(self.price, forKey: .price)
                    }
                    if !state.contains(self.foo)  {
                        try container.encode(self.foo, forKey: .foo)
                    }
                    if !state.contains(self.bars)  {
                        try container.encode(self.bars, forKey: .bars)
                    }
                    if !state.contains(self.setprop)  {
                        try container.encode(self.setprop, forKey: .setprop)
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
