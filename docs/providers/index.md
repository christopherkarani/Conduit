# Providers Overview

Choose the right provider for your use case with this capability matrix and decision guide.

## Overview

Conduit supports 10 providers spanning cloud APIs, local inference, and system-integrated models. Each provider conforms to `TextGenerator` and optionally to additional protocols for embeddings, transcription, image generation, and token counting.

## Capability Matrix

| Capability | Anthropic | OpenAI | MLX | HuggingFace | Foundation Models | Kimi | MiniMax | CoreML | Llama |
|:-----------|:---------:|:------:|:---:|:-----------:|:-----------------:|:----:|:-------:|:------:|:-----:|
| Text Generation | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Streaming | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Structured Output | Yes | Yes | Yes | Yes | Yes | Yes | Yes | — | — |
| Tool Calling | Yes | Yes | — | — | — | — | — | Yes | — |
| Vision | Yes | Yes | — | — | — | — | — | — | — |
| Extended Thinking | Yes | — | — | — | — | — | — | — | — |
| Embeddings | — | Yes | — | Yes | — | — | — | — | — |
| Transcription | — | Yes | — | Yes | — | — | — | — | — |
| Image Generation | — | Yes | — | Yes | — | — | — | — | — |
| Token Counting | — | Yes* | Yes | — | — | — | — | — | — |
| Offline | — | —** | Yes | — | Yes | — | — | Yes | Yes |
| Privacy | — | — | Yes | — | Yes | — | — | Yes | Yes |

*Estimated token counting
**Offline available when using Ollama local endpoint

## Choosing a Provider

### For Production Cloud Applications

- **[AnthropicProvider](/providers/anthropic)** — Best reasoning quality, vision, extended thinking. Ideal for complex tasks.
- **OpenAI via [OpenAIProvider](/providers/openai)** — Broadest feature set (embeddings, images, audio). Enterprise support via Azure.
- **OpenRouter via [OpenAIProvider](/providers/openai)** — Access 200+ models with automatic failover and latency routing.

### For Privacy and Offline Use

- **[MLXProvider](/providers/mlx)** — Best local performance on Apple Silicon. Zero network traffic.
- **[FoundationModelsProvider](/providers/foundation-models)** — Zero setup on iOS 26+/macOS 26+. System-managed.
- **Ollama via [OpenAIProvider](/providers/openai)** — Local inference server, works on macOS and Linux.
- **[LlamaProvider](/providers/llama)** — Direct llama.cpp integration for GGUF models.
- **[CoreMLProvider](/providers/coreml)** — Native Core ML models with Neural Engine acceleration.

### For Specialized Tasks

- **Embeddings**: [OpenAIProvider](/providers/openai) or [HuggingFaceProvider](/providers/huggingface)
- **Transcription**: [HuggingFaceProvider](/providers/huggingface) (Whisper) or [OpenAIProvider](/providers/openai)
- **Image Generation**: [OpenAIProvider](/providers/openai) (DALL-E) or [HuggingFaceProvider](/providers/huggingface) (Stable Diffusion)
- **Long Context (256K)**: [KimiProvider](/providers/kimi)
- **Model Variety**: [HuggingFaceProvider](/providers/huggingface) (hundreds of models)

## Authentication

| Provider | Environment Variable | Auth Type |
|----------|---------------------|-----------|
| Anthropic | `ANTHROPIC_API_KEY` | `.apiKey` or `.auto` |
| OpenAI | `OPENAI_API_KEY` | `.bearer` or `.auto` |
| OpenRouter | `OPENROUTER_API_KEY` | `.bearer` or `.auto` |
| Azure OpenAI | `AZURE_OPENAI_API_KEY` | `.apiKey` |
| Kimi | `MOONSHOT_API_KEY` | `.apiKey` or `.auto` |
| MiniMax | `MINIMAX_API_KEY` | `.apiKey` or `.auto` |
| HuggingFace | `HF_TOKEN` | `.auto` or `.static` |
| MLX | — | None required |
| Foundation Models | — | None required |
| Ollama | — | None required |

Most providers support `.auto` authentication that resolves keys from environment variables.

## Trait Requirements

| Provider | Required Traits |
|----------|----------------|
| AnthropicProvider | `Anthropic` |
| OpenAIProvider | `OpenAI` and/or `OpenRouter` |
| MLXProvider | `MLX` |
| HuggingFaceProvider | (always available) |
| FoundationModelsProvider | (platform-gated, no trait) |
| KimiProvider | `Kimi` + `OpenAI` |
| MiniMaxProvider | `MiniMax` + `OpenAI` |
| CoreMLProvider | `CoreML` |
| LlamaProvider | `Llama` |
