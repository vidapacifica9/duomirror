import Foundation
import Network
import CryptoKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

final class TestRunner: LocalMirrorServerDelegate {
    let server = LocalMirrorServer(port: 8080)
    var isTorchOn = false
    var currentZoom: CGFloat = 1.0
    var frameIndex = 0
    var timer: DispatchSourceTimer?
    
    func start() {
        server.delegate = self
        server.start()
        
        print("\n=======================================================")
        print("  🪞 BackMirror Local Server Running!")
        print("=======================================================")
        if let ip = server.localIPAddress {
            print("  📱 On your phone (same Wi-Fi): http://\(ip):8080")
        }
        print("  💻 On this Mac:                http://localhost:8080")
        print("=======================================================\n")
        print("Streaming simulated 30fps camera feed to connected clients...\n")
        
        startFrameStream()
    }
    
    func serverDidReceiveTorchCommand(enabled: Bool) {
        isTorchOn = enabled
        print("💡 [Remote Command] Torch: \(enabled ? "ON" : "OFF")")
    }
    
    func serverDidReceiveZoomCommand(factor: CGFloat) {
        currentZoom = factor
        print("🔍 [Remote Command] Zoom set to: \(factor)x")
    }
    
    private func startFrameStream() {
        let queue = DispatchQueue(label: "com.backmirror.simulatedStream", qos: .userInteractive)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(33)) // ~30 fps
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.frameIndex += 1
            if let frameData = self.generateFrame(index: self.frameIndex, zoom: self.currentZoom, torch: self.isTorchOn) {
                self.server.broadcastFrame(frameData)
            }
        }
        t.resume()
        self.timer = t
    }
    
    private func generateFrame(index: Int, zoom: CGFloat, torch: Bool) -> Data? {
        let width = 720
        let height = 1280
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Background - changes brightness if torch is on!
        if torch {
            ctx.setFillColor(red: 0.18, green: 0.22, blue: 0.35, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw grid
        ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08)
        ctx.setLineWidth(2)
        for x in stride(from: 0, to: width, by: 60) {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0, to: height, by: 60) {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
        }
        ctx.strokePath()
        
        // Animated orbiting mirror circle
        let angle = Double(index % 180) * (.pi / 90.0)
        let radius = 160.0 * Double(zoom)
        let centerX = Double(width / 2) + cos(angle) * radius
        let centerY = Double(height / 2) + sin(angle) * (radius * 0.7)
        
        // Glow
        ctx.setFillColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: centerX - 45, y: centerY - 45, width: 90, height: 90))
        
        // Center mirror badge
        let centerBox = CGRect(x: width/2 - 180, y: height/2 - 60, width: 360, height: 120)
        ctx.setFillColor(red: 0.08, green: 0.12, blue: 0.2, alpha: 0.9)
        ctx.fill(centerBox)
        ctx.setStrokeColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
        ctx.setLineWidth(4)
        ctx.stroke(centerBox)
        
        // Convert CGContext to JPEG Data
        guard let cgImage = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.65
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return data as Data
    }
}

let runner = TestRunner()
runner.start()
dispatchMain()
