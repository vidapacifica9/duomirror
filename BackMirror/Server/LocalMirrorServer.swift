import Foundation
import Network
import CryptoKit

protocol LocalMirrorServerDelegate: AnyObject {
    func serverDidReceiveTorchCommand(enabled: Bool)
    func serverDidReceiveZoomCommand(factor: CGFloat)
    func serverDidReceiveCameraFlipCommand()
    func serverDidRequestSync()
}

/// Lightweight embedded HTTP and WebSocket server running locally on the device using Network.framework.
final class LocalMirrorServer: ObservableObject {
    
    weak var delegate: LocalMirrorServerDelegate?
    
    @Published var allowRemoteCameraSwitch: Bool = true
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectedClientsCount: Int = 0
    @Published private(set) var localIPAddress: String?
    @Published private(set) var port: UInt16 = 8080
    
    var localURLString: String? {
        guard let ip = localIPAddress else { return nil }
        return "http://\(ip):\(port)"
    }
    
    private var listener: NWListener?
    private let serverQueue = DispatchQueue(label: "com.duomirror.serverQueue", qos: .userInteractive)
    
    // Automatic network path monitoring to detect Wi-Fi / Hotspot changes
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.duomirror.pathMonitor", qos: .utility)
    
    // Active WebSocket client connections
    private var webSocketClients = Set<ClientConnection>()
    private let clientLock = NSLock()
    
    init(port: UInt16 = 8080) {
        self.port = port
        refreshIP()
    }
    
    func refreshIP() {
        let ip = NetworkAddressHelper.getLocalIPAddress()
        DispatchQueue.main.async {
            if self.localIPAddress != ip {
                self.localIPAddress = ip
            }
        }
    }
    
