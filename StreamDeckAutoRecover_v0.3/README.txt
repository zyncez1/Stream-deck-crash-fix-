STREAM DECK AUTO-RECOVER v0.3
================================

WHAT CHANGED
------------
- PowerShell console is now hidden.
- Real Windows system-tray icon added.
- Minimize sends the app to the tray.
- Clicking X sends the app to the tray instead of killing the watchdog.
- Double-click the tray icon to reopen the window.
- Right-click tray icon:
    * Open Stream Deck Auto-Recover
    * Start / Stop monitoring
    * Exit
- Tray tooltip shows monitoring/connection status.
- Still requires NO .NET SDK.

HOW TO RUN
----------
Double-click:
    Run-Now.cmd

The little CMD launcher disappears immediately. Windows may show an
Administrator/UAC prompt. After accepting, only the normal app window should
appear — no permanent PowerShell console.

SYSTEM TRAY
-----------
While running you should see a Stream Deck Auto-Recover icon in the Windows
notification area. Windows may put it under the ^ hidden-icons menu.

Minimize the main window:
    -> it disappears from the taskbar
    -> watchdog keeps running
    -> tray icon remains

Click X:
    -> same behavior; it keeps running

Right-click tray icon -> Exit:
    -> this actually shuts the watchdog down.

MONITORING BEHAVIOR
-------------------
The selected exact Windows device instance is monitored.

If it disappears continuously for the configured threshold (default 3.0 sec):
    disable selected instance
    wait 1.25 sec
    enable selected instance
    rescan devices
    wait for that exact instance to reconnect

A short disconnect under 3 seconds cancels the recovery.

FIRST TEST
----------
1. Run Run-Now.cmd.
2. Accept UAC.
3. Select the same Stream Deck entry you previously tested.
4. Click Test reset selected device.
5. Start monitoring.
6. Minimize the window.
7. Check the Windows system tray / hidden-icons ^ area.
