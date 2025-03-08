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
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
            return "\(identifier)"
        }.compactMap { $0 }
        
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
                CodeBlockItemSyntax("let container = try decoder.container(keyedBy: CodingKeys.self)")
                for key in codingKeys {
                    let typeInfo = type(for: key, in: properties)
                    if typeInfo.1 {
                        CodeBlockItemSyntax("let \(raw: key) = try container.decodeIfPresent(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                    } else {
                        CodeBlockItemSyntax("let \(raw: key) = try container.decode(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                    }
                }
                let initArgs = codingKeys.map { "\($0): \($0)" }.joined(separator: ", ")
                CodeBlockItemSyntax("self.init(\(raw: initArgs))")
            }
        }
        
        // Generate decode(from decoder:)
        let decodeFromDecoder = try FunctionDeclSyntax("func decode(from decoder: Decoder) throws") {
            CodeBlockItemListSyntax {
                CodeBlockItemSyntax("let container = try decoder.container(keyedBy: CodingKeys.self)")
                for key in codingKeys {
                    let typeInfo = type(for: key, in: properties)
                    if typeInfo.1 {
                        CodeBlockItemSyntax("self.\(raw: key) = try container.decodeIfPresent(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                    } else {
                        CodeBlockItemSyntax("self.\(raw: key) = try container.decode(\(raw: typeInfo.0).self, forKey: .\(raw: key))")
                    }
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
            DeclSyntax(codingKeysProperty),
            DeclSyntax(codingKeysEnum),
            DeclSyntax(initFromDecoder),
            DeclSyntax(decodeFromDecoder),
            DeclSyntax(encodeToEncoder)
        ]
    }
    
    static func type(for key: String, in properties: [VariableDeclSyntax]) -> (String, Bool) {
        guard let property = properties.first(where: { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == key }) else {
            return ("Any", false)
        }
        
        // simple non-optional member
        let simpleType = property.bindings.first?.typeAnnotation?.type.as(IdentifierTypeSyntax.self)
        if simpleType != nil { return (simpleType!.name.text, false) }
        
        // array
        let arrayType = property.bindings.first?.typeAnnotation?.type.as(ArrayTypeSyntax.self)
        if arrayType != nil {
            let typeString = arrayType!.element.as(IdentifierTypeSyntax.self)?.name.text
            return typeString != nil ? ("[\(typeString!)]", false) : ("Any", false)
        }

        // optional
        let optionalType = property.bindings.first?.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType
        if optionalType != nil {
            let optionalSimpleType = optionalType!.as(IdentifierTypeSyntax.self)
            if optionalSimpleType != nil { return ("\(optionalSimpleType!.name.text)", true) }
            
            let typeString = optionalType!.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self)?.name.text
            return typeString != nil ? ("[\(typeString!)]", true) : ("Any", true)
            
        } else {
            return ("Any", false)
        }
    }
}

@main
struct CodableTestMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableClassMacro.self
    ]
}
