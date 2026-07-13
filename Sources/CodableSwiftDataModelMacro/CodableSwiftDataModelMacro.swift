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
