import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(CodableTestMacroMacros)
import CodableTestMacroMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
    "CodableClass": CodableClassMacro.self,
]
#endif

final class CodableTestMacroTests: XCTestCase {    
    func test_CodableClass() throws {
        #if canImport(CodableTestMacroMacros)
        assertMacroExpansion(
            """
            @CodableClass
            class MyCodableClass {
                var name: String = ""
                var price: Float = 1.0
                var foo: Foo?
                var bars: [Bar]?

                init(name: String, price: Float, foo: Foo, bars: [Bar]?) {
                    self.name = name
                    self.price = price
                    self.foo = foo
                    self.bars = bars
                }
            }
            """,
            expandedSource: """
            class MyCodableClass {
                var name: String = ""
                var price: Float = 1.0
                var foo: Foo?
                var bars: [Bar]?

                init(name: String, price: Float, foo: Foo, bars: [Bar]?) {
                    self.name = name
                    self.price = price
                    self.foo = foo
                    self.bars = bars
                }
            
                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case name
                    case price
                    case foo
                    case bars
                }
            
                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let name = try container.decode(String.self, forKey: .name)
                    let price = try container.decode(Float.self, forKey: .price)
                    let foo = try container.decode(Foo?.self, forKey: .foo)
                    let bars = try container.decode([Bar]?.self, forKey: .bars)
                    self.init(name: name, price: price, foo: foo, bars: bars)
                }

                func decode(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.name = try container.decode(String.self, forKey: .name)
                    self.price = try container.decode(Float.self, forKey: .price)
                    self.foo = try container.decode(Foo?.self, forKey: .foo)
                    self.bars = try container.decode([Bar]?.self, forKey: .bars)
                }

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(self.name, forKey: .name)
                    try container.encode(self.price, forKey: .price)
                    try container.encode(self.foo, forKey: .foo)
                    try container.encode(self.bars, forKey: .bars)
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
