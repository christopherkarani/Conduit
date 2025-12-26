// GuideMacro.swift
// SwiftAI
//
// @Guide macro implementation for property descriptions and constraints.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// MARK: - GuideMacro

/// Macro that provides description and constraints for Generable properties.
///
/// Usage:
/// ```swift
/// @Generable
/// struct Recipe {
///     @Guide("The recipe title")
///     let title: String
///
///     @Guide("Cooking time in minutes", .range(1...180))
///     let cookingTime: Int
///
///     @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
///     let difficulty: String
/// }
/// ```
public struct GuideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // @Guide is a marker macro - it doesn't generate code itself
        // The GenerableMacro reads @Guide attributes during expansion
        return []
    }
}

// MARK: - GuideDiagnostic

enum GuideDiagnostic: String, DiagnosticMessage {
    case notInGenerable = "@Guide can only be used inside a @Generable struct"
    case invalidConstraint = "Constraint type does not match property type"

    var message: String { rawValue }
    var diagnosticID: MessageID { MessageID(domain: "SwiftAIMacros", id: rawValue) }
    var severity: DiagnosticSeverity { .error }
}
