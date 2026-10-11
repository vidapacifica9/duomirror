import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var server: LocalMirrorServer
    
    @State private var showCopiedAlert = false
    @State private var showPreview = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Status Banner
                        statusHeaderView
                        
                        // QR Code Card
                        if let urlString = server.localURLString {
                            qrCodeCard(urlString: urlString)
                        } else {
                            noNetworkCard
                        }
                        
                        // Hardware Quick Controls
                        hardwareControlsCard
                        
                        // Mini Live Viewfinder
                        livePreviewCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("DuoMirror")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        server.refreshIP()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            cameraManager.start()
            server.start()
            UIApplication.shared.isIdleTimerDisabled = true // Keep screen awake
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Views
    
    private var statusHeaderView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(server.connectedClientsCount > 0 ? Color.green : Color.blue)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(server.connectedClientsCount > 0 ? Color.green.opacity(0.4) : Color.blue.opacity(0.4), lineWidth: 4)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(server.connectedClientsCount > 0 ? "Streaming Active" : "Server Ready")
                    .font(.subheadline.bold())
                
                Text(server.connectedClientsCount > 0 ? "\(server.connectedClientsCount) viewer(s) connected" : "Waiting for viewer to scan QR")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // FPS badge
            Text("\(cameraManager.currentFPS) FPS")
                .font(.caption2.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
    
    private func qrCodeCard(urlString: String) -> some View {
        VStack(spacing: 16) {
            Text("Scan with 2nd Phone")
                .font(.headline)
            
            // QR Code Container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                
                QRCodeView(urlString: urlString)
                    .frame(width: 190, height: 190)
            }
            
            Text("Open native camera on iPhone, Android, iPad, or laptop to view instant mirror.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Copiable URL Pill
            Button(action: {
                UIPasteboard.general.string = urlString
                showCopiedAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.caption.bold())
                    Text(urlString)
                        .font(.caption.monospaced())
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(urlString)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
    
    private var noNetworkCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("No Local Network Found")
                .font(.headline)
            
            Text("To connect the second phone without internet:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Label("Connect both devices to the same Wi-Fi, OR", systemImage: "wifi")
                    .font(.caption)
                Label("Turn on Personal Hotspot and connect 2nd phone", systemImage: "personalhotspot")
                    .font(.caption)
            }
            .padding(.vertical, 4)
            
            Button("Refresh Connection") {
                server.refreshIP()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }
    
    private var hardwareControlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Camera & Hardware Controls")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Camera Flip Button (Front / Back)
                Button(action: {
                    cameraManager.switchCamera()
                }) {
                    HStack {
                        Image(systemName: "camera.rotate.fill")
                        Text(cameraManager.cameraPosition == .back ? "Back Camera" : "Front Camera")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                
                // Torch Button
                Button(action: {
                    cameraManager.toggleTorch()
                }) {
                    HStack {
                        Image(systemName: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        Text(cameraManager.isTorchOn ? "Torch On" : (cameraManager.hasTorch ? "Torch Off" : "No Torch"))
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(cameraManager.isTorchOn ? Color.yellow : Color(UIColor.tertiarySystemGroupedBackground))
                    .foregroundColor(cameraManager.isTorchOn ? .black : (cameraManager.hasTorch ? .primary : .secondary))
                    .cornerRadius(12)
                }
                .disabled(!cameraManager.hasTorch)
                .opacity(cameraManager.hasTorch ? 1.0 : 0.4)
            }
            
            // Zoom Selector
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Digital Zoom")
                        .font(.footnote.bold())
                    Spacer()
                    Text("1x = normal, 2x & 3x zoom into hair/neck details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    ForEach([1.0, 2.0, 3.0], id: \.self) { factor in
                        Button(action: {
                            cameraManager.setZoom(factor: CGFloat(factor))
                        }) {
                            Text("\(Int(factor))x")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(cameraManager.zoomFactor == CGFloat(factor) ? Color.blue : Color(UIColor.tertiarySystemGroupedBackground))
                                .foregroundColor(cameraManager.zoomFactor == CGFloat(factor) ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Remote Permission Toggle
            Toggle("Allow Viewer to Switch Camera", isOn: $server.allowRemoteCameraSwitch)
                .font(.footnote)
                .tint(.blue)
                .onChange(of: server.allowRemoteCameraSwitch) { _ in
                    server.broadcastStateUpdate(
                        torch: cameraManager.isTorchOn,
                        hasTorch: cameraManager.hasTorch,
                        zoom: cameraManager.zoomFactor,
                        isBackCamera: cameraManager.isBackCamera
                    )
                }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
    
    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Local Viewfinder")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation { showPreview.toggle() }
                }) {
                    Text(showPreview ? "Hide" : "Show")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }
            
            if showPreview {
                ZStack(alignment: .bottomTrailing) {
                    CameraPreviewView(session: cameraManager.captureSession)
                        .frame(height: 180)
                        .cornerRadius(12)
                        .clipped()
                    
                    Text("Phone Camera View (Unflipped)")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}
