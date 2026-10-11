import SwiftUI

@main
struct BackMirrorApp: App {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var server = LocalMirrorServer(port: 8080)
    
    var body: some Scene {
        WindowGroup {
            ContentView(cameraManager: cameraManager, server: server)
                .onAppear {
                    setupBridge()
                }
        }
    }
    
    private func setupBridge() {
        // Wire camera frame output directly to WebSocket broadcaster
        cameraManager.onFrameCaptured = { [weak server] jpegData in
            server?.broadcastFrame(jpegData)
        }
        
        // Wire hardware state changes (torch, zoom, camera position) to web clients
        cameraManager.onStateChanged = { [weak server] isTorchOn, hasTorch, zoomFactor, isBackCamera in
            server?.broadcastStateUpdate(torch: isTorchOn, hasTorch: hasTorch, zoom: zoomFactor, isBackCamera: isBackCamera)
        }
        
        // Assign cameraManager directly as delegate (prevents weak delegate deallocation bug)
        server.delegate = cameraManager
    }
}
