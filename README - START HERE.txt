STREAM DECK AUTO-RECOVER - FRESH v1.1 UI FIX
==============================================

V1.1 STARTUP/UI FIX
-------------------
Fresh v1 had a Win32/Go threading bug in the helper application. The window was
created without pinning the GUI message loop to a single Windows OS thread.
Win32 requires the window and message pump to stay on the same thread.

v1.1 fixes that with runtime.LockOSThread() before creating the window.

DETECTION LOGIC IS UNCHANGED
----------------------------
- Elgato's own deviceDidDisconnect event is the trigger.
- The physical USB drop can last only a split millisecond.
- After that event, the helper waits 350 ms for Elgato's own deviceDidConnect
  for the same Stream Deck ID.
- A Windows USB reconnect by itself does NOT cancel recovery.
- If Elgato still has not reported connected, the selected Windows device is
  forced through disable -> enable -> rescan.
- Serial number is never used.


THIS IS A FROM-SCRATCH REBUILD
------------------------------
The old approach was wrong for the failure you actually have.

Your real failure pattern:

  1. Stream Deck drops for only a split millisecond.
  2. Windows sees it again almost immediately.
  3. The Elgato Stream Deck SOFTWARE can remain disconnected/unresponsive.
  4. In the Stream Deck software, the serial number is no longer readable while
     the problem is happening.
  5. Manually disabling and re-enabling the Stream Deck device in Windows fixes it.

Fresh v1 does NOT wait for Windows to notice a long USB disconnect.
It does NOT rely on the serial number.

DETECTION SOURCE: ELGATO SOFTWARE ITSELF
----------------------------------------
A tiny native Stream Deck plugin connects to Elgato's official plugin WebSocket.
It listens for the Stream Deck application's own:

    deviceDidDisconnect
    deviceDidConnect

The disconnect event includes Elgato's device ID even when serial-number data is
not readable, so serial number is not used as the identity key.

RECOVERY LOGIC
--------------
When Elgato software reports your selected Stream Deck DISCONNECTED:

    deviceDidDisconnect
            |
            v
       wait 350 ms
            |
            v
    Did ELGATO SOFTWARE report deviceDidConnect for the same device ID?
            |
       +----+----+
       |         |
      YES       NO
       |         |
   cancel     force Windows reset
                 |
                 v
       pnputil /disable-device <selected exact PnP instance>
       wait 1.1 sec
       pnputil /enable-device <same exact PnP instance>
       pnputil /scan-devices

IMPORTANT:
A physical USB reconnect by itself does NOT cancel recovery. Only the Elgato
software's own deviceDidConnect event cancels it.

WHY THERE ARE TWO DROPDOWNS
---------------------------
1. "Stream Deck reported by Elgato software"
   This chooses which Elgato software device connection to MONITOR.

2. "Windows device to reset"
   This chooses the exact Device Manager / PnP entry to disable and re-enable.
   Use Test Reset to find the same entry that reproduces your successful manual fix.

INSTALL
-------
1. Double-click:
       1 - Install Elgato Sensor.cmd

2. Completely QUIT the Elgato Stream Deck app from its Windows system-tray icon.
   Closing only the main window is not enough.

3. Reopen Elgato Stream Deck.

4. Double-click:
       StreamDeckAutoRecover.exe

5. Accept the Administrator prompt. Windows requires elevation to disable/enable
   PnP devices.

6. Wait for the top dropdown to populate from Elgato software.

7. Choose the Stream Deck to monitor.

8. Choose the Windows reset target in the second dropdown and click Test reset.
   Pick the entry that performs the same recovery as your manual Device Manager fix.

9. Click Start monitoring.

SYSTEM TRAY
-----------
The helper has a Windows tray icon. Minimizing or closing the main window hides it
while monitoring continues. Right-click the tray icon to reopen, start/stop, or exit.

LOGS
----
The sensor writes a log to:

    %LOCALAPPDATA%\StreamDeckAutoRecover\sensor.log

Use Open Sensor Logs.cmd to open that folder.

If a glitch happens, the helper log should show:

    Elgato software says DISCONNECTED
    Verifying Elgato software state in 350 ms

Then either:

    Elgato software says CONNECTED
    Recovery canceled

or, for the bad failure:

    Elgato software STILL reports disconnected
    Forcing Windows disable -> enable

SERIAL NUMBER NOTE
------------------
This build intentionally does NOT query or depend on the Stream Deck serial number.
The fact that the serial becomes unreadable in Stream Deck software during the fault
is useful confirmation that the Elgato software connection state is the right thing
to watch, but the detector uses Elgato's SDK device ID and connection events instead.

SOURCE
------
The Go source for both executables is included in the source folder for inspection
or future GitHub publication.
