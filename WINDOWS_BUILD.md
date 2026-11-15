# Windows-compatible build instructions — Snap Request Assistant

You are on Windows. iOS apps cannot be compiled on Windows directly, and Xcode does not run on Windows. The supported path is:

## 1. Put this folder on GitHub

1. Create a new repository on github.com (for example `SnapRequestAssistantIOS`), public so GitHub Actions is free.
2. Upload / push this whole folder, including `.github/workflows/build.yml`.
3. Do not add any secrets. This app needs no API key, no Snapchat password, and no signing certificate in GitHub.

## 2. Run the build in GitHub Actions

1. On GitHub, open the repo → **Actions** → **Snap Request Assistant tests and unsigned IPA** → **Run workflow**.
2. Wait for the job to finish. It runs `xcodegen generate`, runs the Swift tests (best effort), builds the device app unsigned, and packages `SnapRequestAssistant-unsigned.ipa`.
3. Download the artifact named `SnapRequestAssistant-unsigned-ipa` from the completed run.
4. Verify before installing: unzip the IPA and check it contains `Payload/SnapRequestAssistant.app`, bundle id `com.shaik.snaprequestassistant`, version 1.0.0 build 1. If the workflow failed or produced no IPA, do not claim an installable IPA exists.

## 3. Install on your iPhone from Windows

Use Sideloadly or AltStore (both sign with your own Apple ID on your PC):

**Sideloadly (usual path)**
1. Install Sideloadly on Windows and iTunes / Apple Devices support so the PC sees the iPhone.
2. Connect the iPhone by USB, trust the computer on the phone.
3. In Sideloadly, choose your iPhone, enter your Apple ID, drag in `SnapRequestAssistant-unsigned.ipa`, and Start.
4. On the iPhone, go to Settings → General → VPN & Device Management, trust your Apple ID developer certificate, then open **Snap Request Assistant**.

**AltStore (alternative)**
1. Install AltServer on Windows, install AltStore on the iPhone with your Apple ID.
2. Open the IPA in AltStore (or send it to the phone and open with AltStore).
3. Trust the certificate as above if prompted.

Free Apple ID signing expires in about 7 days. Re-sideload the same IPA to renew it. This is a sideloaded unsigned-origin build, not an App Store build, and it will not update itself.

## 4. Using the 2-hour cycle on the phone

1. Open the app → Home → tap **Start**. Allow notifications when asked, or reminders will not fire.
2. Every 2 hours you get a notification that only opens this app.
3. If you choose to do a Snapchat step, tap **Open Snapchat**, do it yourself in Snapchat, come back, and tap the matching confirmation. If you do not want to do anything, tap **Pause** or **Stop**.
4. Do not tap a confirmation for a step you did not actually do in Snapchat — history is only honest if you do that.

## 5. If you have a Mac

On a Mac with Xcode 16: `brew install xcodegen`, then `xcodegen generate`, open `SnapRequestAssistant.xcodeproj`, select your iPhone, and Run. Xcode will sign with your Apple ID for development.
