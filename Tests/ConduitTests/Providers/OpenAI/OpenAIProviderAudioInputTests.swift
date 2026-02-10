// OpenAIProviderAudioInputTests.swift
// Conduit Tests
//
// Tests for OpenRouter/OpenAI audio input support.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("OpenAI Provider Audio Input Tests")
struct OpenAIProviderAudioInputTests {

    // MARK: - AudioFormat Tests

    @Suite("AudioFormat Type")
    struct AudioFormatTypeTests {

        @Test("AudioFormat has all supported formats")
        func allSupportedFormats() {
            // OpenRouter supports: wav, mp3, aiff, aac, ogg, flac, m4a
            let formats = Message.AudioFormat.allCases

            #expect(formats.count == 7)
            #expect(formats.contains(.wav))
            #expect(formats.contains(.mp3))
            #expect(formats.contains(.aiff))
            #expect(formats.contains(.aac))
            #expect(formats.contains(.ogg))
            #expect(formats.contains(.flac))
            #expect(formats.contains(.m4a))
        }

        @Test("AudioFormat raw values match API specification")
        func rawValues() {
            #expect(Message.AudioFormat.wav.rawValue == "wav")
            #expect(Message.AudioFormat.mp3.rawValue == "mp3")
            #expect(Message.AudioFormat.aiff.rawValue == "aiff")
            #expect(Message.AudioFormat.aac.rawValue == "aac")
            #expect(Message.AudioFormat.ogg.rawValue == "ogg")
            #expect(Message.AudioFormat.flac.rawValue == "flac")
            #expect(Message.AudioFormat.m4a.rawValue == "m4a")
        }

        @Test("AudioFormat conforms to Sendable")
        func sendableConformance() {
            let format: any Sendable = Message.AudioFormat.wav
            #expect(format is Message.AudioFormat)
        }

        @Test("AudioFormat Codable round-trip")
        func codableRoundTrip() throws {
            for format in Message.AudioFormat.allCases {
                let encoded = try JSONEncoder().encode(format)
                let decoded = try JSONDecoder().decode(Message.AudioFormat.self, from: encoded)
                #expect(format == decoded)
            }
        }
    }

    // MARK: - AudioContent Tests

    @Suite("AudioContent Type")
    struct AudioContentTypeTests {

        @Test("AudioContent creation with data and format")
        func audioContentInit() {
            let base64Data = "SGVsbG8gV29ybGQ="  // "Hello World" in base64
            let audio = Message.AudioContent(base64Data: base64Data, format: .wav)

            #expect(audio.base64Data == base64Data)
            #expect(audio.format == .wav)
        }

        @Test("AudioContent creation with different formats")
        func audioContentFormats() {
            let mp3Audio = Message.AudioContent(base64Data: "abc", format: .mp3)
            let flacAudio = Message.AudioContent(base64Data: "def", format: .flac)
            let m4aAudio = Message.AudioContent(base64Data: "ghi", format: .m4a)

            #expect(mp3Audio.format == .mp3)
            #expect(flacAudio.format == .flac)
            #expect(m4aAudio.format == .m4a)
        }

        @Test("AudioContent conforms to Sendable")
        func sendableConformance() {
            let audio: any Sendable = Message.AudioContent(base64Data: "test", format: .wav)
            #expect(audio is Message.AudioContent)
        }

        @Test("AudioContent conforms to Hashable")
        func hashableConformance() {
            let audio1 = Message.AudioContent(base64Data: "abc", format: .wav)
            let audio2 = Message.AudioContent(base64Data: "abc", format: .wav)
            let audio3 = Message.AudioContent(base64Data: "xyz", format: .mp3)

            var audioSet: Set<Message.AudioContent> = []
            audioSet.insert(audio1)
            audioSet.insert(audio2)
            audioSet.insert(audio3)

            #expect(audioSet.count == 2)
        }

        @Test("AudioContent equality")
        func equality() {
            let audio1 = Message.AudioContent(base64Data: "test", format: .wav)
            let audio2 = Message.AudioContent(base64Data: "test", format: .wav)
            let audio3 = Message.AudioContent(base64Data: "test", format: .mp3)

            #expect(audio1 == audio2)
            #expect(audio1 != audio3)
        }

        @Test("AudioContent Codable round-trip")
        func codableRoundTrip() throws {
            let original = Message.AudioContent(base64Data: "dGVzdCBhdWRpbyBkYXRh", format: .flac)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Message.AudioContent.self, from: encoded)

