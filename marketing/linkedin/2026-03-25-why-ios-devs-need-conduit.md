# LinkedIn Post — Why iOS Developers Need Conduit — 2026-03-25

---

The AI SDK problem nobody talks about.

Every few weeks a new LLM provider drops. GPT-4o, Claude 3.5, Gemini 1.5, Llama 3.2.

Each time, teams scramble to integrate. Different APIs. Different message formats. Different streaming implementations.

The result? Vendor lock-in disguised as flexibility.

Built Conduit to fix this properly.

One protocol. Nine backends (and growing). Same code everywhere.

The engineering stuff that wasn't obvious:

Streaming JSON recovery — when a model outputs `{"title": "A story of"}` and stops mid-token, most SDKs crash or return garbage. Conduit tries closing braces, falls back gracefully.

The @Observable + actor trade-off — ChatSession needed SwiftUI binding but @Observable classes can't be actors. Solution: NSLock, never held across await points. Not elegant but it works.

Tool calling as infrastructure — instead of writing the execution loop yourself, it's just configuration.

Swift 6.2 strict concurrency throughout. All public types Sendable.

The pitch: treat AI as infrastructure, not a vendor dependency.

github.com/AIStack/Conduit

