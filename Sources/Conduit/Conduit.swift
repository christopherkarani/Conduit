// Conduit.swift
// Conduit
//
// A unified Swift SDK for LLM inference across multiple providers:
// - MLX: Local inference on Apple Silicon (offline, privacy-preserving)
// - HuggingFace: Cloud inference via HF Inference API (online, model variety)
// - Anthropic: Claude API for advanced reasoning and tool use
// - OpenAI: GPT models and DALL-E image generation
//
// Note: Apple Foundation Models (iOS 26+) are supported via FoundationModelsProvider.
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
// - ImageGenerator: Protocol for text-to-image providers (v1.2.0)
// - ImageGenerationProgress: Progress tracking for local diffusion models (v1.2.0)
// - MLXImageProvider: Local on-device image generation using MLX StableDiffusion (v1.2.0)
// - DiffusionVariant: Supported diffusion model variants (SDXL Turbo, SD 1.5, Flux) (v1.2.0)
// - DiffusionModelRegistry: Registry for managing diffusion model downloads (v1.2.0)
// - DiffusionModelDownloader: Downloads diffusion models from HuggingFace (v1.2.0)

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

// MARK: - Anthropic Provider
// - AnthropicProvider: Anthropic Claude API support
// - AnthropicModelID: Model identifiers for Claude models
// - AnthropicConfiguration: Configuration for Anthropic provider
// - AnthropicAuthentication: API key authentication

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

/// The current version of the Conduit framework.
///
/// ## Version History
/// - 0.6.0: Renamed from SwiftAI to Conduit, structured output and tool calling
/// - 0.5.0: Added image generation (ImageGenerator protocol, MLXImageProvider, DiffusionModelRegistry)
/// - 0.1.0: Initial release with text generation, embeddings, transcription
public let conduitVersion = "0.6.0"
