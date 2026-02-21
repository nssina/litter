package com.litter.android.core.network

data class DiscoveredServer(
    val id: String,
    val name: String,
    val host: String,
    val port: Int,
)

class ServerDiscoveryService {
    fun discover(): List<DiscoveredServer> {
        // Placeholder until discovery protocol from iOS flow is ported.
        return emptyList()
    }
}
