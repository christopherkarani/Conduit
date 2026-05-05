import Foundation
import Testing

@Suite("Package manifest stability")
struct PackageManifestStabilityTests {
    @Test("MLX text graph excludes unstable StableDiffusion examples package")
    func mlxTextGraphExcludesUnstableStableDiffusionPackage() throws {
        let manifest = try String(contentsOf: packageManifestURL(), encoding: .utf8)

        #expect(manifest.contains("includeMLXImageDependencies"))

        let blocks = includeMLXDependencyBlocks(in: manifest)
        #expect(blocks.count == 3)

        for block in blocks {
            #expect(!block.contains("mlx-swift-examples"))
            #expect(!block.contains("StableDiffusion"))
        }
    }

    @Test("Stable consumer graph has no unconditional branch or revision dependencies")
    func stableConsumerGraphHasNoUnconditionalUnstableDependencies() throws {
        let manifest = try String(contentsOf: packageManifestURL(), encoding: .utf8)

        let unstablePackageLines = manifest
            .split(separator: "\n")
            .filter { line in
                line.contains(".package")
                    && (line.contains("revision:") || line.contains("branch:"))
            }

        #expect(unstablePackageLines.allSatisfy { $0.contains("mlx-swift-examples") })
    }

    private func packageManifestURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let candidate = url.deletingLastPathComponent().appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Package.swift")
    }

    private func includeMLXDependencyBlocks(in manifest: String) -> [Substring] {
        var blocks: [Substring] = []
        var searchStart = manifest.startIndex
        let marker = "if includeMLXDependencies {"

        while let range = manifest.range(of: marker, range: searchStart..<manifest.endIndex),
              let blockEnd = endOfBalancedBlock(startingAt: range.lowerBound, in: manifest) {
            blocks.append(manifest[range.lowerBound..<blockEnd])
            searchStart = blockEnd
        }

        return blocks
    }

    private func endOfBalancedBlock(startingAt start: String.Index, in text: String) -> String.Index? {
        var depth = 0
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return text.index(after: index)
                }
            }
            index = text.index(after: index)
        }

        return nil
    }
}