    func start() {
        guard !isRunning else { return }
        refreshIP()
        
        // Start monitoring network interface changes
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            self?.refreshIP()
        }
        monitor.start(queue: monitorQueue)
        self.pathMonitor = monitor
        
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 5
            
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            params.includePeerToPeer = true
            
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
            let newListener = try NWListener(using: params, on: endpointPort)
            
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            newListener.stateUpdateHandler = { [weak self] state in
                print("LocalMirrorServer listener state: \(state)")
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("LocalMirrorServer: LISTENER READY on port \(self?.port ?? 8080)")
                    case .failed(let error):
                        self?.isRunning = false
                        print("LocalMirrorServer: LISTENER FAILED: \(error)")
                    case .cancelled:
                        self?.isRunning = false
                        print("LocalMirrorServer: LISTENER CANCELLED")
                    case .waiting(let error):
                        print("LocalMirrorServer: LISTENER WAITING: \(error)")
                    default:
                        break
                    }
                }
            }
            
            newListener.start(queue: serverQueue)
            self.listener = newListener
            
        } catch {
            print("LocalMirrorServer failed to start: \(error)")
        }
    }
    
    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
        
        clientLock.lock()
        for client in webSocketClients {
            client.connection.cancel()
        }
        webSocketClients.removeAll()
        clientLock.unlock()
        
        listener?.cancel()
        listener = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.connectedClientsCount = 0
        }
    }
    
    // MARK: - Video Frame Broadcasting
    
    /// Broadcasts a JPEG frame to all connected WebSocket clients.
    func broadcastFrame(_ jpegData: Data) {
        clientLock.lock()
        let clients = self.webSocketClients
        clientLock.unlock()
        
        guard !clients.isEmpty else { return }
        
        let frame = WebSocketFramer.makeBinaryFrame(data: jpegData)
        
        for client in clients {
            // Drop frame if client connection is already clogged to maintain minimum latency
            guard !client.isSending else { continue }
            
            client.isSending = true
            client.connection.send(content: frame, isComplete: true, completion: .contentProcessed { [weak self, weak client] error in
                client?.isSending = false
                if let error = error {
                    print("Error sending frame: \(error)")
                    if let client = client {
                        self?.removeClient(client)
                    }
                }
            })
        }
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("LocalMirrorServer: Incoming connection from \(connection.endpoint)")
        connection.start(queue: serverQueue)
        
        // Read the initial HTTP request header
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                print("LocalMirrorServer: Initial receive error: \(String(describing: error))")
                connection.cancel()
                return
            }
            
            let requestString = String(decoding: data, as: UTF8.self)
            print("LocalMirrorServer: Request received:\n\(requestString.prefix(120))")
            
            if requestString.localizedCaseInsensitiveContains("Upgrade: websocket") {
                // Handle WebSocket upgrade
                self.upgradeToWebSocket(connection: connection, request: requestString)
            } else if requestString.hasPrefix("GET ") {
                // Serve the HTML mirror client for all GET requests (including /, /index.html, query params)
                self.serveHTML(connection: connection)
            } else {
                // 404 Not Found
                print("LocalMirrorServer: Unrecognized request, returning 404")
                self.serveNotFound(connection: connection)
            }
        }
    }
    
    private func serveHTML(connection: NWConnection) {
        print("LocalMirrorServer: Serving HTML web client...")
        let htmlData = Data(WebClientContent.html.utf8)
        let responseHeaders = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(htmlData.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        Cache-Control: no-cache, no-store, must-revalidate\r
        \r
        
        """
        
        var responseData = Data(responseHeaders.utf8)
        responseData.append(htmlData)
        
        connection.send(content: responseData, isComplete: true, completion: .contentProcessed { [weak connection] error in
            if let error = error {
                print("LocalMirrorServer: Error sending HTML: \(error)")
            } else {
                print("LocalMirrorServer: HTML successfully sent!")
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                connection?.cancel()
            }
        })
    }
    
    private func serveNotFound(connection: NWConnection) {
        let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), isComplete: true, completion: .contentProcessed { [weak connection] _ in
            connection?.cancel()
        })
    }
    
    private func upgradeToWebSocket(connection: NWConnection, request: String) {
        guard let key = extractHeader(named: "Sec-WebSocket-Key", from: request) else {
            connection.cancel()
            return
        }
        
        // Calculate RFC 6455 Sec-WebSocket-Accept hash
        let magicGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = key.trimmingCharacters(in: .whitespacesAndNewlines) + magicGUID
        let hash = Insecure.SHA1.hash(data: Data(combined.utf8))
        let acceptKey = Data(hash).base64EncodedString()
        
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r
        
        """
        
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard let self = self, error == nil else {
                connection.cancel()
                return
            }
            
            let client = ClientConnection(connection: connection)
            self.addClient(client)
            self.readWebSocketMessages(for: client)
        })
    }
    
    private func readWebSocketMessages(for client: ClientConnection) {
        client.connection.receive(minimumIncompleteLength: 2, maximumLength: 4096) { [weak self, weak client] data, _, isComplete, error in
            guard let self = self, let client = client, let data = data, error == nil else {
                if let client = client {
                    self?.removeClient(client)
                }
                return
            }
            
            client.incomingBuffer.append(data)
            let messages = WebSocketFramer.parseMessages(buffer: &client.incomingBuffer)
            
            for message in messages {
                self.handleIncomingClientCommand(message)
            }
            
            if !isComplete {
                self.readWebSocketMessages(for: client)
            } else {
                self.removeClient(client)
            }
        }
    }
    
    private func handleIncomingClientCommand(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = dict["type"] as? String else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "set_torch":
                if let enabled = dict["value"] as? Bool {
                    self.delegate?.serverDidReceiveTorchCommand(enabled: enabled)
                }
            case "set_zoom":
                if let zoomValue = dict["value"] as? Double {
                    self.delegate?.serverDidReceiveZoomCommand(factor: CGFloat(zoomValue))
                }
            case "switch_camera":
                if self.allowRemoteCameraSwitch {
                    self.delegate?.serverDidReceiveCameraFlipCommand()
                }
            case "sync_request":
                self.delegate?.serverDidRequestSync()
            default:
                break
            }
        }
    }
    
    /// Broadcasts current hardware state to all connected web clients.
    func broadcastStateUpdate(torch: Bool, hasTorch: Bool, zoom: CGFloat, isBackCamera: Bool) {
        let payload: [String: Any] = [
            "type": "state_update",
            "torch": torch,
            "hasTorch": hasTorch,
            "zoom": Double(zoom),
            "position": isBackCamera ? "back" : "front",
            "allowCameraSwitch": allowRemoteCameraSwitch
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            broadcastTextMessage(jsonString)
        }
    }
    
    /// Broadcasts a text message (JSON) to all active WebSocket clients.
    func broadcastTextMessage(_ jsonString: String) {
        clientLock.lock()
        let clients = self.webSocketClients
        clientLock.unlock()
        
        guard !clients.isEmpty, let data = jsonString.data(using: .utf8) else { return }
        let frame = WebSocketFramer.makeTextFrame(data: data)
        for client in clients {
            client.connection.send(content: frame, isComplete: true, completion: .contentProcessed { _ in })
        }
    }
    
    private func addClient(_ client: ClientConnection) {
        clientLock.lock()
        webSocketClients.insert(client)
        let count = webSocketClients.count
        clientLock.unlock()
        
        DispatchQueue.main.async {
            self.connectedClientsCount = count
        }
    }
    
    private func removeClient(_ client: ClientConnection) {
        clientLock.lock()
        webSocketClients.remove(client)
        let count = webSocketClients.count
        clientLock.unlock()
        
        client.connection.cancel()
        
        DispatchQueue.main.async {
            self.connectedClientsCount = count
        }
    }
    
    private func extractHeader(named name: String, from request: String) -> String? {
        let lowerName = name.lowercased()
        let lines = request.components(separatedBy: "\r\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == lowerName {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}

// MARK: - Client Connection Wrapper

private final class ClientConnection: Hashable {
    let id = UUID()
    let connection: NWConnection
    var isSending = false
    var incomingBuffer = Data()
    
    init(connection: NWConnection) {
        self.connection = connection
    }
    
    static func == (lhs: ClientConnection, rhs: ClientConnection) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - WebSocket RFC 6455 Framer

enum WebSocketFramer {
    
    /// Encodes a binary payload (JPEG frame) into an unmasked server-to-client WebSocket frame.
    static func makeBinaryFrame(data: Data) -> Data {
        var frame = Data()
        // Byte 0: FIN (0x80) | Opcode Binary (0x02) = 0x82
        frame.append(0x82)
        
        let count = data.count
        if count <= 125 {
            frame.append(UInt8(count))
        } else if count <= 65535 {
            frame.append(126)
            frame.append(UInt8((count >> 8) & 0xFF))
            frame.append(UInt8(count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((count >> (i * 8)) & 0xFF))
            }
        }
        
        frame.append(data)
        return frame
    }
    
    /// Encodes a text payload (JSON string) into an unmasked server-to-client WebSocket frame.
    static func makeTextFrame(data: Data) -> Data {
        var frame = Data()
        // Byte 0: FIN (0x80) | Opcode Text (0x01) = 0x81
        frame.append(0x81)
        
        let count = data.count
        if count <= 125 {
            frame.append(UInt8(count))
        } else if count <= 65535 {
            frame.append(126)
            frame.append(UInt8((count >> 8) & 0xFF))
            frame.append(UInt8(count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((count >> (i * 8)) & 0xFF))
            }
        }
        
        frame.append(data)
        return frame
    }
    
    /// Parses incoming masked text frames sent from the web browser.
    static func parseMessages(buffer: inout Data) -> [String] {
        var messages = [String]()
        
        while buffer.count >= 2 {
            let byte0 = buffer[0]
            let byte1 = buffer[1]
            
            let opcode = byte0 & 0x0F
            let isMasked = (byte1 & 0x80) != 0
            var payloadLen = Int(byte1 & 0x7F)
            
            var headerOffset = 2
            
            if payloadLen == 126 {
                guard buffer.count >= 4 else { break }
                payloadLen = Int(buffer[2]) << 8 | Int(buffer[3])
                headerOffset = 4
            } else if payloadLen == 127 {
                guard buffer.count >= 10 else { break }
                var len64: UInt64 = 0
                for i in 0..<8 {
                    len64 = (len64 << 8) | UInt64(buffer[2 + i])
                }
                payloadLen = Int(len64)
                headerOffset = 10
            }
            
            let maskKeyLength = isMasked ? 4 : 0
            let totalFrameSize = headerOffset + maskKeyLength + payloadLen
            guard buffer.count >= totalFrameSize else { break }
            
            if opcode == 0x01 { // Text frame
                var payloadData = buffer.subdata(in: (headerOffset + maskKeyLength)..<totalFrameSize)
                if isMasked {
                    let maskKey = [UInt8](buffer[headerOffset..<(headerOffset + 4)])
                    var bytes = [UInt8](payloadData)
                    for i in 0..<bytes.count {
                        bytes[i] ^= maskKey[i % 4]
                    }
                    payloadData = Data(bytes)
                }
                if let str = String(data: payloadData, encoding: .utf8) {
                    messages.append(str)
                }
            }
            
            buffer.removeSubrange(0..<totalFrameSize)
        }
        
        return messages
    }
}
