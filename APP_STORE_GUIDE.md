# DuoMirror: App Store Submission Guide

This comprehensive guide details everything required to release **DuoMirror** on the Apple App Store.

---

## 1. Technical Readiness (Already Completed)

The codebase has already been prepared with all mandatory Apple submission requirements:

* [x] **Production App Icon:** 1024x1024 PNG asset catalog (`Assets.xcassets/AppIcon.appiconset`) configured and verified.
* [x] **Apple Privacy Manifest:** `PrivacyInfo.xcprivacy` included in the root bundle declaring zero tracking (`NSPrivacyTracking = false`) and zero data collection (`NSPrivacyCollectedDataTypes = []`).
* [x] **Export Compliance Exemption:** `<key>ITSAppUsesNonExemptEncryption</key><false/>` added to `Info.plist` to bypass encryption review questionnaires.
* [x] **Permission Justifications:** Clear, user-centric strings for `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription`.
* [x] **Clean Universal Build:** Verified clean compilation for iOS 16.0+ on physical devices and simulator.

---

## 2. Apple Developer Account & App Store Connect Setup

### Step A: Enroll in Apple Developer Program
1. Sign up at [developer.apple.com/programs](https://developer.apple.com/programs/) ($99 USD / year).
2. Open **Xcode -> Settings -> Accounts** and sign in with your Apple ID.

### Step B: Create the App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com) -> **Apps** -> **+** -> **New App**.
2. Fill in the initial details:
   * **Platforms:** iOS
   * **Name:** `DuoMirror` (or `DuoMirror - Smart Hair Mirror` if `DuoMirror` is taken)
   * **Primary Language:** English (U.S.)
   * **Bundle ID:** Select `com.duomirror.app` (or your unique custom bundle ID).
   * **SKU:** `duomirror-ios-01`
   * **User Access:** Full Access

---

## 3. App Store Listing Metadata (Copy & Paste Ready)

### App Information
* **Name (30 chars max):** `DuoMirror: 360 Hair & Outfit`
* **Subtitle (30 chars max):** `Smart 360° Two-Phone Mirror`
* **Primary Category:** `Lifestyle`
* **Secondary Category:** `Utilities`

### Description
```
DuoMirror turns any two phones into an instant, hands-free 360° mirror. 

Say goodbye to twisting your neck and balancing heavy mirrors to check the back of your hair or outfit. With DuoMirror, your iPhone acts as a wireless HD camera, streaming real-time video directly to any second screen—another iPhone, Android, iPad, Mac, or PC—over your private local Wi-Fi or Personal Hotspot.

NO APP NEEDED ON YOUR SECOND DEVICE.
Simply point your second device's camera at the on-screen QR code to open the ultra-low latency mirror feed instantly in Safari or Chrome.

PERFECT FOR:
• Hair Styling: Perfect your curls, braids, updos, hair extensions, and color touch-ups.
• Outfit & Fashion Check: Inspect the back of dresses, zippers, clasps, hemming, and jewelry.
• Grooming & Haircuts: Check necklines, tapers, fades, and hard-to-see blind spots.
• Travel & Getting Ready: Get a 360° salon view even in hotel bathrooms with small mirrors.

KEY FEATURES:
• Sub-50ms Real-Time View: Hardware-accelerated local streaming for zero lag.
• 100% Private, Zero Cloud: Video never touches the internet or cloud servers.
• Remote Torch: Light up dark angles or bathroom shadows directly from your viewer screen.
• 1x, 2x, 3x Digital Zoom: Inspect hair parts, braids, jewelry, or neckline details.
• Freeze Frame: Pause any angle hands-free so you don't have to hold an awkward pose.
• Natural Mirror Reflection: Flips horizontally so moving left feels completely natural.
```

### Keywords (100 chars max)
`mirror,hair,styling,haircut,dress,outfit,braids,curls,zipper,back of head,two mirror,dual camera,fashion`

### Support & Marketing URLs
* **Support URL:** Link to a GitHub README or personal website (e.g. `https://github.com/your-username/DuoMirror#support`).
* **Marketing URL (Optional):** Link to your GitHub repo or project landing page.

---

## 4. Privacy Nutrition Labels (App Store Connect)

In App Store Connect -> **App Privacy**:
1. Click **Get Started**.
2. When asked *"Do you or your third-party partners collect data from this app?"*:
   * Select **No, we do not collect data from this app**.
3. Publish the privacy declaration. Your app will receive the **"Data Not Collected"** privacy badge.

---

## 5. Required Screenshots

You need at least 1 set of iPhone screenshots for the **6.7" / 6.9" display** (1290 x 2796 pixels):

| Screenshot # | What to Showcase | Recommended Caption |
|---|---|---|
| **1** | Main iPhone screen with QR code card | *"Turn any second phone into an instant back-of-head mirror"* |
| **2** | Viewing phone running the Web Mirror | *"Zero install needed on phone #2 — Just scan the QR code"* |
| **3** | Viewing phone with Zoom / Torch active | *"Inspect haircut lines and fades with remote torch & 3x zoom"* |
| **4** | Viewing phone with Freeze Frame | *"Freeze the frame to inspect details comfortably"* |

> **Tip:** You can take screenshots directly from the **iPhone 16 Pro Max Simulator** in Xcode by pressing **Cmd + S**.

---

## 6. How to Archive and Upload in Xcode

1. In Xcode, connect your iPhone or select **Any iOS Device (arm64)** in the top destination bar.
2. Select your target **DuoMirror** -> **Signing & Capabilities** -> ensure **Automatically manage signing** is checked with your Apple Developer Team selected.
3. In the top menu, go to **Product** -> **Archive**.
4. Xcode will build the production release binary and open the **Organizer** window.
5. In the Organizer window:
   * Select your archive and click **Distribute App**.
   * Choose **App Store Connect** -> **Upload**.
   * Keep all options checked (Include bitcode/symbols, Strip Swift symbols) -> click **Next**.
   * Click **Upload**.
6. Within ~5-15 minutes, your build will appear in App Store Connect under **TestFlight** and **Builds**.
7. In App Store Connect, attach the build to your version, fill in the review contact info (your email/phone), and click **Submit for Review**!
