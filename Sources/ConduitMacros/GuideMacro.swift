import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Allows for influencing the allowed values of properties of a generable type.
public struct GuideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
            let firstBinding = variableDecl.bindings.first,
            let identifier = firstBinding.pattern.as(IdentifierPatternSyntax.self)
        else {
            return []
        }

        let baseName = "__conduitGuideMetadata_\(sanitizeIdentifier(identifier.identifier.text))"
        let metadataName = context.makeUniqueName(baseName).text
        let info = extractGuideInfo(from: node)
        let descriptionLiteral = info.description.map { "\"\(escapeString($0))\"" } ?? "nil"
        let rawGuides = info.rawGuides
            .map { "\"\(escapeString($0))\"" }
            .joined(separator: ", ")

        return [
            DeclSyntax(
                stringLiteral: """
                    private enum \(metadataName) {
                        static let description: String? = \(descriptionLiteral)
                        static let rawGuides: [String] = [\(rawGuides)]
                    }
                    """
            )
        ]
    }

    private static func extractGuideInfo(from node: AttributeSyntax) -> GuideMetadata {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return GuideMetadata(description: nil, rawGuides: [])
        }

        var description: String?
        var guideStartIndex = arguments.startIndex

        if let first = arguments.first,
            (first.label == nil || first.label?.text == "description"),
            let text = stringLiteralValue(from: first.expression)
        {
            description = text
            guideStartIndex = arguments.index(after: arguments.startIndex)
        }

        let remaining = arguments[guideStartIndex...]
        let rawGuides = remaining.map {
            $0.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return GuideMetadata(description: description, rawGuides: rawGuides)
    }

    private static func stringLiteralValue(from expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else {
            return nil
        }
        return literal.segments.compactMap { segment in
            segment.as(StringSegmentSyntax.self)?.content.text
        }.joined()
    }

    private static func sanitizeIdentifier(_ raw: String) -> String {
        let scalars = raw.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
                return Character(scalar)
            }
            return "_"
        }
        let sanitized = String(scalars)
        guard let first = sanitized.unicodeScalars.first else {
            return "_"
        }
        if CharacterSet.decimalDigits.contains(first) {
            return "_\(sanitized)"
        }
        return sanitized
    }

    private static func escapeString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

private struct GuideMetadata {
    let description: String?
    let rawGuides: [String]
}
