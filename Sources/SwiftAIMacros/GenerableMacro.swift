// GenerableMacro.swift
// SwiftAI
//
// @Generable macro implementation for type-safe structured output generation.

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - GenerableMacro

/// Macro that generates Generable conformance for structs.
///
/// Usage:
/// ```swift
/// @Generable
/// struct WeatherReport {
///     @Guide("Temperature in Celsius")
///     let temperature: Int
///     let conditions: String
/// }
/// ```
public struct GenerableMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate struct declaration
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: GenerableDiagnostic.notAStruct
            ))
            return []
        }

        let typeName = structDecl.name.text
        let properties = extractProperties(from: structDecl)

        var members: [DeclSyntax] = []

        // Generate schema
        members.append(generateSchema(typeName: typeName, properties: properties))

        // Generate Partial type
        members.append(generatePartialType(typeName: typeName, properties: properties))

        // Generate init(from:)
        members.append(generateInitFromContent(properties: properties))

        // Generate generableContent
        members.append(generateGenerableContent(properties: properties))

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let generable = try ExtensionDeclSyntax("extension \(type.trimmed): Generable {}")
        return [generable]
    }
}

// MARK: - Property Extraction

/// Represents a property extracted from a struct for schema generation.
struct ExtractedProperty {
    let name: String
    let typeName: String
    let isOptional: Bool
    let isArray: Bool
    let elementType: String?
    let guide: GuideInfo?
}

/// Information from @Guide attribute.
struct GuideInfo {
    let description: String?
    let constraints: [String]
}

private func extractProperties(from structDecl: StructDeclSyntax) -> [ExtractedProperty] {
    var properties: [ExtractedProperty] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation else {
            continue
        }

        let name = identifier.identifier.text
        let (typeName, isOptional, isArray, elementType) = parseType(typeAnnotation.type)
        let guide = extractGuideInfo(from: varDecl.attributes)

        properties.append(ExtractedProperty(
            name: name,
            typeName: typeName,
            isOptional: isOptional,
            isArray: isArray,
            elementType: elementType,
            guide: guide
        ))
    }

    return properties
}

private func parseType(_ type: TypeSyntax) -> (String, Bool, Bool, String?) {
    // Handle Optional<T> or T?
    if let optional = type.as(OptionalTypeSyntax.self) {
        let (inner, _, isArray, element) = parseType(optional.wrappedType)
        return (inner, true, isArray, element)
    }

    // Handle Array<T> or [T]
    if let array = type.as(ArrayTypeSyntax.self) {
        let (element, _, _, _) = parseType(array.element)
        return ("[\(element)]", false, true, element)
    }

    // Handle generic Array<Element>
    if let generic = type.as(IdentifierTypeSyntax.self),
       generic.name.text == "Array",
       let args = generic.genericArgumentClause?.arguments.first {
        let (element, _, _, _) = parseType(args.argument)
        return ("[\(element)]", false, true, element)
    }

    // Simple type
    return (type.trimmedDescription, false, false, nil)
}

private func extractGuideInfo(from attributes: AttributeListSyntax) -> GuideInfo? {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self),
              let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
              identifier.name.text == "Guide" else {
            continue
        }

        // Extract arguments from @Guide("description", constraints...)
        var description: String? = nil
        var constraints: [String] = []

        if let args = attr.arguments?.as(LabeledExprListSyntax.self) {
            for (index, arg) in args.enumerated() {
                if index == 0, let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self) {
                    description = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                } else {
                    constraints.append(arg.expression.description)
                }
            }
        }

        return GuideInfo(description: description, constraints: constraints)
    }
    return nil
}

// MARK: - Code Generation

private func generateSchema(typeName: String, properties: [ExtractedProperty]) -> DeclSyntax {
    var propertyLines: [String] = []

    for prop in properties {
        let schemaType = schemaTypeFor(prop)
        let description = prop.guide?.description.map { "\"\($0)\"" } ?? "nil"
        let isRequired = !prop.isOptional

        propertyLines.append("""
                    "\(prop.name)": Schema.Property(
                        schema: \(schemaType),
                        description: \(description),
                        isRequired: \(isRequired)
                    )
        """)
    }

    let propertiesCode = propertyLines.joined(separator: ",\n")

    return """
        public static var schema: Schema {
            .object(
                name: "\(raw: typeName)",
                description: nil,
                properties: [
        \(raw: propertiesCode)
                ]
            )
        }
        """
}

