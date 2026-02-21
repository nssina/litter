# codex-ios

iOS app embedding the [codex](https://github.com/openai/codex) coding agent as an in-process Rust library via C FFI and a local WebSocket JSON-RPC server.

## Prerequisites

- **Xcode.app** (not just Command Line Tools) — required for iOS SDKs. Install from the App Store, then:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- **Rust** with iOS targets:
  ```bash
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```
- The codex repo checked out at `~/dev/codex` (sibling of this repo)

## Build

### 1. Compile the Rust bridge

```bash
./scripts/build-rust.sh
```

Cross-compiles `codex-bridge` for device (`aarch64-apple-ios`) and both simulator architectures, lipo-merges the simulator slices, then packages into `Frameworks/codex_bridge.xcframework`.

### 2. Open the Xcode project

```bash
open CodexIOS.xcodeproj
```

The project is pre-configured (via xcodegen from `project.yml`) with:
- Bridging header pointing to `Sources/CodexIOS/Bridge/codex_bridge_objc.h`
- `codex_bridge.xcframework` embedded and linked
- `Security.framework`, `SystemConfiguration.framework` linked
- `NSLocalNetworkUsageDescription` in Info.plist

Set your Team in the Signing & Capabilities tab, then build.

### 3. Configure and run

Launch → tap **Configure & Connect** → enter your OpenAI API key → tap Connect.

## Regenerate the Xcode project

If you add or remove Swift files, regenerate the `.xcodeproj` from `project.yml`:

```bash
brew install xcodegen   # once
xcodegen generate
```

## Architecture

```
SwiftUI Views (ConversationView, SettingsView, …)
    ↓
ConversationStore (@MainActor ObservableObject)
    ↓
JSONRPCClient (actor, URLSessionWebSocketTask)
    ↓  ws://127.0.0.1:{port}
codex_bridge.xcframework  (Rust staticlib)
  codex-bridge crate  →  codex-app-server  →  tokio runtime
    ↓
codex-core  →  OpenAI Responses API
```

**Flow:** app launch → `codex_start_server(&port)` (C FFI) → tokio runtime starts → app-server binds `127.0.0.1:0` → returns port → Swift WebSocket connects → `initialize` + `thread/start` → user sends `turn/start` → streaming `codex/event/*` notifications render in the UI.

## Key files

| File | Purpose |
|------|---------|
| `codex-bridge/src/lib.rs` | C FFI: `codex_start_server`, `codex_stop_server` |
| `codex-bridge/Cargo.toml` | Standalone staticlib crate; patches for openai-oss-forks of tungstenite |
| `scripts/build-rust.sh` | Cross-compile + lipo + xcframework |
| `Sources/CodexIOS/Bridge/CodexBridge.swift` | Singleton wrapping the C FFI |
| `Sources/CodexIOS/Bridge/JSONRPCClient.swift` | Actor-based WebSocket JSON-RPC multiplexer |
| `Sources/CodexIOS/Bridge/CodexProtocol.swift` | Codable types mirroring the app-server protocol |
| `Sources/CodexIOS/Models/ConversationStore.swift` | App state: messages, status, server lifecycle |
| `Sources/CodexIOS/Views/ConversationView.swift` | Main chat UI |
| `project.yml` | xcodegen spec — edit this, not the `.xcodeproj` directly |
