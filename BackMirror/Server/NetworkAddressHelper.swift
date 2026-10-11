import Foundation

/// Helper to detect the device's local IPv4 address across Wi-Fi and Personal Hotspot interfaces.
enum NetworkAddressHelper {
    
    /// Returns the most appropriate local IPv4 address for hosting the mirror server.
    /// Prefers Wi-Fi (`en0`), followed by Personal Hotspot (`bridge100`), then cellular or fallbacks.
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
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    addresses[name] = ip
                }
            }
        }
        
        // Priority 1: Primary Wi-Fi ("en0")
        if let wifi = addresses["en0"], !wifi.hasPrefix("127.") {
            return wifi
        }
        
        // Priority 2: iOS Personal Hotspot bridge ("bridge100")
        if let hotspot = addresses["bridge100"] {
            return hotspot
        }
        
        // Priority 3: Alternative hotspot / tethering interfaces
        let tetherInterfaces = ["ap0", "en1", "en2", "pdp_ip0"]
        for ifName in tetherInterfaces {
            if let ip = addresses[ifName], !ip.hasPrefix("127.") && !ip.isEmpty {
                return ip
            }
        }
        
        // Priority 4: Any non-loopback IPv4 address
        return addresses.values.first(where: { !$0.hasPrefix("127.") && !$0.isEmpty })
    }
}
