# SonicCage

SonicCage 1.1 is a small macOS menu-bar utility for games that forget to capture the mouse. It recentres the pointer before it reaches the screen edge while preserving mouse-movement events for **Sonic Dream Team** (or any games you add), so the camera keeps responding and the Dock cannot be triggered.

## Use

1. Open `SonicCage/Package.swift` in Xcode, or open the included `SonicCage.app`. **Incase gatekeeper doesn't let you open SonicCage.app then run `xattr -d com.apple.quarantine /Applications/SonicCage.app` assuming you have already moved it to the Applications folder.**
2. Click the lock icon in the menu bar and choose **Open Accessibility Settings…**. Enable the **SonicCage** entry, then return to the app; it rechecks the permission when it becomes active.
3. Leave **Arm SonicCage** on. It recognises `SonicDreamTeam.app` by default, and you can add more games in Settings. It only begins confining the cursor while a protected game is frontmost, and immediately releases on any focus change, game quit, or SonicCage quit.
4. Use the **Emergency Toggle** at any time to turn the cage on or off. It defaults to **⌥⌘L**, but you can choose another combination in Settings. This is intentionally global, so it remains an escape hatch even if the mouse cannot reach the menu bar.
5. To start it automatically, enable **Launch SonicCage at login** in Settings. macOS may ask you to approve the background item; the app provides a button that takes you directly to that System Settings page.
6. **Don't arm while a controller is connected** is enabled by default. SonicCage pauses as soon as macOS detects a supported game controller; turn it off in Settings if you use a controller and mouse together.

The menu-bar menu also includes **About SonicCage**, which shows the bundled icon, the current version, and the macOS account holder's full name.

## Updates

SonicCage 1.1 is the first release with Sparkle 2 updates. The app checks the signed HTTPS feed automatically using Sparkle's normal schedule, and **Check for Updates…** in the menu-bar menu opens Sparkle's normal update interface immediately. It does not send SonicCage analytics or system-profile reports.

Version 1.0 did not include an updater, so its users need to install 1.1 manually. Once they are on 1.1, later releases can update through Sparkle.

The default bottom margin is 16 points. Adjust all four margins in **Settings**. For multiple displays, the default locks the pointer to whichever display it is on when the game comes forward. Disable that setting if you want to travel between displays while retaining the edge margins.

## Build

This is a Swift Package intended to open directly in Xcode 16+ as a buildable macOS project. You can also run:

```text
./script/build_and_run.sh
```

The script creates `dist/SonicCage.app`, embeds Sparkle.framework and its helpers, signs it ad hoc for local development, and launches it. It is not a notarized distribution build.

Before the first updater-enabled build, run `./script/setup_sparkle_key.sh` once on the Mac that will prepare releases. It invokes Sparkle's official `generate_keys` tool, whose private key stays in the login Keychain. The script saves only the matching public key in `script/sparkle.env` for the generated app's `Info.plist`.

To prepare a local release DMG and signed appcast after the key is configured, run:

```text
./script/prepare_release.sh
```

It produces `release/archives/SonicCage-<version>.dmg` and `appcast.xml`, but never commits, tags, uploads, or publishes anything. The DMG contains SonicCage.app and an Applications alias. The appcast points to the corresponding HTTPS GitHub release asset, so upload that exact DMG and commit `appcast.xml` when publishing.

For the next release, use `./script/prepare_release.sh --next 1.2`. It changes the single version source in `script/version.env` to 1.2 and increments its numeric build number before preparing the same local artifacts.

The development signature embeds a stable SonicCage identifier rather than a build-specific hash, so an Accessibility approval for this app bundle persists across rebuilds. After installing this revision, grant Accessibility permission once more to the current SonicCage entry.

The active bundled app icon is the Liquid Glass variant in `Assets/SonicCage-icon-liquid-glass.png`, packaged as `Assets/SonicCage-liquid-glass.icns`.

The rename uses the distinct identity `com.fraise.SonicCage`, so macOS will ask for Accessibility permission once for SonicCage even if you previously allowed Cursor Cage.

## Safety notes

- SonicCage never runs while no protected game is frontmost.
- With controller pausing enabled, SonicCage releases the pointer whenever macOS reports a connected supported controller.
- It only suppresses pointer movement or dragging that would cross the configured display edge; clicks and keyboard input are untouched.
- If the system disables the event tap, SonicCage attempts to re-enable it only while it is actively protecting the selected game.
- Quitting the app removes the event tap immediately.
