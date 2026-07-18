import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Diagnostic emitted by `CodableClassMacro` for model-contract violations
/// (only on classes whose inheritance clause names `CodableModel`).
struct CodableClassDiagnostic: DiagnosticMessage {
    let message: String
    let id: String
    var diagnosticID: MessageID { MessageID(domain: "CodableSwiftDataModelMacro", id: id) }
    var severity: DiagnosticSeverity { .error }
}

public struct CodableClassMacro: MemberMacro {
    
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
                                 in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return []
        }
        
        let properties = classDecl.memberBlock.members.compactMap { member in
            member.decl.as(VariableDeclSyntax.self)
        }
        
        let codingKeys = properties.map { property in
            guard let binding = property.bindings.first else { return "" }
            
            // skip non var
            if property.bindingSpecifier.text != "var" {
                return nil
            }
            // skip properties with @NonCodable
            for attribute in property.attributes {
                if let attribute = attribute.as(AttributeSyntax.self) {
                    if let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self) {
                        if attributeName.name.text == "NonCodable" {
                            return nil
                        }
                    }
                }
            }
            // skip static properties
            for modifier in property.modifiers {
                if modifier.name.text == "static" {
                    return nil
                }
            }
            if let accessors = binding.accessorBlock?.accessors {
                if accessors.as(CodeBlockItemListSyntax.self) != nil {
                    return nil
                }
                // skip computed properties
                if let accessors = accessors.as(AccessorDeclListSyntax.self) {
                    for accessor in accessors {
                        if accessor.accessorSpecifier.text == "get" {
                            return nil
                        }
                    }
                }
            }
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
            return "\(identifier)"
        }.compactMap { $0 }
        
        let prevDataProperty = try VariableDeclSyntax("@Transient @NonCodable public var prevData: Data?")
        let objectDidChangeProperty = try VariableDeclSyntax("@Transient @NonCodable public var objectDidChange = ObjectDidChangePublisher()")
        
        // Add static codingKeys property
        let codingKeysProperty = try VariableDeclSyntax("public static var codingKeys: [CodingKey]") {
            CodeBlockItemListSyntax {
                CodeBlockItemSyntax("return CodingKeys.allCases")
            }
        }
        
        // Generate CodingKeys enum
        let codingKeysEnum = try EnumDeclSyntax("enum CodingKeys: String, CodingKey, CaseIterable") {
            for key in codingKeys {
                try EnumCaseDeclSyntax("case \(raw: key)")
            }
        }
        
        // Generate init(from decoder:)
        let initFromDecoder = try InitializerDeclSyntax("required convenience public init(from decoder: Decoder) throws") {
            CodeBlockItemListSyntax {
                //CodeBlockItemSyntax("let state = DecodingState.initialize(decoder: decoder, modelTypeString: String(describing: Self.self))")
                CodeBlockItemSyntax("let container = try decoder.container(keyedBy: CodingKeys.self)")
                for key in codingKeys {
                    let typeInfo = type(for: key, in: properties)
                    if typeInfo.1 {
                        if typeInfo.2 {
                            CodeBlockItemSyntax("let \(raw: key) = try container.decodeIfPresent(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                            //CodeBlockItemSyntax("\(raw: key)?.removeAll { state.contains($0) && state.isInversCollection($0) }")
                        } else {
                            CodeBlockItemSyntax("let \(raw: key) = try container.decodeIfPresent(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                        }
                    } else {
                        if typeInfo.2 {
                            CodeBlockItemSyntax("let \(raw: key) = try container.decode(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                            //CodeBlockItemSyntax("\(raw: key).removeAll { state.contains($0) && state.isInversCollection($0) }")
                        } else {
                            CodeBlockItemSyntax("let \(raw: key) = try container.decode(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                        }
                    }
                }
                let initArgs = codingKeys.map { "\($0): \($0)" }.joined(separator: ", ")
                CodeBlockItemSyntax("self.init(\(raw: initArgs))")
                //CodeBlockItemSyntax("state.track(self)")
            }
        }
        
        // Generate updateValues(from:) — in-place update of every coded property
        // from another instance (typically a freshly decoded payload). Assignment
        // routes through `SyncReconcile.value(existing:incoming:)`, which the host
        // module must provide: a generic overload plain-assigns scalars, while
        // constrained overloads reconcile relationship properties (to-one /
        // to-many of synced models) by child id so persisted child objects are
        // updated in place instead of being recreated. Keeping the call uniform
        // lets host-side overload resolution decide — this macro is syntactic and
        // cannot know which property types are synced models.
        let className = classDecl.name.text
        let updateValuesFunc = try FunctionDeclSyntax("public func updateValues(from other: \(raw: className))") {
            CodeBlockItemListSyntax {
                for key in codingKeys {
                    CodeBlockItemSyntax("self.\(raw: key) = SyncReconcile.value(existing: self.\(raw: key), incoming: other.\(raw: key))")
                }
            }
        }

        // Generate relinkChildren(in:) — swap freshly-decoded nested relationship
        // children for the persisted rows of the same id before insert, in the
        // strict fetch-all → detach-all → attach order (see the `ChildRelink`
        // doc for why the ordering is load-bearing). Every coded property routes
        // through `ChildRelink` overloads — the host's constrained overloads
        // handle relationship types, the generic base passes scalars through —
        // so the macro stays type-agnostic, same pattern as `updateValues`.
        // Properties marked @BackRef resolve via `resolveBackRef` (persisted
        // parent or nil, never the decoded copy).
        let backRefKeys = Set(codingKeys.filter { key in
            guard let property = properties.first(where: { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == key }) else { return false }
            for attribute in property.attributes {
                if let attribute = attribute.as(AttributeSyntax.self),
                   let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self),
                   attributeName.name.text == "BackRef" {
                    return true
                }
            }
            return false
        })
        let relinkChildrenFunc = try FunctionDeclSyntax("public func relinkChildren(in context: ModelContext)") {
            CodeBlockItemListSyntax {
                for key in codingKeys {
                    let resolver = backRefKeys.contains(key) ? "resolveBackRef" : "resolve"
                    CodeBlockItemSyntax("let __relinked_\(raw: key) = ChildRelink.\(raw: resolver)(self.\(raw: key), in: context)")
                }
                for key in codingKeys {
                    CodeBlockItemSyntax("self.\(raw: key) = ChildRelink.detached(self.\(raw: key))")
                }
                for key in codingKeys {
                    CodeBlockItemSyntax("self.\(raw: key) = __relinked_\(raw: key)")
                }
            }
        }

        // Generate relationshipTargets() — enumerate the CURRENT values of every
        // coded property through `RelationshipTargets.collect`; host modules
        // declare constrained overloads that append persisted-model to-one /
        // to-many values, the generic base ignores scalars (same host-overload
        // pattern as `updateValues` / `relinkChildren`). Hosts use it to validate
        // that no relationship target is managed by a different model context
        // than the one a commit writes to — SwiftData does not validate
        // cross-context links and silently corrupts the graph.
        let relationshipTargetsFunc = try FunctionDeclSyntax("public func relationshipTargets() -> [Any]") {
            CodeBlockItemListSyntax {
                CodeBlockItemSyntax("var __targets: [Any] = []")
                for key in codingKeys {
                    CodeBlockItemSyntax("RelationshipTargets.collect(self.\(raw: key), into: &__targets)")
                }
                CodeBlockItemSyntax("return __targets")
            }
        }

        // Generate encode(to encoder:)
        let encodeToEncoder = try FunctionDeclSyntax("public func encode(to encoder: Encoder) throws") {
            CodeBlockItemListSyntax {
                CodeBlockItemSyntax("let state = EncodingState.track(self, encoder: encoder)")
                CodeBlockItemSyntax("defer { EncodingState.untrack(self, state: state) }")
                CodeBlockItemSyntax("var container = encoder.container(keyedBy: CodingKeys.self)")
                for key in codingKeys {
                    CodeBlockItemSyntax("if !state.contains(self.\(raw: key))  { try container.encode(self.\(raw: key), forKey: .\(raw: key)) }")
                }
            }
        }
        
        var decls = [
            DeclSyntax(prevDataProperty),
            DeclSyntax(objectDidChangeProperty),
            DeclSyntax(codingKeysProperty),
            DeclSyntax(codingKeysEnum),
            DeclSyntax(initFromDecoder),
            DeclSyntax(updateValuesFunc),
            DeclSyntax(relinkChildrenFunc),
            DeclSyntax(relationshipTargetsFunc),
            DeclSyntax(encodeToEncoder)
        ]

        // Generate safe<Relationship> accessors — one per to-many relationship
        // whose `@Relationship(inverse: \Child.prop)` is declared on this class.
        // A live to-many walk on a store-backed model materializes held child
        // faults, which traps (`_InvalidFutureBackingData`) when an external
        // writer (CloudKit mirror coordinator, or a sibling context) has
        // re-keyed the rows. The safe accessor instead fetches CURRENT rows by
        // the child's inverse id — the inverse keypath in the attribute gives
        // the macro both the child type and the inverse property name. The
        // fetch routes through the host's `SafeFetch.fetch` (do/catch +
        // logging stays host-side). Detached (never-inserted) instances have
        // no context and no external writer, so the live array is returned.
        for property in properties {
            guard let inverse = relationshipInverse(of: property),
                  let binding = property.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            let isOptional = binding.typeAnnotation?.type.is(OptionalTypeSyntax.self) ?? false
            guard elementType(of: property) != nil else { continue }   // to-many only
            let accessorName = "safe" + name.prefix(1).uppercased() + name.dropFirst()
            let fallback = isOptional ? "\(name) ?? []" : name
            let safeAccessor = try VariableDeclSyntax("public var \(raw: accessorName): [\(raw: inverse.childType)]") {
                CodeBlockItemListSyntax {
                    CodeBlockItemSyntax("guard let context = modelContext else { return \(raw: fallback) }")
                    CodeBlockItemSyntax("let __ownID = id")
                    CodeBlockItemSyntax("let __descriptor = FetchDescriptor<\(raw: inverse.childType)>(predicate: #Predicate { $0.\(raw: inverse.property)?.id == __ownID })")
                    CodeBlockItemSyntax("return SafeFetch.fetch(__descriptor, in: context)")
                }
            }
            decls.append(DeclSyntax(safeAccessor))
        }

        // The remaining generation + the model-contract diagnostics apply only
        // to classes that declare CodableModel conformance in their own
        // inheritance clause (the macro cannot see conformances added in
        // extensions — plain @CodableClass value/demo classes are exempt).
        let isCodableModel = classDecl.inheritanceClause?.inheritedTypes.contains { inherited in
            let text = inherited.type.trimmedDescription
            return text == "CodableModel" || text == "SelfCodableModel"
        } ?? false

        if isCodableModel {
            // Generate idPredicate — the concrete-typed id predicate every
            // id-keyed fetch uses. It exists per type because a `#Predicate`
            // built over a generic `T` crashes SwiftData's keypath-to-string
            // conversion; the macro is the right place for the concrete copy.
            let idPredicateFunc = try FunctionDeclSyntax("public static func idPredicate(_ id: UUID) -> Predicate<\(raw: className)>") {
                CodeBlockItemListSyntax {
                    CodeBlockItemSyntax("return #Predicate<\(raw: className)> { $0.id == id }")
                }
            }
            decls.append(DeclSyntax(idPredicateFunc))

            diagnoseModelContract(classDecl: classDecl, properties: properties, in: context)
        }

        return decls
    }

    /// Model-contract diagnostics (CodableModel classes only):
    ///
    /// 1. `dedupNonce` must exist and be `@NonCodable`. The property itself
    ///    cannot be macro-generated — `@Model` cannot see other macros'
    ///    output, so a generated stored property would silently drop out of
    ///    the SwiftData schema (not persisted, not CloudKit-synced). What CAN
    ///    be enforced is that the hand-written copy is present and never
    ///    travels in payloads.
    /// 2. Every coded OPTIONAL to-one property of non-primitive type must
    ///    declare its relationship role: `@BackRef` (inverse parent pointer,
    ///    relinks to persisted-or-nil), `@ForwardRef` (forward model
    ///    reference, relinks to persisted-or-incoming), or `@CodableValue`
    ///    (plain Codable value type, not a model). An unmarked model-typed
    ///    to-one silently defaults to forward-ref relinking — adopting a
    ///    decoded parent copy duplicates the parent row per child (the
    ///    duplicate-Exercise cascade bug). The macro cannot tell a model type
    ///    from a value type syntactically, so the role must be explicit.
    private static func diagnoseModelContract(classDecl: ClassDeclSyntax,
                                              properties: [VariableDeclSyntax],
                                              in context: some MacroExpansionContext) {
        let primitiveTypes: Set<String> = [
            "String", "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Double", "Float", "CGFloat", "Bool", "Date", "UUID",
            "Data", "TimeInterval", "Decimal"
        ]

        var dedupNonceProperty: VariableDeclSyntax?
        for property in properties {
            guard let binding = property.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            if name == "dedupNonce" { dedupNonceProperty = property }

            // Rule 2 — unmarked optional to-one of non-primitive type.
            guard property.bindingSpecifier.text == "var",
                  !property.modifiers.contains(where: { $0.name.text == "static" }),
                  binding.accessorBlock == nil,
                  let wrapped = binding.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType,
                  let typeName = wrapped.as(IdentifierTypeSyntax.self)?.name.text,
                  !primitiveTypes.contains(typeName) else { continue }
            let exempting = ["BackRef", "ForwardRef", "CodableValue", "NonCodable", "Transient", "Relationship"]
            if !exempting.contains(where: { hasAttribute(property, $0) }) {
                context.diagnose(Diagnostic(
                    node: Syntax(property),
                    message: CodableClassDiagnostic(
                        message: "'\(name): \(typeName)?' must declare its relationship role: @BackRef (inverse parent pointer), @ForwardRef (forward model reference), or @CodableValue (not a SwiftData model). An unmarked model-typed to-one relinks like a forward ref and can adopt a decoded parent copy as a duplicate row.",
                        id: "unmarkedToOne")))
            }
        }

        // Rule 1 — dedupNonce presence + @NonCodable.
        if let dedupNonceProperty {
            if !hasAttribute(dedupNonceProperty, "NonCodable") {
                context.diagnose(Diagnostic(
                    node: Syntax(dedupNonceProperty),
                    message: CodableClassDiagnostic(
                        message: "'dedupNonce' must be @NonCodable: it is per-row instance identity and must never travel in payloads (a coded nonce would defeat duplicate resolution).",
                        id: "codableDedupNonce")))
            }
        } else {
            context.diagnose(Diagnostic(
                node: Syntax(classDecl.name),
                message: CodableClassDiagnostic(
                    message: "CodableModel class is missing '@NonCodable public var dedupNonce: String = UUID().uuidString'. It cannot be macro-generated (@Model would not see it → not persisted), so declare it by hand.",
                    id: "missingDedupNonce")))
        }
    }

    /// The `inverse: \Child.prop` argument of a property's `@Relationship`
    /// attribute, if present.
    private static func relationshipInverse(of property: VariableDeclSyntax) -> (childType: String, property: String)? {
        for attribute in property.attributes {
            guard let attribute = attribute.as(AttributeSyntax.self),
                  attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Relationship",
                  let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else { continue }
            for argument in arguments where argument.label?.text == "inverse" {
                guard let keyPath = argument.expression.as(KeyPathExprSyntax.self),
                      let root = keyPath.root?.as(IdentifierTypeSyntax.self)?.name.text,
                      let component = keyPath.components.first?.component.as(KeyPathPropertyComponentSyntax.self) else { continue }
                return (childType: root, property: component.declName.baseName.text)
            }
        }
        return nil
    }

    /// The element type of an array-typed (optionally optional) property, or
    /// nil for non-array types.
    private static func elementType(of property: VariableDeclSyntax) -> String? {
        guard var type = property.bindings.first?.typeAnnotation?.type else { return nil }
        if let optional = type.as(OptionalTypeSyntax.self) { type = optional.wrappedType }
        return type.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self)?.name.text
    }

    private static func hasAttribute(_ property: VariableDeclSyntax, _ name: String) -> Bool {
        property.attributes.contains { attribute in
            attribute.as(AttributeSyntax.self)?
                .attributeName.as(IdentifierTypeSyntax.self)?.name.text == name
        }
    }
    
    static func type(for key: String, in properties: [VariableDeclSyntax]) -> (String, Bool, Bool) {
        guard let property = properties.first(where: { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == key }) else {
            return ("Any", false, false)
        }
        
        // simple non-optional member
        let simpleType = property.bindings.first?.typeAnnotation?.type.as(IdentifierTypeSyntax.self)
        if simpleType != nil { return (simpleType!.name.text, false, false) }
        
        // array
        let arrayType = property.bindings.first?.typeAnnotation?.type.as(ArrayTypeSyntax.self)
        if arrayType != nil {
            let typeString = arrayType!.element.as(IdentifierTypeSyntax.self)?.name.text
            return typeString != nil ? ("[\(typeString!)]", false, true) : ("Any", false, false)
        }
        
        // optional
        let optionalType = property.bindings.first?.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType
        if optionalType != nil {
            let optionalSimpleType = optionalType!.as(IdentifierTypeSyntax.self)
            if optionalSimpleType != nil { return ("\(optionalSimpleType!.name.text)", true, false) }
            
            let typeString = optionalType!.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self)?.name.text
            return typeString != nil ? ("[\(typeString!)]", true, true) : ("Any", true, false)
            
        } else {
            return ("Any", false, false)
        }
    }
}

public struct NonCodableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro does nothing, so it returns an empty array.
        return []
    }
}

public struct BackRefMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marker only — read by CodableClassMacro when generating relinkChildren.
        return []
    }
}

public struct ForwardRefMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marker only — satisfies CodableClassMacro's to-one role diagnostic.
        return []
    }
}

public struct CodableValueMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Marker only — satisfies CodableClassMacro's to-one role diagnostic.
        return []
    }
}

@main
struct CodableTestMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableClassMacro.self,
        NonCodableMacro.self,
        BackRefMacro.self,
        ForwardRefMacro.self,
        CodableValueMacro.self
    ]
}
