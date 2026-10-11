# DuoMirror 🪞

A native iOS application in Swift & SwiftUI that turns any two phones into an instant, hands-free 360° mirror for hair styling, outfit checks, and grooming.

## How It Works

1. **Open DuoMirror on your iPhone** (placed behind your head, on a vanity, or shelf).
2. The app starts an embedded, zero-cloud local WebSocket server and displays a **QR Code**.
3. **Point any second phone or tablet** (iPhone, Android, iPad, Mac, Windows) at the QR code using its standard camera app.
4. It instantly opens an ultra-low latency (<50ms) mirror in Safari or Chrome:
   * **No App Needed on Phone #2:** Zero install required on the viewing device.
   * **Horizontally Mirrored:** Natural mirror reflection physics (moving left moves left).
   * **Remote Torch Control:** Light up hair or dressing room shadows remotely from the viewer screen.
   * **Remote Zoom (1x, 2x, 3x):** Inspect curls, braids, jewelry, zippers, or haircut fades with precision.
   * **Freeze Frame:** Pause any angle on screen to inspect details comfortably without holding an awkward pose.
   * **100% Private & Offline:** Streams directly peer-to-peer over local Wi-Fi or Personal Hotspot. Zero cloud, zero accounts.

---

## Architecture

* **Camera Capture:** `AVFoundation` configured for 720p @ 30fps with automatic frame dropping to prevent buffer latency.
* **Compression:** Hardware-accelerated GPU JPEG compression using `CIContext` (Metal).
* **Local Server:** Built with Apple's native `Network.framework` (`NWListener`) and RFC 6455 WebSocket framing.
* **Web Client:** Embedded HTML5/CSS/JavaScript canvas renderer with GPU `createImageBitmap` and `scaleX(-1)` mirror transform.

---

## Requirements

* iOS 16.0+
* Xcode 15.0+ / 16.0+
* Physical iPhone (camera and flashlight features require real hardware)

---

## Running the Project

1. Open `BackMirror.xcodeproj` in Xcode.
2. Connect your iPhone via USB / Wi-Fi.
3. Select your development team under **Signing & Capabilities**.
4. Press **Run** (Cmd + R).
