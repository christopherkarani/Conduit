// SwiftAI.swift
// SwiftAI
//
// A unified Swift SDK for LLM inference across multiple providers:
// - MLX: Local inference on Apple Silicon
// - HuggingFace: Cloud inference via HF Inference API
// - Apple Foundation Models: System-integrated on-device AI (iOS 26+)
//
// Copyright 2025. MIT License.

import Foundation

// MARK: - Module Re-exports

// Core Protocols
// TODO: @_exported import when implemented
// - AIProvider
// - TextGenerator
// - EmbeddingGenerator
// - Transcriber
// - TokenCounter
// - ModelManaging

// Core Types
// TODO: @_exported import when implemented
// - ModelIdentifier
// - Message
// - GenerateConfig
// - EmbeddingResult
// - TranscriptionResult
// - TokenCount

// Streaming
// TODO: @_exported import when implemented
// - GenerationStream
// - GenerationChunk
// - StreamBuffer

// Errors
// TODO: @_exported import when implemented
// - AIError
// - ProviderError

// Providers
// TODO: @_exported import when implemented
// - MLXProvider
// - HuggingFaceProvider
// - FoundationModelsProvider

// Model Management
// TODO: @_exported import when implemented
// - ModelManager
// - ModelRegistry
// - ModelCache

// Builders
// TODO: @_exported import when implemented
// - PromptBuilder
// - MessageBuilder

// MARK: - Version

/// The current version of the SwiftAI framework.
public let swiftAIVersion = "0.1.0"
