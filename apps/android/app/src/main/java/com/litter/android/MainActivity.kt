package com.litter.android

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.litter.android.core.bridge.CodexRpcClient
import com.litter.android.core.network.ServerDiscoveryService
import com.litter.android.feature.conversation.ConversationFeature
import com.litter.android.feature.discovery.DiscoveryFeature
import com.litter.android.feature.sessions.SessionsFeature

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val rpc = CodexRpcClient()
        val discovery = DiscoveryFeature(ServerDiscoveryService())
        val sessions = SessionsFeature(rpc)
        val conversation = ConversationFeature(rpc)

        val status = buildString {
            append("Litter Android modules initialized\n")
            append("servers=${discovery.discoverServers().size}\n")
            append("sessions=${sessions.loadSessions().size}\n")
            append("turn='${conversation.sendPrompt("hello")}'")
        }

        setContentView(TextView(this).apply { text = status })
    }
}
