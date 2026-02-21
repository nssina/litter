package com.litter.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import com.litter.android.state.AppState
import com.litter.android.state.ChatMessage
import com.litter.android.state.ModelOption
import com.litter.android.state.ModelSelection
import com.litter.android.state.ServerConnectionStatus
import com.litter.android.state.ServerManager
import com.litter.android.state.ThreadKey
import com.litter.android.state.ThreadState
import com.litter.android.state.ThreadStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.io.Closeable

data class DirectoryPickerUiState(
    val isVisible: Boolean = false,
    val currentPath: String = "",
    val entries: List<String> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

data class UiShellState(
    val isSidebarOpen: Boolean = false,
    val connectionStatus: ServerConnectionStatus = ServerConnectionStatus.DISCONNECTED,
    val connectionError: String? = null,
    val serverCount: Int = 0,
    val models: List<ModelOption> = emptyList(),
    val selectedModelId: String? = null,
    val selectedReasoningEffort: String? = "medium",
    val sessions: List<ThreadState> = emptyList(),
    val activeThreadKey: ThreadKey? = null,
    val messages: List<ChatMessage> = emptyList(),
    val draft: String = "",
    val isSending: Boolean = false,
    val currentCwd: String = "/",
    val directoryPicker: DirectoryPickerUiState = DirectoryPickerUiState(),
    val uiError: String? = null,
)

interface LitterAppState : Closeable {
    val uiState: StateFlow<UiShellState>

    fun toggleSidebar()

    fun dismissSidebar()

    fun selectModel(modelId: String)

    fun selectReasoningEffort(effort: String)

    fun selectSession(threadKey: ThreadKey)

    fun updateDraft(value: String)

    fun refreshSessions()

    fun openNewSessionPicker()

    fun dismissDirectoryPicker()

    fun navigateDirectoryInto(entry: String)

    fun navigateDirectoryUp()

    fun confirmStartSessionFromPicker()

    fun sendDraft()

    fun interrupt()

    fun clearUiError()
}

class DefaultLitterAppState(
    private val serverManager: ServerManager,
) : LitterAppState {
    private val _uiState = MutableStateFlow(UiShellState())
    override val uiState: StateFlow<UiShellState> = _uiState.asStateFlow()

    private val observerHandle: Closeable =
        serverManager.observe { backend ->
            mergeBackendState(backend)
        }

    init {
        connectAndPrime()
    }

    override fun close() {
        observerHandle.close()
        serverManager.close()
    }

    override fun toggleSidebar() {
        _uiState.update { it.copy(isSidebarOpen = !it.isSidebarOpen) }
    }

    override fun dismissSidebar() {
        _uiState.update { it.copy(isSidebarOpen = false) }
    }

    override fun selectModel(modelId: String) {
        serverManager.updateModelSelection(modelId = modelId)
    }

    override fun selectReasoningEffort(effort: String) {
        serverManager.updateModelSelection(reasoningEffort = effort)
    }

    override fun selectSession(threadKey: ThreadKey) {
        val session = _uiState.value.sessions.firstOrNull { it.key == threadKey } ?: return
        serverManager.selectThread(threadKey = threadKey, cwdForLazyResume = session.cwd) { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to resume session")
            }
            result.onSuccess {
                _uiState.update { it.copy(isSidebarOpen = false) }
            }
        }
    }

    override fun updateDraft(value: String) {
        _uiState.update { it.copy(draft = value) }
    }

    override fun refreshSessions() {
        serverManager.refreshSessions { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to refresh sessions")
            }
        }
    }

    override fun openNewSessionPicker() {
        val current = _uiState.value.currentCwd.trim()
        _uiState.update {
            it.copy(
                directoryPicker =
                    it.directoryPicker.copy(
                        isVisible = true,
                        currentPath = if (current.isNotEmpty()) current else it.directoryPicker.currentPath,
                        errorMessage = null,
                    ),
            )
        }

        val targetPath =
            if (current.isNotEmpty()) {
                current
            } else {
                _uiState.value.directoryPicker.currentPath.trim()
            }

        if (targetPath.isNotEmpty()) {
            loadDirectory(targetPath)
            return
        }

        serverManager.resolveHomeDirectory { result ->
            result.onFailure {
                loadDirectory("/")
            }
            result.onSuccess { home ->
                loadDirectory(home.ifBlank { "/" })
            }
        }
    }

    override fun dismissDirectoryPicker() {
        _uiState.update {
            it.copy(
                directoryPicker =
                    it.directoryPicker.copy(
                        isVisible = false,
                        errorMessage = null,
                        isLoading = false,
                    ),
            )
        }
    }

    override fun navigateDirectoryInto(entry: String) {
        val current = _uiState.value.directoryPicker.currentPath.ifBlank { "/" }
        val target =
            if (current == "/") {
                "/$entry"
            } else {
                "$current/$entry"
            }
        loadDirectory(target)
    }

    override fun navigateDirectoryUp() {
        val current = _uiState.value.directoryPicker.currentPath.ifBlank { "/" }
        if (current == "/") {
            loadDirectory("/")
            return
        }
        val trimmed = current.trimEnd('/')
        val up = trimmed.substringBeforeLast('/', "/").ifBlank { "/" }
        loadDirectory(up)
    }

    override fun confirmStartSessionFromPicker() {
        val snapshot = _uiState.value
        val cwd = snapshot.directoryPicker.currentPath.ifBlank { snapshot.currentCwd }
        val modelSelection =
            ModelSelection(
                modelId = snapshot.selectedModelId,
                reasoningEffort = snapshot.selectedReasoningEffort,
            )
        serverManager.startThread(cwd = cwd, modelSelection = modelSelection) { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to start session")
            }
            result.onSuccess {
                _uiState.update {
                    it.copy(
                        isSidebarOpen = false,
                        directoryPicker = it.directoryPicker.copy(isVisible = false, errorMessage = null),
                    )
                }
                refreshSessions()
            }
        }
    }

    override fun sendDraft() {
        val snapshot = _uiState.value
        val prompt = snapshot.draft.trim()
        if (prompt.isEmpty() || snapshot.isSending) {
            return
        }

        _uiState.update { it.copy(draft = "") }

        val modelSelection =
            ModelSelection(
                modelId = snapshot.selectedModelId,
                reasoningEffort = snapshot.selectedReasoningEffort,
            )

        serverManager.sendMessage(
            text = prompt,
            cwd = snapshot.currentCwd,
            modelSelection = modelSelection,
        ) { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to send message")
            }
        }
    }

    override fun interrupt() {
        serverManager.interrupt { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to interrupt turn")
            }
        }
    }

    override fun clearUiError() {
        _uiState.update { it.copy(uiError = null) }
    }

    private fun connectAndPrime() {
        serverManager.connectLocalDefaultServer { result ->
            result.onFailure { error ->
                setUiError(error.message ?: "Failed to connect")
            }
            result.onSuccess {
                serverManager.loadModels { modelsResult ->
                    modelsResult.onFailure { error ->
                        setUiError(error.message ?: "Failed to load models")
                    }
                }
                refreshSessions()
            }
        }
    }

    private fun loadDirectory(path: String) {
        val normalized = path.trim().ifEmpty { "/" }
        _uiState.update {
            it.copy(
                directoryPicker =
                    it.directoryPicker.copy(
                        isVisible = true,
                        currentPath = normalized,
                        isLoading = true,
                        errorMessage = null,
                        entries = emptyList(),
                    ),
            )
        }

        serverManager.listDirectories(normalized) { result ->
            result.onFailure { error ->
                _uiState.update {
                    it.copy(
                        directoryPicker =
                            it.directoryPicker.copy(
                                isVisible = true,
                                currentPath = normalized,
                                isLoading = false,
                                entries = emptyList(),
                                errorMessage = error.message ?: "Failed to list directory",
                            ),
                    )
                }
            }
            result.onSuccess { directories ->
                _uiState.update {
                    it.copy(
                        directoryPicker =
                            it.directoryPicker.copy(
                                isVisible = true,
                                currentPath = normalized,
                                isLoading = false,
                                entries = directories,
                                errorMessage = null,
                            ),
                    )
                }
            }
        }
    }

    private fun mergeBackendState(backend: AppState) {
        val activeThread = backend.activeThread
        _uiState.update { current ->
            current.copy(
                connectionStatus = backend.connectionStatus,
                connectionError = backend.connectionError,
                serverCount = backend.servers.size,
                models = backend.availableModels,
                selectedModelId = backend.selectedModel.modelId,
                selectedReasoningEffort = backend.selectedModel.reasoningEffort,
                sessions = backend.threads,
                activeThreadKey = backend.activeThreadKey,
                messages = activeThread?.messages ?: emptyList(),
                isSending = activeThread?.status == ThreadStatus.THINKING,
                currentCwd = backend.currentCwd,
            )
        }
    }

    private fun setUiError(message: String) {
        _uiState.update { it.copy(uiError = message) }
    }
}

@Composable
fun rememberLitterAppState(
    serverManager: ServerManager,
): LitterAppState {
    val appState = remember(serverManager) { DefaultLitterAppState(serverManager = serverManager) }
    DisposableEffect(appState) {
        onDispose { appState.close() }
    }
    return appState
}