            #expect(original == decoded)
            #expect(decoded.base64Data == "dGVzdCBhdWRpbyBkYXRh")
            #expect(decoded.format == .flac)
        }
    }

    // MARK: - ContentPart Audio Tests

    @Suite("ContentPart Audio")
    struct ContentPartAudioTests {

        @Test("ContentPart.audio case exists")
        func audioCaseExists() {
            let audioContent = Message.AudioContent(base64Data: "test", format: .wav)
            let part = Message.ContentPart.audio(audioContent)

            if case .audio(let audio) = part {
                #expect(audio.base64Data == "test")
                #expect(audio.format == .wav)
            } else {
                Issue.record("Expected audio content part")
            }
        }

        @Test("ContentPart with audio is not considered text")
        func audioPartNotText() {
            let content = Message.Content.parts([
                .audio(Message.AudioContent(base64Data: "test", format: .wav))
            ])

            // Audio-only content should have empty text value (like image-only)
            #expect(content.textValue.isEmpty)
        }

        @Test("ContentPart.audio Codable round-trip")
        func audioCodableRoundTrip() throws {
            let audioContent = Message.AudioContent(base64Data: "abc123", format: .mp3)
            let part = Message.ContentPart.audio(audioContent)

            let encoded = try JSONEncoder().encode(part)
            let decoded = try JSONDecoder().decode(Message.ContentPart.self, from: encoded)

            if case .audio(let decodedAudio) = decoded {
                #expect(decodedAudio.base64Data == "abc123")
                #expect(decodedAudio.format == .mp3)
            } else {
                Issue.record("Expected audio content part")
            }
        }
    }

    // MARK: - Message Audio Content Tests

    @Suite("Message Audio Content")
    struct MessageAudioContentTests {

        @Test("Create message with audio-only content")
        func messageWithAudioOnly() {
            let audioContent = Message.AudioContent(base64Data: "audio_data", format: .wav)
            let message = Message(
                role: .user,
                content: .parts([.audio(audioContent)])
            )

            #expect(message.role == .user)

            if case .parts(let parts) = message.content {
                #expect(parts.count == 1)
                if case .audio(let audio) = parts[0] {
                    #expect(audio.base64Data == "audio_data")
                    #expect(audio.format == .wav)
                } else {
                    Issue.record("Expected audio part")
                }
            } else {
                Issue.record("Expected parts content")
            }
        }

        @Test("Create message with audio and text")
        func messageWithAudioAndText() {
            let audioContent = Message.AudioContent(base64Data: "audio_data", format: .mp3)
            let message = Message(
                role: .user,
                content: .parts([
                    .audio(audioContent),
                    .text("What is being said in this audio?")
                ])
            )

            #expect(message.content.textValue == "What is being said in this audio?")

            if case .parts(let parts) = message.content {
                #expect(parts.count == 2)
            } else {
                Issue.record("Expected parts content")
            }
        }

        @Test("Create message with audio, text, and image")
        func messageWithAudioTextAndImage() {
            let audioContent = Message.AudioContent(base64Data: "audio_data", format: .wav)
            let imageContent = Message.ImageContent(base64Data: "image_data", mimeType: "image/jpeg")

            let message = Message(
                role: .user,
                content: .parts([
                    .text("Describe both the audio and the image"),
                    .audio(audioContent),
                    .image(imageContent)
                ])
            )

            if case .parts(let parts) = message.content {
                #expect(parts.count == 3)

                // Verify each part type
                var hasText = false
                var hasAudio = false
                var hasImage = false

                for part in parts {
                    switch part {
                    case .text:
                        hasText = true
                    case .audio:
                        hasAudio = true
                    case .image:
                        hasImage = true
                    }
                }

                #expect(hasText)
                #expect(hasAudio)
                #expect(hasImage)
            } else {
                Issue.record("Expected parts content")
            }
        }

        @Test("Message with audio Codable round-trip")
        func messageCodableRoundTrip() throws {
            let audioContent = Message.AudioContent(base64Data: "test_audio", format: .flac)
            let original = Message(
                role: .user,
                content: .parts([
                    .text("Transcribe this"),
                    .audio(audioContent)
                ])
            )

            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Message.self, from: encoded)

            #expect(original.id == decoded.id)
            #expect(original.role == decoded.role)

            if case .parts(let parts) = decoded.content {
                #expect(parts.count == 2)
                if case .audio(let audio) = parts[1] {
                    #expect(audio.base64Data == "test_audio")
                    #expect(audio.format == .flac)
                } else {
                    Issue.record("Expected audio part")
                }
            } else {
                Issue.record("Expected parts content")
            }
        }
    }

    // MARK: - Edge Case Tests

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Empty base64 data is handled gracefully")
        func emptyBase64Data() {
            // Should not crash, but may be invalid for actual API calls
            let audio = Message.AudioContent(base64Data: "", format: .wav)
            #expect(audio.base64Data == "")
            #expect(audio.format == .wav)
        }

        @Test("Large base64 data is preserved correctly")
        func largeBase64Data() {
            // Simulate a larger audio file (1KB of repeated pattern)
            let largeData = String(repeating: "SGVsbG8gV29ybGQh", count: 64)
            let audio = Message.AudioContent(base64Data: largeData, format: .flac)

            #expect(audio.base64Data == largeData)
            #expect(audio.base64Data.count == 16 * 64)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
