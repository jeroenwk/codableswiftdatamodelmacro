import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
        
        return [
            DeclSyntax(prevDataProperty),
            DeclSyntax(objectDidChangeProperty),
            DeclSyntax(codingKeysProperty),
            DeclSyntax(codingKeysEnum),
            DeclSyntax(initFromDecoder),
            DeclSyntax(updateValuesFunc),
            DeclSyntax(encodeToEncoder)
        ]
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

@main
struct CodableTestMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableClassMacro.self,
        NonCodableMacro.self
    ]
}
