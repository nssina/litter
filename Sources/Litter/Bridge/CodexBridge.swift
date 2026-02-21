import Foundation

enum CodexError: Error {
    case startFailed(Int32)
    case alreadyRunning
    case unavailable
}

final class CodexBridge {
    static let shared = CodexBridge()
    static var isAvailable: Bool { OnDeviceCodexFeature.compiledIn }
    private(set) var port: UInt16 = 0
    private(set) var isRunning = false

    private init() {}

    func start() throws {
        guard Self.isAvailable, OnDeviceCodexFeature.isEnabled else {
            throw CodexError.unavailable
        }
        guard !isRunning else { throw CodexError.alreadyRunning }
#if LITTER_DISABLE_ON_DEVICE_CODEX
        throw CodexError.unavailable
#else
        var p: UInt16 = 0
        let result = codex_start_server(&p)
        guard result == 0 else { throw CodexError.startFailed(result) }
        port = p
        isRunning = true
#endif
    }

    func stop() {
#if !LITTER_DISABLE_ON_DEVICE_CODEX
        codex_stop_server()
#endif
        isRunning = false
    }
}
