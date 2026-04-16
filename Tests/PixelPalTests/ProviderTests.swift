import Testing
import Foundation
@testable import PixelPalCore

@Suite("ProviderAdapter")
struct ProviderTests {

    @Test("Registry contains 3 providers")
    func registrySize() {
        #expect(ProviderRegistry.all.count == 3)
    }

    @Test("Provider IDs are unique")
    func uniqueIds() {
        let ids = ProviderRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Lookup by ID works")
    func lookupById() {
        #expect(ProviderRegistry.adapter(for: "claude-code") != nil)
        #expect(ProviderRegistry.adapter(for: "codex") != nil)
        #expect(ProviderRegistry.adapter(for: "aider") != nil)
        #expect(ProviderRegistry.adapter(for: "nonexistent") == nil)
    }

    @Test("Claude Code supports native remote")
    func claudeCodeRemote() {
        let adapter = ProviderRegistry.adapter(for: "claude-code")!
        #expect(adapter.supportsNativeRemote == true)
    }

    @Test("Codex and Aider do not support native remote")
    func codexAiderNoRemote() {
        let codex = ProviderRegistry.adapter(for: "codex")!
        let aider = ProviderRegistry.adapter(for: "aider")!
        #expect(codex.supportsNativeRemote == false)
        #expect(aider.supportsNativeRemote == false)
    }

    @Test("Display names are human-readable")
    func displayNames() {
        for provider in ProviderRegistry.all {
            #expect(!provider.displayName.isEmpty)
            #expect(provider.displayName != provider.id) // should be human-friendly, not raw ID
        }
    }

    @Test("ClaudeCodeAdapter extracts remote URL from stdout line")
    func claudeRemoteURLParsing() {
        let adapter = ProviderRegistry.adapter(for: "claude-code")!
        let event = adapter.parseOutput("Remote session ready: https://claude.ai/chat/abc123")
        if case .remoteURL(let url) = event {
            #expect(url.hasPrefix("https://claude.ai/chat/"))
        } else {
            Issue.record("Expected .remoteURL, got \(String(describing: event))")
        }
    }

    @Test("ClaudeCodeAdapter returns nil for non-URL lines")
    func claudeIgnoresUnrelatedLines() {
        let adapter = ProviderRegistry.adapter(for: "claude-code")!
        #expect(adapter.parseOutput("some random output") == nil)
        #expect(adapter.parseOutput("https://github.com/example") == nil)
    }
}
