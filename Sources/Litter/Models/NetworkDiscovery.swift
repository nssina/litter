import Foundation
import Network
import UIKit

@MainActor
final class NetworkDiscovery: ObservableObject {
    @Published var servers: [DiscoveredServer] = []

    private var scanTask: Task<Void, Never>?

    func startScanning() {
        stopScanning()

        servers = []
        if OnDeviceCodexFeature.isEnabled {
            servers.append(DiscoveredServer(
                id: "local",
                name: UIDevice.current.name,
                hostname: "127.0.0.1",
                port: nil,
                source: .local,
                hasCodexServer: true
            ))
        }

        scanTask = Task { await scanSubnetForSSH() }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - SSH Port Scan

    private func scanSubnetForSSH() async {
        guard let (localIP, _) = Self.localIPv4Address() else { return }
        let parts = localIP.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return }
        let prefix = parts[0...2].joined(separator: ".")

        // Scan in batches to avoid overwhelming the network stack
        let batchSize = 30
        var i = 1
        while i <= 254 {
            guard !Task.isCancelled else { return }
            let end = min(i + batchSize - 1, 254)
            await withTaskGroup(of: (String, String?)?.self) { group in
                for j in i...end {
                    let ip = "\(prefix).\(j)"
                    if ip == localIP { continue }
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        let open = await Self.isPortOpen(host: ip, port: 22, timeout: 1.0)
                        guard open else { return nil }
                        let name = await Self.reverseDNS(ip)
                        return (ip, name)
                    }
                }
                for await result in group {
                    guard let (ip, name) = result else { continue }
                    let id = "ssh-\(ip)"
                    guard !servers.contains(where: { $0.id == id }) else { continue }
                    servers.append(DiscoveredServer(
                        id: id, name: name ?? ip, hostname: ip,
                        port: nil, source: .ssh, hasCodexServer: false
                    ))
                }
            }
            i = end + 1
        }
    }

    nonisolated private static func isPortOpen(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { cont in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let resumed = LockedFlag()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if resumed.setTrue() {
                        connection.cancel()
                        cont.resume(returning: true)
                    }
                case .failed, .cancelled:
                    if resumed.setTrue() {
                        connection.cancel()
                        cont.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if resumed.setTrue() {
                    connection.cancel()
                    cont.resume(returning: false)
                }
            }
        }
    }

    nonisolated private static func reverseDNS(_ ip: String) async -> String? {
        await withCheckedContinuation { cont in
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            inet_pton(AF_INET, ip, &addr.sin_addr)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    getnameinfo(sa, socklen_t(MemoryLayout<sockaddr_in>.size), &host, socklen_t(host.count), nil, 0, 0)
                }
            }
            if result == 0 {
                let name = String(cString: host)
                let cleaned = name.hasSuffix(".local") ? String(name.dropLast(6)) : name
                cont.resume(returning: cleaned != ip ? cleaned : nil)
            } else {
                cont.resume(returning: nil)
            }
        }
    }

    nonisolated private static func localIPv4Address() -> (String, String)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            guard ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                inet_ntop(AF_INET, &sin.pointee.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
            }
            return (String(cString: buf), name)
        }
        return nil
    }
}

/// Thread-safe flag for one-shot continuation resumption.
private final class LockedFlag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()
    /// Returns `true` the first time it's called; `false` thereafter.
    func setTrue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if value { return false }
        value = true
        return true
    }
}
