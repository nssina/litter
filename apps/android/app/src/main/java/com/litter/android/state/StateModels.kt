package com.litter.android.state

import java.util.UUID

enum class MessageRole {
    USER,
    ASSISTANT,
    SYSTEM,
    REASONING,
}

enum class ThreadStatus {
    IDLE,
    CONNECTING,
    READY,
    THINKING,
    ERROR,
}

enum class ServerConnectionStatus {
    DISCONNECTED,
    CONNECTING,
    READY,
    ERROR,
}

enum class ServerSource {
    LOCAL,
    REMOTE,
}

data class ThreadKey(
    val serverId: String,
    val threadId: String,
)

data class ServerConfig(
    val id: String,
    val name: String,
    val host: String,
    val port: Int,
    val source: ServerSource,
) {
    companion object {
        fun local(port: Int): ServerConfig =
            ServerConfig(
                id = "local",
                name = "On Device",
                host = "127.0.0.1",
                port = port,
                source = ServerSource.LOCAL,
            )
    }
}

data class ReasoningEffortOption(
    val effort: String,
    val description: String,
)

data class ModelOption(
    val id: String,
    val displayName: String,
    val description: String,
    val defaultReasoningEffort: String?,
    val supportedReasoningEfforts: List<ReasoningEffortOption>,
    val isDefault: Boolean,
)

data class ModelSelection(
    val modelId: String? = null,
    val reasoningEffort: String? = "medium",
)

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: MessageRole,
    val text: String,
    val timestampEpochMillis: Long = System.currentTimeMillis(),
    val isStreaming: Boolean = false,
)

data class ThreadState(
    val key: ThreadKey,
    val serverName: String,
    val serverSource: ServerSource,
    val status: ThreadStatus = ThreadStatus.READY,
    val messages: List<ChatMessage> = emptyList(),
    val preview: String = "",
    val cwd: String = "",
    val updatedAtEpochMillis: Long = System.currentTimeMillis(),
    val activeTurnId: String? = null,
    val lastError: String? = null,
) {
    val hasTurnActive: Boolean
        get() = status == ThreadStatus.THINKING
}

data class AppState(
    val connectionStatus: ServerConnectionStatus = ServerConnectionStatus.DISCONNECTED,
    val connectionError: String? = null,
    val servers: List<ServerConfig> = emptyList(),
    val activeServerId: String? = null,
    val threads: List<ThreadState> = emptyList(),
    val activeThreadKey: ThreadKey? = null,
    val selectedModel: ModelSelection = ModelSelection(),
    val availableModels: List<ModelOption> = emptyList(),
    val currentCwd: String = defaultWorkingDirectory(),
) {
    val activeThread: ThreadState?
        get() = activeThreadKey?.let { key ->
            threads.firstOrNull { it.key == key }
        }
}

internal fun defaultWorkingDirectory(): String =
    (System.getProperty("java.io.tmpdir") ?: "/data/local/tmp").trim().ifEmpty { "/data/local/tmp" }
