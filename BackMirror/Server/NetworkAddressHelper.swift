import Foundation

/// Helper to detect the device's local IPv4 address across Wi-Fi and Personal Hotspot interfaces.
enum NetworkAddressHelper {
    
    enum NetworkKind {
        case personalHotspot
        case wifi
        case localOther
    }
    
    /// Determines the type of network currently being used based on the resolved IP.
    static func getNetworkKind(for ip: String) -> NetworkKind {
        if ip.hasPrefix("172.20.10.") {
            return .personalHotspot
        }
        return .wifi
    }
    
    /// Returns the most appropriate local IPv4 address for hosting the mirror server.
    /// Prefers Personal Hotspot (`bridge100`), then Wi-Fi (`en0`), and excludes cellular or VPN addresses.
    static func getLocalIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        var addresses = [String: String]()
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Filter for IPv4 interfaces
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                
                // Exclude known non-routable or virtual interfaces immediately
                guard !isIgnoredInterface(name: name) else { continue }
                
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    // Only record if it is a valid, usable local network address (not loopback, not link-local)
                    if isValidUsableIP(ip: ip) {
                        addresses[name] = ip
                    }
                }
            }
        }
        
        // Priority 1: iOS Personal Hotspot bridge ("bridge100")
        // If Personal Hotspot is active, connecting the guest phone to it provides a direct,
        // zero-isolation peer-to-peer Wi-Fi connection with maximum reliability.
        if let hotspot = addresses["bridge100"] {
            return hotspot
        }
        
        // Priority 2: Primary Wi-Fi ("en0")
        if let wifi = addresses["en0"] {
            return wifi
        }
        
        // Priority 3: Alternative local adapters (e.g. secondary Wi-Fi or USB-C Ethernet)
        let tetherInterfaces = ["ap0", "en1", "en2"]
        for ifName in tetherInterfaces {
            if let ip = addresses[ifName] {
                return ip
            }
        }
        
        // Priority 4: Any valid local IP from remaining allowed network interfaces
        return addresses.values.first
    }
    
    /// Checks whether an IPv4 address is usable on a local network.
    /// Excludes loopback (127.0.0.1), link-local APIPA (169.254.x.x), and invalid subnets.
    private static func isValidUsableIP(ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        
        // Exclude loopback (127.0.0.0/8)
        if parts[0] == 127 { return false }
        
        // Exclude link-local / APIPA (169.254.0.0/16) - assigned when DHCP fails
        if parts[0] == 169 && parts[1] == 254 { return false }
        
        // Exclude 0.0.0.0 and multicast (>= 224)
        if parts[0] == 0 || parts[0] >= 224 { return false }
        
        return true
    }
    
    /// Excludes cellular data (WAN), VPN tunnels, and internal Apple interfaces
    /// that cannot be reached directly by guest devices.
    private static func isIgnoredInterface(name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasPrefix("lo") { return true }       // Loopback
        if lower.hasPrefix("pdp_ip") { return true }   // Cellular data (WAN - unreachable by peers)
        if lower.hasPrefix("utun") { return true }     // VPN tunnel (Tailscale, WireGuard, WARP, etc.)
        if lower.hasPrefix("ipsec") { return true }    // IPsec VPN tunnel
        if lower.hasPrefix("ppp") { return true }      // Point-to-Point VPN
        if lower.hasPrefix("awdl") { return true }     // Apple Wireless Direct Link (AirDrop internal)
        if lower.hasPrefix("llw") { return true }      // Low Latency WLAN internal
        if lower.hasPrefix("pan") { return true }      // Bluetooth PAN
        return false
    }
}
