@attached(member, names: arbitrary)
public macro CodableClass() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "CodableClassMacro")
@attached(peer, names: arbitrary)
public macro NonCodable() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "NonCodableMacro")

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
