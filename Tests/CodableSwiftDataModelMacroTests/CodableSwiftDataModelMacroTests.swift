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
                @BackRef var parent: Foo?

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
                @BackRef var parent: Foo?

                init(name: String, price: Float, foo: Foo, bars: [Bar]?, setprop: Float) {
                    self.name = name
                    self.price = price
                    self.foo = foo
                    self.bars = bars
                    self.setprop = setprop
                }

                @Transient @NonCodable public var prevData: Data?
            
                @Transient @NonCodable public var objectDidChange = ObjectDidChangePublisher()
            
                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case name
                    case price
                    case foo
                    case bars
                    case setprop
                    case parent
                }

                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let name = try container.decode(String.self, forKey: .name)
                    let price = try container.decode(Float.self, forKey: .price)
                    let foo = try container.decodeIfPresent(Foo.self, forKey: .foo)
                    let bars = try container.decodeIfPresent([Bar].self, forKey: .bars)
                    let setprop = try container.decode(Float.self, forKey: .setprop)
                    let parent = try container.decodeIfPresent(Foo.self, forKey: .parent)
                    self.init(name: name, price: price, foo: foo, bars: bars, setprop: setprop, parent: parent)
                }

                public func updateValues(from other: MyCodableClass) {
                    self.name = SyncReconcile.value(existing: self.name, incoming: other.name)
                    self.price = SyncReconcile.value(existing: self.price, incoming: other.price)
                    self.foo = SyncReconcile.value(existing: self.foo, incoming: other.foo)
                    self.bars = SyncReconcile.value(existing: self.bars, incoming: other.bars)
                    self.setprop = SyncReconcile.value(existing: self.setprop, incoming: other.setprop)
                    self.parent = SyncReconcile.value(existing: self.parent, incoming: other.parent)
                }

                public func relinkChildren(in context: ModelContext) {
                    let __relinked_name = ChildRelink.resolve(self.name, in: context)
                    let __relinked_price = ChildRelink.resolve(self.price, in: context)
                    let __relinked_foo = ChildRelink.resolve(self.foo, in: context)
                    let __relinked_bars = ChildRelink.resolve(self.bars, in: context)
                    let __relinked_setprop = ChildRelink.resolve(self.setprop, in: context)
                    let __relinked_parent = ChildRelink.resolveBackRef(self.parent, in: context)
                    self.name = ChildRelink.detached(self.name)
                    self.price = ChildRelink.detached(self.price)
                    self.foo = ChildRelink.detached(self.foo)
                    self.bars = ChildRelink.detached(self.bars)
                    self.setprop = ChildRelink.detached(self.setprop)
                    self.parent = ChildRelink.detached(self.parent)
                    self.name = __relinked_name
                    self.price = __relinked_price
                    self.foo = __relinked_foo
                    self.bars = __relinked_bars
                    self.setprop = __relinked_setprop
                    self.parent = __relinked_parent
                }

                public func relationshipTargets() -> [Any] {
                    var __targets: [Any] = []
                    RelationshipTargets.collect(self.name, into: &__targets)
                    RelationshipTargets.collect(self.price, into: &__targets)
                    RelationshipTargets.collect(self.foo, into: &__targets)
                    RelationshipTargets.collect(self.bars, into: &__targets)
                    RelationshipTargets.collect(self.setprop, into: &__targets)
                    RelationshipTargets.collect(self.parent, into: &__targets)
                    return __targets
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
                    if !state.contains(self.parent)  {
                        try container.encode(self.parent, forKey: .parent)
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
