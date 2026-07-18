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

#if canImport(CodableSwiftDataModelMacroMacros)
/// The CodableModel-gated generation (idPredicate, safe accessors) and the
/// model-contract diagnostics. Plain @CodableClass classes (no CodableModel in
/// the inheritance clause) get none of this — covered by test_CodableClass.
final class CodableModelContractTests: XCTestCase {

    func test_CodableModel_GeneratesIdPredicateAndSafeAccessors() throws {
        assertMacroExpansion(
            """
            @CodableClass
            final class Exercise: CodableModel {
                var name: String = ""
                @Relationship(deleteRule: .cascade, inverse: \\ExerciseInterval.exercise)
                var intervals: [ExerciseInterval]?
                var id: UUID = UUID()
                @NonCodable var dedupNonce: String = UUID().uuidString

                init(name: String, intervals: [ExerciseInterval]?, id: UUID) {
                    self.name = name
                    self.intervals = intervals
                    self.id = id
                }
            }
            """,
            expandedSource: """
            final class Exercise: CodableModel {
                var name: String = ""
                @Relationship(deleteRule: .cascade, inverse: \\ExerciseInterval.exercise)
                var intervals: [ExerciseInterval]?
                var id: UUID = UUID()
                @NonCodable var dedupNonce: String = UUID().uuidString

                init(name: String, intervals: [ExerciseInterval]?, id: UUID) {
                    self.name = name
                    self.intervals = intervals
                    self.id = id
                }

                @Transient @NonCodable public var prevData: Data?

                @Transient @NonCodable public var objectDidChange = ObjectDidChangePublisher()

                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case name
                    case intervals
                    case id
                }

                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let name = try container.decode(String.self, forKey: .name)
                    let intervals = try container.decodeIfPresent([ExerciseInterval].self, forKey: .intervals)
                    let id = try container.decode(UUID.self, forKey: .id)
                    self.init(name: name, intervals: intervals, id: id)
                }

                public func updateValues(from other: Exercise) {
                    self.name = SyncReconcile.value(existing: self.name, incoming: other.name)
                    self.intervals = SyncReconcile.value(existing: self.intervals, incoming: other.intervals)
                    self.id = SyncReconcile.value(existing: self.id, incoming: other.id)
                }

                public func relinkChildren(in context: ModelContext) {
                    let __relinked_name = ChildRelink.resolve(self.name, in: context)
                    let __relinked_intervals = ChildRelink.resolve(self.intervals, in: context)
                    let __relinked_id = ChildRelink.resolve(self.id, in: context)
                    self.name = ChildRelink.detached(self.name)
                    self.intervals = ChildRelink.detached(self.intervals)
                    self.id = ChildRelink.detached(self.id)
                    self.name = __relinked_name
                    self.intervals = __relinked_intervals
                    self.id = __relinked_id
                }

                public func relationshipTargets() -> [Any] {
                    var __targets: [Any] = []
                    RelationshipTargets.collect(self.name, into: &__targets)
                    RelationshipTargets.collect(self.intervals, into: &__targets)
                    RelationshipTargets.collect(self.id, into: &__targets)
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
                    if !state.contains(self.intervals)  {
                        try container.encode(self.intervals, forKey: .intervals)
                    }
                    if !state.contains(self.id)  {
                        try container.encode(self.id, forKey: .id)
                    }
                }

                public var safeIntervals: [ExerciseInterval] {
                    guard let context = modelContext else {
                        return intervals ?? []
                    }
                    let __ownID = id
                    let __descriptor = FetchDescriptor<ExerciseInterval>(predicate: #Predicate {
                            $0.exercise?.id == __ownID
                        })
                    return SafeFetch.fetch(__descriptor, in: context)
                }

                public static func idPredicate(_ id: UUID) -> Predicate<Exercise> {
                    return #Predicate<Exercise> {
                        $0.id == id
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func test_CodableModel_Diagnostics_UnmarkedToOneAndCodableDedupNonce() throws {
        assertMacroExpansion(
            """
            @CodableClass
            final class Broken: CodableModel {
                var equipment: Equipment?
                var dedupNonce: String = UUID().uuidString

                init(equipment: Equipment?) {
                    self.equipment = equipment
                }
            }
            """,
            expandedSource: """

            final class Broken: CodableModel {
                var equipment: Equipment?
                var dedupNonce: String = UUID().uuidString

                init(equipment: Equipment?) {
                    self.equipment = equipment
                }

                @Transient @NonCodable public var prevData: Data?

                @Transient @NonCodable public var objectDidChange = ObjectDidChangePublisher()

                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case equipment
                    case dedupNonce
                }

                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let equipment = try container.decodeIfPresent(Equipment.self, forKey: .equipment)
                    let dedupNonce = try container.decode(String.self, forKey: .dedupNonce)
                    self.init(equipment: equipment, dedupNonce: dedupNonce)
                }

                public func updateValues(from other: Broken) {
                    self.equipment = SyncReconcile.value(existing: self.equipment, incoming: other.equipment)
                    self.dedupNonce = SyncReconcile.value(existing: self.dedupNonce, incoming: other.dedupNonce)
                }

                public func relinkChildren(in context: ModelContext) {
                    let __relinked_equipment = ChildRelink.resolve(self.equipment, in: context)
                    let __relinked_dedupNonce = ChildRelink.resolve(self.dedupNonce, in: context)
                    self.equipment = ChildRelink.detached(self.equipment)
                    self.dedupNonce = ChildRelink.detached(self.dedupNonce)
                    self.equipment = __relinked_equipment
                    self.dedupNonce = __relinked_dedupNonce
                }

                public func relationshipTargets() -> [Any] {
                    var __targets: [Any] = []
                    RelationshipTargets.collect(self.equipment, into: &__targets)
                    RelationshipTargets.collect(self.dedupNonce, into: &__targets)
                    return __targets
                }

                public func encode(to encoder: Encoder) throws {
                    let state = EncodingState.track(self, encoder: encoder)
                    defer {
                        EncodingState.untrack(self, state: state)
                    }
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    if !state.contains(self.equipment)  {
                        try container.encode(self.equipment, forKey: .equipment)
                    }
                    if !state.contains(self.dedupNonce)  {
                        try container.encode(self.dedupNonce, forKey: .dedupNonce)
                    }
                }

                public static func idPredicate(_ id: UUID) -> Predicate<Broken> {
                    return #Predicate<Broken> {
                        $0.id == id
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'equipment: Equipment?' must declare its relationship role: @BackRef (inverse parent pointer), @ForwardRef (forward model reference), or @CodableValue (not a SwiftData model). An unmarked model-typed to-one relinks like a forward ref and can adopt a decoded parent copy as a duplicate row.",
                    line: 3, column: 5),
                DiagnosticSpec(
                    message: "'dedupNonce' must be @NonCodable: it is per-row instance identity and must never travel in payloads (a coded nonce would defeat duplicate resolution).",
                    line: 4, column: 5),
            ],
            macros: testMacros
        )
    }

    func test_CodableModel_Diagnostics_MissingDedupNonce() throws {
        assertMacroExpansion(
            """
            @CodableClass
            final class Broken: CodableModel {
                @ForwardRef var equipment: Equipment?
                @BackRef var parent: Exercise?
                @CodableValue var state: WorkoutState?
                var comment: String?

                init() {
                }
            }
            """,
            expandedSource: """

            final class Broken: CodableModel {
                @ForwardRef var equipment: Equipment?
                @BackRef var parent: Exercise?
                @CodableValue var state: WorkoutState?
                var comment: String?

                init() {
                }

                @Transient @NonCodable public var prevData: Data?

                @Transient @NonCodable public var objectDidChange = ObjectDidChangePublisher()

                public static var codingKeys: [CodingKey] {
                    return CodingKeys.allCases
                }

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case equipment
                    case parent
                    case state
                    case comment
                }

                required convenience public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let equipment = try container.decodeIfPresent(Equipment.self, forKey: .equipment)
                    let parent = try container.decodeIfPresent(Exercise.self, forKey: .parent)
                    let state = try container.decodeIfPresent(WorkoutState.self, forKey: .state)
                    let comment = try container.decodeIfPresent(String.self, forKey: .comment)
                    self.init(equipment: equipment, parent: parent, state: state, comment: comment)
                }

                public func updateValues(from other: Broken) {
                    self.equipment = SyncReconcile.value(existing: self.equipment, incoming: other.equipment)
                    self.parent = SyncReconcile.value(existing: self.parent, incoming: other.parent)
                    self.state = SyncReconcile.value(existing: self.state, incoming: other.state)
                    self.comment = SyncReconcile.value(existing: self.comment, incoming: other.comment)
                }

                public func relinkChildren(in context: ModelContext) {
                    let __relinked_equipment = ChildRelink.resolve(self.equipment, in: context)
                    let __relinked_parent = ChildRelink.resolveBackRef(self.parent, in: context)
                    let __relinked_state = ChildRelink.resolve(self.state, in: context)
                    let __relinked_comment = ChildRelink.resolve(self.comment, in: context)
                    self.equipment = ChildRelink.detached(self.equipment)
                    self.parent = ChildRelink.detached(self.parent)
                    self.state = ChildRelink.detached(self.state)
                    self.comment = ChildRelink.detached(self.comment)
                    self.equipment = __relinked_equipment
                    self.parent = __relinked_parent
                    self.state = __relinked_state
                    self.comment = __relinked_comment
                }

                public func relationshipTargets() -> [Any] {
                    var __targets: [Any] = []
                    RelationshipTargets.collect(self.equipment, into: &__targets)
                    RelationshipTargets.collect(self.parent, into: &__targets)
                    RelationshipTargets.collect(self.state, into: &__targets)
                    RelationshipTargets.collect(self.comment, into: &__targets)
                    return __targets
                }

                public func encode(to encoder: Encoder) throws {
                    let state = EncodingState.track(self, encoder: encoder)
                    defer {
                        EncodingState.untrack(self, state: state)
                    }
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    if !state.contains(self.equipment)  {
                        try container.encode(self.equipment, forKey: .equipment)
                    }
                    if !state.contains(self.parent)  {
                        try container.encode(self.parent, forKey: .parent)
                    }
                    if !state.contains(self.state)  {
                        try container.encode(self.state, forKey: .state)
                    }
                    if !state.contains(self.comment)  {
                        try container.encode(self.comment, forKey: .comment)
                    }
                }

                public static func idPredicate(_ id: UUID) -> Predicate<Broken> {
                    return #Predicate<Broken> {
                        $0.id == id
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "CodableModel class is missing '@NonCodable public var dedupNonce: String = UUID().uuidString'. It cannot be macro-generated (@Model would not see it → not persisted), so declare it by hand.",
                    line: 2, column: 13),
            ],
            macros: testMacros
        )
    }
}
#endif
