# SonicCage

SonicCage is a small macOS menu-bar utility for games that forget to capture the mouse during camera movement. It recentres the cursor before it reaches the screen edge while preserving mouse movement events for what this app was originally intended to target, **Sonic Dream Team**, so the camera keeps responding and the dock cannot be triggered. However, users are also free to add an app of their choice for SonicCage to target too.

## Use

1. Open `SonicCage.app` as provided as a .dmg in the releases tab.
2. Click the lock icon in the menu bar and choose **Open Accessibility Settings**. Enable the **SonicCage** entry, then return to the app; it rechecks the permission when it becomes active.
3. Leave **Arm SonicCage** on. It recognises `SonicDreamTeam.app` by default, only begins confining the cursor when the game is frontmost, and immediately releases on any focus change, game quit, or SonicCage quit.
4. Use the **Emergency Toggle** at any time to turn the cage on or off. It defaults to **⌥⌘L**, but you can choose another combination in Settings. This is intentionally global, so it remains an escape hatch even if the mouse cannot reach the menu bar.
5. To start it automatically, enable **Launch SonicCage at login** in Settings. macOS may ask you to approve the background item; the app provides a button that takes you directly to that System Settings page.

The default bottom margin is 16 points. Adjust all four margins in **Settings**. For multiple displays, the default locks the pointer to whichever display it is on when the game comes forward. Disable that setting if you want to travel between displays while retaining the edge margins.

## Safety notes

- SonicCage never runs while the selected game is not frontmost.
- It only suppresses pointer movement or dragging that would cross the configured display edge; clicks and keyboard input are untouched.
- If the system disables the event tap, SonicCage attempts to re-enable it only while it is actively protecting the selected game.
- Quitting the app removes the event tap immediately.
