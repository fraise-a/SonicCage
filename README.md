# SonicCage

SonicCage is a small macOS menu-bar utility for games that forget to capture the mouse. It recentres the pointer before it reaches the screen edge while preserving mouse-movement events for **Sonic Dream Team** (or another app you choose), so the camera keeps responding and the Dock cannot be triggered.

## Use

1. Open `SonicCage/Package.swift` in Xcode, or open the included `SonicCage.app` after building.
2. Click the lock icon in the menu bar and choose **Open Accessibility Settings…**. Enable the **SonicCage** entry, then return to the app; it rechecks the permission when it becomes active.
3. Leave **Arm SonicCage** on. It recognises `SonicDreamTeam.app` by default, only begins confining the cursor when the game is frontmost, and immediately releases on any focus change, game quit, or SonicCage quit.
4. Use the **Emergency Toggle** at any time to turn the cage on or off. It defaults to **⌥⌘L**, but you can choose another combination in Settings. This is intentionally global, so it remains an escape hatch even if the mouse cannot reach the menu bar.
5. To start it automatically, enable **Launch SonicCage at login** in Settings. macOS may ask you to approve the background item; the app provides a button that takes you directly to that System Settings page.

The default bottom margin is 16 points. Adjust all four margins in **Settings**. For multiple displays, the default locks the pointer to whichever display it is on when the game comes forward. Disable that setting if you want to travel between displays while retaining the edge margins.

## Build

This is a Swift Package intended to open directly in Xcode 16+ as a buildable macOS project. You can also run:

```text
./script/build_and_run.sh
```

The script creates `dist/SonicCage.app`, signs it ad hoc for local development, and launches it. It is not a notarized distribution build.

The development signature embeds a stable SonicCage identifier rather than a build-specific hash, so an Accessibility approval for this app bundle persists across rebuilds. After installing this revision, grant Accessibility permission once more to the current SonicCage entry.

The active bundled app icon is the Liquid Glass variant in `Assets/SonicCage-icon-liquid-glass.png`, packaged as `Assets/SonicCage-liquid-glass.icns`.

The rename uses the distinct identity `com.fraise.SonicCage`, so macOS will ask for Accessibility permission once for SonicCage even if you previously allowed Cursor Cage.

## Safety notes

- SonicCage never runs while the selected game is not frontmost.
- It only suppresses pointer movement or dragging that would cross the configured display edge; clicks and keyboard input are untouched.
- If the system disables the event tap, SonicCage attempts to re-enable it only while it is actively protecting the selected game.
- Quitting the app removes the event tap immediately.
