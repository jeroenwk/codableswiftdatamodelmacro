@attached(member, names: arbitrary)
public macro CodableClass() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "CodableClassMacro")
@attached(peer, names: arbitrary)
public macro NonCodable() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "NonCodableMacro")
/// Marks a relationship property as an inverse BACK-REFERENCE to its owning
/// parent (e.g. a child's `exercise` pointer). The generated `relinkChildren`
/// routes it through `ChildRelink.resolveBackRef` instead of
/// `ChildRelink.resolve`: a back-ref must resolve to the persisted parent or
/// nil — never keep the decoded copy, which would cascade-insert a duplicate
/// parent. The property is still coded (unlike `@NonCodable`).
@attached(peer, names: arbitrary)
public macro BackRef() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "BackRefMacro")

/// Assignment router for the generated `updateValues(from:)`.
///
/// The macro emits `self.x = SyncReconcile.value(existing: self.x, incoming: other.x)`
/// for every coded property. This base overload plain-assigns the incoming value —
/// correct for scalars and value types. Host modules may declare MORE SPECIFIC
/// overloads in an `extension SyncReconcile` (e.g. reconciling to-one / to-many
/// relationships of persisted models by id, updating matched objects in place);
/// Swift overload resolution at the macro-expansion site picks the most specific
/// visible candidate, so the macro itself stays type-agnostic.
public enum SyncReconcile {
    public static func value<T>(existing: T, incoming: T) -> T { incoming }
}

/// Relink router for the generated `relinkChildren(in:)`.
///
/// The macro emits, for every coded property, a three-phase body that swaps
/// freshly-decoded nested relationship children for the persisted rows of the
/// same id BEFORE the model is inserted into a context:
///
/// ```swift
/// let __relinked_x = ChildRelink.resolve(self.x, in: context)   // 1. fetch ALL first
/// self.x = ChildRelink.detached(self.x)                         // 2. detach while unmanaged
/// self.x = __relinked_x                                         // 3. attach
/// ```
///
/// The strict fetch-all → detach-all → attach ordering is load-bearing: the
/// FIRST assignment that links a managed row to a still-unmanaged decoded
/// object auto-registers it — and every decoded child still attached to it —
/// into the context via inverse maintenance, creating duplicate rows and
/// corrupting later same-pass fetches. Detaching everything first means that
/// by the time the first managed link registers the object, no orphan can
/// cascade in.
///
/// These base overloads plain-pass scalars and value types through (phases
/// collapse to self-assignment). Host modules declare MORE SPECIFIC overloads
/// in an `extension ChildRelink` for their persisted-model relationship types
/// (to-one / to-many), where `resolve` fetches the persisted row and
/// `detached` returns nil; Swift overload resolution at the macro-expansion
/// site picks the most specific visible candidate, so the macro itself stays
/// type-agnostic. `Context` is generic for the same reason (hosts constrain it
/// to their model-context type).
public enum ChildRelink {
    /// Forward relationship (the model owns or references its child).
    public static func resolve<T, Context>(_ value: T, in context: Context) -> T { value }
    /// Inverse back-reference to an owning parent — see `@BackRef`.
    public static func resolveBackRef<T, Context>(_ value: T, in context: Context) -> T { value }
    /// Phase-2 detach; hosts return nil for relationship types.
    public static func detached<T>(_ value: T) -> T { value }
}

/// Collector for the generated `relationshipTargets()`.
///
/// The macro emits `RelationshipTargets.collect(self.x, into: &__targets)` for
/// every coded property and returns the accumulated `[Any]`. This base overload
/// ignores the value — correct for scalars and value types. Host modules declare
/// MORE SPECIFIC overloads in an `extension RelationshipTargets` for their
/// persisted-model relationship types (to-one appends the value if non-nil,
/// to-many appends the elements); Swift overload resolution at the
/// macro-expansion site picks the most specific visible candidate, so the macro
/// itself stays type-agnostic.
///
/// Purpose: hosts validate before a commit that no relationship target is
/// managed by a DIFFERENT model context than the one being written to —
/// SwiftData does not check cross-context links and silently corrupts the graph.
public enum RelationshipTargets {
    public static func collect<T>(_ value: T, into targets: inout [Any]) {}
}

/// Marks a coded to-one property as a FORWARD model reference (the model owns
/// or references the target; e.g. an exercise's `equipment`). Behaviorally
/// inert — relinking already treats unmarked properties as forward refs
/// (`ChildRelink.resolve`: persisted row if one exists, else the decoded
/// incoming copy). The marker exists to satisfy `@CodableClass`'s to-one role
/// diagnostic: every coded optional to-one of non-primitive type must declare
/// whether it is `@BackRef`, `@ForwardRef`, or `@CodableValue`, so a parent
/// back-reference can never silently default to forward-ref adoption (which
/// duplicates the parent row per child).
@attached(peer, names: arbitrary)
public macro ForwardRef() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "ForwardRefMacro")

/// Marks a coded optional property as a plain Codable VALUE type (not a
/// SwiftData model; e.g. a persisted `Codable` struct). Behaviorally inert —
/// value types already pass through relinking untouched. The marker exists to
/// satisfy `@CodableClass`'s to-one role diagnostic (see `@ForwardRef`),
/// because the macro cannot distinguish a model type from a value type
/// syntactically.
@attached(peer, names: arbitrary)
public macro CodableValue() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "CodableValueMacro")

/// Fetch router for the generated `safe<Relationship>` accessors.
///
/// For every to-many relationship declaring `@Relationship(inverse: \Child.prop)`,
/// the macro emits a `safe<Name>` accessor that fetches the CURRENT child rows
/// by inverse id instead of walking the live relationship (whose held faults
/// trap when an external writer re-keyed the rows):
///
/// ```swift
/// public var safeIntervals: [ExerciseInterval] {
///     guard let context = modelContext else { return intervals ?? [] }
///     let __ownID = id
///     let __descriptor = FetchDescriptor<ExerciseInterval>(predicate: #Predicate { $0.exercise?.id == __ownID })
///     return SafeFetch.fetch(__descriptor, in: context)
/// }
/// ```
///
/// The host module must provide `SafeFetch.fetch(_:in:)` (typically
/// `do { try context.fetch(descriptor) } catch { log; return [] }`) — it is
/// NOT declared here so this package stays free of a SwiftData dependency and
/// hosts keep error logging in their own logging system.
