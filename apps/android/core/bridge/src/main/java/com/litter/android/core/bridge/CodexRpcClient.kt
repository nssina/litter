package com.litter.android.core.bridge

data class SessionSummary(
    val id: String,
    val title: String,
)

class CodexRpcClient {
    private var activePort: Int? = null

    fun ensureServerStarted(): Int {
        activePort?.let { return it }
        val startResult = NativeCodexBridge.startServerPort()
        if (startResult <= 0) {
            throw IllegalStateException("Failed to start Codex bridge server (status=$startResult)")
        }
        activePort = startResult
        return startResult
    }

    fun listSessions(): List<SessionSummary> {
        ensureServerStarted()
        // Placeholder until WebSocket + JSON-RPC client is ported.
        return emptyList()
    }

    fun startTurn(prompt: String): String {
        val port = ensureServerStarted()
        // Placeholder until real streaming response implementation lands.
        return "TODO: bridge turn for prompt '$prompt' via ws://127.0.0.1:$port"
    }

    fun stop() {
        NativeCodexBridge.stopServer()
        activePort = null
    }
}
