// SwiftAI.swift
// SwiftAI
//
// A unified Swift SDK for LLM inference across two providers:
// - MLX: Local inference on Apple Silicon (offline, privacy-preserving)
// - HuggingFace: Cloud inference via HF Inference API (online, model variety)
//
// Note: Apple Foundation Models (iOS 26+) is intentionally not wrapped.
// SwiftAgents provides adapters for FM when unified orchestration is needed.
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

// Image Generation Types
// - GeneratedImage: Image result with SwiftUI support and save methods
// - ImageGenerationConfig: Configuration for text-to-image (dimensions, steps, guidance)
// - ImageFormat: Supported image formats (PNG, JPEG, WebP)
// - GeneratedImageError: Errors for image operations

// Streaming
// TODO: @_exported import when implemented
// - GenerationStream
// - GenerationChunk

// Errors
// TODO: @_exported import when implemented
// - AIError
// - ProviderError

// Providers
// TODO: @_exported import when implemented
// - MLXProvider
// - HuggingFaceProvider

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
