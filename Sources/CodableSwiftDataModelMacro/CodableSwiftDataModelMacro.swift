@attached(member, names: arbitrary)
public macro CodableClass() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "CodableClassMacro")
@attached(peer, names: arbitrary)
public macro NonCodable() = #externalMacro(module: "CodableSwiftDataModelMacroMacros", type: "NonCodableMacro")
