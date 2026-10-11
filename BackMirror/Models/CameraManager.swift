import Foundation
import AVFoundation
import SwiftUI

/// Manages camera capture session, hardware torch, zoom factor, front/back switching, and frame output.
final class CameraManager: NSObject, ObservableObject {
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isTorchOn: Bool = false
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    @Published private(set) var permissionGranted: Bool = false
    @Published private(set) var currentFPS: Int = 0
    
    var hasTorch: Bool {
        videoDevice?.hasTorch ?? false
    }
    
    var isBackCamera: Bool {
        cameraPosition == .back
    }
    
    let captureSession = AVCaptureSession()
    
    var onFrameCaptured: ((Data) -> Void)?
    var onStateChanged: ((Bool, Bool, CGFloat, Bool) -> Void)?
    
    private let compressor = FrameCompressor()
    private let cameraQueue = DispatchQueue(label: "com.duomirror.cameraQueue", qos: .userInteractive)
    private var videoDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    
    // FPS Tracking
    private var frameCounter: Int = 0
    private var lastFPSTime: Date = Date()
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            DispatchQueue.main.async { self.permissionGranted = false }
        }
    }
    
    private func setupSession() {
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            }
            
            // Start with back camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            self.videoDevice = device
            self.currentInput = input
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }
            
            // Configure 30fps lock
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                device.unlockForConfiguration()
            } catch {
                print("Could not configure device frame duration: \(error)")
            }
            
            // Setup Video Output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true // Never buffer stale frames
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: self.cameraQueue)
            
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
            }
            
            // Orient video properly
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.captureSession.commitConfiguration()
            self.notifyStateChanged()
        }
    }
    
    func start() {
        cameraQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.captureSession.isRunning
            }
        }
    }
    
    func stop() {
        cameraQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    // MARK: - Hardware Controls
    
    func setTorch(enabled: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.isTorchOn = enabled
                self.notifyStateChanged()
            }
        } catch {
            print("Failed to toggle torch: \(error)")
        }
    }
    
    func toggleTorch() {
        setTorch(enabled: !isTorchOn)
    }
    
    func setZoom(factor: CGFloat) {
        guard let device = videoDevice else { return }
        let clampedFactor = max(1.0, min(factor, min(device.activeFormat.videoMaxZoomFactor, 5.0)))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.zoomFactor = clampedFactor
                self.notifyStateChanged()
            }
        } catch {
            print("Failed to set zoom factor: \(error)")
        }
    }
    
    func switchCamera() {
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = (self.cameraPosition == .back) ? .front : .back
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                return
            }
            
            // Turn off torch if active before switching
            if self.isTorchOn {
                self.setTorch(enabled: false)
            }
            
            self.captureSession.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.captureSession.removeInput(currentInput)
            }
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.currentInput = newInput
                self.videoDevice = newDevice
            }
            
            do {
                try newDevice.lockForConfiguration()
                newDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                newDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                newDevice.unlockForConfiguration()
            } catch {
                print("Failed to lock new device configuration: \(error)")
            }
            
            // Orient video properly
            if let videoOutput = self.captureSession.outputs.compactMap({ $0 as? AVCaptureVideoDataOutput }).first,
               let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (newPosition == .front)
                }
            }
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.cameraPosition = newPosition
                self.zoomFactor = 1.0
                self.notifyStateChanged()
            }
        }
    }
    
    private func notifyStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChanged?(self.isTorchOn, self.hasTorch, self.zoomFactor, self.cameraPosition == .back)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Track FPS
        frameCounter += 1
        let now = Date()
        if now.timeIntervalSince(lastFPSTime) >= 1.0 {
            let fps = frameCounter
            DispatchQueue.main.async { self.currentFPS = fps }
            frameCounter = 0
            lastFPSTime = now
        }
        
        // Fast GPU JPEG compression
        guard let jpegData = compressor.compress(sampleBuffer: sampleBuffer) else { return }
        onFrameCaptured?(jpegData)
    }
}

// MARK: - LocalMirrorServerDelegate

extension CameraManager: LocalMirrorServerDelegate {
    
    func serverDidReceiveTorchCommand(enabled: Bool) {
        setTorch(enabled: enabled)
    }
    
    func serverDidReceiveZoomCommand(factor: CGFloat) {
        setZoom(factor: factor)
    }
    
    func serverDidReceiveCameraFlipCommand() {
        switchCamera()
    }
    
    func serverDidRequestSync() {
        onStateChanged?(isTorchOn, hasTorch, zoomFactor, isBackCamera)
    }
}
