// Conduit.swift
// Conduit
//
// A unified Swift SDK for LLM inference across multiple providers.
// All public types are available via `import Conduit`.
//
// Copyright 2025. MIT License.

import Foundation

// MARK: - Version

/// The current version of the Conduit framework.
///
/// ## Version History
/// - 0.6.0: Renamed from SwiftAI to Conduit, structured output and tool calling
/// - 0.5.0: Added image generation (ImageGenerator protocol, MLXImageProvider, DiffusionModelRegistry)
/// - 0.1.0: Initial release with text generation, embeddings, transcription
public let conduitVersion = "0.6.0"
