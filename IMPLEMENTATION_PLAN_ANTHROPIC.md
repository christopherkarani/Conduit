# Anthropic Provider Implementation Plan

**Status**: ✅ APPROVED FOR IMPLEMENTATION
**Date**: 2025-12-26
**Feature**: Anthropic Claude API Integration
**Scope**: Full implementation (Text + Streaming + Vision + Extended Thinking)

---

## 📋 Plan Documents

This implementation is guided by three comprehensive plan documents:

1. **Technical Plan** (`enchanted-leaping-pine.md`) - Detailed implementation steps with all code structures
2. **Implementation Checklist** (`anthropic-implementation-checklist.md`) - Step-by-step progress tracker
3. **Executive Summary** (`anthropic-provider-plan-FINAL.md`) - Review findings and design decisions

**Plan Files Location**: `~/.claude/plans/`

---

## 🎯 Implementation Overview

### Scope
- ✅ Text generation (non-streaming + streaming)
- ✅ Vision support (multimodal images)
- ✅ Extended thinking mode
- ✅ Progressive disclosure (3 initialization levels)

### Metrics
- **Files**: 8 new + 2 modifications
- **Lines of Code**: ~1,360 new lines
- **Tests**: 7 test suites, 30+ individual tests
- **Estimated Time**: 6-8 hours

---

## 🏗️ File Structure

```
Sources/SwiftAI/
├── Core/Types/
│   └── ForwardDeclarations.swift       ← ADD .anthropic case
├── Providers/Anthropic/ (NEW)
│   ├── AnthropicProvider.swift         (150 lines)
│   ├── AnthropicProvider+Helpers.swift (120 lines)
│   ├── AnthropicProvider+Streaming.swift (180 lines)
│   ├── AnthropicModelID.swift          (120 lines)
│   ├── AnthropicConfiguration.swift    (100 lines)
│   ├── AnthropicAuthentication.swift   (60 lines)
│   └── AnthropicAPITypes.swift         (150 lines)
└── SwiftAI.swift                       ← ADD export comments

Tests/SwiftAITests/Providers/Anthropic/ (NEW)
├── AnthropicProviderTests.swift        (400 lines)
└── AnthropicIntegrationTests.swift     (80 lines)
```

---

## 📐 Architecture

### Protocol Conformances
```swift
public actor AnthropicProvider: AIProvider, TextGenerator {
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = AnthropicModelID
}
```

### Key Patterns
- **Actor-based concurrency** with nonisolated streaming methods
- **Progressive disclosure**: 3 initialization levels
- **Error mapping**: All 9 Anthropic error types → AIError
- **System messages**: Separate `system` field (not in messages array)
- **SSE streaming**: URLSession.bytes(for:).lines for async iteration

---

## 🔑 Critical Success Factors

1. ✅ **System Message Handling**: Extract from messages array, send in separate `system` field
2. ✅ **Error Mapping**: All Anthropic error types mapped to existing AIError cases
3. ✅ **Streaming Events**: Only yield GenerationChunk for `content_block_delta` events
4. ✅ **Actor Isolation**: Streaming methods marked `nonisolated`
5. ✅ **Testing**: Unit tests must pass before integration tests

---

## 📊 Implementation Steps

### Phase 1: Foundation (CRITICAL)
1. Update ProviderType enum (add `.anthropic` case)
2. Create AnthropicModelID
3. Create AnthropicAuthentication
4. Create AnthropicConfiguration

### Phase 2: DTOs (CRITICAL)
5. Create AnthropicAPITypes (Request/Response structures)

### Phase 3: Provider (HIGH)
6. Create AnthropicProvider actor skeleton
7. Implement AnthropicProvider+Helpers
8. Implement generate() method

### Phase 4: Streaming (HIGH)
9. Create AnthropicProvider+Streaming
10. Implement SSE parsing and event processing

### Phase 5: Advanced Features (MEDIUM)
11. Add Vision support (multimodal content)
12. Add Extended Thinking support

### Phase 6: Integration (HIGH)
13. Add convenience methods
14. Update SwiftAI.swift exports

### Phase 7: Testing (CRITICAL)
15. Write unit tests (7 suites)
16. Write integration tests

### Phase 8: Documentation (MEDIUM)
17. Add doc comments
18. Update README

---

## 🔐 Security

- ✅ API keys handled securely (environment variable support)
- ✅ HTTPS enforced via base URL
- ✅ No sensitive data in error messages
- ✅ Credential redaction in debug descriptions

---

## ✅ Reviews Completed

- ✅ **Architectural Review**: Pattern consistency verified
- ✅ **Swift 6.2 Compliance**: Concurrency safety confirmed
- ✅ **Security Audit**: API key handling verified
- ✅ **Completeness Check**: All edge cases covered

---

## 🚀 Next Steps

1. Review detailed plan in `~/.claude/plans/anthropic-provider-plan-FINAL.md`
2. Use checklist in `~/.claude/plans/anthropic-implementation-checklist.md`
3. Begin with **Step 1.1**: Update ProviderType enum

---

## 📚 Reference

### Anthropic API
- **Base URL**: `https://api.anthropic.com/v1/messages`
- **API Version**: `2023-06-01`
- **Authentication**: `X-Api-Key` header
- **Environment Variable**: `ANTHROPIC_API_KEY`

### Models Supported
- `claude-opus-4-5-20251101`
- `claude-sonnet-4-5-20250929`
- `claude-3-5-sonnet-20241022`
- `claude-3-opus-20240229`
- `claude-3-sonnet-20240229`
- `claude-3-haiku-20240307`

---

**Plan Status**: ✅ READY FOR IMPLEMENTATION
**Context Saved**: ✅ Memory tool updated with full context
**Implementation Approach**: Precision implementation using specialized sub-agents