private func schemaTypeFor(_ prop: ExtractedProperty) -> String {
    let constraints = prop.guide?.constraints.joined(separator: ", ") ?? ""
    let constraintArray = constraints.isEmpty ? "[]" : "[\(constraints)]"

    if prop.isArray {
        let element = prop.elementType ?? "String"
        return ".array(items: \(schemaForType(element)), constraints: \(constraintArray))"
    }

    if prop.isOptional {
        return ".optional(wrapped: \(schemaForType(prop.typeName)))"
    }

    return schemaForType(prop.typeName, constraints: constraintArray)
}

private func schemaForType(_ typeName: String, constraints: String = "[]") -> String {
    switch typeName {
    case "String": return ".string(constraints: \(constraints))"
    case "Int": return ".integer(constraints: \(constraints))"
    case "Double", "Float": return ".number(constraints: \(constraints))"
    case "Bool": return ".boolean(constraints: \(constraints))"
    default: return "\(typeName).schema"
    }
}

private func generatePartialType(typeName: String, properties: [ExtractedProperty]) -> DeclSyntax {
    var propertyDecls: [String] = []

    for prop in properties {
        let partialType = prop.isOptional ? prop.typeName : "\(prop.typeName)?"
        propertyDecls.append("        public var \(prop.name): \(partialType)")
    }

    let propertiesCode = propertyDecls.joined(separator: "\n")

    return """
        public struct Partial: GenerableContentConvertible, Sendable {
        \(raw: propertiesCode)

            public var generableContent: StructuredContent {
                var dict: [String: StructuredContent] = [:]
        \(raw: properties.map { "        if let v = \($0.name) { dict[\"\($0.name)\"] = v.generableContent }" }.joined(separator: "\n"))
                return .object(dict)
            }

            public init(from structuredContent: StructuredContent) throws {
                let obj = try structuredContent.object
        \(raw: properties.map { "        self.\($0.name) = try? obj[\"\($0.name)\"].map { try \(baseType($0)).init(from: $0) }" }.joined(separator: "\n"))
            }

            public init() {}
        }
        """
}

private func baseType(_ prop: ExtractedProperty) -> String {
    if prop.isOptional {
        return prop.typeName.replacingOccurrences(of: "?", with: "")
    }
    return prop.typeName
}

private func generateInitFromContent(properties: [ExtractedProperty]) -> DeclSyntax {
    var assignments: [String] = []

    for prop in properties {
        if prop.isOptional {
            assignments.append("        self.\(prop.name) = try obj[\"\(prop.name)\"].map { try \(baseType(prop)).init(from: $0) }")
        } else {
            assignments.append("        guard let \(prop.name)Content = obj[\"\(prop.name)\"] else { throw StructuredContentError.missingKey(\"\(prop.name)\") }")
            assignments.append("        self.\(prop.name) = try \(prop.typeName).init(from: \(prop.name)Content)")
        }
    }

    return """
        public init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
        \(raw: assignments.joined(separator: "\n"))
        }
        """
}

private func generateGenerableContent(properties: [ExtractedProperty]) -> DeclSyntax {
    var entries: [String] = []

    for prop in properties {
        if prop.isOptional {
            entries.append("        if let v = \(prop.name) { dict[\"\(prop.name)\"] = v.generableContent }")
        } else {
            entries.append("        dict[\"\(prop.name)\"] = \(prop.name).generableContent")
        }
    }

    return """
        public var generableContent: StructuredContent {
            var dict: [String: StructuredContent] = [:]
        \(raw: entries.joined(separator: "\n"))
            return .object(dict)
        }
        """
}

// MARK: - Diagnostics

enum GenerableDiagnostic: String, DiagnosticMessage {
    case notAStruct = "@Generable can only be applied to structs"
    case missingType = "Property must have an explicit type annotation"

    var message: String { rawValue }
    var diagnosticID: MessageID { MessageID(domain: "SwiftAIMacros", id: rawValue) }
    var severity: DiagnosticSeverity { .error }
}
