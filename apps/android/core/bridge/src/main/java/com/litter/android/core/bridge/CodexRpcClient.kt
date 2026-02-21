package com.litter.android.core.bridge

data class SessionSummary(
    val id: String,
    val title: String,
)

class CodexRpcClient {
    fun listSessions(): List<SessionSummary> {
        // Placeholder until WebSocket + JSON-RPC client is ported.
        return emptyList()
    }

    fun startTurn(prompt: String): String {
        // Placeholder until real streaming response implementation lands.
        return "TODO: bridge turn for prompt '$prompt'"
    }
}
