// TestURL.swift
// ConduitTests

import Foundation
import Testing

/// Creates a URL from a string, failing the test if the URL is invalid.
///
/// This helper is shared across the entire `ConduitTests` module to avoid
/// duplicate global symbol definitions in multiple test files.
func makeTestURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
        Issue.record("Failed to create URL from string: \(string)")
        return makeTestURL("https://example.com")
    }
    return url
}

