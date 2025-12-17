// SwiftAIMacrosPlugin.swift
// SwiftAI

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftAIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // TODO: Phase 14 - Register macros here
        // GenerableMacro.self,
        // GuideMacro.self,
    ]
}
